#!/bin/bash

# Script de compilation des fonctions stockées du module ARTICLES (inventory)
# SAP vers IFS. Ce script compile toutes les fonctions dans l'ordre de dépendance.
#
# Périmètre des articles : raw_data.export_article_qlikview (pilote la liste des
# articles à migrer, cf. clean_data.alimenter_ifs_article).
#
# Les fonctions du module PHL (alimenter_*_phl) sont dans sql/articlePhl/.

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
echo "  Compilation des fonctions ARTICLES"
echo "=========================================="
echo ""
log_info "Connexion: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo ""

# Compteur d'erreurs
errors=0

# Liste des fichiers dans l'ordre d'exécution (= ordre de dépendance du module)
#   1. clean_data.alimenter_ifs_article()            -> clean_data.ifs_article_maitre
#      (périmètre = raw_data.export_article_qlikview)
#   2. clean_data.alimenter_part_catalog()           -> clean_data.part_catalog (table de base)
#   3. clean_data.alimenter_inventory_part()         -> clean_data.inventory_part      (EXISTS part_catalog)
#   4. clean_data.alimenter_inventory_part_planning()-> clean_data.invent_part_plan    (EXISTS inventory_part)
#   5. clean_data.alimenter_purchase_part()          -> clean_data.purchase_part       (EXISTS part_catalog,
#                                                       hors articles de vente : NOT EXISTS articles_vente_sap)
#   6. clean_data.alimenter_purchase_part_supplier() -> clean_data.purchase_part_supplier (EXISTS purchase_part)
#   7. clean_data.alimenter_sales_part()             -> clean_data.sales_part          (EXISTS part_catalog)
files=(
    "alimenter_ifs_article.sql"
    "alimenter_part_catalog.sql"
    "alimenter_inventory_part.sql"
    "alimenter_inventory_part_planning.sql"
    "alimenter_purchase_part.sql"
    "alimenter_purchase_part_supplier.sql"
    "alimenter_sales_part.sql"
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

