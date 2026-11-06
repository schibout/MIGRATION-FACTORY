#!/bin/bash
# Renomme un profil Hermes sur le serveur : dossier, alias et profil actif.
# Hermes arrete la gateway du profil si elle tourne et refuse un nom deja pris.
# Pour "default", seul le nom affiche change : son identifiant reste "default".
#
# Usage : ./renameHermes.sh <ancien_nom> <nouveau_nom>

set -euo pipefail

SSH_HOST="migration"
CONTAINER="hermes"

if [ $# -ne 2 ]; then
    echo "Usage : $0 <ancien_nom> <nouveau_nom>" >&2
    exit 1
fi

# Les noms sont transmis a un shell distant : on n'accepte que les caracteres d'un nom de profil.
for name in "$1" "$2"; do
    if ! [[ "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
        echo "❌ Nom de profil invalide : $name" >&2
        exit 1
    fi
done

ssh "$SSH_HOST" "docker exec $CONTAINER hermes profile rename $1 $2"
ssh "$SSH_HOST" "docker exec $CONTAINER hermes profile list"
