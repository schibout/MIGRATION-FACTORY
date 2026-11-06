#!/bin/bash
# Exporte un profil Hermes du serveur vers une archive locale :
# config.yaml, SOUL.md, skills, memories, cron, plugins, scripts...
# Non exportes : secrets (.env, auth.json), conversations, logs et caches.
# Les mots de passe sont masques : les ressaisir apres import (MCP de config.yaml).
#
# Usage : ./exportHermes.sh <profil> [dossier_destination]
# Sans argument : liste les profils disponibles.
# Restauration : ./importHermes.sh <archive> [nom]

set -euo pipefail

SSH_HOST="migration"
CONTAINER="hermes"

if [ $# -eq 0 ]; then
    ssh "$SSH_HOST" "docker exec $CONTAINER hermes profile list"
    echo "Usage : $0 <profil> [dossier_destination]"
    exit 0
fi

PROFILE="$1"
BACKUP_DIR="${2:-$(pwd)}"
# Le nom est transmis a un shell distant : on n'accepte que les caracteres d'un nom de profil.
if ! [[ "$PROFILE" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
    echo "❌ Nom de profil invalide : $PROFILE" >&2
    exit 1
fi

NAME="hermes_${PROFILE}_$(date +%Y%m%d_%H%M%S).tar.gz"
REMOTE_FILE="/tmp/$NAME"
BACKUP_FILE="$BACKUP_DIR/$NAME"

trap 'ssh "$SSH_HOST" "docker exec $CONTAINER rm -f $REMOTE_FILE" || true' EXIT

# hermes profile export retire .env et auth.json, mais garde pour un profil nomme
# les conversations (qui contiennent des mots de passe en clair), logs et caches.
ssh "$SSH_HOST" "docker exec -i $CONTAINER sh -s -- $PROFILE $REMOTE_FILE" <<'EOF'
set -eu
hermes profile export "$1" -o "$2"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
tar xzf "$2" -C "$WORK"
cd "$WORK"/*
# Liste d'inclusion de Hermes (_DEFAULT_EXPORT_INCLUDE_ROOT), sans sessions.
for entry in $(ls -A); do
    case "$entry" in
        config.yaml|profile.yaml|SOUL.md|MEMORY.md|USER.md|todo.json|system_prompt.md|\
        AGENTS.md|CLAUDE.md|.cursorrules|desktop.json|skills|cron|scripts|plugins|\
        memories|knowledge|preferences) ;;
        *) rm -rf "$entry" ;;
    esac
done
rm -rf cron/output cron/executions.db
# ponytail: motifs generiques, un secret de forme inconnue dans les memoires passerait.
# Le masquage des valeurs reelles du .env serait l'etape suivante si besoin.
if [ -d memories ]; then
    find memories -type f -exec sed -i -E \
        -e 's#(://[^:/@ ]+:)[^@ ]+@#\1***@#g' \
        -e 's/((pass(word|wd)?|mot de passe)[ :=]+)[^ ,;]+/\1***/Ig' {} +
fi
cd ..
# /tmp est protege : root ne peut pas reecrire le fichier cree par l'utilisateur hermes.
rm -f "$2"
tar czf "$2" *
EOF
ssh "$SSH_HOST" "docker exec $CONTAINER cat $REMOTE_FILE" > "$BACKUP_FILE"

# Via stdin : sous Git Bash, tar prendrait "C:/..." pour un hote distant.
if ! tar tz < "$BACKUP_FILE" > /dev/null; then
    rm -f "$BACKUP_FILE"
    echo "❌ Archive invalide, export abandonne" >&2
    exit 1
fi

echo "✅ Profil $PROFILE exporte : $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"
