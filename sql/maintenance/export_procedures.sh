#!/bin/bash

# Script d'export des procédures/fonctions stockées du module MAINTENANCE (ecran IH02)
# depuis la base PostgreSQL, vers des fichiers SQL.
#
# ⚠️ Les fichiers .sql versionnés de ce répertoire contiennent des en-têtes de
#    documentation et des instructions DROP qui n'existent PAS dans la base
#    (pg_get_functiondef ne renvoie que le CREATE). Pour ne rien écraser, les
#    exports sont écrits par défaut dans le sous-répertoire ./export.
#
# Usage :
#   ./export_procedures.sh            # -> ./export/*.sql (par défaut)
#   ./export_procedures.sh .          # -> écrase les fichiers du répertoire courant
#   ./export_procedures.sh /chemin    # -> répertoire de sortie au choix

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

# Répertoire de sortie
OUTPUT_DIR="${1:-export}"

# Couleurs pour les messages
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Définir le mot de passe pour psql
export PGPASSWORD="$DB_PASSWORD"

# Début du script
echo "=========================================="
echo "  Export des procédures MAINTENANCE (IH02)"
echo "=========================================="
echo ""
log_info "Connexion: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
log_info "Sortie   : $OUTPUT_DIR"
echo ""

mkdir -p "$OUTPUT_DIR" || { log_error "Impossible de créer $OUTPUT_DIR"; exit 1; }

# Compteurs
count=0
errors=0

# Liste des procédures/fonctions à exporter : "schema:nom:fichier_de_sortie"
# (ordre de compile.sh)
procedures=(
    # --- Table unique ecran IH02 (maintenance_object) ---
    "clean_data:mo_touch:mo_touch.sql"                                              # trigger updated_at (DDL dans create_maintenance_object.sql)
    "clean_data:load_maintenance_object:proc_load_maintenance_object.sql"           # chargement FULL
    "clean_data:load_maintenance_object_merge:proc_load_maintenance_object_merge.sql" # chargement MERGE (preserve le travail UI)
    # --- Procedures existantes (dependent de v_fl_nomenclature) ---
    "clean_data:alimenter_equipment_functional:alimenter_equipment_functional.sql"
    "clean_data:load_equipment_spare_structure:proc_load_equipment_spare_structure.sql"
    "clean_data:load_equipment_object_spare:proc_load_equipment_object_spare.sql"
    # --- Obsolete : supprimait dans les tables SAP, conservee pour historique ---
    "raw_data:sp_keep_only_t_hierarchy:sp_keep_only_T_hierarchy.sql"
)

# Fonction pour exporter une procédure/fonction (toutes ses surcharges)
export_procedure() {
    local schema=$1
    local proc_name=$2
    local output_file=$3

    log_info "Export de $schema.$proc_name..."

    local query="
    SELECT pg_get_functiondef(p.oid) || E';\n'
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = '$schema'
    AND p.proname = '$proc_name'
    ORDER BY p.oid;
    "

    local result
    result=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c "$query" 2>&1)
    local exit_code=$?
    local psql_error=$(echo "$result" | grep -i "error" || true)

    if [ $exit_code -eq 0 ] && [ -n "$result" ] && [ -z "$psql_error" ]; then
        # Supprimer les lignes vides parasites en fin de resultat
        printf '%s\n' "$result" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > "$output_file"
        log_info "✅ $output_file créé avec succès"
        return 0
    else
        log_warning "⚠ $schema.$proc_name non trouvée"
        if [ -n "$psql_error" ]; then
            log_debug "Erreur: $psql_error"
        fi
        return 1
    fi
}

# Export de chaque procédure
for entry in "${procedures[@]}"; do
    schema="${entry%%:*}"
    rest="${entry#*:}"
    proc_name="${rest%%:*}"
    output_file="$OUTPUT_DIR/${rest#*:}"

    if export_procedure "$schema" "$proc_name" "$output_file"; then
        ((count++))
    else
        ((errors++))
    fi

    echo ""
done

# Résumé
echo "=========================================="
if [ $errors -eq 0 ]; then
    log_info "✅ $count procédure(s) exportée(s) avec succès!"
    exit 0
else
    log_warning "$count procédure(s) exportée(s), $errors en échec"
    exit 1
fi
