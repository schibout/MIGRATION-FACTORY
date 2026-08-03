#!/bin/bash

# Passage des appels de transcodification des fonctions PHL en source_system=LEGACY.
#
# Les articles PHL ne viennent pas de SAP : get_transcodification() doit etre
# appelee avec ('LEGACY', 'IFS') et non avec les valeurs par defaut ('SAP', 'IFS').
#
# Pour chaque fonction :
#   1. recharge la definition depuis la base (pg_get_functiondef) -> ecrase le .sql local
#   2. ajoute les parametres 'LEGACY', 'IFS' a chaque appel get_transcodification
#   3. recompile la fonction dans la base
#
# Usage :
#   ./fix_transco_legacy.sh            # dry-run : recharge + patch les fichiers, ne compile pas
#   ./fix_transco_legacy.sh --apply    # + recompile les fonctions dans la base

set -u

# Charger les variables depuis .profile
if [ -f ~/.profile ]; then
    source ~/.profile
fi

# Configuration de la connexion PostgreSQL
DB_HOST="10.190.100.58"
DB_PORT="5432"
DB_NAME="sap_migration_db"
DB_USER="postgres"
DB_PASSWORD="trimet2025"

export PGPASSWORD="$DB_PASSWORD"

APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Fonctions PHL qui appellent get_transcodification
# (fichier cible : meme nom + .sql, dans le repertoire courant sauf indication)
functions=(
    "alimenter_part_catalog_phl:alimenter_part_catalog_phl.sql"
    "alimenter_inventory_part_phl:alimenter_inventory_part_phl.sql"
    "alimenter_sales_part_phl:alimenter_sales_part_phl.sql"
    "alimenter_purchase_part_phl:alimenter_purchase_part_phl.sql"
    "alimenter_ifs_article_phl:../inventory/alimenter_ifs_article_phl.sql"
)

echo "=========================================="
echo "  Transcodification PHL : SAP -> LEGACY"
echo "=========================================="
echo ""
log_info "Connexion: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
if [ $APPLY -eq 0 ]; then
    log_warning "Mode dry-run : les fichiers sont mis a jour, la base n'est PAS modifiee"
    log_warning "Relancer avec --apply pour recompiler les fonctions"
fi
echo ""

errors=0
patched_total=0

for entry in "${functions[@]}"; do
    fn="${entry%%:*}"
    file="${entry##*:}"

    log_info "--- $fn ---"

    # 1. Recharger la definition depuis la base
    def=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c \
        "SELECT pg_get_functiondef(p.oid) || ';'
         FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'clean_data' AND p.proname = '$fn';" 2>&1)

    if [ -z "$def" ] || echo "$def" | grep -qi "^ERROR"; then
        log_error "$fn : definition introuvable en base"
        ((errors++))
        echo ""
        continue
    fi

    printf '%s\n' "$def" > "$file"

    # 2. Ajouter 'LEGACY', 'IFS' aux appels get_transcodification qui n'ont que 2 arguments
    #    Deux formes presentes : avec et sans UPPER(). Idempotent : les appels deja
    #    parametres (se terminant par 'IFS')) ne sont pas retouches.
    perl -0pi -e "
        s/(get_transcodification\('UOM', NULLIF\(TRIM\(phl\.\"U\/M\"\), ''\))\)/\$1, 'LEGACY', 'IFS')/g;
        s/(get_transcodification\('UOM', NULLIF\(UPPER\(TRIM\(phl\.\"U\/M\"\)\), ''\))\)/\$1, 'LEGACY', 'IFS')/g;
    " "$file"

    patched=$(grep -c "'LEGACY', 'IFS'" "$file")
    remaining=$(grep -c "get_transcodification" "$file")
    patched_total=$((patched_total + patched))

    if [ "$patched" -ne "$remaining" ]; then
        log_warning "$fn : $patched appel(s) patche(s) sur $remaining -- verifier le fichier a la main"
    else
        log_info "$fn : $patched appel(s) passe(s) en LEGACY/IFS"
    fi

    # 3. Recompiler dans la base
    if [ $APPLY -eq 1 ]; then
        if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -f "$file" > /dev/null 2>&1; then
            log_info "$fn : recompilee en base"
        else
            log_error "$fn : echec de la recompilation"
            psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -f "$file"
            ((errors++))
        fi
    fi

    echo ""
done

echo "=========================================="
log_info "$patched_total appel(s) get_transcodification en LEGACY/IFS"
if [ $errors -ne 0 ]; then
    log_error "$errors erreur(s)"
    exit 1
fi

if [ $APPLY -eq 1 ]; then
    log_warning "Pensez a rejouer le chargement pour propager les nouvelles unites :"
    echo "    SELECT clean_data.alimenter_all_phl();"
fi
echo "=========================================="
