-- ============================================================================
-- 048 : FISCAL_NO (numero de TVA) sur les infos de facturation
-- ----------------------------------------------------------------------------
-- Cote FOURNISSEUR (clean_data.identity_invoice_info) la colonne existait deja
-- et figurait deja dans l'export id=10 : seule la procedure
-- sql/supplier/10_sp_insert_identity_invoice_info_from_sap.sql a ete modifiee
-- (source : ifs_fournisseurs.tva, tronque a 16 caracteres). Rien a faire ici.
--
-- Cote CLIENT (clean_data.cus_ident_invoice_info = entite IFS
-- IDENTITY_INVOICE_INFO du LOT01) la colonne n'existait PAS :
--   * on l'ajoute (VARCHAR(16), comme CUSTOMER_TAX_INFO.FISCAL_NO et comme le
--     catalogue IFS : VARCHAR2(16), non obligatoire) ;
--   * on l'ajoute a l'export id=27, a la position du modele IFS LOT01
--     (sort_order 693 : apres NO_INVOICE_COPIES, avant DIGITAL_INVOICE).
--
-- Le remplissage se fait par
-- sql/customerFile/sp_insert_cus_ident_invoice_info_from_file_customer.sql,
-- avec la MEME expression que customer_tax_info.fiscal_no :
--   COALESCE(kna1.stceg, kna1.stcd1, file_customer.tax_number_1) tronque a 16.
-- Reference : 194 des 196 clients ont deja un fiscal_no dans customer_tax_info.
--
-- Ordre : jouer cette migration AVANT de recompiler la procedure client
-- (elle insere dans la nouvelle colonne).
-- ============================================================================

BEGIN;

-- --- 1. La colonne ----------------------------------------------------------
ALTER TABLE clean_data.cus_ident_invoice_info
    ADD COLUMN IF NOT EXISTS fiscal_no VARCHAR(16);

COMMENT ON COLUMN clean_data.cus_ident_invoice_info.fiscal_no IS
'N° fiscal IFS (IDENTITY_INVOICE_INFO.FISCAL_NO) : numero de TVA intracommunautaire du client (kna1.stceg, repli stcd1 puis file_customer.tax_number_1), tronque a 16 caracteres.';

-- --- 2. L'export ------------------------------------------------------------
-- Insere FISCAL_NO apres NO_INVOICE_COPIES si absent (idempotent).
UPDATE public.etl_export_queries
SET column_list = REPLACE(column_list, 'NO_INVOICE_COPIES,', 'NO_INVOICE_COPIES,FISCAL_NO,'),
    updated_at  = CURRENT_TIMESTAMP,
    updated_by  = 'migration_048'
WHERE table_schema = 'clean_data'
  AND table_name   = 'cus_ident_invoice_info'
  AND column_list NOT ILIKE '%FISCAL_NO%';

COMMIT;

-- --- Controle ---------------------------------------------------------------
-- SELECT column_list FROM public.etl_export_queries WHERE table_name='cus_ident_invoice_info';
-- SELECT COUNT(*), COUNT(fiscal_no) FROM clean_data.cus_ident_invoice_info;

-- =====================================================
-- ROLLBACK
-- =====================================================
-- BEGIN;
-- UPDATE public.etl_export_queries
-- SET column_list = REPLACE(column_list, 'NO_INVOICE_COPIES,FISCAL_NO,', 'NO_INVOICE_COPIES,')
-- WHERE table_schema='clean_data' AND table_name='cus_ident_invoice_info';
-- ALTER TABLE clean_data.cus_ident_invoice_info DROP COLUMN IF EXISTS fiscal_no;
-- COMMIT;
