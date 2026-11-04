# Migration Factory - instructions communes Claude et Codex

## Projet et points d'entree

Migration SAP ECC 6.0+ vers IFS : React 18, TypeScript, Material UI et Vite ;
Flask 2.3, SQLAlchemy 2, Python 3.11 ; PostgreSQL externe ; Docker Compose.

- Backend : `backend/app.py`, routes `backend/api/`, logique `backend/services/`,
  loaders `backend/etl_modules/`, SQL dans `sql/`, migrations dans `migrations/`.
- Frontend : `frontend/src/pages/`, `components/`, `services/`, Redux Toolkit.
- Routes API sous `/api/v1/`, JWT et logs loguru. Axios utilise des URL relatives.
- Le menu reel est dans `frontend/src/components/layout/MainLayout.tsx` ;
  `Sidebar.tsx` est un ancien composant inutilise.

## Regles de travail

- Repondre en francais et privilegier les changements limites au besoin demande.
- Ne jamais versionner `.env`, mots de passe, jetons, donnees importees ou backups.
- Les demandes utilisateur autorisent les travaux necessaires dans leur perimetre ;
  ne pas demander de confirmation supplementaire pour une operation deja autorisee.
- Ne pas deployer, lancer de migration ou contacter des services en production
  pour une simple verification locale. Distinguer tests hors ligne et integration.
- Ne pas modifier directement les tables SAP `raw_data`.
- Les requetes d'export sont dynamiques dans `public.etl_export_queries`.
- Trouver le prochain numero libre dans les fichiers `migrations/` : ne pas
  conserver de compteur manuel dans les instructions.

## Maintenance et ETL

`raw_data` contient les sources SAP, `clean_data` les transformations IFS,
`public` les tables systeme et configurations. Inspecter les types et contraintes
avant d'ecrire un loader ; ne pas generaliser un exemple a tout le schema.

- IH02 et ses exports reposent sur `clean_data.maintenance_object`.
- Fusion maintenance : preserver `source='MANUAL'` et `updated_by IS NOT NULL`.
  Un snapshot precede le rechargement ; un seul job, verrou 778812, retours 409.
- `mode=reset` est destructif. `sql/maintenance/compile.sh` contient un
  `DROP TABLE CASCADE` : ne pas le lancer entierement sur une base en service.
- Respecter les regles SAP des nomenclatures T/M/E, les cles et les perimetres
  propres au module. Lire `docs/README_MIGRATION_IH02.md` avant de les changer.
- Imports CSV/XLSX/XLS suivis par `import_jobs` et `import_details` ; exports ZIP/CSV.
  Les identifiants fournisseur IFS restent ceux du fichier source.

## Assistant IA applicatif

Pipeline question FR -> RAG (`ai_prompt_builder`, `ai_schema_retriever`) -> LLM
-> `sql_filters` -> `sql_guard` -> execution et tableau de resultats.

- Ollama local : `qwen2.5-coder:7b`, CPU, semaphore 1 ; provider externe optionnel
  via `llm_service` et `external_llm_service`, meme prompt RAG.
- Profil compact : `num_ctx=4096`, ne pas grossir le prompt sans retirer ailleurs.
  Les budgets externes peuvent utiliser le profil large (`ai_rag_budget`).
- Pas de filtres techniques SAP mandt/loevm/lvorm/loekz/stblg dans les few-shots.
  Apres modification : `python build_ai_index.py --only examples` depuis backend.
- Depuis la demande du 2026-07-07, l'application execute le SQL IA avec `postgres`
  SUPERUSER : conserver ce choix explicite. `sql_guard` reste une barriere critique.
  Le role propose pour les outils de developpement ne change pas ce compte.
- Conserver JWT, SELECT/WITH seulement, controles DDL/DML, LIMIT, timeout 30 s et audit.
- Apres changement de prompt/redeploiement, laisser 8-10 minutes de chauffe ;
  ne pas lancer de generation automatiquement depuis un hook ou une CI.
- Documentation : `README_ASSISTANT_IA.md`, `docs/ANALYSE_IMPLEMENTATION_IA.md`.

## Environnement et verifications

- Installer les outils : `README.md`, `install_claude.sh`, `install_codex.sh`.
- Verifier : `python scripts/ai/verify_change.py --plan`, puis la meme commande
  sans `--plan`. `--staged` pour l'index, `--all` pour le socle hors ligne complet.
- Backend : tests cibles depuis `backend/`. Certains tests se connectent a la
  vraie base meme si leur transaction est annulee ; ne pas lancer tout pytest
  automatiquement. Le verificateur maintient une liste hors ligne explicite.
- Frontend : `npm ci`, `npm run build`, `npm run lint` dans `frontend/`.
- Les skills sources sont dans `.agents/skills/`. Les copies Claude sont
  generees par `python scripts/ai/sync_skills.py` et controlees avec `--check`.
- Reviewers : `reviewer-sap-ifs` et `reviewer-fullstack` ; fournir le diff et les
  fichiers utiles. Ils produisent une revue, l'assistant principal fait les changements.
- Graphify est installe et le graphe du projet est disponible dans
  `graphify-out/graph.json`. Claude et Codex doivent le consulter en priorite pour
  les questions d'architecture, de dependances, de flux et de localisation afin
  de reduire le contexte charge et le nombre de tokens :
  `graphify query "<question precise>" --budget 1500`.
- Utiliser `graphify path` pour relier deux concepts et `graphify explain` pour
  expliquer un noeud. Ne pas reconstruire le graphe pour une simple question ;
  `/graphify --update` est reserve aux demandes explicites de mise a jour.
- Graphify sert d'index de navigation. Avant toute modification, verifier les
  faits importants dans le code et les migrations actuels, qui restent la source
  de verite. Si Graphify n'est pas accessible dans une session, continuer avec
  `rg` et la lecture ciblee des fichiers sans bloquer la tache.

## Deployment et documentation metier

Le nginx de l'hote sert l'application sur 8081, le frontend sur loopback 3100,
le backend sur loopback 5000. Les ports 80/3000/8080 servent le portail d'accueil.
Les conventions locales Vite peuvent differer : lire la configuration avant usage.
Ne pas recoder d'URL API absolue ni exposer Ollama sur le reseau.

L'ancien CLAUDE.md est conserve integralement dans `docs/ai/project-reference.md`.
Pour IH02, PE Tools, articles, finance, ressources, contrats d'interface ou loaders,
y rechercher les symboles du module et lire les passages utiles. Cette reference
historique peut contenir des constats anciens : verifier avec le code et les
migrations actuels. `AGENTS.md` est le socle commun, pas un journal des corrections.
