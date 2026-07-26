# Analyse de l'implémentation de l'Assistant IA

> **Projet** : Migration Factory (SAP ECC 6.0+ → IFS)
> **Date d'analyse** : 2026-06-13
> **Périmètre** : Assistant IA texte → SQL (chatbot d'interrogation de la base SAP)

---

## 1. Vue d'ensemble

L'Assistant IA est un **chatbot texte-vers-SQL** qui permet à un utilisateur de poser une
question en français (« Combien y a-t-il de fournisseurs actifs ? ») et d'obtenir
automatiquement une requête SQL, son explication et le tableau de résultats.

Le système repose entièrement sur un **LLM local (Ollama)** : aucune donnée ne sort de la VM,
aucun appel à une API cloud.

### Chaîne de traitement (pipeline)

```
┌──────────────┐   question FR   ┌───────────────┐   prompt RAG   ┌──────────────┐
│  Frontend    │ ──────────────▶ │  Flask API    │ ─────────────▶ │   Ollama     │
│ AssistantIA  │                 │ /api/v1/ai/*  │                │ qwen2.5-coder│
│   (React)    │ ◀────────────── │               │ ◀───────────── │     :7b      │
└──────────────┘  résultats JSON └───────┬───────┘   {sql, expl}  └──────────────┘
                                         │
                          ┌──────────────┼──────────────┐
                          ▼              ▼              ▼
                    ┌──────────┐  ┌────────────┐  ┌──────────────┐
                    │sql_guard │  │ readonly_ai│  │ ai_query_log │
                    │ (valide) │  │ (exécute)  │  │  (journalise)│
                    └──────────┘  └────────────┘  └──────────────┘
```

### Stack technique

| Couche      | Technologie                                                        |
|-------------|--------------------------------------------------------------------|
| Modèle      | **qwen2.5-coder:7b** via Ollama (`localhost:11434`), CPU 4 cœurs    |
| Backend     | Flask Blueprint `/api/v1/ai/*`, JWT, SQLAlchemy                     |
| Validation  | `sqlparse` (analyse par tokens, pas regex)                         |
| Base        | PostgreSQL, rôle dédié `readonly_ai` (SELECT seul, timeout 30 s)    |
| Frontend    | React 18 + TypeScript + MUI (`AssistantIA.tsx`)                     |

---

## 2. Architecture backend

### 2.1 Fichiers et rôles

| Fichier | Lignes | Rôle |
|---------|--------|------|
| [api/ai_assistant.py](../backend/api/ai_assistant.py) | 553 | Blueprint Flask, routes REST, orchestration du pipeline |
| [services/ollama_service.py](../backend/services/ollama_service.py) | 386 | Communication Ollama, concurrence, keep-warm |
| [services/ai_prompt_builder.py](../backend/services/ai_prompt_builder.py) | 147 | Construction du prompt dynamique (RAG) |
| [services/ai_schema_retriever.py](../backend/services/ai_schema_retriever.py) | 249 | Sélection RAG des tables/colonnes pertinentes |
| [services/sql_guard.py](../backend/services/sql_guard.py) | 172 | Validation défensive du SQL généré |
| [services/ai_readonly_db.py](../backend/services/ai_readonly_db.py) | 68 | Moteur SQLAlchemy dédié au rôle `readonly_ai` |
| [config/ai_system_prompt.py](../backend/config/ai_system_prompt.py) | 110 | Prompt système statique (fallback) |
| [config/dataset_sap_ia.jsonl](../backend/config/dataset_sap_ia.jsonl) | 61 | Jeu d'exemples few-shot |
| [compare_prompts.py](../backend/compare_prompts.py) | 135 | Benchmark A/B prompt statique vs dynamique |

### 2.2 Enregistrement du Blueprint

Dans [api/__init__.py](../backend/api/__init__.py) :
```python
from .ai_assistant import ai_blueprint
app.register_blueprint(ai_blueprint, url_prefix=f'{API_PREFIX}/ai')   # → /api/v1/ai/*
```

Le keep-warm est démarré au boot dans [app.py](../backend/app.py) :
```python
from services.ollama_service import start_keepwarm
from services.ai_prompt_builder import get_socle
if start_keepwarm(get_socle):
    app.logger.info("Préchauffage Ollama (keep-warm) activé")
```

### 2.3 Endpoints REST (`/api/v1/ai/*`)

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| POST | `/ask` | Question FR → SQL → résultats (max 500 lignes) |
| POST | `/export` | Ré-exécute un SQL journalisé → Excel (max 50 000 lignes) |
| GET | `/templates` | Liste des analyses prédéfinies (SQL figé, sans IA) |
| POST | `/templates/<id>/run` | Exécute un template |
| POST | `/rerun` | Ré-exécute un SQL passé via `id_log` |
| GET | `/history` | Historique paginé (50/page) |
| GET | `/conversations` + `/conversations/<id>` | Gestion des conversations |
| GET | `/health` | Disponibilité Ollama + présence du modèle |

Toutes les routes sont protégées par `@jwt_required()`.

---

## 3. Le cœur : génération et exécution

### 3.1 Construction du prompt — approche RAG

Le système est passé d'un **prompt statique** (~3800 tokens, liste *toutes* les tables —
ne passe pas à l'échelle) à un **prompt dynamique RAG** beaucoup plus léger.

`build_dynamic_prompt(question, conn)` assemble :

1. **SOCLE_HEAD** (~700 tokens, **stable** → reste en cache KV d'Ollama) : règles SAP +
   dialecte PostgreSQL + format JSON attendu.
2. **Bloc schéma dynamique** (~300 tokens) : uniquement les tables pertinentes pour la
   question, avec leurs **vraies colonnes** issues du dictionnaire SAP (`sap_table_fields`).
3. **Exemples few-shot** (~200 tokens) : les 3 questions les plus proches du dataset,
   sélectionnées par recouvrement de mots.
4. **SOCLE_TAIL** : instruction finale.

> **Bénéfice clé** : seuls ~600 tokens (schéma + exemples) sont réévalués à chaque question ;
> le SOCLE_HEAD reste « chaud » dans le cache. Cela évite de ré-évaluer ~3800/4096 tokens à
> chaque appel — décisif sur un modèle 7B en CPU.

### 3.2 Sélection des tables (anti-hallucination)

`ai_schema_retriever.py` garantit que le modèle ne voit que des colonnes **réelles** :

- `_match_domain_tables()` : carte de mots-clés curée (`DOMAIN_TABLES`), p. ex.
  `"facture" → [rbkp, rseg, lfa1]`, `"stock" → [mard, mara, marc]`.
- `_fts_fallback()` : recherche plein-texte française sur le dictionnaire si la carte ne
  couvre pas la question.
- `build_schema_block()` : récupère les vraies colonnes (max 18/table), épingle toujours les
  colonnes SAP critiques (`PINNED_COLUMNS = {mandt, loevm, lvorm, loekz, stblg}`).

> Conséquence : le modèle **ne peut pas inventer** de colonnes inexistantes → l'erreur
> PostgreSQL 42703 (`undefined_column`) devient quasi impossible.

### 3.3 Appel au modèle (`ollama_service.py`)

```python
# Paramètres d'inférence (_call_chat)
model        = qwen2.5-coder:7b   # via OLLAMA_MODEL
num_ctx      = 4096               # fenêtre de contexte
num_predict  = 768                # plafond de sortie (SQL + explication)
temperature  = 0                  # déterministe
format       = json               # JSON forcé par Ollama
keep_alive   = 24h                # modèle maintenu en RAM
timeout      = 240 s              # AI_TIMEOUT_SECONDS
stream       = False
```

- **Retry** : si la première réponse n'est pas un JSON valide, un second appel correctif est
  effectué.
- **Concurrence** : `threading.Semaphore(1)` — une seule génération à la fois (VM 4 cœurs).
  Un appel concurrent renvoie **HTTP 429** (`OllamaBusyError`).
- **Keep-warm** : un thread daemon envoie une mini-génération toutes les 60 s pour maintenir
  le SOCLE_HEAD dans le cache KV. Les requêtes utilisateur préemptent le warmup.

---

## 4. Sécurité — défense en profondeur

La sécurité est multi-couches : même si le modèle génère du SQL dangereux, plusieurs barrières
indépendantes l'arrêtent.

| Couche | Contrôle | Mise en œuvre |
|--------|----------|---------------|
| **API** | Authentification | `@jwt_required()` sur toutes les routes |
| **Génération** | Validation par tokens | `sqlparse` (pas de regex) dans `sql_guard.py` |
| **Mots-clés** | Liste noire | INSERT, UPDATE, DELETE, DROP, ALTER, TRUNCATE, CREATE, GRANT, COPY, EXECUTE, DO, CALL, SET, VACUUM, MERGE, INTO… |
| **Fonctions** | Liste noire | `dblink`, `pg_sleep`, `pg_read_file`, `pg_ls_dir`, `lo_*`… |
| **Schémas** | Whitelist `public` | 3 tables seulement (`fournisseurs_a_conserver`, `sap_table_fields`, `sap_table_properties`) ; `pg_catalog`/`information_schema` bloqués |
| **Première instruction** | SELECT/WITH only | Le premier mot-clé doit être SELECT ou WITH |
| **Multi-requêtes** | Bloqué | Une seule instruction (anti-injection via `;`) |
| **Volumétrie** | Wrap LIMIT | `SELECT * FROM ( <requête> ) AS ai_sub LIMIT 500` |
| **Rôle BDD** | SELECT seul | Rôle PostgreSQL `readonly_ai`, aucun droit d'écriture |
| **Timeout serveur** | 30 s | `statement_timeout` (migration 013) |
| **Concurrence** | 1 génération | `Semaphore(1)` → HTTP 429 si occupé |
| **Audit** | Journalisation | `public.ai_query_log` (user, statut, SQL, durée, nb lignes) |

### Validation `sql_guard.validate_and_wrap()`

1. Une seule instruction (sinon rejet).
2. Premier mot-clé significatif ∈ {SELECT, WITH}.
3. Scan des mots-clés interdits (token Keyword).
4. Scan des noms de fonctions/identifiants interdits (token Name).
5. Blocage des schémas système + whitelist stricte du schéma `public`.
6. Encapsulation dans un `LIMIT` (préserve ORDER BY / LIMIT existants).

> L'analyse **par tokens** évite les faux positifs : le mot « UPDATE » dans une chaîne
> littérale ne déclenche pas de rejet.

### Exécution `readonly_ai`

- Moteur SQLAlchemy dédié (`ai_readonly_db.py`), pool minimal (`pool_size=2`).
- Utilise `exec_driver_sql()` (et non `text()`) pour ne pas casser les casts `::` ni les
  motifs `%` des `LIKE`.
- Le rôle PostgreSQL n'a **aucun** privilège INSERT/UPDATE/DELETE → application au niveau base.

---

## 5. Règles métier SAP encodées dans le prompt

Le prompt système ([ai_system_prompt.py](../backend/config/ai_system_prompt.py)) injecte les
règles non négociables du domaine SAP :

1. **Mandant** : toujours filtrer `mandt = '700'` sur les tables `raw_data`.
2. **Drapeaux de suppression** : `loevm` (fournisseurs/clients), `lvorm` (articles/équipements),
   `loekz` (achats), `stblg` (contre-passation factures).
3. **Zéros non significatifs** : codes article → `LTRIM(matnr, '0')`.
4. **Typage** : colonnes SAP en varchar → `CAST(... AS numeric)` pour les calculs,
   dates au format `YYYYMMDD`.
5. **Multilingue** : préférer `spras = 'F'` (français) pour les libellés (`makt`, `t005t`…).
6. **Dialecte** : PostgreSQL 14+ (`::cast`, `ILIKE`, `COALESCE`, `DISTINCT ON`, `LIMIT`).

---

## 6. Frontend (`AssistantIA.tsx`)

- **Route** : `/assistant-ia` (protégée, sous `Layout`) — [App.tsx](../frontend/src/App.tsx).
- **Menu** : entrée « Assistant IA » (icône `SmartToy`) — [Layout.tsx](../frontend/src/components/layout/Layout.tsx).
- **Service** : [aiService.ts](../frontend/src/services/aiService.ts) centralise les 10 appels API.

### Fonctionnalités UI

- **Chat** : champ de saisie (Entrée pour envoyer), bouton Envoyer/Stop (avec `AbortController`),
  auto-scroll, indicateur de génération.
- **Réponse** : accordéon dépliable du SQL, chips de métadonnées (nb lignes, durée, troncature),
  bouton export Excel.
- **Conversations** : liste sauvegardée, chargement/suppression, surlignage de l'active.
- **Templates** : boutons d'analyses prédéfinies (avec tooltips).
- **Historique** : onglet paginé, statut coloré (succès=vert, rejeté=orange, erreur=rouge).
- **Santé** : bandeau d'alerte si Ollama indisponible ou modèle manquant.

> **Timeout frontend** : `ASK_TIMEOUT_MS = 260 000 ms` (260 s), légèrement supérieur aux 240 s
> backend, pour absorber la latence d'inférence locale.

---

## 7. Dataset, évaluation et amélioration

### Dataset (`dataset_sap_ia.jsonl` — 61 exemples)

Format JSONL standard (messages system/user/assistant), couvrant 9 domaines métier :
fournisseurs (20), articles/stocks (11), codification IFS (5), achats (9), maintenance (6),
clients (3), dictionnaire (4), qualité des données (3). Tous validés par introspection réelle
du schéma (2026-06-11) et exécutables (vérifiés via `EXPLAIN`).

### Outils

- [docs/build_dataset.py](build_dataset.py) : régénère le dataset à partir de la liste
  `EXEMPLES` (tuples question/SQL/explication).
- [docs/eval_dataset.py](eval_dataset.py) : banc d'évaluation — mesure la validité du format
  JSON (objectif ≥90 %) et l'exécutabilité (`EXPLAIN`). ~30 min pour les 61 questions.
- [backend/compare_prompts.py](../backend/compare_prompts.py) : benchmark A/B prompt statique
  vs dynamique (détecte les régressions). ~60-90 min sur CPU.

### Trois voies d'amélioration (par ROI décroissant)

1. **Few-shot dynamique** (déjà en place) : injection des 3 exemples les plus proches.
   Très efficace sur 7B, sans fine-tuning. ✅
2. **Banc d'évaluation** : à lancer avant tout changement de prompt/modèle.
3. **Fine-tuning LoRA** (GPU requis, plus tard) : viser 200-300 exemples, enrichis par les
   questions validées de `ai_query_log`. **Non recommandé à court terme** (pas de GPU sur la VM).

---

## 8. Configuration (variables d'environnement)

```bash
OLLAMA_URL              http://localhost:11434
OLLAMA_MODEL            qwen2.5-coder:7b
AI_TIMEOUT_SECONDS      240          # timeout appel Ollama
AI_DB_USER              readonly_ai
AI_DB_PASSWORD          (secret .env)
DB_HOST                 10.190.100.58
DB_PORT                 5432
DB_NAME                 sap_migration_db
AI_KEEPWARM_ENABLED     true
AI_KEEPWARM_SECONDS     60
AI_KEEPWARM_LOCK_PORT   5051
AI_MAX_ROWS             500          # lignes UI
AI_EXPORT_MAX_ROWS      50000        # lignes export Excel
AI_EXAMPLES_PATH        backend/config/dataset_sap_ia.jsonl
```

### Installation ([install_IA.sh](../install_IA.sh))

```bash
curl -fsSL https://ollama.com/install.sh | sh        # Ollama
ollama pull qwen2.5-coder:7b                          # modèle (~4,7 Go)
# Service systemd : OLLAMA_NUM_THREADS=4, OLLAMA_KEEP_ALIVE=24h
```

> ⚠️ Le script configure `OLLAMA_HOST=0.0.0.0:11434`, mais le README préconise de **restreindre
> à `127.0.0.1`** et de ne pas exposer le port 11434 au pare-feu.

---

## 9. Flux complet d'une requête `/ask`

1. **Réception** : `POST /api/v1/ai/ask {question, conversation_id}` — JWT validé, identité extraite.
2. **Prompt** : `build_dynamic_prompt()` (RAG : schéma + exemples), fallback prompt statique en cas d'erreur.
3. **Génération** : `generate_sql()` → Ollama (`num_ctx=4096`, `num_predict=768`, `format=json`).
4. **Validation** : `sql_guard.validate_and_wrap()` → SQL sûr encapsulé en LIMIT.
5. **Exécution** : `run_readonly_query()` sous le rôle `readonly_ai` (timeout 30 s).
6. **Sérialisation** : conversion decimals/dates en types JSON-safe.
7. **Journalisation** : insertion dans `public.ai_query_log` (statut, durée, nb lignes).
8. **Persistance** : Q/R ajoutées à `public.ai_conversations` / `ai_messages`.

---

## 10. Forces, limites et pistes

### Points forts

- ✅ **Confidentialité totale** : LLM 100 % local, aucune donnée vers le cloud.
- ✅ **Sécurité robuste** : défense en profondeur (validation + rôle BDD + timeouts + audit).
- ✅ **Anti-hallucination** : RAG sur le dictionnaire réel → colonnes toujours valides.
- ✅ **Optimisation contexte** : keep-warm + prompt dynamique économisent le coût d'inférence.
- ✅ **Traçabilité** : journalisation complète, historique, conversations.

### Limites

- ⚠️ **Latence** : ~4-6 s/question (7B en CPU, ~2 tok/s). Les timeouts froids correspondent à
  l'évaluation du prompt à froid.
- ⚠️ **Débit** : une seule génération à la fois (`Semaphore(1)`) → HTTP 429 en cas de concurrence.
- ⚠️ **Budget `num_ctx=4096` tendu** : le prompt doit rester compact ; risque de troncature si
  trop de tables/colonnes sont injectées.
- ⚠️ **Pas de GPU** : fine-tuning LoRA exclu à court terme.

### Pistes d'évolution

1. Enrichir le dataset few-shot avec les questions réelles validées (`ai_query_log`).
2. Envisager un GPU pour réduire la latence et permettre le fine-tuning LoRA.
3. Étendre `MAX_TABLES` / `MAX_COLS_PAR_TABLE` prudemment selon le budget de contexte.
4. Mettre en place un suivi du taux de rejet `sql_guard` pour détecter les dérives du modèle.

---

*Document généré le 2026-06-13 à partir de l'analyse du code source du projet Migration Factory.*
