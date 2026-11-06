#!/bin/bash
# Sauvegarde complete sur le serveur, dans <dossier>/backup_<date>/ :
#   sap_migration_db.dump  base complete (pg_restore)
#   roles.sql              roles PostgreSQL (hachages de mots de passe inclus)
#   hermes.tar.gz          /root/.hermes avec tous les profils, skills, config et
#                          SECRETS (.env, auth.json), /root/hermes (compose) et /root/skills
# Non sauvegardes : conversations Hermes (state.db, sessions), logs et caches.
# Dossier reserve a root : ne pas le diffuser, il contient les secrets.
#
# Sur le serveur : bash /root/migration-Factory/dump/backupAll.sh [dossier]
# Depuis le poste : ssh migration 'bash -s' < dump/backupAll.sh
# Dossier par defaut : /root/db_dump
#
# Restauration :
#   export PATH=/usr/lib/postgresql/15/bin:$PATH
#   psql -h 10.190.100.58 -U postgres -f roles.sql
#   pg_restore -h 10.190.100.58 -U postgres -d sap_migration_db --clean --if-exists sap_migration_db.dump
#   docker stop hermes && tar xzf hermes.tar.gz -C /root && docker start hermes

set -euo pipefail
umask 077

DEST="${1:-/root/db_dump}"
STAMP="$(date +%Y%m%d_%H%M%S)"
TARGET="$DEST/backup_$STAMP"
WORK="$TARGET.partial"

set -a
. /root/migration-Factory/.env
set +a
export PGPASSWORD="$DB_PASSWORD"
DB_HOST="${DB_HOST:-10.190.100.58}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"
DB_NAME="${DB_NAME:-sap_migration_db}"
# Avec -h, le lanceur Debian prend les outils 18 (et ignore PGCLUSTER) : dump illisible en 15.
export PATH="/usr/lib/postgresql/15/bin:$PATH"

# Une sauvegarde interrompue ne doit jamais ressembler a une sauvegarde complete.
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK"

echo "Base $DB_NAME..."
pg_dump -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -F c -b -f "$WORK/$DB_NAME.dump" "$DB_NAME"
pg_dumpall -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" --globals-only -f "$WORK/roles.sql"

echo "Hermes..."
EXCLUDES=()
for item in logs cache home bin sandboxes image_cache audio_cache lazy-packages sessions \
            state.db state.db-shm state.db-wal .npm .venv-immo .venv-pg .local/share .local/state; do
    EXCLUDES+=("--exclude=.hermes/$item" "--exclude=.hermes/profiles/*/$item")
done
# Code 1 de GNU tar : un fichier a change pendant la lecture (Hermes tourne), archive utilisable.
tar czf "$WORK/hermes.tar.gz" --anchored --no-wildcards-match-slash "${EXCLUDES[@]}" \
    -C /root .hermes hermes skills || [ $? -eq 1 ]

echo "Controle..."
pg_restore -l "$WORK/$DB_NAME.dump" > /dev/null
tar tzf "$WORK/hermes.tar.gz" > /dev/null
(cd "$WORK" && sha256sum -- * > SHA256SUMS)

mv "$WORK" "$TARGET"
du -h "$TARGET"/*
echo "✅ Sauvegarde terminee : $TARGET"
