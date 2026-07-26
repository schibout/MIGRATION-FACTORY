#!/bin/bash

# Script d'export des procédures stockées PM ACTIONS depuis la base PostgreSQL
# Ce script extrait toutes les procédures/fonctions du schéma clean_data et les sauvegarde dans des fichiers SQL

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
echo "  Export des procédures PM ACTIONS"
echo "=========================================="
echo ""
log_info "Connexion: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo ""

# Compteurs
count=0
errors=0

# Liste des procédures/fonctions à exporter
procedures=(
    "pe_num"
    "populate_pm_action"
    "populate_pm_action_work_step"
    "populate_pm_action_resource"
    "populate_pm_action_role"
    "populate_all_pm_actions"
)

# Fichiers de sortie correspondants avec numérotation
output_files=(
    "00_pm_helpers.sql"
    "01_populate_pm_action.sql"
    "02_populate_pm_action_work_step.sql"
    "03_populate_pm_action_resource.sql"
    "04_populate_pm_action_role.sql"
    "05_populate_all_pm_actions.sql"
)

# Fonction pour exporter une procédure/fonction
export_procedure() {
    local proc_name=$1
    local output_file=$2

    log_info "Export de $proc_name..."

    # Requête pour récupérer la définition de la procédure/fonction
    # On récupère toutes les signatures pour une procédure donnée
    local query="
    SELECT pg_get_functiondef(p.oid) || E';\n'
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'clean_data'
    AND p.proname = '$proc_name'
    ORDER BY p.oid;
    "

    # Exécuter la requête et récupérer le résultat
    local result
    result=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c "$query" 2>&1)
    local exit_code=$?
    local psql_error=$(echo "$result" | grep -i "error" || true)

    if [ $exit_code -eq 0 ] && [ -n "$result" ] && [ "$result" != "" ] && [ -z "$psql_error" ]; then
        # Nettoyer le résultat (supprimer les lignes vides en fin)
        result=$(echo "$result" | sed '/^$/d')
        # Écrire le résultat dans le fichier
        echo -e "$result" > "$output_file"
        log_info "✅ $output_file créé avec succès"
        return 0
    else
        log_warning "⚠ $proc_name non trouvée dans le schéma clean_data"
        if [ -n "$psql_error" ]; then
            log_debug "Erreur: $psql_error"
        fi
        return 1
    fi
}

# Export de chaque procédure
for i in "${!procedures[@]}"; do
    proc_name="${procedures[$i]}"
    output_file="${output_files[$i]}"

    if export_procedure "$proc_name" "$output_file"; then
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
else
    log_info "✅ $count procédure(s) exportée(s)"
    log_warning "⚠ $errors procédure(s) non trouvée(s)"
fi
echo "=========================================="
