#!/bin/bash

# Script de compilation des procédures stockées ARTICLES PHL (source: raw_data.phl_article)
# Ce script exécute toutes les procédures dans l'ordre requis.
# IMPORTANT: à lancer APRÈS les procédures SAP du module inventory (qui font le TRUNCATE
# des tables cibles). Les fonctions PHL insèrent en append.

# Se placer dans le repertoire du script (les chemins des fichiers SQL sont relatifs)
cd "$(dirname "$0")" || exit 1

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

log_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Fonction pour exécuter un fichier SQL
execute_sql() {
    local file=$1
    local filename=$(basename "$file")

    log_info "Compilation de $filename..."

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
echo "  Compilation des procédures ARTICLES PHL"
echo "=========================================="
echo ""
log_info "Connexion: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo ""

errors=0

# Liste des fichiers dans l'ordre d'exécution.
# La vue de dédoublonnage en premier (toutes les fonctions lisent dessus),
# puis part_catalog (table de base référencée par EXISTS), puis les tables filles,
# puis l'orchestrateur (qui les appelle dans le bon ordre à l'exécution).
files=(
    "nettoyer_phl_article.sql"
    "sources/v_phl_article_retenu.sql"
    "alimenter_part_catalog_phl.sql"
    "alimenter_inventory_part_phl.sql"
    "alimenter_sales_part_phl.sql"
    "alimenter_purchase_part_phl.sql"
    "alimenter_manuf_part_attribute_phl.sql"
    "sources/vider_tables_articles_phl.sql"
    "alimenter_all_phl.sql"
)

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

echo "=========================================="
if [ $errors -eq 0 ]; then
    log_info "✅ Toutes les procédures PHL ont été compilées avec succès!"
    echo ""
    log_info "Pour alimenter les tables : SELECT clean_data.alimenter_all_phl();"
    log_warning "À lancer APRÈS le module inventory SAP (qui TRUNCATE les tables cibles)."
    exit 0
else
    log_error "❌ $errors erreur(s) détectée(s)"
    exit 1
fi
