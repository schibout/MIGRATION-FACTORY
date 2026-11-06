#!/bin/bash
# Importe sur le serveur une archive creee par exportHermes.sh.
# Hermes refuse d'ecraser un profil existant et d'importer sous le nom "default" :
# pour une archive du profil default, indiquer un autre nom.
#
# Usage : ./importHermes.sh <archive.tar.gz> [nom_du_profil]
# Sans nom, le profil reprend le nom contenu dans l'archive.

set -euo pipefail

SSH_HOST="migration"
CONTAINER="hermes"

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage : $0 <archive.tar.gz> [nom_du_profil]" >&2
    exit 1
fi

ARCHIVE="$1"
NEW_NAME="${2:-}"
if [ ! -f "$ARCHIVE" ]; then
    echo "❌ Archive introuvable : $ARCHIVE" >&2
    exit 1
fi
# Via stdin : sous Git Bash, tar prendrait "C:/..." pour un hote distant.
if ! tar tz < "$ARCHIVE" > /dev/null; then
    echo "❌ Archive invalide : $ARCHIVE" >&2
    exit 1
fi
# Le nom est transmis a un shell distant : on n'accepte que les caracteres d'un nom de profil.
if [ -n "$NEW_NAME" ] && ! [[ "$NEW_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
    echo "❌ Nom de profil invalide : $NEW_NAME" >&2
    exit 1
fi

REMOTE_FILE="/tmp/hermes_import_$(date +%Y%m%d_%H%M%S)_$$.tar.gz"
trap 'ssh "$SSH_HOST" "docker exec $CONTAINER rm -f $REMOTE_FILE" || true' EXIT

# Hermes s'execute avec son propre utilisateur : l'archive doit rester lisible.
ssh "$SSH_HOST" "docker exec -i $CONTAINER sh -c 'cat > $REMOTE_FILE && chmod 644 $REMOTE_FILE'" < "$ARCHIVE"
ssh "$SSH_HOST" "docker exec $CONTAINER hermes profile import $REMOTE_FILE${NEW_NAME:+ --name $NEW_NAME}"

echo "✅ Profil importe."
echo "⚠️  A ressaisir : .env et auth.json du profil, mots de passe masques (***) de config.yaml et des memoires."
