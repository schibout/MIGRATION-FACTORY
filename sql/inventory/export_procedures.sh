#!/bin/bash

# Script d'export des objets INVENTORY depuis la base PostgreSQL
# Exporte :
#   - les fonctions/procedures stockees du module (schema clean_data)
#   - les vues utilisees par ces fonctions
#   - la structure des tables CIBLES (ecrites : TRUNCATE/INSERT)
#   - la structure des tables SOURCES (lues uniquement) dans sources/

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

# Export des tables sources (lecture seule) : 1 = oui, 0 = non
EXPORT_SOURCES="${EXPORT_SOURCES:-1}"
SOURCES_DIR="sources"

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

# Definir le mot de passe pour psql
export PGPASSWORD="$DB_PASSWORD"

# Debut du script
echo "=========================================="
echo "  Export des objets INVENTORY"
echo "=========================================="
echo ""
log_info "Connexion: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo ""

# Compteurs
count=0
errors=0

# ----------------------------------------------------------------------------
# Fonctions / procedures stockees executees par compile.sh (schema clean_data)
# ----------------------------------------------------------------------------
procedures=(
    "alimenter_ifs_article"
    "alimenter_ifs_article_phl"
    "alimenter_part_catalog"
    "alimenter_inventory_part"
    "alimenter_inventory_part_planning"
    "alimenter_purchase_part"
    "alimenter_purchase_part_supplier"
    "alimenter_sales_part"
    # --- Ajoutees le 2026-08-25 : presentes en base mais jamais exportees ---
    "alimenter_inventory_part_refonte"
    "alimenter_inventory_part_saint_jean"
    "alimenter_part_catalog_refonte"
    "alimenter_part_catalog_saint_jean"
    "alimenter_selection_articles_utilises"
    "sp_load_part_catalog"
)

# Fichiers de sortie correspondants
output_files=(
    "alimenter_ifs_article.sql"
    "alimenter_ifs_article_phl.sql"
    "alimenter_part_catalog.sql"
    "alimenter_inventory_part.sql"
    "alimenter_inventory_part_planning.sql"
    "alimenter_purchase_part.sql"
    "alimenter_purchase_part_supplier.sql"
    "alimenter_sales_part.sql"
)

# ----------------------------------------------------------------------------
# Vues utilisees par les fonctions (format "schema.vue")
# ----------------------------------------------------------------------------
views=(
    "clean_data.v_article"
    "raw_data.v_phl_article_retenu"
)

# ----------------------------------------------------------------------------
# Tables CIBLES : ecrites par les fonctions (TRUNCATE + INSERT)
# ----------------------------------------------------------------------------
target_tables=(
    "clean_data.ifs_article_maitre"
    "clean_data.part_catalog"
    "clean_data.inventory_part"
    "clean_data.invent_part_plan"
    "clean_data.purchase_part"
    "clean_data.purchase_part_supplier"
    "clean_data.sales_part"
)

# ----------------------------------------------------------------------------
# Tables SOURCES : lues par les fonctions (jamais modifiees)
# ----------------------------------------------------------------------------
source_tables=(
    "clean_data.mapping_codification_articles"
    "clean_data.supplier_info_general"
    "raw_data.article_definitif"
    "raw_data.articles_vente_sap"
    "raw_data.eina"
    "raw_data.eine"
    "raw_data.lfa1"
    "raw_data.makt"
    "raw_data.mara"
    "raw_data.marc"
    "raw_data.mard"
    "raw_data.mbew"
    "raw_data.mvke"
    "raw_data.t023t"
    "raw_data.t134"
)

# Fonction pour exporter une procedure/fonction
export_procedure() {
    local proc_name=$1
    local output_file=$2

    log_info "Export de $proc_name..."

    # Requete pour recuperer la definition de la procedure/fonction
    # On recupere toutes les signatures pour une procedure donnee
    local query="
    SELECT pg_get_functiondef(p.oid) || E';\n'
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'clean_data'
    AND p.proname = '$proc_name'
    ORDER BY p.oid;
    "

    # Executer la requete et recuperer le resultat
    local result
    result=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c "$query" 2>&1)
    local exit_code=$?
    local psql_error=$(echo "$result" | grep -i "error" || true)

    if [ $exit_code -eq 0 ] && [ -n "$result" ] && [ "$result" != "" ] && [ -z "$psql_error" ]; then
        # Nettoyer le resultat (supprimer les lignes vides en fin)
        result=$(echo "$result" | sed '/^$/d')
        # Ecrire le resultat dans le fichier
        echo -e "$result" > "$output_file"
        log_info "✅ $output_file cree avec succes"
        return 0
    else
        log_warning "⚠ $proc_name non trouvee dans le schema clean_data"
        if [ -n "$psql_error" ]; then
            log_debug "Erreur: $psql_error"
        fi
        return 1
    fi
}

# Fonction pour exporter une vue (schema.vue)
export_view() {
    local schema_name=$1
    local view_name=$2
    local output_file=$3

    log_info "Export de la vue $schema_name.$view_name..."

    local query="
    SELECT 'CREATE OR REPLACE VIEW $schema_name.$view_name AS ' || E'\n' || pg_get_viewdef('$schema_name.$view_name', true) || ';'
    "

    local result=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c "$query" 2>&1)

    if [ -n "$result" ] && ! echo "$result" | grep -qi "error"; then
        {
            echo "-- ============================================================================"
            echo "-- Vue $view_name"
            echo "-- Schema: $schema_name"
            echo "-- ============================================================================"
            echo ""
            echo "$result"
        } > "$output_file"

        log_info "✅ $output_file cree avec succes"
        return 0
    else
        log_warning "⚠ Vue $schema_name.$view_name non trouvee"
        return 1
    fi
}

# Fonction pour exporter la structure d'une table (colonnes + PK + index)
export_table() {
    local schema_name=$1
    local table_name=$2
    local output_file=$3
    local role=$4   # CIBLE (ecrite) ou SOURCE (lecture seule)

    log_info "Export de la table $schema_name.$table_name ($role)..."

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

    if [ -z "$result" ] || echo "$result" | grep -qi "error"; then
        log_warning "⚠ Table $table_name non trouvee dans $schema_name"
        return 1
    fi

    # Contraintes (PK, UNIQUE, CHECK, FK) et index
    local constraints_query="
    SELECT 'ALTER TABLE $schema_name.$table_name ADD CONSTRAINT ' || conname || ' ' || pg_get_constraintdef(oid) || ';'
    FROM pg_constraint
    WHERE conrelid = '$schema_name.$table_name'::regclass
    ORDER BY conname;
    "
    local constraints=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c "$constraints_query" 2>/dev/null)

    local indexes_query="
    SELECT indexdef || ';'
    FROM pg_indexes
    WHERE schemaname = '$schema_name' AND tablename = '$table_name'
    ORDER BY indexname;
    "
    local indexes=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c "$indexes_query" 2>/dev/null)

    {
        echo "-- ============================================================================"
        echo "-- Table $table_name"
        echo "-- Schema: $schema_name"
        echo "-- Role dans le module INVENTORY: $role"
        echo "-- ============================================================================"
        echo ""
        echo "$result"
        if [ -n "$constraints" ]; then
            echo ""
            echo "-- Contraintes"
            echo "$constraints"
        fi
        if [ -n "$indexes" ]; then
            echo ""
            echo "-- Index"
            echo "$indexes"
        fi
    } > "$output_file"

    log_info "✅ $output_file cree avec succes"
    return 0
}

# ----------------------------------------------------------------------------
# 1. Export des fonctions / procedures
# ----------------------------------------------------------------------------
echo "--- Fonctions et procedures ---"
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

# ----------------------------------------------------------------------------
# 2. Export des vues
# ----------------------------------------------------------------------------
echo "--- Vues ---"
for full_view in "${views[@]}"; do
    v_schema="${full_view%%.*}"
    v_name="${full_view##*.}"

    if export_view "$v_schema" "$v_name" "${v_name}.sql"; then
        ((count++))
    else
        ((errors++))
    fi
    echo ""
done

# ----------------------------------------------------------------------------
# 3. Export des tables cibles (ecrites par les fonctions)
# ----------------------------------------------------------------------------
echo "--- Tables cibles (ecrites) ---"
for full_table in "${target_tables[@]}"; do
    t_schema="${full_table%%.*}"
    t_name="${full_table##*.}"

    if export_table "$t_schema" "$t_name" "${t_name}_structure.sql" "CIBLE (TRUNCATE + INSERT)"; then
        ((count++))
    else
        ((errors++))
    fi
    echo ""
done

# ----------------------------------------------------------------------------
# 4. Export des tables sources (lecture seule)
# ----------------------------------------------------------------------------
if [ "$EXPORT_SOURCES" = "1" ]; then
    echo "--- Tables sources (lecture seule) ---"
    mkdir -p "$SOURCES_DIR"

    for full_table in "${source_tables[@]}"; do
        t_schema="${full_table%%.*}"
        t_name="${full_table##*.}"

        if export_table "$t_schema" "$t_name" "$SOURCES_DIR/${t_schema}.${t_name}_structure.sql" "SOURCE (lecture seule)"; then
            ((count++))
        else
            ((errors++))
        fi
        echo ""
    done
fi

# Resume
echo "=========================================="
if [ $errors -eq 0 ]; then
    log_info "✅ $count objet(s) exporte(s) avec succes!"
else
    log_info "✅ $count objet(s) exporte(s)"
    log_warning "⚠ $errors objet(s) non trouve(s)"
fi
echo "=========================================="
