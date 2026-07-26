# Assistant IA Migration — Prompt Claude Code (v2 corrigée)

> Lancer Claude Code depuis la racine du projet Migration Factory, mode Plan, puis coller le prompt ci-dessous.

---

# PROMPT

## Contexte

Tu travailles dans le projet **Migration Factory** : une application full-stack de migration de données SAP **ECC 6.0+** vers **IFS Cloud**. Stack existante (voir `CLAUDE.md` à la racine) :

- **Backend** : Flask 2.3.3 + SQLAlchemy + Python 3.11 (port 5000). Routes en Blueprints sous le préfixe `/api/v1/`. Auth JWT (Flask-JWT-Extended). Logs via `loguru`.
- **Frontend** : React 18 + TypeScript + Material-UI (MUI) + Vite (port 3000). State Redux Toolkit, HTTP Axios, routing react-router-dom v6. Pages dans `frontend/src/pages/`, composants réutilisables dans `frontend/src/components/`, services API dans `frontend/src/services/`.
- **Base de données** : PostgreSQL `sap_migration` sur `10.190.100.58:5432`. Trois schémas :
  - `raw_data` : 121 tables SAP brutes en **lecture seule** — `lfa1` (fournisseurs), `mara` (articles), `marc` (articles/site), `mard` (stocks), `makt` (désignations), etc. **Ne jamais modifier ces tables.**
  - `clean_data` : 45 vues/tables transformées pour IFS.
  - `public` : 15 tables système (users, jobs, configs, logs).
- Les tables SAP sont **schéma-qualifiées** : toujours écrire `raw_data.lfa1`, `raw_data.mara`, etc.
- Règles SAP : filtrer systématiquement `mandt = '700'`, exclure les enregistrements supprimés (`loevm` non vide pour `lfa1`, `lvorm` pour `mara`/`marc`).

**Avant de commencer : explore la structure existante du projet** (Blueprints dans `backend/api/`, services dans `backend/services/`, modèles SQLAlchemy dans `backend/models/`, config dans `backend/config/settings.py`, pages et services React dans `frontend/src/`) et réutilise les conventions en place (loguru, préfixe `/api/v1/`, pattern des services Axios). Ne casse rien d'existant.

## Objectif

Ajouter un **menu "Assistant IA"** : un chatbot connecté à PostgreSQL qui permet de poser des questions en langage naturel, exécute des requêtes SQL en lecture seule, affiche des tableaux de résultats, produit des analyses de qualité de données et exporte des rapports Excel.

L'IA est **locale** : Ollama avec le modèle `qwen2.5-coder:7b` sur `http://localhost:11434`.

## Architecture cible

```
React (AssistantIA.tsx) → Flask (/api/v1/ai/*) → Ollama (génération SQL)
                                               → PostgreSQL (engine readonly_ai dédié)
                                               → export_service.py / pandas (export Excel)
```

### Pipeline en deux temps (IMPORTANT)

Le modèle 7B est lent (~2 tok/s) et moins fiable qu'un grand modèle. Ne PAS faire de tool use en boucle. Pipeline strict :

1. L'utilisateur pose une question en français
2. Le backend appelle Ollama avec un system prompt contenant le schéma compact de la base → le modèle répond **uniquement** un JSON : `{"sql": "...", "explication": "..."}`
3. Le backend **valide** le SQL (voir sécurité)
4. Le backend exécute la requête et renvoie : SQL généré + explication + tableau de résultats
5. Le frontend affiche le tout ; PAS de synthèse en langage naturel par le modèle (trop lent)

### Appel Ollama — points techniques imposés

- Utiliser l'API **native** `POST http://localhost:11434/api/chat` avec l'option `"format": "json"` (sortie JSON garantie par Ollama) plutôt que l'endpoint compatible OpenAI. Options : `"temperature": 0`, `"num_ctx": 4096`.
- Parsing **tolérant** malgré tout : retirer d'éventuels fences markdown (```json), tenter `json.loads`, et si échec faire **un seul retry** avec un message correctif ("Réponds uniquement le JSON demandé"). Au 2e échec : statut `erreur` + message clair.
- **Verrou de concurrence** : la VM n'a que 4 cœurs, Ollama ne doit traiter qu'une génération à la fois. Implémenter un `threading.Semaphore(1)` dans `ollama_service.py` ; si occupé, renvoyer HTTP 429 avec message "Une analyse est déjà en cours, réessayez dans un instant".
- Timeout `requests` : **120 secondes** (attention : `requests` prend des secondes, pas des millisecondes).
- Endpoint santé : `GET /api/v1/ai/health` qui ping `GET {OLLAMA_URL}/api/tags` et vérifie que le modèle configuré est présent. Le frontend l'appelle à l'ouverture de la page pour afficher un bandeau si l'IA est indisponible.

## Tâches à réaliser

### 1. Base de données

- Rôle PostgreSQL `readonly_ai` :
  ```sql
  CREATE ROLE readonly_ai LOGIN PASSWORD '...';
  GRANT USAGE ON SCHEMA raw_data, clean_data TO readonly_ai;
  GRANT SELECT ON ALL TABLES IN SCHEMA raw_data, clean_data TO readonly_ai;
  ALTER DEFAULT PRIVILEGES IN SCHEMA raw_data GRANT SELECT ON TABLES TO readonly_ai;
  ALTER DEFAULT PRIVILEGES IN SCHEMA clean_data GRANT SELECT ON TABLES TO readonly_ai;
  ALTER ROLE readonly_ai SET statement_timeout = '30s';
  ALTER ROLE readonly_ai CONNECTION LIMIT 3;
  ```
  Aucun droit sur `public` (la journalisation s'écrit via le rôle applicatif principal, PAS via readonly_ai).
- Table `public.ai_query_log` : `id, utilisateur (depuis le JWT), question, sql_genere, statut ('succes'|'erreur'|'rejete'), raison_rejet, template_id (nullable), duree_ms, nb_lignes, date_creation` + index sur `(date_creation DESC)` et `(utilisateur)`.
- Script SQL dans `migrations/` en respectant la numérotation existante (regarder le dernier numéro présent).

### 2. Backend Flask — Blueprint `/api/v1/ai`

Créer `backend/api/ai_assistant.py`, l'enregistrer dans `backend/api/__init__.py`. **Toutes les routes protégées par `@jwt_required()`** ; l'identité JWT alimente le champ `utilisateur` du log.

- `POST /api/v1/ai/ask` : question → Ollama → validation → exécution → `{ id_log, sql, explication, colonnes, lignes, duree_ms, tronque (bool) }`. Max 500 lignes.
- `POST /api/v1/ai/export` : reçoit `id_log`, **re-valide le SQL via sql_guard** puis ré-exécute et renvoie le `.xlsx` (réutiliser `backend/services/export_service.py` / pandas / openpyxl). Pour l'export, LIMIT relevé à `AI_EXPORT_MAX_ROWS` (50 000).
- `GET /api/v1/ai/templates` : liste des analyses pré-définies.
- `POST /api/v1/ai/templates/<id>/run` : exécute le SQL pré-écrit du template (sans IA), journalisé avec `template_id`.
- `GET /api/v1/ai/history?page=&par_utilisateur=` : historique paginé depuis `public.ai_query_log`.
- `GET /api/v1/ai/health` : statut Ollama + modèle.
- `backend/services/ollama_service.py` : appel HTTP, format json, retry, sémaphore, loguru.
- `backend/services/sql_guard.py` : validation (voir sécurité).
- Engine SQLAlchemy **dédié** pour readonly_ai (distinct du pool applicatif), `pool_size=2`, `pool_pre_ping=True`.

### 3. Sécurité (NON NÉGOCIABLE)

Dans `sql_guard.py`, utiliser la bibliothèque **`sqlparse`** (pas de regex artisanales) :

- Parser la requête ; rejeter si plus d'un statement (`sqlparse.split` → exactement 1).
- Le statement doit être de type `SELECT` (ou commencer par `WITH ... SELECT`).
- Parcourir les **tokens de type Keyword/DDL/DML** (pas le texte brut, pour ne pas rejeter à tort des mots dans des littéraux de chaîne) et rejeter : `INSERT, UPDATE, DELETE, DROP, ALTER, TRUNCATE, CREATE, GRANT, REVOKE, COPY, EXECUTE, DO, CALL, SET, VACUUM, ANALYZE INTO`, plus rejet de `SELECT ... INTO` et des fonctions `pg_sleep`, `pg_read_file`, `dblink`, `lo_*`.
- Rejeter les identifiants commençant par `pg_` et l'accès à `pg_catalog` / `information_schema` dans la requête.
- Forcer la limite **en wrappant** la requête : `SELECT * FROM ( <requete sans ; final> ) AS ai_sub LIMIT :max_rows` — ne PAS concaténer un `LIMIT` en fin de chaîne (casse les requêtes avec `ORDER BY` + `LIMIT` existant ou commentaires). Si la requête contient déjà un LIMIT ≤ max, le wrapping reste sans effet néfaste.
- Exécution exclusivement via l'engine `readonly_ai`. Défense en profondeur : même si sql_guard laissait passer quelque chose, le rôle ne peut pas écrire.
- Journaliser CHAQUE question (succès, erreur, rejet avec `raison_rejet`).

### 4. Analyses pré-définies (SQL pré-écrit, sans IA)

`backend/config/ai_templates.py` — dictionnaire `{id: {titre, description, sql}}` avec au minimum :

- **Complétude fournisseurs** : % de remplissage des champs critiques de `raw_data.lfa1` (name1, ort01, pstlz, land1, stras) pour `mandt='700'` et `loevm` vide
- **Doublons fournisseurs** : groupes de `raw_data.lfa1` partageant `name1` normalisé (UPPER + regexp_replace espaces multiples) + `ort01`
- **Fournisseurs sans contact** : `raw_data.lfa1` actifs sans téléphone ni email
- **Synthèse par pays** : répartition des fournisseurs par `land1`
- **Qualité codification articles** : articles de `raw_data.mara` (divisions 2200/9200, `lvorm` vide) sans code IFS dans la table de mapping — **inspecter d'abord `clean_data` pour trouver le nom réel de la table de mapping**, ne pas l'inventer

Les SQL des templates passent aussi par `sql_guard` à l'exécution (cohérence + filet de sécurité).

### 5. System prompt du modèle

`backend/config/ai_system_prompt.py` :

- En français
- Schéma COMPACT : pour chaque table utile (`raw_data.lfa1`, `raw_data.mara`, `raw_data.marc`, `raw_data.mard`, `raw_data.makt`, tables de mapping de `clean_data`), une ligne par colonne pertinente avec sa description métier — **génère ce schéma en interrogeant réellement la base au moment du développement** (information_schema côté développeur / outil MCP postgres), ne l'invente pas. Limiter à ~15-20 colonnes par table (les pertinentes métier), sinon le contexte 4096 tokens déborde.
- Règles à rappeler dans le prompt : schéma-qualifier en `raw_data.*` / `clean_data.*`, `mandt = '700'`, flags de suppression (`loevm`/`lvorm`), `LTRIM(matnr, '0')` pour les codes articles, dialecte PostgreSQL, toujours un alias lisible pour les agrégats.
- Sortie JSON strict : `{"sql": "...", "explication": "..."}` sans markdown.
- 3 exemples few-shot question → JSON (dont un avec jointure lfa1 + adresse, un avec agrégat GROUP BY).

### 6. Frontend React — page `AssistantIA`

- Item de menu "Assistant IA" dans la navigation existante (react-router-dom v6 + MUI).
- `frontend/src/pages/AssistantIA.tsx` + `frontend/src/services/aiService.ts` (Axios, pattern des services existants ; **timeout Axios à 150 000 ms pour `/ask`**, supérieur au timeout backend).
- Au chargement : appel `/health` → bandeau d'alerte MUI si Ollama indisponible.
- Panneau de chat : historique de session, champ de saisie, indicateur de chargement avec message « Génération en cours (modèle local, ~20-60 s)... » et **bouton Annuler** (AbortController côté Axios).
- Affichage par réponse : explication, SQL dans un `Accordion` repliable, tableau de résultats (réutiliser le composant DataGrid/Table existant de `frontend/src/components/`), mention « résultats tronqués à 500 lignes » si `tronque`, bouton « Exporter Excel » (appelle `/export` avec `id_log`).
- Sidebar : boutons des analyses pré-définies (un clic = `/templates/<id>/run`).
- Onglet « Historique » : `/history` paginé, clic sur une entrée = ré-exécution possible.
- Gestion d'erreur : SQL rejeté (afficher `raison_rejet`), 429 (analyse en cours), Ollama indisponible, timeout.

### 7. Configuration

- `backend/.env` + `backend/.env.example` : `OLLAMA_URL=http://localhost:11434`, `OLLAMA_MODEL=qwen2.5-coder:7b`, `AI_DB_USER=readonly_ai`, `AI_DB_PASSWORD=...`, `AI_MAX_ROWS=500`, `AI_EXPORT_MAX_ROWS=50000`, `AI_TIMEOUT_SECONDS=120`. Charger via `backend/config/settings.py`.
- Ajouter `sqlparse` à `requirements.txt`.
- Mettre à jour le README : installation Ollama, création du rôle, variables d'env, lancement.

### 8. Tests

- `pytest` sur `sql_guard.py` : SELECT valide ; WITH valide ; UPDATE/DELETE/DROP rejetés ; multi-statements rejeté ; `SELECT ... INTO` rejeté ; mot "update" dans un littéral de chaîne NON rejeté ; wrapping LIMIT correct avec ORDER BY ; `pg_sleep` rejeté.
- `pytest` sur `ollama_service.py` : parsing JSON avec et sans fences markdown, retry, timeout, sémaphore occupé → 429.
- Test d'intégration `/api/v1/ai/ask` avec `requests` mocké (`responses` ou `unittest.mock`), JWT de test.

## Contraintes

- Aller PAS À PAS : explore d'abord le projet, présente ton plan, attends ma validation avant d'écrire du code.
- Ordre : exploration → migration SQL (rôle + log) → `sql_guard` + tests → `ollama_service` + tests → routes `/ask`/`/health` → templates → frontend → export → README.
- Code commenté en français (cohérent avec le projet).
- Ne jamais exposer le port 11434 hors de la VM (Ollama doit écouter sur 127.0.0.1 uniquement ; vérifier qu'aucune règle firewall ne l'ouvre).

---

## Vérifications post-développement

```bash
# 1. Le rôle readonly_ai ne peut pas écrire
psql -h 10.190.100.58 -U readonly_ai -d sap_migration \
  -c "DELETE FROM raw_data.lfa1 WHERE 1=0;"   # attendu : permission denied

# 2. Le rôle ne voit pas le schéma public
psql -h 10.190.100.58 -U readonly_ai -d sap_migration \
  -c "SELECT * FROM public.users LIMIT 1;"    # attendu : permission denied

# 3. L'API rejette les requêtes dangereuses (avec un token JWT valide)
curl -X POST http://localhost:5000/api/v1/ai/ask \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"question": "supprime tous les fournisseurs"}'
# attendu : statut "rejete" + raison

# 4. Santé Ollama
curl -H "Authorization: Bearer $TOKEN" http://localhost:5000/api/v1/ai/health

# 5. Timeout statement : une requête volontairement lourde s'arrête à 30 s
# 6. Deux /ask simultanés : le second reçoit un 429
```