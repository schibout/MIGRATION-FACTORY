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
- `raw_data` : 121 tables SAP brutes (lecture seule)
- `clean_data` : 45 vues/tables transformees pour IFS
- `public` : 15 tables systeme (users, jobs, configs, logs)

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
- Migrations SQL dans `migrations/` (numerotees 003_, 004_, etc.)
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
- Les fichiers d'export sont generes en ZIP contenant des CSV
- Le systeme d'import supporte CSV, XLSX, XLS avec validation ligne par ligne
- L'integration SharePoint utilise NTLM pour l'authentification
- Le cache d'export a un TTL de 5 minutes (frontend et backend)
- Les tables SAP dans `raw_data` ne doivent jamais etre modifiees directement
- **Assistant IA** : ne jamais elargir le prompt systeme sans retirer ailleurs (`num_ctx=4096` sature -> troncature des regles SAP critiques + hallucinations). Apres redeploiement/changement de prompt, laisser ~8-10 min de chauffe sans solliciter l'assistant (eviter de spammer "reessayer" sur un timeout, ca casse le keep-warm). Ollama doit ecouter sur `127.0.0.1` (ne pas exposer le port 11434)
