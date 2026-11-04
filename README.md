# Migration Factory — environnement de développement Claude et Codex

Application de migration SAP ECC vers IFS : Flask/Python, React/TypeScript/MUI,
PostgreSQL et Docker Compose. Ce guide installe les assistants et leurs outils
de développement. L'installation de l'IA **applicative Ollama** reste décrite
dans [README_ASSISTANT_IA.md](README_ASSISTANT_IA.md).

## Installation rapide

Cloner le dépôt, ouvrir un terminal **Bash à sa racine**, puis :

```bash
bash install_claude.sh --dry-run --vscode
bash install_codex.sh --dry-run

bash install_claude.sh --vscode
bash install_codex.sh
```

Sur Windows, utiliser **Git Bash** ou WSL pour les fichiers `.sh`. Ne pas les
exécuter directement dans PowerShell. Dans WSL, les CLI sont installées dans
Linux ; elles sont distinctes des CLI Windows. Ouvrir ensuite le dossier avec
VS Code et choisir l'environnement local ou distant correspondant.

Prérequis : Git, Bash, **Node.js 20+ avec npm**, **Python 3.11+** et un accès
réseau aux registres et marketplaces. Pour créer l'environnement du backend,
préférer Python **3.11**, version de l'application. VS Code est nécessaire
seulement avec `--vscode`. `curl` est requis pour installer Claude sous Unix ;
Git Bash utilise son installateur PowerShell natif.

Les scripts conservent les CLI présentes dans le PATH. Si elles sont absentes,
Claude est installé par l'installateur natif sur le canal `stable`, et Codex
par `npm install -g @openai/codex@latest`. Aucune utilisation de `sudo` et aucune
connexion à PostgreSQL n'est effectuée. Une installation npm globale doit donc
avoir un préfixe accessible à l'utilisateur, par exemple via un gestionnaire Node.

## Options des deux scripts

| Option | Effet |
| --- | --- |
| `--dry-run` | Affiche les actions sans écriture, installation ni appel réseau. |
| `--configure-only` | Synchronise uniquement les skills du dépôt ; aucun appel aux CLI. |
| `--skip-cli` | Exige une CLI existante sans la mettre à jour. |
| `--update-cli` | Réinstalle explicitement Claude stable ou Codex publié sur npm. |
| `--vscode` | Installe les extensions officielles Python, Pylance, debugpy, Black, Flake8, Prettier, ESLint et l'assistant concerné. |
| `--design` | Ajoute le plugin `frontend-design`. |
| `--help` | Affiche l'aide. |

```bash
bash install_claude.sh --update-cli
bash install_codex.sh --skip-cli --design
bash install_claude.sh --configure-only
```

`--skip-cli` et `--update-cli` sont incompatibles. `--configure-only` n'accepte
pas les options d'installation `--update-cli`, `--vscode` ou `--design`.
Les erreurs de téléchargement et d'installation arrêtent le script et sont
renvoyées au terminal ; une installation partielle peut être relancée.

Les versions des CLI et des plugins restent celles fournies par les canaux
choisis au moment de l'installation. Ce dispositif est relançable ; il ne
constitue pas un verrouillage complet des versions des produits externes.

## Connexion et vérification des assistants

Après installation, ouvrir un nouveau terminal et démarrer `claude` puis
`codex` pour se connecter à ses comptes. Les scripts ne créent pas de compte,
ne copient pas de jeton et ne modifient pas les fichiers d'authentification.

```bash
claude --version
claude plugin list
codex --version
codex plugin list
```

Context7 est enregistré sans ouvrir de connexion interactive pendant
l'installation. Si le service demande une authentification :

```bash
codex mcp login context7
```

Si la CLI et l'extension VS Code ont des comportements différents, comparer
les versions et les exécutables : `type -a claude codex` dans Bash,
`Get-Command claude,codex -All` dans PowerShell. Le terminal peut conserver
une ancienne installation npm alors que l'extension utilise sa CLI embarquée.
Relancer avec `--update-cli` pour installer la CLI du canal prévu, puis vérifier
le PATH dans un nouveau terminal. Aucune version arbitraire de modèle n'est imposée.

## Plugins, skills et agents fournis

| Assistant | Ensemble installé |
| --- | --- |
| Claude | `playwright`, `code-review`, `context7` depuis `anthropics/claude-plugins-official`, au niveau projet. |
| Codex | `playwright` et `code-review` depuis la même marketplace ; Context7 configuré comme MCP HTTPS. |

La revue GitHub du plugin `code-review` peut nécessiter GitHub CLI (`gh`) et sa
connexion, selon le workflow invoqué. Pour une revue locale, les reviewers
ci-dessous et la fonction de revue native Codex ne nécessitent pas ce workflow GitHub.
Les services externes peuvent demander leur propre authentification. Context7
sert à consulter de la documentation ; ne pas lui transmettre de données SAP.

Le profil projet désactive Ralph Loop, Feature Dev, Playground, Firecrawl et
UI/UX Pro Max. Leurs installations personnelles sont préservées ; ils peuvent
être réactivés pour un besoin précis dans `.claude/settings.json` ou
`.codex/config.toml`. Le runtime et les outils système Codex sont conservés.

Les deux skills spécifiques sont versionnés dans `.agents/skills/` :

- **migration-factory** : introspection des schémas, règles SAP/IFS, migrations,
  loaders et préservation des saisies. Aucune recommandation de DROP/RECREATE
  des sources SAP.
- **verify-change** : sélection des contrôles, exécution et restitution des
  preuves ; distinction entre tests locaux et tests connectés.

Claude les expose par `/migration-factory` et `/verify-change` ; Codex permet
de les mentionner par `$migration-factory` et `$verify-change`. Les copies
Claude sont générées depuis la source commune :

```bash
python scripts/ai/sync_skills.py
python scripts/ai/sync_skills.py --check
```

Modifier la source `.agents/skills/`, puis synchroniser. Les autres skills
personnels restent intacts. Si une copie Claude diffère, la synchronisation
la sauvegarde dans `.ai-backups/` avant remplacement.

Pour retirer les seules entrées personnelles exactement dupliquées entre les
packs génériques et dédiés (chaos, SLO, feature flags, Kubernetes) :

```bash
python scripts/ai/curate_skills.py
python scripts/ai/curate_skills.py --apply
```

Les entrées `SKILL.md` identiques sont sauvegardées avant retrait ; les variantes
différentes et les ressources des skills restent intactes. Restaurer l'entrée
sauvegardée réactive sa découverte. Cette opération est indépendante des
installateurs pour préserver les choix personnels sur une nouvelle machine.

Les reviewers **reviewer-sap-ifs** et **reviewer-fullstack** sont définis pour
Claude dans `.claude/agents/*.md` et pour Codex dans `.codex/agents/*.toml`.
Fournir le diff et les extraits utiles. Le premier examine SQL et ETL ; le
second suit le contrat Flask/JSON/Axios/React. L'assistant principal applique
les corrections. Claude limite leurs outils à Read/Grep/Glob. Côté Codex,
shell, apps et plugins sont désactivés pour ces rôles ; le sandbox reste celui
du parent. Pour une session entièrement contrainte à la lecture :

```bash
codex --sandbox read-only
```

`AGENTS.md` contient les règles communes. `CLAUDE.md` l'importe ; l'ancien
document complet est conservé dans [docs/ai/project-reference.md](docs/ai/project-reference.md).
Ce document historique reste consultable par module, sans être injecté
systématiquement dans chaque session.

## Python, frontend et VS Code

Créer un environnement `.venv` avec Python 3.11 et le sélectionner via
**Python: Select Interpreter**. La configuration accepte le répertoire `.venv`
sous Windows et Linux, sans imposer `/usr/local/bin/python`.

```bash
python3.11 -m venv .venv
source .venv/bin/activate             # Linux / WSL
# Git Bash sur Windows : source .venv/Scripts/activate
python -m pip install -r backend/requirements.txt
cd frontend
npm ci --ignore-scripts --no-audit --no-fund
npm run build
npm run lint
npm test
```

Sous Windows, créer le venv avec `py -3.11 -m venv .venv` si le lanceur `py`
est installé. L'interpréteur utilisé par l'outillage peut être Python 3.11+ ;
celui du backend doit rester cohérent avec le conteneur Python 3.11.

Les extensions sont aussi recommandées dans `.vscode/extensions.json`.
Python utilise Black, TypeScript utilise Prettier et les configurations de
débogage utilisent `debugpy`. L'explorateur pytest est limité aux tests hors
ligne SQL guard/filter pour éviter une connexion implicite à la vraie base.

Le lint React (`rules-of-hooks` et `exhaustive-deps`) et les tests frontend sont
bloquants dans la CI. Les corrections de dépendances conservent une recherche
sur action explicite ou différée selon l'écran, sans relancer les chargements
sur chaque nouveau rendu du parent. Le build signale encore un bundle volumineux.

Le `tsconfig.json` historique inclut `frontend/src` depuis le dossier `frontend/`
au lieu de `src` : sa commande `tsc` ne vérifie actuellement aucun fichier de
l'application. Un contrôle diagnostique avec le bon périmètre a révélé une dette
de types préexistante. Le build Vite, le lint et les tests React sont contrôlés ;
ils ne constituent pas une validation TypeScript complète de l'application.
La correction globale de cette dette est distincte des erreurs de hooks.

## Tests frontend

`npm test` exécute les tests React avec Vitest et jsdom, sans mode interactif.
Les tests utilisent les vrais composants, hooks et services du frontend, avec
la frontière réseau simulée. Ils vérifient les retours utilisateur et les
requêtes attendues pour la connexion, l'import, l'export et la maintenance.
Ils ne constituent pas des tests navigateur/backend de bout en bout et ne
contactent ni SAP, ni PostgreSQL, ni Ollama.

## Contrôles locaux, hook et CI

```bash
python scripts/ai/verify_change.py --plan
python scripts/ai/verify_change.py
python scripts/ai/verify_change.py --all
python scripts/ai/verify_change.py --staged
python scripts/ai/verify_change.py backend/services/sql_guard.py
python -m unittest discover -s tests -p 'test_*.py'
```

Le vérificateur sélectionne syntaxe Python/JSON/Bash, tests de l'outillage,
synchronisation des skills, tests SQL guard/filter, lint, tests React et build frontend selon
les fichiers concernés. Aucun paquet n'est installé par ce contrôle.
Les fichiers SQL déclenchent un rappel de revue, sans exécution ni promesse de
validation sémantique PostgreSQL. Les tests backend connectés à la vraie base
doivent être examinés et lancés séparément dans un environnement approprié.

Installer le hook dans chaque clone :

```bash
python scripts/ai/install_hooks.py
```

Un hook personnel ou `core.hooksPath` existant est préservé : le script refuse
de le remplacer. Intégrer alors `python scripts/ai/verify_change.py --staged`
au hook existant. Le hook refuse les fichiers partiellement indexés. Il
sélectionne les chemins de l'index mais exécute tests/build sur l'arbre de
travail : des dépendances non indexées peuvent encore influencer le résultat.
Le hook n'est donc pas un environnement isolé ; la CI vérifie le commit.

[La CI](.github/workflows/dev-checks.yml) vérifie les scripts, les skills,
les tests hors ligne SQL guard/filter, le lint, les tests React et le build frontend. Aucun secret ni
service PostgreSQL/Ollama distant n'est requis. Les tests d'installation
utilisent des CLI simulées et un HOME temporaire.

## PostgreSQL pour les outils de développement

L'ancien `@modelcontextprotocol/server-postgres` est archivé. Le projet le
désactive côté Codex. Pour retirer également sa configuration personnelle et
les permissions Claude qui mémorisent `PGPASSWORD` :

```bash
python scripts/ai/setup_postgres.py --retire-legacy
python scripts/ai/setup_postgres.py --retire-legacy --apply
```

La première commande simule ; la deuxième sauvegarde puis retire uniquement
le serveur archivé reconnu et les permissions concernées. Les autres serveurs
et réglages sont conservés. Fermer puis relancer les assistants pour que les
serveurs déjà chargés dans une session cessent d'être accessibles.

Le remplacement optionnel utilise `postgres-mcp==0.3.0` en mode **restricted**,
avec le rôle dédié `factory_dev_reader`. Un administrateur prépare ce rôle
sur la **base de développement** avec
[create_factory_dev_reader.sql](sql/devtools/create_factory_dev_reader.sql),
puis définit son mot de passe avec `\password factory_dev_reader` dans psql.
Les droits accordés portent sur `raw_data` et `clean_data` ; aucun SELECT
global sur `public`, qui peut contenir des secrets. Examiner les droits
hérités de PUBLIC et accorder les tables supplémentaires au cas par cas.

Installer `uv` séparément. Le lanceur utilise `uvx` et un Python 3.12 isolé,
sans changer le Python du backend. Fournir ensuite la variable
**MIGRATION_FACTORY_DEV_DATABASE_URL** au processus Claude/Codex, par un
gestionnaire de secrets ou l'environnement utilisateur, puis :

```bash
python scripts/ai/setup_postgres.py --enable
python scripts/ai/setup_postgres.py --enable --apply
```

L'URI doit désigner `factory_dev_reader` et une base explicite, sans paramètres
de requête ni fragment (qui pourraient remplacer l'utilisateur libpq). Le lanceur
refuse les autres noms de compte, transmet le secret dans l'environnement
du MCP et ne l'inscrit pas dans les arguments ou configurations générées.
Ce contrôle de nom ne remplace pas la vérification des privilèges du rôle.
Ne pas réutiliser le compte `postgres` de l'application.

Le provisionnement SQL, la définition du secret et la validation des droits
réels ne sont jamais exécutés automatiquement par les installateurs. Le compte
utilisé par l'assistant IA **dans l'application** n'est pas modifié.

## État appliqué sur le poste audité

Première installation du 4 novembre 2026 : les deux installateurs ont été exécutés avec les CLI
existantes ; les plugins essentiels et les extensions VS Code recommandées
sont installés. Le hook précommit est installé dans ce clone. L'ancien MCP
PostgreSQL et les permissions mémorisant son mot de passe ont été retirés
avec sauvegarde ; huit entrées personnelles de skills exactement dupliquées
ont été sauvegardées puis retirées de la découverte. La référence globale
Graphify côté Codex a été corrigée vers `.agents/skills/graphify/SKILL.md`.

Graphify est installé pour Claude et Codex et le graphe courant est conservé
dans `graphify-out/graph.json`. Les assistants reçoivent dans `AGENTS.md` la
consigne de l'interroger en priorité pour les questions d'architecture, de flux,
de dépendances et de localisation, avec un budget court pour limiter les tokens :

```bash
graphify query "Où est géré le chargement IH02 ?" --budget 1500
graphify path "IH02" "maintenance_object"
graphify explain "maintenance_object"
```

Une requête ne reconstruit pas le graphe. La mise à jour reste explicite avec
`/graphify --update`. Le graphe accélère la navigation ; le code et les migrations
actuels restent la source de vérité avant toute modification.

Relancer VS Code et les assistants pour charger les nouvelles configurations.
Le nouveau rôle PostgreSQL reste à provisionner sur une base de développement
et son secret à fournir avant l'activation de `postgres-dev`.

Validation de la première installation : **41 tests d'outillage réussis**, un test de liens ignoré
sous Windows faute de privilèges, **27 tests backend hors ligne réussis**, build
frontend réussi. La publication du complément frontend et ses résultats de CI
sont suivis dans le plan `docs/superpowers/plans/2026-11-04-frontend-quality.md`.

Le complément ajoute **26 tests React dans six suites** (connexion, import,
export ZIP, maintenance, recherche SAP et filtres de mapping). Le lint ne
contient plus les 36 diagnostics initiaux. La publication est isolée sur la
branche `chore/ai-dev-quality-ci`, pour exclure les modifications IFS menées
en parallèle dans le dossier de travail principal. Les résultats distants
sont accessibles dans la pull request et dans GitHub Actions.

## Sauvegardes et restauration

Avant une écriture personnelle, les outils créent une sauvegarde sous
`~/.migration-factory/backups/`, avec permissions restreintes quand le système
le permet. Ces sauvegardes peuvent contenir d'anciens secrets : ne pas les
copier dans Git. `setup_postgres.py` fournit `restore.json`, qui associe
chaque fichier sauvegardé à son chemin d'origine.

Pour restaurer, fermer les assistants, consulter le dossier de sauvegarde
indiqué et recopier seulement les fichiers concernés vers leurs chemins
d'origine. Les sauvegardes des installateurs portent leurs noms d'origine
(`settings.json`, `.claude.json`, `config.toml`). Les copies de skills gérées
ont leurs propres sauvegardes locales dans `.ai-backups/`.

## Références officielles

- [Installation Claude Code](https://code.claude.com/docs/en/setup)
- [Skills Claude](https://code.claude.com/docs/en/skills)
- [Codex CLI](https://developers.openai.com/codex/cli)
- [Skills Codex](https://developers.openai.com/codex/skills)
- [Agents Codex](https://developers.openai.com/codex/subagents)
- [Postgres MCP Pro](https://github.com/crystaldba/postgres-mcp)
