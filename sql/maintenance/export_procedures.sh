#!/bin/bash

# Script d'export des procédures stockées clients PHL depuis la base PostgreSQL
# Ce script extrait toutes les procédures du schéma clean_data et les sauvegarde dans des fichiers SQL

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
echo "  Export des procédures CLIENT PHL"
echo "=========================================="
echo ""
log_info "Connexion: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo ""

# Compteur
count=0

# Liste des procédures à exporter (ordre de compile.sh)
procedures=(
    "alimenter_equipment_functional"
)

# Export de chaque procédure
for proc_name in "${procedures[@]}"; do
    output_file="${proc_name}.sql"
    
    log_info "Export de $proc_name..."
    
    # Requête pour récupérer la définition de la procédure
    query="
    SELECT pg_get_functiondef(p.oid)
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'clean_data'
    AND p.proname = '$proc_name'
    ORDER BY p.oid
    LIMIT 1;
    "
    
    # Exécuter la requête et sauvegarder dans le fichier
    result=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c "$query" 2>&1)
    
    if [ $? -eq 0 ] && [ -n "$result" ]; then
        # Écrire le résultat dans le fichier
        echo "$result" > "$output_file"
        log_info "✅ $output_file créé avec succès"
        ((count++))
    else
        log_error "❌ Erreur lors de l'export de $proc_name"
        log_debug "Détails: $result"
    fi
    
    echo ""
done

# Résumé
echo "=========================================="
log_info "✅ $count procédure(s) exportée(s) avec succès!"
echo "=========================================="
