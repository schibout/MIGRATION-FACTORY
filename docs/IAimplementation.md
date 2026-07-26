# Implémentation de l'Assistant IA — Migration Factory

> **Projet** : Migration Factory (SAP ECC 6.0+ → IFS Cloud)
> **Composant** : Assistant IA texte → SQL (chatbot d'interrogation de la base SAP)
> **Dernière mise à jour** : 2026-06-13
> **Portée** : architecture, sécurité, recherche sémantique (pgvector), cache, auto-correction, déploiement

---

## 1. Vue d'ensemble

L'Assistant IA est un **chatbot texte-vers-SQL** : l'utilisateur pose une question en
français (« Combien y a-t-il de fournisseurs actifs ? ») et obtient automatiquement une
requête SQL, son explication et le tableau de résultats.

Le système repose sur un **LLM local (Ollama)** : aucune donnée ne sort de la VM, aucun
appel à une API cloud. Depuis 2026-06-13, il intègre une **recherche sémantique vectorielle**
(pgvector + embeddings locaux), un **cache sémantique** des réponses et une **auto-correction**
du SQL fautif.

### Chaîne de traitement (pipeline)

```
┌──────────────┐  question FR   ┌────────────────────────────────────────────┐
│  Frontend    │ ─────────────▶ │                Flask /api/v1/ai            │
│ AssistantIA  │                │                                            │
│   (React)    │ ◀───────────── │  1. cache sémantique  (pgvector)           │
└──────────────┘  résultats     │  2. prompt RAG        (sémantique + lexical)│
                                │  3. génération SQL    (Ollama qwen2.5)     │
                                │  4. sql_guard         (validation)         │
                                │  5. readonly_ai       (exécution)          │
                                │  6. auto-correction   (si erreur schéma)   │
                                │  7. journalisation    (ai_query_log)       │
                                └───────────────┬────────────────────────────┘
                                                │
                          ┌─────────────────────┼─────────────────────┐
                          ▼                     ▼                     ▼
                   ┌────────────┐        ┌────────────┐        ┌────────────┐
                   │  Ollama    │        │ PostgreSQL │        │  Ollama    │
                   │ qwen2.5    │        │ pgvector   │        │  bge-m3    │
                   │ -coder:7b  │        │ (vecteurs) │        │(embeddings)│
                   └────────────┘        └────────────┘        └────────────┘
```

### Stack technique

| Couche         | Technologie                                                         |
|----------------|---------------------------------------------------------------------|
| Modèle SQL     | **qwen2.5-coder:7b** via Ollama (`localhost:11434`), CPU 4 cœurs     |
| Embeddings     | **bge-m3** (1024 dim, multilingue/FR) via Ollama `/api/embeddings`   |
| Backend        | Flask Blueprint `/api/v1/ai/*`, JWT, SQLAlchemy / psycopg2           |
| Validation     | `sqlparse` (analyse par tokens, pas de regex)                       |
| Base vectorielle | **pgvector** (extension PostgreSQL, index HNSW, distance cosinus) |
| Base           | PostgreSQL, rôle dédié `readonly_ai` (SELECT seul, timeout 30 s)     |
| Frontend       | React 18 + TypeScript + MUI (`AssistantIA.tsx`)                      |

---

## 2. Architecture backend

### 2.1 Fichiers et rôles

| Fichier | Rôle |
|---------|------|
| `backend/api/ai_assistant.py` | Blueprint Flask, routes REST, orchestration (cache → RAG → génération → validation → exécution → auto-correction → log) |
| `backend/services/ollama_service.py` | Communication Ollama (génération SQL), concurrence, keep-warm, `repair_sql` |
| `backend/services/ai_prompt_builder.py` | Construction du prompt dynamique (RAG) + sélection des exemples few-shot (sémantique, repli lexical) |
| `backend/services/ai_schema_retriever.py` | Sélection des tables/colonnes pertinentes (map d'alias + sémantique + FTS) |
| `backend/services/ai_embeddings.py` | **Embeddings locaux** (bge-m3) : `embed()`, cache LRU, formatage pgvector |
| `backend/services/ai_semantic_cache.py` | **Cache sémantique** : `lookup()` / `store()` sur `ai_query_log.embedding` |
| `backend/services/sql_guard.py` | Validation défensive du SQL généré |
| `backend/services/ai_readonly_db.py` | Moteur SQLAlchemy dédié au rôle `readonly_ai` |
| `backend/config/ai_system_prompt.py` | Prompt système statique (fallback) |
| `backend/config/ai_templates.py` | Analyses pré-définies (SQL figé, sans IA) |
| `backend/config/dataset_sap_ia.jsonl` | Jeu d'exemples few-shot |
| `backend/build_ai_index.py` | **Script d'indexation vectorielle** (tables du dictionnaire + exemples) |

### 2.2 Endpoints REST (`/api/v1/ai/*`)

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| POST | `/ask` | Question FR → SQL → résultats (max 500 lignes) |
| POST | `/export` | Ré-exécute un SQL journalisé → Excel (max 50 000 lignes) |
| GET | `/templates` | Liste des analyses prédéfinies |
| POST | `/templates/<id>/run` | Exécute un template |
| GET | `/history` | Historique paginé |
| GET | `/conversations` + `/conversations/<id>` | Gestion des conversations |
| GET | `/health` | Disponibilité Ollama + présence du modèle |

Toutes les routes sont protégées par `@jwt_required()`.

---

## 3. Recherche sémantique vectorielle (pgvector)

### 3.1 Pourquoi pgvector

Le RAG initial était **100 % lexical** : une map de mots-clés curée (`DOMAIN_TABLES`) + une
recherche plein-texte PostgreSQL + une sélection des few-shots par recouvrement de mots. Limite :
une reformulation (« qui nous livre ? » au lieu de « fournisseur ») ratait la cible, et la map
devait être maintenue à la main.

La recherche sémantique capte le **sens** plutôt que les mots exacts. Le choix de **pgvector**
(extension PostgreSQL) plutôt qu'un service vectoriel dédié (Qdrant/Weaviate/Milvus) est délibéré :
pour ~140 tables + ~60 exemples, un service séparé serait surdimensionné. pgvector réutilise la
base existante, sans nouveau conteneur ni RAM supplémentaire, et s'intègre à l'audit `ai_query_log`.

### 3.2 Modèle d'embeddings

- **bge-m3**, 1024 dimensions, multilingue (fort en français), servi localement par Ollama
  (`POST /api/embeddings`). Aucune dépendance Python lourde (pas de `torch` /
  `sentence-transformers`).
- Module `ai_embeddings.py` : `embed(text)` renvoie le vecteur, avec :
  - **cache LRU** en mémoire (512 entrées) pour éviter de ré-embedder un texte identique ;
  - **plafond d'entrée** (`MAX_INPUT_CHARS = 6000`) pour éviter l'erreur Ollama
    « input length exceeds the context length » ;
  - **`keep_alive = 1h`** pour maintenir le modèle chaud entre les appels ;
  - **un retry sur timeout** (le premier appel « à froid » peut être lent sur CPU).
- **Tolérance aux pannes** : si les embeddings sont désactivés (`AI_EMBED_ENABLED=false`) ou
  indisponibles, `embed()` renvoie `None` et tous les appelants retombent sur le mode lexical.

### 3.3 Schéma de base (migration 015)

`migrations/015_create_ai_embeddings.sql` :

- `CREATE EXTENSION IF NOT EXISTS vector;`
- Table `public.ai_embeddings` :

  | Colonne | Type | Rôle |
  |---------|------|------|
  | `kind` | `varchar(20)` | `'table'` ou `'example'` |
  | `ref_id` | `varchar(200)` | identifiant logique (`raw_data.lfa1`, `ex_0007`) |
  | `content` | `text` | texte source (traçabilité / ré-indexation) |
  | `embedding` | `vector(1024)` | vecteur bge-m3 |

  Contrainte d'unicité `(kind, ref_id)` (upsert idempotent), **index HNSW**
  (`vector_cosine_ops`) + index sur `kind`.
- Colonne `public.ai_query_log.embedding vector(1024)` (support du cache) + index HNSW
  **partiel** (`WHERE embedding IS NOT NULL AND statut = 'succes'`).

### 3.4 Indexation (`build_ai_index.py`)

Script idempotent (upsert par `kind, ref_id`), relançable après mise à jour du dictionnaire ou
du dataset :

- **Tables** (`kind='table'`) : pour chaque table du dictionnaire SAP, document =
  description FR + libellés des colonnes, **tronqué à ~1500 caractères** (les tables à 100+
  colonnes saturent sinon le modèle).
- **Exemples** (`kind='example'`) : chaque question du dataset few-shot.

```bash
cd backend && python build_ai_index.py
python build_ai_index.py --only tables      # ou --only examples
```

### 3.5 Câblage RAG

- **Sélection des tables** (`ai_schema_retriever.retrieve_tables`) — cascade :
  1. map d'alias `DOMAIN_TABLES` (priorité, sûre pour les questions fréquentes) ;
  2. **complément sémantique** (`_semantic_tables` : top-k cosinus sur `kind='table'`) ;
  3. repli FTS si l'ensemble reste trop maigre (embeddings indisponibles).
- **Sélection des few-shots** (`ai_prompt_builder._select_examples`) :
  - `_select_examples_semantic` : top-k cosinus sur `kind='example'` ;
  - repli `_select_examples_lexical` (recouvrement de mots) si embeddings KO.

---

## 4. Cache sémantique des réponses

Module `ai_semantic_cache.py`. Objectif : éviter de rappeler le modèle (lent sur CPU, ~4-6 s)
quand une question quasi identique a déjà réussi.

- **`lookup(question)`** : embedde la question, cherche dans `ai_query_log` (statut `succes`)
  la plus proche par cosinus. Si la similarité dépasse `AI_CACHE_THRESHOLD` (défaut 0.94), renvoie
  le SQL déjà généré (+ `id_log`, `similarity`, et le vecteur réutilisable).
- **`store(id_log, question, vector)`** : mémorise l'embedding de la question réussie sur sa
  ligne `ai_query_log` (non bloquant).
- **Hook dans `/ask`** : le cache est consulté **avant** la génération. Sur hit, le SQL est
  **ré-validé par sql_guard et ré-exécuté via readonly_ai** → données fraîches et bornées ; seule
  la génération est court-circuitée. La réponse porte `source: "cache"` et `cache_similarity`.
- Si le SQL caché échoue (schéma modifié depuis), on régénère normalement.

> Gain typique : ~5 s → ~50 ms sur une question déjà vue.

---

## 5. Auto-correction du SQL (self-heal)

- `ollama_service.repair_sql(question, system_prompt, bad_sql, erreur)` : renvoie au modèle sa
  requête fautive + le message d'erreur PostgreSQL, et demande **une** correction JSON. Respecte
  le `Semaphore(1)`.
- **Hook dans `_execute_and_pack`** : si `run_readonly_query` lève une erreur de schéma/syntaxe
  (`pgcode` ∈ `{42703 colonne, 42P01 table, 42601 syntaxe}`) et que `AI_SELFHEAL_ENABLED=true`,
  une réparation est tentée **une seule fois** (récursion bornée par `_repair_done`), puis le SQL
  corrigé est ré-exécuté. En cas d'échec, comportement inchangé (message d'erreur lisible).
- Best-effort : toute erreur Ollama pendant la réparation est absorbée.

---

## 6. Sécurité — défense en profondeur

Inchangée et toujours appliquée, y compris au SQL issu du cache ou de l'auto-correction.

| Couche | Contrôle |
|--------|----------|
| **API** | `@jwt_required()` sur toutes les routes |
| **Validation** | `sqlparse` par tokens (`sql_guard.py`) |
| **Mots-clés interdits** | INSERT, UPDATE, DELETE, DROP, ALTER, TRUNCATE, CREATE, GRANT, COPY, EXECUTE, DO, CALL, SET, VACUUM, MERGE, INTO… |
| **Fonctions interdites** | `dblink`, `pg_sleep`, `pg_read_file`, `pg_ls_dir`, `lo_*`… |
| **Schémas** | Whitelist `public` (3 tables) ; `pg_catalog`/`information_schema` bloqués |
| **Première instruction** | SELECT ou WITH uniquement ; une seule instruction (anti-injection) |
| **Volumétrie** | Encapsulation `SELECT * FROM ( <requête> ) AS ai_sub LIMIT n` |
| **Rôle BDD** | `readonly_ai` : SELECT seul, `statement_timeout = 30 s`, `CONNECTION LIMIT 3` |
| **Concurrence** | `Semaphore(1)` → HTTP 429 si occupé |
| **Audit** | `public.ai_query_log` (user, statut, SQL, durée, nb lignes, embedding) |

> Le rôle `readonly_ai` n'a **aucun droit** sur le schéma `public` : les embeddings et le cache
> sont lus/écrits via le rôle applicatif principal (`get_db_connection`), pas via `readonly_ai`.

---

## 7. Règles métier SAP (encodées dans le prompt)

1. **Mandant** : toujours filtrer `mandt = '700'` sur les tables `raw_data`.
2. **Drapeaux de suppression** : `loevm` (fournisseurs/clients), `lvorm` (articles/équipements),
   `loekz` (achats), `stblg` (contre-passation factures).
3. **Zéros non significatifs** : codes article → `LTRIM(matnr, '0')`.
4. **Typage** : colonnes SAP varchar → `CAST(... AS numeric)` ; dates `YYYYMMDD`.
5. **Multilingue** : préférer `spras = 'F'` pour les libellés.
6. **Dialecte** : PostgreSQL 14+ (`::cast`, `ILIKE`, `COALESCE`, `LIMIT`).

---

## 8. Configuration (variables d'environnement)

```bash
# Modèle SQL
OLLAMA_URL                http://localhost:11434
OLLAMA_MODEL              qwen2.5-coder:7b
AI_TIMEOUT_SECONDS        240
AI_MAX_ROWS               500
AI_EXPORT_MAX_ROWS        50000

# Rôle base lecture seule
AI_DB_USER                readonly_ai
AI_DB_PASSWORD            (secret .env)

# Recherche sémantique (pgvector + embeddings locaux)
AI_EMBED_MODEL            bge-m3
AI_EMBED_ENABLED          true     # false => repli lexical (mots-clés/FTS)
AI_EMBED_TIMEOUT_SECONDS  30

# Cache sémantique
AI_CACHE_ENABLED          true
AI_CACHE_THRESHOLD        0.94     # similarité cosinus minimale pour un hit

# Auto-correction
AI_SELFHEAL_ENABLED       true
```

---

## 9. Déploiement (serveur distant)

> Aucune nouvelle dépendance Python (le vecteur est passé en SQL via un cast `%s::vector`),
> donc `requirements.txt` et le Dockerfile backend sont inchangés.

1. **Installer l'extension pgvector** sur le serveur PostgreSQL :
   ```bash
   sudo apt-get install postgresql-NN-pgvector   # NN = version majeure
   ```
2. **Télécharger le modèle d'embeddings** sur la VM Ollama :
   ```bash
   ollama pull bge-m3
   ```
3. **Appliquer la migration** (rôle superutilisateur, car `CREATE EXTENSION`) :
   ```bash
   psql -h 10.190.100.58 -U postgres -d sap_migration_db -f migrations/015_create_ai_embeddings.sql
   ```
4. **Compléter le `.env`** du serveur (variables §8).
5. **Déployer le backend** puis **construire l'index** :
   ```bash
   ./deploybackend.sh -b
   # Pré-chauffer bge-m3 pour éviter les timeouts à froid
   curl http://10.190.100.58:11434/api/embeddings \
     -d '{"model":"bge-m3","prompt":"warmup","keep_alive":"1h"}'
   # Indexation (timeout élargi par sécurité)
   docker exec -it -e AI_EMBED_TIMEOUT_SECONDS=120 migration-app-backend python build_ai_index.py
   ```

### Vérifications post-déploiement

```bash
# Index peuplé (tables + exemples)
psql -h 10.190.100.58 -U postgres -d sap_migration_db \
  -c "SELECT kind, count(*) FROM public.ai_embeddings GROUP BY kind;"

# bge-m3 présent et chargé
curl http://localhost:11434/api/tags | grep bge-m3
ollama ps
```

> **Dépannage timeouts d'indexation** : si `ollama ps` ne montre qu'un seul modèle alors que
> qwen et bge-m3 devraient coexister, c'est une contention RAM (Ollama décharge/recharge à chaque
> appel). Soit ajouter de la RAM à la VM, soit indexer pendant que qwen est déchargé
> (`curl .../api/generate -d '{"model":"qwen2.5-coder:7b","keep_alive":0}'`). L'usage courant
> n'embedde ensuite que de courtes questions, donc rapide.

---

## 10. Tests

```bash
cd backend && pytest tests/ -v
```

- `test_sql_guard.py` : SELECT/WITH valides ; UPDATE/DELETE/DROP/multi-statements/`SELECT INTO`/`pg_sleep` rejetés ; mot « update » dans un littéral non rejeté ; wrapping LIMIT avec ORDER BY.
- `test_ollama_service.py` : parsing JSON (avec/sans fences), retry, sémaphore → 429, **`repair_sql`** (succès, JSON invalide, sémaphore occupé).
- `test_ai_embeddings.py` : vecteur renvoyé, désactivation, dimension invalide, erreur HTTP, cache LRU, formatage pgvector.
- `test_ai_semantic_cache.py` : désactivation, embeddings KO, hit au-dessus du seuil, miss sous le seuil, aucune ligne, `store` (écriture / no-op sans id).

---

## 11. Forces, limites et pistes

### Points forts

- ✅ **Confidentialité totale** : LLM et embeddings 100 % locaux.
- ✅ **Recherche sémantique** : capte les reformulations, réduit la curation manuelle.
- ✅ **Cache sémantique** : latence quasi nulle sur les questions répétées.
- ✅ **Auto-correction** : rattrape les hallucinations de colonnes/tables.
- ✅ **Robustesse** : chaque brique sémantique est dégradable (repli lexical, jamais bloquant).
- ✅ **Sécurité** : défense en profondeur inchangée, appliquée à tous les chemins (cache inclus).

### Limites

- ⚠️ **Latence du modèle SQL** : ~4-6 s/question (7B en CPU).
- ⚠️ **Débit** : une seule génération à la fois (`Semaphore(1)`).
- ⚠️ **Contention RAM** : qwen + bge-m3 doivent coexister ; sinon timeouts à l'indexation.
- ⚠️ **Pas de GPU** : fine-tuning LoRA exclu à court terme.

### Pistes d'évolution

1. **Feedback 👍/👎** : indexer les paires Q→SQL validées pour enrichir automatiquement les
   few-shots (amélioration continue sans fine-tuning).
2. **EXPLAIN pré-exécution** : rejeter les requêtes trop coûteuses avant le timeout 30 s.
3. **Streaming** des tokens vers le frontend (latence perçue).
4. **Dashboard admin** sur `ai_query_log` (taux de rejet, p95 latence, hits de cache).
5. **Contexte conversationnel** pour les questions de suivi (« et pour 2024 ? »).

---

*Document généré le 2026-06-13 — décrit l'implémentation complète de l'Assistant IA, recherche
sémantique pgvector, cache et auto-correction inclus.*
