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
- Migrations SQL dans `migrations/` (numerotees 003_, 004_, etc. — dernier numero utilise : 074)
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
- **Nomenclatures IH02 : deux chemins, pas un** (2026-09-08, `sql/maintenance/proc_load_maintenance_object[_merge].sql`). La nomenclature d'un poste technique vient soit de `tpst -> stko -> stpo (stlty='T')` (passe 5a), soit — pour les **53 % de postes sans aucune ligne `tpst`** — de son **type de construction IBAU** : `raw_data.iflo.submt -> mara -> mast -> stpo (stlty='M')` (passe 5c / `4c` en MERGE), rattachee **a plat** sous le poste comme dans SAP, tracee par `attributes.origin='SUBMT'` + `attributes.submt`. `tpst` prime sur `submt` (`NOT EXISTS`). **Le submt n'est lisible que dans `raw_data.iflo`** : `iflot.submt` et `iflot.ematn` sont vides sur 100 % des lignes (defaut d'extraction), d'ou l'usage de cette vue SAP malgre la mefiance affichee en passe 1 — avec `RAISE WARNING` si `iflo` est vide. **Le prefixe `'S:'` de la `sap_key` est obligatoire** : la meme nomenclature est deja chargee en 5b sous le noeud ARTICLE de l'IBAU avec le prefixe `'M:'`, et reutiliser `'M:'` en perdrait une par `ON CONFLICT DO NOTHING`. La passe ARTICLE materialise aussi les `iflo.submt` (+493) car elle ne partait que des composants `stpo.idnrk` : sans cela un IBAU de haut de structure n'existe pas et sa BOM n'est jamais chargee — **ne pas elargir a toutes les tetes de `mast`** (+10 627 articles inatteignables dans l'arbre). Cote lecture, `/bom`, `/bom-counts`, `POST`/`PUT /bom-component` ne filtrent plus `attributes->>'stlty'='T'` (la jointure sur un parent `FUNC_LOC` suffit) ; **`v_fl_nomenclature` ne filtre plus `stlty` non plus** (demande explicite) -> l'export IFS `equipment_object_spare` passe de 14 731 a 20 221 lignes. `recreate_v_fl_nomenclature.sql` n'etait rejouable qu'une fois (`DROP MATERIALIZED VIEW IF EXISTS` echoue sur une vue simple) : il teste desormais `pg_class.relkind` et fait un `CREATE OR REPLACE VIEW` sans `CASCADE`. Perimetre : les ancres de la recursion acceptent les postes a `tplma` vide portant le prefixe de la racine (`T200-X060-60`, `T300-X050` -> 12 627 postes). **Tri de l'arbre** : les `FUNC_LOC` sont ordonnes par `code` (le code AFFICHE) et NON par `sap_key` — 498 postes portent un strno different de leur tplnr et les postes en numerotation interne ont un sap_key `?01000000000000000xx`, ce qui donnait 105 fratries dans un ordre incoherent avec l'ecran (sous `T000-V`, V050 arrivait apres V900). **Les `EQUIPMENT` restent ordonnes par `sap_key`** : leur `code` est `equnr` sans les zeros de tete, donc un tri texte mettrait 100 avant 99, alors que `sap_key` est complete a 18 zeros et donne le bon ordre numerique. Doc : `docs/README_MIGRATION_IH02.md` §8sexies
- **`raw_data.stas` n'existe pas et `eqst` n'est jamais lue** : les alternatives de nomenclature ne sont pas discriminables (la passe 5a joint `stpo` sur `stlnr` seul, sans `stlal` -> deux alternatives partageant un `posnr` produisent la meme `sap_key`, l'une est perdue silencieusement) et aucune nomenclature d'equipement n'est chargee
- **Module Maintenance (etats sauvegardes / rechargement SAP)** : `POST /api/v1/maintenance/reload` avec `mode=merge` preserve le travail utilisateur (lignes `source='MANUAL'` ou `updated_by IS NOT NULL`) via `clean_data.load_maintenance_object_merge()` ; `mode=reset` appelle la procedure destructive d'origine. Un snapshot automatique precede toujours l'operation. Un seul job maintenance a la fois (index unique + verrou consultatif `778812`) ; les ecrans maintenance renvoient 409 pendant. `sql/maintenance/compile.sh` contient un `DROP TABLE CASCADE` : ne jamais le lancer entierement sur une base en service. Doc : `docs/README_MIGRATION_IH02.md` §8quater
- **Valeurs par defaut ETL parametrables** (migration 031, ecran `/configuration/valeurs-defaut`) : les constantes des fonctions ETL supplier passent par `public.get_default_value(table_cible, colonne, fallback[, variante])`, le fallback etant l'ancienne valeur codee en dur -> comportement inchange si la table `public.etl_default_values` est vide ou la ligne desactivee. Les changements ne s'appliquent qu'au **prochain chargement ETL** (les donnees deja chargees ne bougent pas). **`get_default_value` retourne TEXT et PostgreSQL n'a aucun cast implicite texte->numeric/boolean/date/entier** : toute colonne cible non textuelle exige un cast explicite (`::numeric`, `::date`) et tout repli numerique doit etre quote (`'1'`, jamais `1`, sinon la resolution de fonction echoue). **Les DDL du depot (`sql/*/viewsAndTables/`, `sql/structure/`, `sql/inventory/sources/`) sont perimes et divergent de la base reelle** : verifier les types via `information_schema.columns` sur la base, jamais dans ces fichiers. **Depuis 2026-08-27, tous les modules ETL sont branches** : supplier, articlePhl, customer, customer_phl, customerFile, inventory, operation, projet (via `sql/config/apply_default_values.py`, 977 litteraux remplaces) et pm_actions (constantes du bloc `DECLARE`, invisibles pour l'inventaire automatique). Les anciennes lignes `A_ARBITRER` (meme colonne, valeurs differentes selon le bloc) sont traitees elles aussi, avec une variante par bloc : `cus_comm_method` -> `PHONE_PRINCIPAL` / `PHONE_SECONDAIRE` / `PHONE_ADRESSE` / `FAX` / `FAX_ADRESSE` / `EMAIL_PRINCIPAL` / `TELEX` / `TELETEX` (partagees par customer et customerFile), `inventory_part` -> `ARTICLEPHL` vs `SILICIUM`. Il ne reste code en dur que les colonnes d'audit (`created_by`, `updated_by`, `is_deleted`) et les expressions derivees (CASE / COALESCE), hors perimetre par construction. `python sql/config/verifier_valeurs_defaut.py` verifie l'ensemble : chaque appel a `get_default_value` doit avoir sa ligne seedee avec un repli identique, et aucun litteral d'inventaire ne doit subsister (sortie 0 = coherent). **Piege des variantes** : une meme cle (table, colonne) partagee par plusieurs modules avec des valeurs divergentes recoit une variante par module (`CUSTOMER`, `CUSTOMERFILE`, `CUSTOMER_PHL`, `INVENTORY`, `ARTICLEPHL`...) ; un appel sans 4e argument lirait alors la ligne `STANDARD` d'un AUTRE module (ex. `payment_way_per_identity.party_type` = `Supplier`). `apply_default_values.py` resout la variante depuis les migrations de seed et refuse de reecrire une ligne dont le litteral differe de la valeur seedee. Etendre a un nouveau module = generer l'inventaire CSV (`extract_default_values.py`), le seed (`generate_default_values_seed.py`), puis `apply_default_values.py sql/<module>` ; l'API et l'ecran n'ont pas a changer
- **Sources articles PHL separees par site** (migration 068) : chaque site a sa table de staging — `raw_data.phl_article` (SJ = Saint-Jean, table historique) et `raw_data.phl_article_cs` (CS = Castel, structure clonee par `LIKE`). `raw_data.v_phl_article_retenu` les expose en `UNION ALL` avec une colonne **`site`**, et les 5 fonctions `clean_data.alimenter_*_phl(p_contract)` filtrent sur `site = p_contract` (16 emplacements) : **un article n'est charge que sur le site de son fichier d'origine**. Avant la 068 les deux passes ETL de la migration 033 lisaient toutes les lignes, donc chargeaient le MEME catalogue sur les deux sites. `part_catalog` reste mono-site (garde `NOT EXISTS` sur `part_no`) : un article present dans les deux fichiers n'y est cree qu'une fois, par la passe SJ qui s'execute en premier. `clean_data.nettoyer_phl_article()` traite les DEUX tables, avec une seule liste de colonnes appliquee par `format('%I')`. Toute evolution de colonne doit etre faite sur les deux tables puis la vue rejouee. Migration 068 + `cd sql/articlePhl && ./compile.sh`, puis import de chaque fichier dans SA table (la cible doit etre declaree dans `public.import_types`). `sql/inventory/sources/v_phl_article_retenu.sql` est un dump regenere par `export_procedures.sh`, jamais compile : ne pas s'en servir comme reference
- **Colonnes articlePhl non alimentees par le fichier** (migration 069) : les 5 tables cibles totalisent 405 colonnes ; 169 n'etaient ecrites par aucun INSERT et restaient NULL, invisibles dans l'ecran. Elles passent desormais toutes par `public.get_default_value(table, colonne, **'ARTICLEPHL'**)`. La variante est obligatoire : 76 de ces cles portent deja une ligne `COMPOSANT` (module articleComposant, memes tables IFS) — sans variante dediee, articlePhl lirait la valeur d'un autre module. Colonnes NON textuelles : `NULLIF(get_default_value(...), '')::numeric` — sans le `NULLIF`, une case laissee vide dans l'ecran fait echouer `''::numeric` (22P02) et casse tout le chargement. Effet mesure : les 127 colonnes texte ne sont plus jamais NULL (chaine vide a defaut de valeur), les 42 numeric/timestamp restent NULL tant qu'aucune valeur n'est saisie. Hors perimetre par construction : audit (`create_date`, `date_entered`), derivees (`default_print_unit` = `pc.unit_code`) et les 2 colonnes ecrites par un UPDATE (`part_catalog.lot_quantity_rule`, `sales_part.intrastat_conv_factor`). **Toute migration de seed doit utiliser un `INSERT ... VALUES (...)` par ligne** : `apply_default_values._decouper_valeurs` s'arrete a la premiere parenthese fermante, un `VALUES` multi-lignes n'est lu qu'a moitie. Toute nouvelle migration de seed doit aussi etre ajoutee a `FICHIERS_SEED` dans `sql/config/apply_default_values.py`, sinon `verifier_valeurs_defaut.py` signale les appels comme orphelins
- **Matrice Site x Famille** (migration 066, ecran `/configuration/matrice-site-famille`) : quand une valeur par defaut depend du site (`contract`) ET de la famille d'article (`"FAMILLE"` du fichier PHL), elle se parametre dans `public.etl_default_value_matrix` au lieu de `etl_default_values`. Les loaders appellent `public.get_default_value_ctx(table, colonne, contract, famille)` qui resout en 3 niveaux : matrice (site+famille > site > famille > joker) -> constante `get_default_value` -> NULL. Second volet : `public.etl_part_type_matrix` + `get_part_type_matrix(table, contract, famille)` decide quelles tables creer pour un article (`sales_part` / `purchase_part` / `manuf_part_attribute`, cumulables) ; absence de ligne = creation autorisee (`COALESCE(..., TRUE)` cote loader), et passer une cellule a FALSE purge aussi les lignes deja chargees. Branche sur les **5** procedures `sql/articlePhl/alimenter_*_phl.sql` depuis la migration 071 (cf. puce suivante). Unicite par index d'expression sur `COALESCE(contract,'*')` (deux NULL sont distincts pour un UNIQUE). Migration 066 + `cd sql/articlePhl && ./compile.sh` a jouer sur le serveur. Doc : `docs/README_MATRICE_VALEURS_DEFAUT.md`
- **articlePhl : la matrice est l'UNIQUE source des valeurs par defaut** (migration 071, demande explicite). Les 5 procedures `alimenter_*_phl` n'appellent plus ni `get_default_value` ni `get_default_value_ctx` mais `public.get_matrix_value(table, colonne, contract, part_family)` (381 appels), qui lit **la seule** `public.etl_default_value_matrix`, **sans aucun repli** sur `etl_default_values` : une colonne sans regle dans la matrice vaut NULL au chargement. La 071 a donc d'abord recopie en regles joker (contract NULL + part_family NULL) les 142 constantes actives que les procedures resolvaient jusque-la (95 inserees, 47 deja couvertes par une regle joker saisie a l'ecran) ; les 206 autres colonnes appelees resolvaient deja NULL et n'ont rien recu. `get_matrix_value` **ignore la variante** : les appels portaient `ARTICLEPHL`/`FIL`/rien alors que l'ecran ecrit toujours `STANDARD`, chercher avec la variante de l'appel aurait rendu illisibles les regles saisies sur 174 colonnes. **Les autres modules ETL (supplier, customer, inventory, operation, projet, pm_actions...) restent sur `get_default_value` : ne pas leur appliquer ce schema sans demande.** Consequence a connaitre : `sql/config/verifier_valeurs_defaut.py` ne couvre plus articlePhl (il ne connait que `get_default_value[_ctx]`). Piege : un appel place dans une sous-requete du `FROM` doit etre en `LATERAL` **apres** `raw_data.v_phl_article_retenu phl`, sinon `phl."FAMILLE"` n'est pas dans le scope (erreur `missing FROM-clause entry for table "phl"` a l'execution seulement, jamais a la compilation). Verification : `BEGIN; SELECT clean_data.alimenter_all_phl('SJ'); ... ROLLBACK;`
- **articleComposant : idem, et la FAMILLE separe les deux modules** (migration 072). Les 5 procedures `sql/ArticleComposant/alimenter_*_cmp.sql` sont passees aux memes `get_matrix_value` (448 appels, famille = `NULLIF(TRIM(cmp.famille), '')`, source `raw_data.composant_sj_cs`). **La matrice ignore la notion de module** (cle = table, colonne, variante, site, famille ; et l'ecran n'ecrit QUE `STANDARD` -- `saveValue` n'envoie jamais de variante) : sur les 211 colonnes communes aux deux modules, les **50** qui attendent une valeur differente (ex-variantes `ARTICLEPHL` vs `COMPOSANT`) sont separees par la **famille**, disjointe entre modules (PHL = 20/21/22/23/24/RF... ; composant = AL/BL/CR/EB/FX/HS/MA/MP/MS/MY/RS/SC/TM). La 072 a donc seede 738 regles : 7 jokers (colonnes propres au composant), 650 par famille, 90 par (site, famille) pour les 6 ex-variantes `COMPOSANT_SJ`/`_CS`, et rien pour les 161 colonnes deja alignees. **Consequence : ajouter une famille composant sans lui creer ses regles la ferait heriter des valeurs articlePhl sur ces 50 colonnes** (visible dans l'ecran comme valeur heritee). Les familles MP et MY, presentes en donnees mais absentes du referentiel, ont ete declarees par la 072 pour que leurs regles aient une colonne dans l'ecran. Meme piege de scope que pour PHL, sous une autre forme : `alimenter_part_catalog_cmp` avait une CTE `def` **sans FROM** (legitime pour des constantes) ; les expressions ont ete fusionnees dans la CTE `src`, seule a avoir l'alias `cmp`.
- **`clean_data.purchase_part` ne peut pas etre alimente par PHL** (constat 2026-09-06, anterieur a la 071) : `alimenter_purchase_part_phl` ne retient que les articles dont le `STATUT` n'est **pas** F/I, tout en exigeant un `EXISTS` sur `part_catalog` qui, lui, ne recoit que les F/I. La table reste donc vide sur les deux sites, quel que soit le routage `etl_part_type_matrix`.
- **Axes de la matrice = referentiels, jamais les donnees chargees** (migrations 067 familles/tables cibles, 070 sites ; ecran `/configuration/matrice-parametres`, `api/matrix_settings.py`) : `public.etl_site`, `etl_part_family` et `etl_matrix_target_table` pilotent UNIQUEMENT ce que l'ecran propose, aucune procedure ETL ne les lit (le site de chargement vient de `etl_target_tables.module_params`). L'axe des sites (`_sites_de_l_ecran()` dans `api/default_value_matrix.py`) est l'union ordonnee de 4 sources : referentiel actif (il fixe l'ordre) > sites chargés dans `clean_data.inventory_part` > sites livres dans `raw_data.v_phl_article_retenu` > sites deja porteurs d'une regle, avec `SITES_REPLI = ['SJ','CS']` en dernier filet. **Ne jamais rededuire un axe du seul resultat de l'ETL** : l'axe venait de `SELECT DISTINCT contract FROM clean_data.inventory_part`, et comme seule la passe CS avait ete chargee, la colonne SJ disparaissait en emportant 36 regles Saint-Jean — invisibles et non modifiables, mais toujours appliquees par `get_default_value_ctx()`. Meme regle pour les familles. Renommer ou supprimer un code encore utilise par une regle renvoie 409 (desactiver reste possible : la colonne disparait, les regles survivent). Garde-fou : `backend/tests/test_matrix_meta_sites.py`
- **Contrats d'interface (`/interface-contracts`, `api/interface_contracts.py`, migrations 051/052)** : remplace le classeur fige `contrat_interface_SAP_IFS_*.xlsx`. La **definition technique** (`interface_contract_table` + `_column`) et l'**etat de validation metier** (`_validation`, journal `_event`) sont dans des tables SEPAREES : corriger une regle n'efface jamais la relecture, elle la rend « obsolete » (`v_interface_contract.validation_obsolete`, calcule en comparant `column.updated_at` a `validation.validated_at`). **Consequence : tout horodatage ecrit par le code doit venir de l'horloge PostgreSQL (`db.func.current_timestamp()`), jamais de `datetime.utcnow()`** — le serveur de base est en UTC+2, un `utcnow()` Python rendait toute validation immediatement obsolete. Cle naturelle d'une ligne = (table, **section**, colonne cible) : un onglet documente parfois deux fois la meme colonne (chargement en 2 etapes, cf. `payment_address`). Chargement initial : `python scripts/seed_interface_contracts.py [classeur.xlsx] [--module X]` (idempotent, ne reecrit que ce qui a change) ; **ensuite la base est la source de verite**, le script ne sert qu'a amorcer un nouveau module. Permissions : `validate_contracts` (operator+admin) pour valider/commenter/signer, `manage_contracts` (admin) pour le CRUD, l'import Excel et le demasquage des echantillons sensibles (IBAN, identifiants fiscaux). L'export regenere le classeur depuis la base, l'import ne reprend que les colonnes jaunes (jamais la definition). `openpyxl` n'est pas installe sur l'hote : lancer le seed dans le conteneur (`docker exec -e PYTHONPATH=/app migration-app-backend python ...`)
- **Navigation frontend** : `frontend/src/components/layout/Sidebar.tsx` est du **code mort** (jamais importe). Le menu reel vient du tableau `menuItems` de `components/layout/Layout.tsx`, et la sous-navigation Configuration de la grille de cartes `configItems` dans `pages/Configuration.tsx` : une nouvelle page de configuration doit y etre ajoutee, sinon elle est inaccessible malgre sa route
- **Assistant IA** : ne jamais elargir le prompt systeme sans retirer ailleurs (`num_ctx=4096` sature -> troncature des regles SAP critiques + hallucinations). Apres redeploiement/changement de prompt, laisser ~8-10 min de chauffe sans solliciter l'assistant (eviter de spammer "reessayer" sur un timeout, ca casse le keep-warm). Ollama doit ecouter sur `127.0.0.1` (ne pas exposer le port 11434)
