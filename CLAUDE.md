# Migration Factory - Instructions Claude Code

## Projet

Application full-stack de migration de donnees SAP ECC 6.0+ vers IFS. Plateforme temporaire (5 mois) avec interface web pour extraction, transformation et chargement (ETL).

## Architecture

```
Frontend: React 18 + TypeScript + Material-UI + Vite (port 3000)
Backend:  Flask 2.3.3 + SQLAlchemy + Python 3.11 (port 5000)
Database: PostgreSQL 12+ (serveur externe 10.190.100.58:5432)
Deploy:   Docker Compose + Nginx
```

### Schemas base de donnees
- `raw_data` : 230 tables + 10 vues SAP brutes / imports SharePoint (lecture seule)
- `clean_data` : 112 tables + 22 vues transformees pour IFS (cible des exports)
- `public` : 41 tables + 5 vues systeme (users, jobs, configs, logs, dictionnaires SAP/IFS, Assistant IA)
- `snapshots` : 20 tables, copies automatiques avant operations Maintenance destructives

**Reference complete generee : `.astro/warehouse.md`** — colonnes, types, cles (PK / index unique /
DDIC SAP / spec IFS), valeurs categorielles, catalogue d'export, routage mot-cle -> tables, graphe de
jointures SAP DDIC. Fichier entierement genere, ecrase a chaque regeneration : le contexte metier se
met dans la base (`COMMENT ON`, `etl_export_queries.description`, `ai_domain_tables`), pas dans le md.
Regenerer : `./.astro/refresh_warehouse.sh` (apres une migration SQL ou une re-extraction SAP).

## Structure du code

```
backend/
  app.py                    # Point d'entree Flask
  api/                      # Routes REST (24 fichiers)
  api/ai_assistant.py       # Assistant IA texte->SQL (blueprint /api/v1/ai/*)
  services/                 # Logique metier (export, import, extraction, sharepoint)
  services/ollama_service.py        # Appel modele Ollama + concurrence + keep-warm
  services/ai_prompt_builder.py     # Prompt dynamique RAG (SOCLE + schema cible + few-shots)
  services/ai_schema_retriever.py   # Selection RAG des tables/colonnes (anti-hallucination)
  services/sql_guard.py             # Validation defensive du SQL genere
  services/ai_readonly_db.py        # Moteur SQLAlchemy role readonly_ai (SELECT seul)
  config/ai_system_prompt.py        # Prompt systeme statique (fallback)
  config/dataset_sap_ia.jsonl       # 61 exemples few-shot
  etl_modules/              # Transformations ETL (customer, supplier, project, inventory)
  models/                   # Modeles SQLAlchemy
  config/settings.py        # Configuration

frontend/src/
  pages/                    # 58 pages React (Export*, Import*, Data*, Admin/*)
  components/               # 50+ composants reutilisables
  services/                 # Services API (axios)
  store/                    # Redux Toolkit
```

## Conventions

### Backend (Python)
- Framework: Flask avec Blueprints pour les routes API
- ORM: SQLAlchemy pour les modeles, SQL brut pour les requetes complexes
- Auth: JWT via Flask-JWT-Extended
- Prefix API: `/api/v1/`
- Logs: loguru
- Les requetes d'export sont dynamiques, stockees dans `etl_export_queries` (pas de code a modifier pour ajouter un export)
- Langue du code: melange francais/anglais (commentaires souvent en francais)

### Frontend (TypeScript/React)
- UI: Material-UI (MUI)
- State: Redux Toolkit
- HTTP: Axios
- Routing: react-router-dom v6
- Build: Vite
- Composants pages dans `src/pages/`, composants reutilisables dans `src/components/`

### Base de donnees
- Migrations SQL dans `migrations/` (numerotees 003_, 004_, etc. — dernier numero utilise : 027)
- Procedures stockees dans `sql/`
- Les imports passent par `import_jobs` + `import_details` pour le suivi ligne par ligne

### Assistant IA (texte -> SQL)
- Page `/assistant-ia` (`frontend/src/pages/AssistantIA.tsx`, service `aiService.ts`), menu "Assistant IA"
- Modele **local** `qwen2.5-coder:7b` via **Ollama** (`10.190.100.58:11434`, CPU only, ~3 tok/s) -- aucune donnee vers le cloud
- Pipeline : question FR -> prompt dynamique **RAG** (`ai_prompt_builder` + `ai_schema_retriever`) -> Ollama -> `{sql, explication}` -> `sql_guard.validate_and_wrap()` -> execution lecture seule (role PG `readonly_ai`, timeout 30s) -> resultats
- Fournisseurs : `AI_PROVIDER` = `ollama` (local, defaut) | `openai` (API OpenAI-compatible, cles `AI_EXTERNAL_*` en base, cf. `services/llm_service.py` + `external_llm_service.py`). Les deux recoivent le **meme prompt RAG**. Budgets RAG adaptatifs (`services/ai_rag_budget.py`) : profil `compact` (Ollama, num_ctx=4096) / `large` (externe), forcable via `AI_RAG_PROFILE`. La regle « ne pas gonfler le prompt » ne vaut que pour le profil compact.
- Filet de securite : `services/sql_filters.py` retire les filtres techniques SAP (mandt/loevm/lvorm/loekz/stblg) du SQL genere AVANT `sql_guard` (le modele les ajoute malgre le SOCLE -> erreur 42703). Few-shots (`dataset_sap_ia.jsonl`) SANS ces filtres ; apres modif du dataset, relancer `python build_ai_index.py --only examples`.
- Le modele genere le SQL mais **ne synthetise PAS** les resultats (rendus en tableau)
- Securite : JWT, `sql_guard` (tokens sqlparse, SELECT/WITH only, blacklist DDL/DML, whitelist `public`), wrap LIMIT, statement_timeout 30s (injecte au niveau connexion), audit `public.ai_query_log`. **⚠️ Depuis 2026-07-07 (demande explicite), le SQL de l'IA s'execute sous le compte `postgres` SUPERUSER (plus de role `readonly_ai`) : `sql_guard` est desormais la SEULE barriere contre les requetes destructives.**
- Concurrence : `Semaphore(1)` cote Ollama (1 generation a la fois -> HTTP 429 si occupe)
- Budget `num_ctx=4096` tres tendu : keep-warm garde le SOCLE en cache KV ; ne pas gonfler le prompt
- Historique : `public.ai_conversations` + `ai_messages` (stockage "SQL seul", re-execute via `/rerun` a la reouverture)
- Doc detaillee : `docs/ANALYSE_IMPLEMENTATION_IA.md`, `README_ASSISTANT_IA.md`

## Commandes

```bash
# Backend
cd backend && pip install -r requirements.txt
python app.py                          # Dev
gunicorn -w 4 -b 0.0.0.0:5000 app:app # Prod

# Frontend
cd frontend && npm install
npm run dev                            # Dev (Vite)
npm run build                          # Build prod

# Docker
docker-compose up -d                   # Lancer tout
docker-compose up -d backend           # Backend seul
docker-compose up -d frontend          # Frontend seul
docker-compose logs -f backend         # Logs backend

# Assistant IA (sur le serveur 10.190.100.58)
./install_IA.sh                                          # Install Ollama + pull qwen2.5-coder:7b
docker-compose exec backend python -m services.ai_prompt_builder "question"  # Test prompt RAG
docker-compose exec backend python compare_prompts.py --n 10                 # Banc A/B prompts
python3 docs/eval_dataset.py --n 10                                          # Banc d'eval format

# Deploy
./deploybackend.sh
./deployfrontend.sh
```

## Points d'attention

- **Ne jamais commiter le fichier `.env`** (contient mots de passe DB, cles JWT)
- **Tout passe par le nginx de l'HOTE** (service systemd, config mirroree dans `nginx/`, jamais dans docker-compose). Repartition des ports : `80`, `3000` et `8080` -> **portail d'accueil** statique `/var/www/html/index.html` (`sites-available/default` pour 80+3000, `migration-factory-8080.conf` pour 8080) ; `8081` -> **application Migration Factory** (`sites-available/migration-factory.conf` : `/` -> frontend Vite sur `127.0.0.1:3100`, `/api/` et `/health` -> backend sur `127.0.0.1:5000`) ; `9120` -> Hermes. Les conteneurs sont bindes sur `127.0.0.1` dans `docker-compose.yml` et ne sont plus joignables depuis le reseau — le frontend est sur le port hote **3100** (et non 3000, repris par nginx pour le portail) ; les tests de sante des scripts de deploiement passent donc par `127.0.0.1:3100` / `127.0.0.1:5000`. Toute nouvelle route API doit rester sous `/api/` pour heriter des timeouts 3600s, de `client_max_body_size 200m` et de `proxy_buffering off` (indispensable au streaming SSE d'Hermes). Le frontend n'utilise que des URL **relatives** (`/api/v1`) : ne jamais recoder une URL absolue avec port. La map WebSocket `$connection_upgrade` est definie une seule fois dans `nginx/conf.d/hermes-ws-map.conf`, ne pas la redeclarer. Application : copier les fichiers dans `/etc/nginx/sites-available/`, lier dans `sites-enabled/`, puis `nginx -t` + `systemctl reload nginx`
- Les fichiers d'export sont generes en ZIP contenant des CSV
- Le systeme d'import supporte CSV, XLSX, XLS avec validation ligne par ligne
- L'integration SharePoint utilise NTLM pour l'authentification
- Le cache d'export a un TTL de 5 minutes (frontend et backend)
- Les tables SAP dans `raw_data` ne doivent jamais etre modifiees directement
- **Ecran IH02 (`/maintenance/ih02`, `api/ih02_hierarchy.py`)** : sert **uniquement** `clean_data.maintenance_object` (une table pour les 4 natures, via `object_type` ; `parent_id` porte l'arbre, `ref_object_id` l'article d'une ligne de nomenclature). `raw_data` y est en LECTURE SEULE (pick-lists crhd/crtx, equi/eqkt, mara/makt uniquement). L'ancien backend ecrivant dans `raw_data` et le flag `IH02_USE_MAINTENANCE_OBJECT` ont ete supprimes le 2026-07-30. `sap_key` = cle SAP immuable ; `code` = identifiant affiche, modifiable, unique **parmi les freres** via `uq_mo_code_sibling` (migration 028, hors `BOM_ITEM`) -> les routes qui ecrivent `code` renvoient 409 sur conflit. Suppression = soft delete (`is_active=false`). Attention : les ecrans Equipements et Articles ecrivent encore dans `raw_data`, leurs modifications n'apparaissent dans IH02 qu'apres un rechargement en mode fusion. Doc : `docs/README_MIGRATION_IH02.md` §8quinquies
- **Chargement de `maintenance_object`** : `clean_data.load_maintenance_object[_merge](p_root_tplnr)` n'importe que la racine (defaut `'T'`) et ses descendants ; le mode fusion purge en plus les postes SAP hors perimetre. `raw_data.sp_keep_only_t_hierarchy()` est obsolete (elle supprimait dans les tables SAP)
- **Module Maintenance (etats sauvegardes / rechargement SAP)** : `POST /api/v1/maintenance/reload` avec `mode=merge` preserve le travail utilisateur (lignes `source='MANUAL'` ou `updated_by IS NOT NULL`) via `clean_data.load_maintenance_object_merge()` ; `mode=reset` appelle la procedure destructive d'origine. Un snapshot automatique precede toujours l'operation. Un seul job maintenance a la fois (index unique + verrou consultatif `778812`) ; les ecrans maintenance renvoient 409 pendant. `sql/maintenance/compile.sh` contient un `DROP TABLE CASCADE` : ne jamais le lancer entierement sur une base en service. Doc : `docs/README_MIGRATION_IH02.md` §8quater
- **Assistant IA** : ne jamais elargir le prompt systeme sans retirer ailleurs (`num_ctx=4096` sature -> troncature des regles SAP critiques + hallucinations). Apres redeploiement/changement de prompt, laisser ~8-10 min de chauffe sans solliciter l'assistant (eviter de spammer "reessayer" sur un timeout, ca casse le keep-warm). Ollama doit ecouter sur `127.0.0.1` (ne pas exposer le port 11434)
