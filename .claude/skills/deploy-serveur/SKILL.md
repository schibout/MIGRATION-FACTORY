---
name: deploy-serveur
description: Installer ou deployer Migration Factory sur le serveur (commit, push, git pull, compile.sh, migrations, deploybackend, deployfrontend, test sur 8081). A utiliser quand la demande dit « installe sur le serveur », « deploie » ou « developpe en autonomie ».
---

# Deployer sur le serveur

Serveur : `ssh migration`, clone `/root/migration-Factory`, application sur
`http://10.190.100.58:8081`. Cette demande autorise les etapes ci-dessous sans
nouvelle confirmation. Hors de ces mots, s'arreter au code local et proposer.

## 1. Commit et push

D'autres travaux peuvent etre en cours dans le meme depot.

- Indexer des chemins explicites, jamais `git add -A`.
- Apres le commit, controler `git branch --show-current` et `git show --stat HEAD` :
  le hook pre-commit dure et l'index peut changer pendant ce temps (incident `7d73ce3` :
  91 fichiers au lieu de 12, pousses et deployes). En cas d'ecart avec les fichiers
  attendus, ne pas pousser et demander.
- Avant de pousser, `ssh migration 'cd /root/migration-Factory && git fetch && git status -sb'` :
  le clone du serveur a deja ete en avance. Ne pas ecraser une version plus recente.
- Ne pas masquer la sortie de `git push`.

## 2. Installer

```bash
ssh migration 'cd /root/migration-Factory && git pull 2>&1 | tail -7 && git log --oneline -1'
```

N'installer que ce que le commit touche :

| Fichiers modifies | Commande sur le serveur |
| --- | --- |
| `sql/<module>/` | `cd sql/<module> && bash compile.sh` (le bit executable peut manquer) |
| `migrations/NNN_*.sql` | `psql` avec les variables de `.env`, puis le fichier |
| `backend/` | `bash deploybackend.sh` |
| `frontend/` | `bash deployfrontend.sh` |

Pieges :

- `sql/maintenance/compile.sh` contient un `DROP TABLE CASCADE` : ne jamais le lancer
  entierement sur la base en service. `mode=reset` est destructif.
- Rejouer des fichiers dans `BEGIN ... ROLLBACK` n'est pas un essai a blanc si l'un
  d'eux contient son propre `COMMIT`. Le chercher avant tout essai.
- Lire le code de sortie reel : `bash deploybackend.sh 2>&1 | tail -12; echo "rc=${PIPESTATUS[0]}"`.
- Apres un changement de prompt IA ou un redeploiement du backend, compter 8 a 10 minutes
  de chauffe avant de juger l'assistant ; ne pas lancer de generation automatiquement.

## 3. Verifier

- Base : `bash scripts/ai/sql_serveur.sh "SELECT ..."`, en lecture seule, depuis le poste.
- Conteneurs : `docker ps` et `docker-compose logs --tail=40 backend` sur le serveur.
- Si la demande dit « en autonomie », tester l'ecran reel avec Playwright sur le port
  8081 : naviguer, cliquer, verifier l'affichage et les telechargements. Ne pas
  declencher d'import ou de rechargement sans que la demande le prevoie.

Restituer le commit deploye, les commandes jouees avec leur resultat, ce qui a ete teste
et ce qui ne l'a pas ete.
