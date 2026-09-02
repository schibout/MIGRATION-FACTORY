#!/bin/bash

# Script de compilation des procédures stockées PM ACTIONS
# Ce script exécute toutes les procédures dans l'ordre requis

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

# Fonction pour exécuter un fichier SQL
execute_sql() {
    local file=$1
    local filename=$(basename "$file")

    log_info "Compilation de $filename..."

    # Définir le mot de passe pour psql
    export PGPASSWORD="$DB_PASSWORD"

    if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -f "$file" > /dev/null 2>&1; then
        log_info "✅ $filename compilé avec succès"
        return 0
    else
        log_error "❌ Erreur lors de la compilation de $filename"
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -f "$file"
        return 1
    fi
}

# Début du script
echo "=========================================="
echo "  Compilation des procédures PM ACTIONS"
echo "=========================================="
echo ""
log_info "Connexion: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo ""

# Compteur d'erreurs
errors=0

# Liste des fichiers dans l'ordre d'exécution
# L'ordre est important: 00_pm_helpers (fonction pe_num) doit être compilé en premier (dépendance)
files=(
    "00_pm_helpers.sql"
    "01_populate_pm_action.sql"
    "02_populate_pm_action_work_step.sql"
    "03_populate_pm_action_resource.sql"
    "04_populate_pm_action_role.sql"
    "05_populate_all_pm_actions.sql"
)

# Exécution de chaque fichier
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        execute_sql "$file"
        if [ $? -ne 0 ]; then
            ((errors++))
        fi
    else
        log_warning "Fichier non trouvé: $file"
        ((errors++))
    fi
    echo ""
done

# Résumé
echo "=========================================="
if [ $errors -eq 0 ]; then
    log_info "✅ Toutes les procédures ont été compilées avec succès!"
    exit 0
else
    log_error "❌ $errors erreur(s) détectée(s)"
    exit 1
fi
