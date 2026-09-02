-- ============================================================================
-- 046 : ajout de clean_data.supplier_addr_tax_number a l'export fournisseur
-- ----------------------------------------------------------------------------
-- Les exports sont pilotes par la table public.etl_export_queries : aucune
-- ligne de code a modifier, il suffit d'y declarer la table et ses colonnes.
--
-- La table est alimentee par clean_data.sp_insert_supplier_addr_tax_number()
-- (sql/supplier/16_sp_insert_supplier_addr_tax_number.sql) : une ligne par
-- numero fiscal, TAX_ID_TYPE valant 'TVA UE', 'SIREN' ou 'SIRET'.
--
-- DEFAULT_TAX_ID_NUMBER est exportee bien qu'elle ne soit jamais alimentee
-- (regle <col>/<col>_db du depot : seule la colonne _db porte la valeur). Le
-- couple est conserve dans l'export car IFS attend les deux colonnes, comme
-- pour supplier_document_tax_info (RELIABILITY_STATUS / _DB).
--
-- Idempotent : la contrainte unique_table_name (table_name, category) protege
-- contre un doublon si la migration est rejouee.
-- ============================================================================

INSERT INTO public.etl_export_queries (
    table_schema,
    table_name,
    display_name,
    column_list,
    description,
    category,
    is_active,
    created_by
)
VALUES (
    'clean_data',
    'supplier_addr_tax_number',
    'Numéros Fiscaux Fournisseur',
    'SUPPLIER_ID,ADDRESS_ID,COMPANY,TAX_ID_TYPE,TAX_ID_NUMBER,DEFAULT_TAX_ID_NUMBER,DEFAULT_TAX_ID_NUMBER_DB',
    'Numéros d''identification fiscale par type : TVA UE, SIREN, SIRET (une ligne par numéro)',
    'supplier',
    TRUE,
    'migration_046'
)
ON CONFLICT (table_name, category) DO UPDATE SET
    table_schema = EXCLUDED.table_schema,
    display_name = EXCLUDED.display_name,
    column_list  = EXCLUDED.column_list,
    description  = EXCLUDED.description,
    is_active    = EXCLUDED.is_active,
    updated_at   = CURRENT_TIMESTAMP,
    updated_by   = 'migration_046';

-- =====================================================
-- ROLLBACK
-- =====================================================
-- DELETE FROM public.etl_export_queries
--  WHERE table_name = 'supplier_addr_tax_number' AND category = 'supplier';
