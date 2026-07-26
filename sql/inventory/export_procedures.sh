#!/bin/bash

# Script d'export des procédures stockées INVENTORY depuis la base PostgreSQL
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
echo "  Export des procédures INVENTORY"
echo "=========================================="
echo ""
log_info "Connexion: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo ""

# Compteurs
count=0
errors=0

# Liste des procédures à exporter (fonctions et procédures stockées)
procedures=(
    "alimenter_ifs_article"
    "alimenter_part_catalog"
)

# Fichiers de sortie correspondants avec numérotation
output_files=(
    "alimenter_ifs_article.sql"
    "alimenter_part_catalog.sql"
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

# Fonction pour exporter la vue v_article
export_view() {
    local view_name=$1
    local output_file=$2
    
    log_info "Export de la vue $view_name..."
    
    local query="
    SELECT 'CREATE OR REPLACE VIEW clean_data.$view_name AS ' || E'\n' || pg_get_viewdef('clean_data.$view_name', true) || ';'
    "
    
    local result=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c "$query" 2>&1)
    
    if [ -n "$result" ] && ! echo "$result" | grep -qi "error"; then
        {
            echo "-- ============================================================================"
            echo "-- Vue $view_name"
            echo "-- Schéma: clean_data"
            echo "-- ============================================================================"
            echo ""
            echo "$result"
        } > "$output_file"
        
        log_info "✅ $output_file créé avec succès"
        return 0
    else
        log_warning "⚠ Vue $view_name non trouvée"
        return 1
    fi
}

# Fonction pour exporter la structure d'une table
export_table() {
    local table_name=$1
    local schema_name=$2
    local output_file=$3
    
    log_info "Export de la table $schema_name.$table_name..."
    
    local query="
    SELECT 'CREATE TABLE IF NOT EXISTS $schema_name.$table_name (' || E'\n' ||
           string_agg('    ' || column_name || ' ' || 
                      CASE 
                          WHEN data_type = 'character varying' THEN 'VARCHAR(' || COALESCE(character_maximum_length::text, '255') || ')'
                          WHEN data_type = 'character' THEN 'CHAR(' || character_maximum_length || ')'
                          WHEN data_type = 'numeric' THEN 'NUMERIC' || COALESCE('(' || numeric_precision || ',' || numeric_scale || ')', '')
                          WHEN data_type = 'integer' THEN 'INTEGER'
                          WHEN data_type = 'bigint' THEN 'BIGINT'
                          WHEN data_type = 'text' THEN 'TEXT'
                          WHEN data_type = 'boolean' THEN 'BOOLEAN'
                          WHEN data_type = 'date' THEN 'DATE'
                          WHEN data_type = 'timestamp without time zone' THEN 'TIMESTAMP'
                          WHEN data_type = 'timestamp with time zone' THEN 'TIMESTAMPTZ'
                          ELSE data_type
                      END ||
                      CASE WHEN is_nullable = 'NO' THEN ' NOT NULL' ELSE '' END, 
                      ',' || E'\n' ORDER BY ordinal_position) || E'\n);'
    FROM information_schema.columns
    WHERE table_schema = '$schema_name'
    AND table_name = '$table_name';
    "
    
    local result=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c "$query" 2>&1)
    
    if [ -n "$result" ] && ! echo "$result" | grep -qi "error" && [ "$result" != "" ]; then
        {
            echo "-- ============================================================================"
            echo "-- Table $table_name"
            echo "-- Schéma: $schema_name"
            echo "-- Table principale pour stocker les articles IFS"
            echo "-- ============================================================================"
            echo ""
            echo "$result"
            echo ""
            echo "COMMENT ON TABLE $schema_name.$table_name IS 'Table des articles maîtres pour migration vers IFS';"
        } > "$output_file"
        
        log_info "✅ $output_file créé avec succès"
        return 0
    else
        log_warning "⚠ Table $table_name non trouvée dans $schema_name"
        return 1
    fi
}

# Export de chaque procédure standard
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

# Export de la vue v_article
if export_view "v_article" "v_article.sql"; then
    ((count++))
else
    ((errors++))
fi
echo ""

# Export de la table ifs_article_maitre
if export_table "ifs_article_maitre" "clean_data" "ifs_article_maitre_structure.sql"; then
    ((count++))
else
    ((errors++))
fi
echo ""

# Résumé
echo "=========================================="
if [ $errors -eq 0 ]; then
    log_info "✅ $count procédure(s)/vue(s) exportée(s) avec succès!"
else
    log_info "✅ $count procédure(s)/vue(s) exportée(s)"
    log_warning "⚠ $errors procédure(s)/vue(s) non trouvée(s)"
fi
echo "=========================================="
