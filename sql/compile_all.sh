#!/bin/bash
#
# Compilation de TOUTES les fonctions et procedures stockees des modules ETL.
#
# A lancer notamment apres une modification de public.get_default_value :
# la migration 044 supprime l'ancienne signature a 4 arguments, donc toute
# procedure encore compilee avec l'ancien appel echoue au chargement avec
#   function public.get_default_value(..., unknown, unknown) does not exist
#
# Ordre : prerequis (table etl_default_values + accesseur + seeds), puis les
# compile.sh de chaque module.
#
# Usage :
#   ./compile_all.sh                  # tous les modules non destructifs
#   ./compile_all.sh supplier         # un ou plusieurs modules precis
#   ./compile_all.sh --avec-maintenance   # inclut sql/maintenance (voir plus bas)
#
# ATTENTION : sql/maintenance/compile.sh contient un DROP TABLE ... CASCADE.
# Il n'est JAMAIS lance par defaut -- il detruirait des donnees sur une base en
# service. Il faut le demander explicitement avec --avec-maintenance.

set -uo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPOT="$(dirname "$RACINE")"

# --- Configuration de la connexion PostgreSQL (alignee sur les compile.sh) ---
DB_HOST="${PG_HOST:-10.190.100.58}"
DB_PORT="${PG_PORT:-5432}"
DB_NAME="${PG_DATABASE:-sap_migration_db}"
DB_USER="${PG_USER:-postgres}"
DB_PASSWORD="${PG_PASSWORD:-trimet2025}"
export PGPASSWORD="$DB_PASSWORD"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_step()    { echo -e "${BLUE}==>${NC} $1"; }

# Modules compiles par defaut, dans l'ordre des dependances :
# les fonctions communes d'abord, puis les modules metier.
MODULES_DEFAUT=(
    supplier
    customerFile
    inventory
    articlePhl
    operation
    pm_actions
    projet
    maintenanceRousource
    ai
    sharepoint
)

AVEC_MAINTENANCE=0
MODULES=()
for arg in "$@"; do
    case "$arg" in
        --avec-maintenance) AVEC_MAINTENANCE=1 ;;
        -h|--help) sed -n '2,25p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) MODULES+=("$arg") ;;
    esac
done
if [ ${#MODULES[@]} -eq 0 ]; then
    MODULES=("${MODULES_DEFAUT[@]}")
    [ "$AVEC_MAINTENANCE" -eq 1 ] && MODULES+=(maintenance)
fi

erreurs=0
compiles=0

executer_sql() {
    local fichier=$1
    local nom
    nom=$(basename "$fichier")
    if [ ! -f "$fichier" ]; then
        log_warning "Fichier introuvable : $fichier"
        return 1
    fi
    log_info "Compilation de $nom..."
    if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
            -v ON_ERROR_STOP=1 -f "$fichier" > /dev/null 2>&1; then
        return 0
    fi
    log_error "Echec sur $nom -- sortie complete :"
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -f "$fichier"
    return 1
}

echo "=============================================="
echo "  Compilation de toutes les procedures ETL"
echo "=============================================="
log_info "Connexion : $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo ""

# --- 1. Prerequis communs -----------------------------------------------------
# Idempotents (IF NOT EXISTS / ON CONFLICT DO NOTHING / CREATE OR REPLACE), ils
# peuvent etre rejoues sans risque. get_default_value doit exister AVANT les
# fonctions ETL qui l'appellent.
log_step "Prerequis (valeurs par defaut parametrables)"
PREREQUIS=(
    "$DEPOT/migrations/031_create_etl_default_values.sql"
    "$DEPOT/migrations/043_seed_devise_defaut_supplier.sql"
    "$DEPOT/migrations/044_get_default_value_sans_repli.sql"
    "$RACINE/functions/get_default_value.sql"
)
for fichier in "${PREREQUIS[@]}"; do
    if executer_sql "$fichier"; then
        compiles=$((compiles + 1))
    else
        erreurs=$((erreurs + 1))
        log_error "Prerequis en echec : les modules vont probablement tous echouer."
    fi
done
echo ""

# --- 2. Modules ---------------------------------------------------------------
for module in "${MODULES[@]}"; do
    script="$RACINE/$module/compile.sh"
    log_step "Module $module"

    if [ "$module" = "maintenance" ] && [ "$AVEC_MAINTENANCE" -ne 1 ]; then
        log_warning "sql/maintenance ignore (DROP TABLE CASCADE) -- utiliser --avec-maintenance"
        echo ""
        continue
    fi

    if [ ! -f "$script" ]; then
        log_warning "Pas de compile.sh pour le module '$module' -- ignore"
        echo ""
        continue
    fi

    # Les compile.sh utilisent des chemins relatifs a leur propre dossier.
    if (cd "$RACINE/$module" && bash compile.sh); then
        log_info "Module $module compile"
        compiles=$((compiles + 1))
    else
        log_error "Module $module en echec"
        erreurs=$((erreurs + 1))
    fi
    echo ""
done

# --- 3. Resume ----------------------------------------------------------------
echo "=============================================="
if [ "$erreurs" -eq 0 ]; then
    log_info "$compiles etapes compilees, aucune erreur"
    echo ""
    log_info "Controle recommande : python sql/config/verifier_valeurs_defaut.py"
    log_info "(un appel sans ligne seedee ecrit desormais NULL en silence)"
    exit 0
fi
log_error "$erreurs erreur(s) sur $((compiles + erreurs)) etapes"
exit 1
