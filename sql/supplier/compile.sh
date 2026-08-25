#!/bin/bash

# Script de compilation des procédures stockées fournisseurs SAP vers IFS
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
    
    if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$file" > /dev/null 2>&1; then
        log_info "✅ $filename compilé avec succès"
        return 0
    else
        log_error "❌ Erreur lors de la compilation de $filename"
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$file"
        return 1
    fi
}

# Début du script
echo "=========================================="
echo "  Compilation des procédures FOURNISSEUR"
echo "=========================================="
echo ""
log_info "Connexion: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo ""

# Compteur d'erreurs
errors=0

# Liste des fichiers dans l'ordre d'exécution
files=(
    # Prerequis des valeurs par defaut parametrables : la table et l'accesseur
    # doivent exister AVANT les fonctions ETL qui les appellent, sinon chaque
    # chargement echoue sur "function public.get_default_value does not exist".
    # Les deux fichiers sont idempotents (IF NOT EXISTS / ON CONFLICT DO NOTHING
    # / CREATE OR REPLACE), ils peuvent donc etre rejoues sans risque.
    "../../migrations/031_create_etl_default_values.sql"
    "../functions/get_default_value.sql"
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
    "sp_update_supplier_id_cascade.sql"
    "sp_keep_supplier_sample.sql"
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

