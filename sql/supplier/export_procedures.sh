#!/bin/bash

# Script d'export des procédures stockées fournisseurs depuis la base PostgreSQL
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
echo "  Export des procédures FOURNISSEUR"
echo "=========================================="
echo ""
log_info "Connexion: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo ""

# Compteurs
count=0
errors=0

# Liste des procédures à exporter (fonctions et procédures stockées)
procedures=(
    "alimenter_ifs_fournisseurs"
    "alimenter_supplier_info_general"
    "alimenter_supplier_info_our_id"
    "alimenter_supplier_info_address"
    "insert_supplier_address_types"
    "alimenter_comm_method"
    "alimenter_supplier_address"
    "insert_supplier_document_tax_info"
    "sp_insert_supplier_from_sap"
    "sp_insert_identity_invoice_info_from_sap"
    "sp_insert_identity_pay_info_from_sap"
    "fn_upsert_payment_way_per_identity"
    "fn_upsert_supplier_delivery_tax_code"
    "fn_upsert_payment_address"
    "fn_upsert_supplier_tax_info"
    # --- Ajoutees le 2026-08-25 : presentes en base mais jamais exportees ---
    "extract_and_insert_supplier_data"
    "fn_calculate_iban"
    "insert_comm_method"
    "insert_supplier_address"
    "populate_supplier_info_address_type"
    "sp_insert_comm_method_from_sap"
    "sp_insert_payment_address_from_sap"
)

# Fichiers de sortie correspondants avec numérotation
output_files=(
    "01_alimenter_ifs_fournisseurs.sql"
    "02_alimenter_supplier_info_general.sql"
    "03_alimenter_supplier_info_our_id.sql"
    "04_alimenter_supplier_info_address.sql"
    "05_insert_supplier_address_types.sql"
    "06_alimenter_comm_method.sql"
    "07_alimenter_supplier_address.sql"
    "08_insert_supplier_document_tax_info.sql"
    "09_sp_insert_supplier_from_sap.sql"
    "10_sp_insert_identity_invoice_info_from_sap.sql"
    "11_sp_insert_identity_pay_info_from_sap.sql"
    "12_fn_upsert_payment_way_per_identity.sql"
    "13_fn_upsert_supplier_delivery_tax_code.sql"
    "14_fn_upsert_payment_address.sql"
    "15_fn_upsert_supplier_tax_info.sql"
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

# Fonction spéciale pour exporter sp_update_supplier_id_cascade (contient 2 procédures)
export_cascade_procedures() {
    local output_file="sp_update_supplier_id_cascade.sql"
    
    log_info "Export des procédures cascade (sp_update_supplier_id_cascade + sp_renumber_all_suppliers)..."
    
    # Export de la première procédure
    local query1="
    SELECT pg_get_functiondef(p.oid)
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'clean_data'
    AND p.proname = 'sp_update_supplier_id_cascade'
    ORDER BY p.oid
    LIMIT 1;
    "
    
    local result1=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c "$query1" 2>&1)
    
    # Export de la deuxième procédure
    local query2="
    SELECT pg_get_functiondef(p.oid)
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'clean_data'
    AND p.proname = 'sp_renumber_all_suppliers'
    ORDER BY p.oid
    LIMIT 1;
    "
    
    local result2=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c "$query2" 2>&1)
    
    if [ -n "$result1" ] && [ -n "$result2" ] && ! echo "$result1" | grep -qi "error" && ! echo "$result2" | grep -qi "error"; then
        {
            echo "$result1;"
            echo ""
            echo "-- ============================================================================"
            echo "-- Procédure pour mettre à jour TOUS les supplier_id avec une séquence à partir de 600000"
            echo "-- ============================================================================"
            echo ""
            echo "$result2;"
            echo ""
            echo "-- Commentaires sur les procédures"
            echo "COMMENT ON PROCEDURE clean_data.sp_update_supplier_id_cascade(VARCHAR, VARCHAR) IS "
            echo "'Procédure pour mettre à jour un supplier_id en cascade dans toutes les tables liées. "
            echo "Sauvegarde l''ancien ID dans la colonne SUPPLIER_LEGACY_SAP_ID.';"
            echo ""
            echo "COMMENT ON PROCEDURE clean_data.sp_renumber_all_suppliers() IS "
            echo "'Procédure pour renuméroter tous les fournisseurs avec une séquence commençant à 600000."
            echo "Utilise sp_update_supplier_id_cascade pour chaque fournisseur.';"
        } > "$output_file"
        
        log_info "✅ $output_file créé avec succès (2 procédures)"
        return 0
    else
        log_warning "⚠ Procédures cascade non trouvées ou erreur lors de l'export"
        return 1
    fi
}

# Export de chaque procédure
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

# Export spécial pour les procédures cascade (dans un seul fichier)
if export_cascade_procedures; then
    ((count++))  # Compter 1 fichier (contenant 2 procédures)
else
    ((errors++))
fi
echo ""

# Export de sp_keep_supplier_sample
log_info "Export de sp_keep_supplier_sample..."
query_sample="
SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'clean_data'
AND p.proname = 'sp_keep_supplier_sample'
ORDER BY p.oid
LIMIT 1;
"
result_sample=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c "$query_sample" 2>&1)

if [ -n "$result_sample" ] && ! echo "$result_sample" | grep -qi "error"; then
    {
        echo "-- ============================================================================"
        echo "-- Procédure pour garder un échantillon de N fournisseurs (défaut: 200)"
        echo "-- Supprime les données des autres fournisseurs dans toutes les tables liées"
        echo "-- ============================================================================"
        echo "$result_sample;"
        echo ""
        echo "COMMENT ON PROCEDURE clean_data.sp_keep_supplier_sample(INTEGER) IS "
        echo "'Procédure pour garder un échantillon aléatoire de N fournisseurs (défaut: 200)."
        echo "Supprime les données des autres fournisseurs dans toutes les tables liées.';"
    } > "sp_keep_supplier_sample.sql"
    log_info "✅ sp_keep_supplier_sample.sql créé avec succès"
    ((count++))
else
    log_warning "⚠ sp_keep_supplier_sample non trouvée"
    ((errors++))
fi
echo ""

# Export de la table selection_fournisseurs dans viewsAndTables/
log_info "Export de la table selection_fournisseurs..."
mkdir -p viewsAndTables
query_selection="
SELECT 'CREATE TABLE IF NOT EXISTS raw_data.selection_fournisseurs (' || E'\n' ||
       string_agg('    ' || column_name || ' ' || 
                  CASE 
                      WHEN data_type = 'character varying' THEN 'VARCHAR(' || character_maximum_length || ')'
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
WHERE table_schema = 'raw_data'
AND table_name = 'selection_fournisseurs';
"
result_selection=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c "$query_selection" 2>&1)

if [ -n "$result_selection" ] && ! echo "$result_selection" | grep -qi "error" && [ "$result_selection" != "" ]; then
    {
        echo "-- ============================================================================"
        echo "-- Table de sélection des fournisseurs à exporter"
        echo "-- Liste définitive des fournisseurs retenus pour la migration"
        echo "-- ============================================================================"
        echo ""
        echo "$result_selection"
        echo ""
        echo "-- Index sur lifnr pour améliorer les performances des jointures"
        echo "CREATE INDEX IF NOT EXISTS idx_selection_fournisseurs_lifnr ON raw_data.selection_fournisseurs(lifnr);"
        echo ""
        echo "COMMENT ON TABLE raw_data.selection_fournisseurs IS 'Liste définitive des fournisseurs sélectionnés pour la migration vers IFS';"
    } > "viewsAndTables/selection_fournisseurs.sql"
    log_info "✅ viewsAndTables/selection_fournisseurs.sql créé avec succès"
    ((count++))
else
    log_warning "⚠ Table selection_fournisseurs non trouvée dans raw_data"
    ((errors++))
fi
echo ""

# Résumé
echo "=========================================="
if [ $errors -eq 0 ]; then
    log_info "✅ $count procédure(s) exportée(s) avec succès!"
else
    log_info "✅ $count procédure(s) exportée(s)"
    log_warning "⚠ $errors procédure(s) non trouvée(s)"
fi
echo "=========================================="

