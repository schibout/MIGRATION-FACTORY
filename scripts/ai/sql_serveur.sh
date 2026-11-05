#!/usr/bin/env bash
# Lit la base du serveur en lecture seule, sans recopier le preambule ssh/.env/psql.
#   bash scripts/ai/sql_serveur.sh "SELECT count(*) FROM clean_data.part_catalog"
#   bash scripts/ai/sql_serveur.sh < requete.sql
# ponytail: garde-fou contre les ecritures accidentelles, pas une barriere : le compte
# reste superutilisateur. Passer au role factory_dev_reader si un vrai cloisonnement compte.
set -euo pipefail

remote='cd /root/migration-Factory && set -a && . ./.env && set +a
export PGPASSWORD="$DB_PASSWORD" PGCLIENTENCODING=UTF8
export PGOPTIONS="-c default_transaction_read_only=on -c statement_timeout=60000"
exec psql -X -q -v ON_ERROR_STOP=1 -h "${DB_HOST:-10.190.100.58}" -p "${DB_PORT:-5432}" -U "${DB_USER:-postgres}" -d "${DB_NAME:-sap_migration_db}"'

if (( $# )); then
  printf '%s;\n' "$1" | ssh -o BatchMode=yes migration "$remote"
else
  ssh -o BatchMode=yes migration "$remote"
fi
