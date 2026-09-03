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
  api/interface_contracts.py        # Contrats d'interface (blueprint /api/v1/interface-contracts/*)
  services/interface_contract_excel.py  # Lecture/generation du classeur de contrat
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
- Migrations SQL dans `migrations/` (numerotees 003_, 004_, etc. — dernier numero utilise : 052)
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
- **Valeurs par defaut ETL parametrables** (migration 031, ecran `/configuration/valeurs-defaut`) : les constantes des fonctions ETL supplier passent par `public.get_default_value(table_cible, colonne, fallback[, variante])`, le fallback etant l'ancienne valeur codee en dur -> comportement inchange si la table `public.etl_default_values` est vide ou la ligne desactivee. Les changements ne s'appliquent qu'au **prochain chargement ETL** (les donnees deja chargees ne bougent pas). **`get_default_value` retourne TEXT et PostgreSQL n'a aucun cast implicite texte->numeric/boolean/date/entier** : toute colonne cible non textuelle exige un cast explicite (`::numeric`, `::date`) et tout repli numerique doit etre quote (`'1'`, jamais `1`, sinon la resolution de fonction echoue). **Les DDL du depot (`sql/*/viewsAndTables/`, `sql/structure/`, `sql/inventory/sources/`) sont perimes et divergent de la base reelle** : verifier les types via `information_schema.columns` sur la base, jamais dans ces fichiers. **Depuis 2026-08-27, tous les modules ETL sont branches** : supplier, articlePhl, customer, customer_phl, customerFile, inventory, operation, projet (via `sql/config/apply_default_values.py`, 977 litteraux remplaces) et pm_actions (constantes du bloc `DECLARE`, invisibles pour l'inventaire automatique). Les anciennes lignes `A_ARBITRER` (meme colonne, valeurs differentes selon le bloc) sont traitees elles aussi, avec une variante par bloc : `cus_comm_method` -> `PHONE_PRINCIPAL` / `PHONE_SECONDAIRE` / `PHONE_ADRESSE` / `FAX` / `FAX_ADRESSE` / `EMAIL_PRINCIPAL` / `TELEX` / `TELETEX` (partagees par customer et customerFile), `inventory_part` -> `ARTICLEPHL` vs `SILICIUM`. Il ne reste code en dur que les colonnes d'audit (`created_by`, `updated_by`, `is_deleted`) et les expressions derivees (CASE / COALESCE), hors perimetre par construction. `python sql/config/verifier_valeurs_defaut.py` verifie l'ensemble : chaque appel a `get_default_value` doit avoir sa ligne seedee avec un repli identique, et aucun litteral d'inventaire ne doit subsister (sortie 0 = coherent). **Piege des variantes** : une meme cle (table, colonne) partagee par plusieurs modules avec des valeurs divergentes recoit une variante par module (`CUSTOMER`, `CUSTOMERFILE`, `CUSTOMER_PHL`, `INVENTORY`, `ARTICLEPHL`...) ; un appel sans 4e argument lirait alors la ligne `STANDARD` d'un AUTRE module (ex. `payment_way_per_identity.party_type` = `Supplier`). `apply_default_values.py` resout la variante depuis les migrations de seed et refuse de reecrire une ligne dont le litteral differe de la valeur seedee. Etendre a un nouveau module = generer l'inventaire CSV (`extract_default_values.py`), le seed (`generate_default_values_seed.py`), puis `apply_default_values.py sql/<module>` ; l'API et l'ecran n'ont pas a changer
- **Contrats d'interface (`/interface-contracts`, `api/interface_contracts.py`, migrations 051/052)** : remplace le classeur fige `contrat_interface_SAP_IFS_*.xlsx`. La **definition technique** (`interface_contract_table` + `_column`) et l'**etat de validation metier** (`_validation`, journal `_event`) sont dans des tables SEPAREES : corriger une regle n'efface jamais la relecture, elle la rend « obsolete » (`v_interface_contract.validation_obsolete`, calcule en comparant `column.updated_at` a `validation.validated_at`). **Consequence : tout horodatage ecrit par le code doit venir de l'horloge PostgreSQL (`db.func.current_timestamp()`), jamais de `datetime.utcnow()`** — le serveur de base est en UTC+2, un `utcnow()` Python rendait toute validation immediatement obsolete. Cle naturelle d'une ligne = (table, **section**, colonne cible) : un onglet documente parfois deux fois la meme colonne (chargement en 2 etapes, cf. `payment_address`). Chargement initial : `python scripts/seed_interface_contracts.py [classeur.xlsx] [--module X]` (idempotent, ne reecrit que ce qui a change) ; **ensuite la base est la source de verite**, le script ne sert qu'a amorcer un nouveau module. Permissions : `validate_contracts` (operator+admin) pour valider/commenter/signer, `manage_contracts` (admin) pour le CRUD, l'import Excel et le demasquage des echantillons sensibles (IBAN, identifiants fiscaux). L'export regenere le classeur depuis la base, l'import ne reprend que les colonnes jaunes (jamais la definition). `openpyxl` n'est pas installe sur l'hote : lancer le seed dans le conteneur (`docker exec -e PYTHONPATH=/app migration-app-backend python ...`)
- **Navigation frontend** : `frontend/src/components/layout/Sidebar.tsx` est du **code mort** (jamais importe). Le menu reel vient du tableau `menuItems` de `components/layout/Layout.tsx`, et la sous-navigation Configuration de la grille de cartes `configItems` dans `pages/Configuration.tsx` : une nouvelle page de configuration doit y etre ajoutee, sinon elle est inaccessible malgre sa route
- **Assistant IA** : ne jamais elargir le prompt systeme sans retirer ailleurs (`num_ctx=4096` sature -> troncature des regles SAP critiques + hallucinations). Apres redeploiement/changement de prompt, laisser ~8-10 min de chauffe sans solliciter l'assistant (eviter de spammer "reessayer" sur un timeout, ca casse le keep-warm). Ollama doit ecouter sur `127.0.0.1` (ne pas exposer le port 11434)
