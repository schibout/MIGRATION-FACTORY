# Qualite frontend et premiere execution de CI

## Perimetre autorise

Corriger les 36 diagnostics ESLint existants, ajouter des tests React sur les
parcours connexion/import/export/maintenance et publier les changements avec
une execution GitHub Actions. Ne pas provisionner de role PostgreSQL, ne pas
modifier de secret, ne pas contacter la base ou SAP.

## Implementation

- [x] Stabiliser les fonctions et donnees utilisees par les hooks sans masquer
  exhaustive-deps ; verifier notamment recherche differee et pagination.
- [x] Installer un runner React compatible avec Vite 4 ; tests DOM et hooks
  avec API simulee, sans pretendre couvrir un backend integre.
- [x] Couvrir validation et erreurs de connexion, selection de fichier et
  echec import, export ZIP, maintenance et verrouillage 409.
- [x] Ajouter lint et tests frontend aux controles locaux et a la CI.
- [x] Verifier la portee reelle de TypeScript et documenter toute dette
  preexistante hors perimetre au lieu d'annoncer un faux controle.
- [x] Executer lint, tests React, build, tests d'outillage et tests SQL hors DB.
- [x] Mettre a jour le README.
- Publication : branche `chore/ai-dev-quality-ci`, puis pull request ; le resultat
  de la premiere execution CI sera consigne dans le compte rendu et la PR.

## Organisation

Un agent modifie uniquement les sources avec diagnostics de hooks. Un autre
possede les configurations/dependances/tests React. Le coordinateur gere les
controles Python, la CI, la documentation, l'integration et la publication.
La branche distante sera distincte de master ; aucun deploiement ni fusion
automatique n'est prevu. Les changements precedents d'installation font partie
du livrable a versionner, hors secrets et configurations personnelles.

## Validation

Pas de suppression de regle ESLint pour obtenir du vert. Assertions observables
sur les vrais composants et leur contrat API, avec simulations explicites.
La CI utilise npm ci et ne depend d'aucun serveur metier. Examiner le diff
complet avant commit et verifier les resultats distants avant livraison.

## Resultats locaux

- 36 diagnostics initiaux corriges dans 27 fichiers sans desactiver les regles.
- 26 tests React reussis dans 6 suites ; garde reseau fetch/XHR.
- Regression de temporisation SapDataTable reproduite avant correction, puis
  testee avec un changement de callback parent pendant les 250 ms de debounce.
- 43 tests d'outillage executes : 42 reussis, 1 ignore (liens Windows).
- 27 tests SQL guard/filter hors base reussis ; build Vite reussi.
- Le tsconfig historique ne selectionne aucune source applicative. Un diagnostic
  du vrai perimetre montre une dette TypeScript distincte, documentee au README.
- Publication preparee dans un worktree isole, avec manifeste explicite des
  fichiers de la tache. Les changements concurrents backend/consultation IFS
  et guides utilisateur sont exclus. Aucun provisionnement PostgreSQL effectue.
