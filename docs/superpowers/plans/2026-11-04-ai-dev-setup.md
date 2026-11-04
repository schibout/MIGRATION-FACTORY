# Installation Claude et Codex pour Migration Factory

## Objectif et decisions

Fournir `README.md`, `install_claude.sh` et `install_codex.sh`, puis appliquer
les recommandations de l'audit du 4 novembre 2026. Les scripts ciblent Bash
(Linux, macOS, WSL, Git Bash) et preservent les configurations personnelles.
Les connexions interactives aux comptes restent a effectuer par l'utilisateur.
Le compte PostgreSQL de l'application et les donnees du serveur ne sont pas modifies.

## Travaux

- [x] Installateurs relancables, mode simulation, selection reduite de plugins,
      options CLI/VS Code et erreurs explicites ; tests sans installation reseau.
- [x] Instructions communes dans AGENTS.md ; sauvegarde integrale de l'ancien
      CLAUDE.md dans docs/ai ; entree Claude courte vers le socle commun.
- [x] Deux skills versionnes : migration-factory et verify-change ; copies
      Claude generees depuis `.agents/skills` et controle de synchronisation.
- [x] Deux reviewers en lecture seule, definitions propres a Claude et Codex.
- [x] Configuration VS Code Python/Prettier/debugpy et recommandations d'extensions.
- [x] Verification deterministe sans base distante par defaut, hook pre-commit
      et CI ; tests de selection des controles et de propagation des echecs.
- [x] Acces PostgreSQL de developpement : role SQL dedie et MCP restreint,
      secrets lus dans l'environnement ; aucune execution SQL sur le serveur.
- [x] README : prerequis, commandes, options, authentification, sauvegardes,
      commandes de verification, limites et restauration des configurations.
- [x] Executer les tests d'outillage, les controles de syntaxe et les controles
      frontend disponibles ; relire les modifications avant livraison.

## Repartition et contraintes

Les installateurs, les controles et la documentation sont des chantiers
independants, confies a des agents avec perimetres de fichiers distincts.
Le coordinateur assemble les livrables et verifie leur coherence.

- Ne jamais afficher, copier dans Git ou incorporer un secret aux commandes.
- Aucune suppression globale de skills ou de plugins ; dedoublonnage limite
  aux fichiers geres et profil allege explicite avec sauvegarde.
- Aucune modification des regles SAP, du code metier ou du role IA applicatif.
- Aucun test connecte a la vraie base lance implicitement par un hook ou une CI.
- Les echecs reels de lint/build sont rapportes et ne deviennent pas des succes.

## Validation

Tests unitaires et simulations avec HOME temporaire, relance de l'installation,
configuration preexistante, absence de dependances, chemins avec espaces et
propagation d'une erreur de commande. Syntaxe Bash avec Git Bash disponible
sur le poste, JSON/TOML/YAML et egalite des copies de skills. Les connexions
externes et le provisionnement de la base restent hors des tests automatiques.

## Resultats du 4 novembre 2026

- Installation reelle des plugins Claude/Codex et extensions VS Code reussie.
- 42 tests d'outillage executes : 41 reussis, 1 ignore (liens Windows).
- 27 tests backend hors ligne reussis ; build frontend reussi.
- Lint : 36 constats existants, maintenus visibles et exclus de la porte CI.
- Configurations JSON/TOML/YAML, syntaxe Bash et copie des skills validees.
- Reference CLAUDE historique conservee integralement (hors normalisation LF).
- Revue independante : les deux problemes de validation d'URI et de confinement
  ont ete corriges et reverifies.
- Hook installe ; ancien MCP PostgreSQL retire avec sauvegarde, sans acces DB.
- Nouveau role et secret PostgreSQL a provisionner manuellement sur base de dev.
- Modification concurrente backend/api/ifs_fournisseurs.py preservee.
