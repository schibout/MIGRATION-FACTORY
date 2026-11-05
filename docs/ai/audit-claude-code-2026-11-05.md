# Audit de l'installation Claude Code - 5 novembre 2026

Poste Windows 11, Claude Code 2.1.318, projet Migration Factory.

## Synthèse

L'installation fonctionne et le socle du projet est sain : instructions courtes,
mémoire dans les limites, cache très efficace (96,5 %). Quatre sujets méritent
d'être traités, dans cet ordre :

1. **Sécurité** : le mot de passe PostgreSQL superutilisateur est en clair dans la
   mémoire et dans le dépôt, et les jetons OAuth de Claude sont lisibles par un
   groupe bac à sable Codex.
2. **Mémoire** : elle est fiable en volume, mais pas toujours en contenu. Une entrée
   de l'index dit le contraire de son fichier et plusieurs constats sont périmés.
3. **Contexte** : 179 skills personnels saturent le budget de listing et une grande
   partie perd sa description. Les connecteurs et les hooks ajoutent leur coût à
   chaque session.
4. **Coût** : cinq sessions sur 196 représentent 49 % des tokens relus en cache.
   Le levier principal est de découper les sessions, pas de réduire la configuration.

Aucun réglage personnel, aucune mémoire et aucun fichier hors dépôt n'a été modifié.
Seul le script d'installation a changé (voir [Script d'installation](#script-dinstallation)).

## Plan d'action

| Priorité | Action | Effort | Gain |
| --- | --- | --- | --- |
| 1 | Retirer le mot de passe de `workflow_execution_distante.md`, puis planifier la rotation | 5 min, puis un chantier | Secret superutilisateur |
| 1 | Retirer `CodexSandboxUsers` de l'ACL de `~/.claude` après vérification | 5 min | Jetons OAuth protégés |
| 1 | Vérifier si `primaryApiKey` de `~/.claude/config.json` sert encore, sinon révoquer et supprimer | 5 min | Clé ancienne en clair |
| Fait | Entrée contradictoire de `MEMORY.md` corrigée, statuts sortis de l'index | - | Décisions fiables |
| Fait | Règles durables déplacées vers `AGENTS.md` et le skill `deploy-serveur` | - | Partagées avec Codex |
| 2 | Purger les règles `allow` et ajouter des règles `deny` | 20 min | Moins d'exécution arbitraire |
| Fait | Skills et plugins inutilisés désactivés (voir [Désactivation](#désactivation-du-5-novembre)) | - | Descriptions de nouveau visibles |
| À faire par Samir | Déconnecter Higgsfield et les connecteurs inutiles dans claude.ai | 2 min | Moins de contexte |
| Fait | `language` défini, Ponytail en `lite` | - | Réponses plus stables |
| Fait | Installation native, npm retiré | - | Méthode recommandée |
| Fait | Worktrees orphelins supprimés, marketplaces inutiles retirées | - | Environ 330 Mo libérés |

Les points de priorité 1 et la purge des permissions sont reportés à la fin, à la demande de
Samir. Voir [Mise en œuvre](#mise-en-œuvre-du-5-novembre) pour le détail.

## 1. Sécurité

### Mot de passe PostgreSQL

Le mot de passe du compte `postgres`, qui est superutilisateur et exécute aussi le
SQL de l'assistant IA, apparaît dans :

| Emplacement | Occurrences |
| --- | --- |
| Mémoire `workflow_execution_distante.md`, relue par les sessions | 1 fichier |
| Transcripts de `~/.claude/projects` | 23 fichiers |
| `~/.claude/file-history` | 9 fichiers |
| Fichiers suivis par Git (dont `backend/config/database.py`, `mcpo/mcp-config.json`, `dump/*.sh`) | 42 fichiers |

**Recommandations**

- Remplacer la valeur dans la mémoire par « mot de passe dans `.env` du serveur ».
- Planifier la rotation, déjà signalée comme restante dans l'audit de juillet. Elle
  impose d'abord de retirer la valeur du code suivi. Sinon, le nouveau mot de passe
  s'y retrouvera.
- Les transcripts disparaissent seuls après 30 jours (`cleanupPeriodDays`). La rotation
  reste le seul vrai remède, car l'historique Git conserve la valeur.

### Fichiers d'identifiants Claude

- `~/.claude` accorde une lecture explicite à `FRSJMWL00170\CodexSandboxUsers`, héritée
  par `.credentials.json`. Votre clé `~/.ssh/id_ed25519` n'a pas ce droit.
  - Vérifier d'abord que Codex n'en a pas besoin, puis exécuter :
    `icacls "%USERPROFILE%\.claude" /remove:g "FRSJMWL00170\CodexSandboxUsers"`.
    Codex peut remettre ce droit à sa prochaine configuration : `--audit` le signalera.
- `~/.claude/config.json` (avril 2026) contient une clé `primaryApiKey`. Je n'ai pas pu
  déterminer si elle est encore utilisée.

### Permissions

94 règles `allow` s'accumulent et aucune règle `deny` n'existe.

| Règle | Problème |
| --- | --- |
| `Bash(python -)`, `Bash(python -c ' *)` | Exécutent du Python arbitraire sans confirmation |
| `Bash(git checkout *)`, `Bash(git rm *)` | Peuvent perdre du travail non commité |
| `Bash(curl -X POST .../import/etats-avancement/...)` | Déclenche un import réel sur le serveur |
| `mcp__postgres__query` | Obsolète : le MCP PostgreSQL a été retiré |
| Commandes ponctuelles (`python _run_ai_migration_013.py`, chemins `plsql`...) | Scories sans usage futur |

Réglages à ajouter (non testés sur ce poste, syntaxe issue de la documentation) :

```jsonc
// ~/.claude/settings.json
{
  "language": "french",
  "permissions": { "deny": ["Read(~/.claude/.credentials.json)"] }
}

// .claude/settings.json du projet
{
  "permissions": {
    "deny": ["Read(./.env)", "Read(./backend/.env)", "Read(./frontend/.env)"]
  }
}
```

Limite à connaître : une règle `deny` sur `Read` couvre les outils de lecture de
fichiers, mais ne doit pas être considérée comme une barrière contre un `cat` en Bash.
Elle réduit les lectures accidentelles et ne remplace pas la rotation. Si vous lisez
souvent ces `.env` pour diagnostiquer, n'ajoutez que la règle sur `.credentials.json`.

## 2. Gestion de la mémoire

### Ce qui fonctionne

| Mesure | Valeur | Limite |
| --- | --- | --- |
| `MEMORY.md` | 37 lignes, 7,5 Ko (environ 2 000 tokens, estimation) | 200 lignes ou 25 Ko |
| Fichiers de mémoire | 35, tous indexés | Chargés à la demande |
| `AGENTS.md` + `CLAUDE.md` | 6,9 Ko | Cible : moins de 200 lignes |
| `docs/ai/project-reference.md` | 75 Ko, non chargé d'office | Bon choix de conception |

### Ce qui pose problème

**L'index contredit le contenu.** L'entrée de `workflow_execution_distante.md` dit « Ne
pas lancer pip/pytest/python en local », alors que le fichier indique que les tests
backend tournent en local depuis le 7 juillet. Comme seul l'index est chargé
d'office, c'est la version périmée qui oriente les sessions.

**Des constats sont périmés.**

| Mémoire | Elle affirme | État vérifié |
| --- | --- | --- |
| `workflow_execution_distante` | `node_modules` absent du frontend | Présent |
| `audit_qualite_application_2026_07` | Pas d'ESLint | `frontend/.eslintrc.cjs` existe |
| `audit_qualite_application_2026_07` | `include` de tsconfig cassé | **Toujours vrai** (`"frontend/src"` dans `frontend/tsconfig.json`) |

**Des statuts restent ouverts.** Six entrées de l'index portent encore un état du type
« à jouer sur le serveur » ou « à déployer », parfois depuis juillet : `catalogue_ifs_spec_factory`,
`module_operations_jt_task`, `maintenance_snapshots_reload`, `liste_ibau_referentiel`,
`matrice_site_famille` et le reste à faire d'`audit_securite_2026_07`. Je n'ai pas
vérifié en base s'ils ont été exécutés.

**Les règles de comportement restent côté Claude.** La mémoire n'est lue ni par Codex
ni par les autres projets. La préférence pour le français n'existe que dans ce dépôt ;
`~/.claude/CLAUDE.md` ne contient que Graphify.

**La mémoire est morcelée.** Elle est rangée par dossier : `pyrfc_app` n'a aucune mémoire,
mais son worktree `musing-blackburn` en a 4.

### Recommandations

1. **Corriger l'entrée contradictoire**, par exemple : « Tests backend mockés en local ;
   SQL, migrations et exports sur le serveur ».
2. **Sortir les statuts de l'index.** L'index décrit le sujet ; l'état daté reste dans
   le fichier. Un statut périmé dans un fichier lu à la demande trompe moins.
3. **Réécrire `workflow_execution_distante`.** Ses « MISE À JOUR » empilées obligent à
   lire l'historique pour trouver la règle en vigueur : garder l'état actuel seul.
4. **Déplacer vers `AGENTS.md`** `developpe_en_autonomie` et `verifier_commit_avant_push`.
   Supprimer `installer_sur_serveur` si `AGENTS.md` couvre tout, en conservant le détail
   `compile.sh`.
5. **Ajouter dans `~/.claude/CLAUDE.md`** ce qui vaut pour tous les projets : langue et
   profil.
6. **Vérifier les statuts à chaque audit**, par une requête sur les migrations plutôt
   que de relire la mémoire.

Le dossier mémoire reste utile pour les pièges non déductibles du code : `ddl_depot_perime`,
`extracteur_pyrfc_config` ou `renumerotation_identites_600000` sont de bons exemples.

## 3. Réponses et instructions

Trois couches pilotent actuellement la forme et la méthode des réponses :

| Couche | Injectée à chaque session | Consigne |
| --- | --- | --- |
| `AGENTS.md` | 6,4 Ko | Français, changements limités |
| Superpowers | 5,4 Ko | Invoquer un skill dès 1 % de pertinence |
| Ponytail (niveau `full`) | Environ 6 Ko | Trois lignes au plus après le code, solution minimale |

**Effets à surveiller**

- Ponytail et Superpowers tirent en sens opposés : l'un réduit la démarche, l'autre
  impose des étapes (brainstorming, plan). Ponytail réserve les explications longues
  aux demandes explicites, ce qui peut écourter des analyses SAP/IFS où le raisonnement
  compte.
- Superpowers est très utilisé (340 usages enregistrés, dont `brainstorming` 23 fois).
  Le compteur de `skillUsage` ne montre aucune invocation de skill Ponytail, mais son
  hook agit à chaque session sans passer par ce compteur.
- La langue dépend du dépôt et les consignes injectées sont en anglais.

**Recommandations**

- Définir `"language": "french"` au niveau utilisateur.
- Conserver Superpowers et tester Ponytail en `/ponytail lite` pendant une semaine. Si
  les réponses vous conviennent mieux, gardez ce niveau.
- Corriger le titre de `CLAUDE.md` : `Migration Factory ? Claude Code` contient un `?`
  issu d'un problème d'encodage (sans effet fonctionnel).

## 4. Contexte et coût

Mesures sur les transcripts du projet (60 sessions récentes pour le détail, 196 pour
la concentration).

| Indicateur | Valeur |
| --- | --- |
| Contexte au premier appel, médiane | 39 700 tokens (33 000 sur les sessions neuves récentes) |
| Pic de contexte, médiane | 65 700 tokens |
| Sessions au-delà de 150 000 tokens | 12 sur 59 |
| Pic maximal | 524 000 tokens |
| Taux de cache | 96,5 % |
| Sortie par appel, médiane | 848 tokens |
| Compactions / interruptions | 10 / 5 |
| Résultats d'outil supérieurs à 30 000 caractères | 18 sur 1 564 |
| Part des 5 plus grosses sessions dans les relectures de cache | 49 % |

Le premier appel varie jusqu'à 155 000 tokens sur certaines sessions, probablement des
reprises ou de grosses pièces jointes. Je ne l'ai pas vérifié au cas par cas. Le chiffre
exact d'une session se lit avec `/context`, que je n'ai pas pu lancer ici.

**Le comportement pèse plus que la configuration.** Une session de 627 appels relit tout
son contexte à chaque tour. Retirer 5 000 tokens au démarrage gagne moins que de lancer
`/clear` entre deux sujets, et `/compact <consigne>` avant qu'une session ne dépasse
150 000 tokens.

### Skills

- `~/.claude/skills` contient **179 `SKILL.md`**, dont 5 noms en double. `skillUsage` ne
  recense que 21 skills différents jamais utilisés, tous dossiers confondus.
- Le budget est dépassé : dans cette session, de nombreux skills (`engineering-skills:*`,
  `marketing:*`, `product-skills:*`) sont listés **sans description**. Claude ne peut
  donc pas les choisir par pertinence, seulement si vous les nommez.
- La désactivation dans `.claude/settings.json` du projet n'a pas d'effet sur
  `ui-ux-pro-max`, car ce skill reste aussi présent dans `~/.claude/skills`.

**Recommandation** : retirer d'abord les collections `engineering-team`, `engineering`,
`product-team` et `productivity`, puis réinstaller les seuls skills utiles
(`rag-architect`, `senior-frontend`, `senior-devops`, `ui-design-system`). Faites une
sauvegarde avant. Pour un retrait plus doux : `skillOverrides` (`off` ou `name-only`),
qui ne s'applique pas aux skills de plugins. Évitez d'augmenter
`SLASH_COMMAND_TOOL_CHAR_BUDGET`, qui déplace le coût sans résoudre le problème.

La copie synchronisée `anthropic-skills:migration-factory` porte le même nom que le
skill du projet. Je n'ai pas comparé leurs contenus : à vérifier, car la source officielle
est `.agents/skills/`.

### Connecteurs

Higgsfield (génération d'images, de vidéos et de sites, sans lien avec ce projet)
ajoute plus de 100 noms d'outils et de longues instructions de serveur à chaque session.
Gmail et Drive ajoutent aussi leurs noms d'outils.

- **Recommandé** : déconnecter Higgsfield dans les réglages de connecteurs de claude.ai
  si vous ne l'utilisez plus.
- **Par projet** : `"disableClaudeAiConnectors": true` coupe tous les connecteurs claude.ai,
  donc aussi Gmail, Drive et Claude Docs.

### Plugins et hooks

| Constat | Action |
| --- | --- |
| `security-guidance` : hook à chaque prompt et revue LLM du diff à l'arrêt et après commit/push | Décider en connaissance de cause : utile, mais consomme des tokens et envoie les diffs au modèle. Mesurer avec `/usage` |
| `security-guidance` : version 2.0.8 active alors que 2.0.17 est dans le cache | `claude plugin update` |
| `security-guidance` : environnement Python de 299 Mo | Se justifie seulement si le plugin reste |
| `playwright`, `code-review`, `context7` installés deux fois (utilisateur + projet) | Sans gravité ; à simplifier si vous ne les voulez que sur ce projet |
| Marketplaces `ecc` et `last30days-skill` sans aucun plugin installé | `claude plugin marketplace remove` : moins de code tiers à faire confiance |
| Marketplaces : 236 Mo | Réduits par les retraits ci-dessus |

## 5. Installation

| Point | Constat | Recommandation |
| --- | --- | --- |
| Méthode | npm global, alors que le README annonce un CLI natif et que la documentation recommande le natif | Installer le natif, puis `npm uninstall -g @anthropic-ai/claude-code` et vérifier avec `where.exe claude` |
| Canal | Version 2.1.318 (`latest`), `stable` est à 2.1.311 | Sur un poste de travail critique, envisager `"autoUpdatesChannel": "stable"` |
| Mises à jour | Saut de 2.1.177 à 2.1.318 le 4 novembre ; `autoUpdates` à `false` dans `~/.claude.json` | Mise à jour régulière, automatique ou planifiée |
| Node | Une seconde copie dans `AppData/Local/hermes` figure dans le PATH | À surveiller si un outil prend la mauvaise version |
| Graphe Graphify | À jour au 4 novembre | Rien à faire |
| Hook pre-commit | Installé | Désormais posé par le script |

### Espace disque

| Dossier | Taille | Remarque |
| --- | --- | --- |
| `.claude/worktrees/` du dépôt | 389 Mo | `admiring-dubinsky-181c33` et `nifty-dhawan` : pointeur Git cassé, inconnus de `git worktree list` |
| `~/.claude/security` | 300 Mo | Dépend de `security-guidance` |
| `~/.claude/plugins` | 289 Mo | Marketplaces principalement |
| `~/.claude/projects` | 161 Mo | Purge automatique à 30 jours, fonctionne (transcript le plus ancien : 6 octobre) |

Les deux worktrees ne peuvent plus être inspectés avec Git, et d'éventuels fichiers non
commités y seraient invisibles. Comparez-les à la main avec le dépôt avant suppression.
Je ne les ai pas supprimés.

## Script d'installation

### Modifications

| Fichier | Changement |
| --- | --- |
| `scripts/ai/install_common.sh` | `--update-cli` passe par npm si le CLI a été installé par npm. Auparavant, l'installateur natif ajoutait un second binaire à côté |
| `scripts/ai/install_common.sh` | Installation du hook pre-commit, jusque-là manuelle ; un hook personnel existant est conservé avec un simple avertissement |
| `scripts/ai/install_common.sh` | Nouvelle option `--audit` |
| `scripts/ai/audit_claude.py` | Nouveau contrôle en lecture seule, qui ne révèle jamais de valeur secrète |
| `tests/test_ai_install.py`, `tests/test_audit_claude.py` | 8 nouveaux tests |
| `README.md` | Options documentées |

```bash
bash install_claude.sh --audit
```

Vérification : `python -m unittest tests.test_ai_install tests.test_audit_claude`
donne 25 tests réussis. L'audit réel relève 9 points et retourne le code 1. La mise à
jour npm a été testée avec des CLI simulés, jamais réellement exécutée sur ce poste.

**Note** : `--update-cli` installe le canal `stable`, soit aujourd'hui **2.1.311** contre
2.1.318 en place : c'est une rétrogradation, conforme au contrat du script.

### Conflit tranché : `.env` de nouveau ignoré

Le commit `e10a68f` autorisait à versionner `.env`, mais `scripts/ai/verify_change.py:136`
refuse ces fichiers : le contrôle standard échouait et le hook aurait bloqué tout commit
en contenant un. Décision du 5 novembre : `.gitignore` exclut de nouveau `.env` et `.env.*`
(sauf `.env.example`), et `AGENTS.md` et la mémoire sont alignés. Aucun `.env` n'a été
commité dans l'historique. Sur le serveur, `.env` se gère donc hors Git.

### Volontairement non fait

- **Réglages `deny` et `language` posés par le script** : ils dépendent des arbitrages
  ci-dessus. Le script n'écrit jamais dans vos réglages personnels.
- **Migration automatique vers le natif** : elle supprimerait votre installation sans
  que vous l'ayez décidé.
- **Rotation des sauvegardes** : 6 dossiers, 362 Ko au total, sans enjeu.

## Désactivation du 5 novembre

Critère : aucun usage réel depuis plus de 3 mois, ou doublon. Tout est réversible.
Sauvegarde des réglages : `~/.migration-factory/backups/20261105T145559-avant-desactivation`.
Ces changements s'appliquent aux prochaines sessions.

| Élément | Action | Raison |
| --- | --- | --- |
| `ralph-loop`, `playground`, `firecrawl`, `code-simplifier`, `claude-code-setup`, `skill-creator` | Plugin désactivé | Aucun usage de skill ou de commande (les compteurs de Ralph ne reflètent que son hook) |
| `claude-api@anthropic-agent-skills` | Plugin désactivé | Doublon du skill intégré `claude-api`, qui reste disponible |
| `code-review`, `context7` | Désactivés au niveau utilisateur | Restent actifs dans ce dépôt ; absents des autres projets |
| `marketing`, `cowork-plugin-management`, `engineering`, `qodo` (synchronisés) | Plugin désactivé | Aucun usage |
| 13 dossiers de `~/.claude/skills`, soit 156 `SKILL.md` | Déplacés vers `~/.migration-factory/skills-desactives` | Dernier usage en juillet, ou aucun |

**Conservés** : Superpowers, Ponytail, Playwright, security-guidance, frontend-design,
feature-dev, claude-md-management, `graphify`, les skills du projet et les skills
synchronisés du compte (`anthropic-skills:*`).

**Restauration**

```bash
claude plugin enable <plugin>@<marketplace> -s user
mv ~/.migration-factory/skills-desactives/<dossier> ~/.claude/skills/
```

Les skills `rag-architect`, `senior-frontend`, `senior-devops` et `ui-design-system`,
déjà utilisés par le passé, font partie des collections déplacées.

## Outils ajoutés pour la performance

Choix fondés sur 202 sessions : 1 542 commandes shell dont 658 `ssh` et 290 `psql`,
500 appels au MCP PostgreSQL retiré le 4 novembre, 264 commandes de déploiement. Fichiers
les plus touchés : SQL, Python, TSX.

| Ajout | Apport |
| --- | --- |
| `pyright-lsp`, `typescript-lsp` (+ `pyright`, `typescript-language-server`, `typescript` en npm global) | Navigation sémantique et diagnostics, plutôt que `grep` |
| Skill `/deploy-serveur` | La procédure et ses pièges, chargés seulement au déploiement |
| `scripts/ai/sql_serveur.sh` | Lecture de la base sans recopier le préambule SSH, en lecture seule et avec délai de 60 s |

**Écartés** : `serena` (recouvre les LSP), `github` (`gh` absent, 4 usages), `remember`
(fait double emploi avec la mémoire), `data-engineering` et `data` (Airflow, absent du
projet), `chrome-devtools-mcp` (Playwright suffit), `commit-commands` (règles de commit
déjà propres au projet).

**TypeScript** : `frontend/tsconfig.json` visait un mauvais dossier, donc `tsc` ne vérifiait
rien et le serveur de langage ne résolvait pas les imports. `include` et `paths` sont
corrigés et les 122 erreurs de types ainsi révélées sont résorbées (56 fichiers, +59/-404, sans
`any` ni `@ts-*`). `tsc` contrôle de nouveau réellement `npm run build`, et `npm run type-check`
le lance seul. Vrais bugs corrigés : import `useCallback` manquant dans `ConfigurationIA.tsx`
(page en erreur au rendu) et `onFileSelect` absent dans `ImportArticles` et `ImportClients`
(TypeError à chaque sélection de fichier). Comportements préservés à arbitrer : aperçu des 7 pages
`Export*` jamais affiché (code mort retiré), suivi d'import absent dans `ImportArticles` et
`ImportClients`, `ImportClients` non routée, boutons Import de `FieldMappingManagement` sans effet,
case « tâches en cours » d'`Extraction` sans effet, recherche de `DataBrowser` sans champ de saisie.

**Prérequis local du plugin TypeScript** : `node_modules/typescript` à la racine est une jonction
vers `frontend/node_modules/typescript`, ignorée par Git et à recréer sur un autre clone.

**Résultat des essais** : `documentSymbol` et `goToDefinition` fonctionnent, y compris d'un
fichier à l'autre. Le serveur TypeScript a besoin de quelques secondes après son démarrage.
`findReferences` n'a renvoyé que les références du fichier ouvert lors des essais.
`sql_serveur.sh` est autorisé par une règle de `.claude/settings.local.json` et validé sur le
serveur : `transaction_read_only = on`, délai d'une minute, accents préservés.

## Mise en œuvre du 5 novembre

Les constats des sections précédentes décrivent l'état initial.

**Mémoire** (sauvegarde : `~/.migration-factory/backups/20261105T154646-memoire`)

- `workflow_execution_distante` réécrit avec l'état actuel seul. Sa commande `psql` passe par
  `.env`, comme les sessions récentes, ce qui retire aussi le mot de passe de ce fichier.
- Index corrigé : migration 027 appliquée, valeurs par défaut branchées sur tous les modules.
- Statuts « à jouer » retirés de l'index pour le catalogue IFS, les opérations, IBAU et la
  matrice site/famille. **Ils ne sont pas vérifiés en base** : la lecture de production a été
  refusée. L'état reste dans leurs fichiers quand il y figure.
- `developpe_en_autonomie`, `installer_sur_serveur` et `verifier_commit_avant_push` supprimés
  après report dans `AGENTS.md` et `deploy-serveur`.
- Mémoire de `pyrfc_app` copiée depuis son ancien worktree vers le dossier du projet.

**Réponses** : `"language": "french"`, profil dans `~/.claude/CLAUDE.md`, `defaultMode: lite` dans
`%APPDATA%\ponytail\config.json`, titre de `CLAUDE.md` corrigé. Le retour à `full` se fait dans ce fichier.

**Installation** : CLI natif 2.1.318 dans `~/.local/bin`, ajouté au PATH utilisateur (copie de
l'ancien PATH dans `~/.migration-factory/backups/`). Il ne reste plus de CLI npm. Le canal
reste `latest`.

**Plugins** : marketplaces `ecc` et `last30days-skill` retirées (236 à 104 Mo), `security-guidance`
passé en 2.0.17.

**Worktrees** : `admiring-dubinsky-181c33` et `nifty-dhawan` supprimés. Hors `node_modules`, tous
leurs fichiers étaient dans Git sauf 21 par worktree, archivés dans
`~/.migration-factory/worktrees-orphelins` (187 Mo, 22 fichiers après dédoublonnage) : configurations
d'outils, `backend/.env`, ancien build et le dump `sap_migration_db_20250709_230043.dump`, seule
copie trouvée sur ce poste. Cette archive se supprime si le dump n'a plus d'utilité.

**Reste à arbitrer** : la copie synchronisée `anthropic-skills:migration-factory` diffère du skill
du projet (autre rédaction des règles). Elle vient du compte claude.ai et se retire de ce côté.

## Limites de cet audit

- Les chiffres de tokens viennent des champs `usage` des transcripts ; les tailles en
  tokens des fichiers sont des estimations.
- Le comptage des lectures et écritures de mémoire est heuristique, je ne l'ai donc pas
  retenu comme indicateur.
- La recherche de secrets repose sur des motifs et peut manquer certains formats.
- Le serveur et la base n'ont pas été contactés : les statuts « à jouer » restent à
  confirmer.

Sources : documentation Claude Code (`code.claude.com/docs/en/`) : `memory`, `settings`,
`settings-reference`, `skills`, `mcp`, `costs`, `setup`, `plugins/cli-reference`.
