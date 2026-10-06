#!/bin/bash

# Compilation du module ETL Article SAP (raw_data.article_sap + SAP -> clean_data.part_catalog)
# Identifiants lus depuis le .env de la racine du depot (cf. sql/immobilisation/compile.sh).

ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/.env"
if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
fi
export PGPASSWORD="${DB_PASSWORD:-$PG_PASSWORD}"
if [ -z "$PGPASSWORD" ]; then
    echo "[ERROR] DB_PASSWORD non defini : renseignez-le dans $ENV_FILE ou exportez-le"
    exit 1
fi

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

# texte_long_sap : texte de commande SAP (info_text)
for file in ../functions/texte_long_sap.sql alimenter_part_catalog_sap.sql; do
    echo "[INFO] Compilation de $file..."
    psql -h "${DB_HOST:-10.190.100.58}" -p "${DB_PORT:-5432}" -U "${DB_USER:-postgres}" \
         -d "${DB_NAME:-sap_migration_db}" -v ON_ERROR_STOP=1 -q -f "$file" || exit 1
done
echo "[INFO] OK. Enregistrement du module (une fois) : psql ... -f add_etl_article_sap_module.sql"
