#!/bin/bash

# Script de compilation des procédures stockées COMPOSANTS (source: raw_data.composant_sj_cs)
# Ce script exécute toutes les procédures dans l'ordre requis.
# IMPORTANT: à lancer APRÈS les procédures SAP du module inventory (qui font le TRUNCATE
# des tables cibles). Les fonctions PHL insèrent en append.

# Charger les variables depuis .profile
if [ -f ~/.profile ]; then
    source ~/.profile
fi

# Configuration de la connexion PostgreSQL.
# Aucun identifiant en dur ici : ils viennent du .env de la racine du depot
# (non versionne, cf. .gitignore) ou de l'environnement, qui a la priorite.
ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/.env"
if [ -f "$ENV_FILE" ]; then
    while IFS='=' read -r cle valeur; do
        case "$cle" in
            DB_HOST|DB_PORT|DB_NAME|DB_USER|DB_PASSWORD)
                # L'environnement l'emporte sur le fichier
                [ -z "${!cle}" ] && export "$cle=$valeur"
                ;;
        esac
    done < <(grep -E '^(DB_HOST|DB_PORT|DB_NAME|DB_USER|DB_PASSWORD)=' "$ENV_FILE")
fi

DB_HOST="${DB_HOST:?DB_HOST requis (definir dans $ENV_FILE ou l'environnement)}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:?DB_NAME requis (definir dans $ENV_FILE ou l'environnement)}"
DB_USER="${DB_USER:?DB_USER requis (definir dans $ENV_FILE ou l'environnement)}"
DB_PASSWORD="${DB_PASSWORD:?DB_PASSWORD requis (definir dans $ENV_FILE ou l'environnement)}"

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
echo "  Compilation des procédures COMPOSANTS"
echo "=========================================="
echo ""
log_info "Connexion: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo ""

errors=0

# Liste des fichiers dans l'ordre d'exécution.
# part_catalog en premier (table de base référencée par EXISTS), puis les tables
# filles, puis l'orchestrateur (qui les appelle dans le bon ordre à l'exécution).
# Le vidage des tables n'appartient plus à ce module : il est fait en tête de chaîne
# par la passe Saint-Jean du module Articles PHL (vider_tables_articles_phl).
files=(
    "alimenter_part_catalog_cmp.sql"
    "alimenter_inventory_part_cmp.sql"
    "alimenter_sales_part_cmp.sql"
    "alimenter_purchase_part_cmp.sql"
    "alimenter_manuf_part_attribute_cmp.sql"
    "alimenter_all__cmp.sql"
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
    log_info "✅ Toutes les procédures COMPOSANTS ont été compilées avec succès!"
    echo ""
    log_info "Pour alimenter les tables : SELECT clean_data.alimenter_all_cmp('SJ');"
    log_warning "À lancer APRÈS le module inventory SAP (qui TRUNCATE les tables cibles)."
    exit 0
else
    log_error "❌ $errors erreur(s) détectée(s)"
    exit 1
fi
