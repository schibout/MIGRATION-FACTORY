CREATE OR REPLACE PROCEDURE clean_data.sp_insert_identity_invoice_info_from_sap()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_with_bank_count INTEGER := 0;
    v_without_bank_count INTEGER := 0;
    v_start_time TIMESTAMP;
    rec RECORD;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    RAISE NOTICE '=== DÉBUT INSERTION IDENTITY_INVOICE_INFO ===';
    RAISE NOTICE 'Heure de début: %', v_start_time;
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.IDENTITY_INVOICE_INFO;
    RAISE NOTICE 'Table IDENTITY_INVOICE_INFO vidée';
    
    -- Créer une table temporaire pour dédupliquer les données - Colonnes essentielles uniquement
    CREATE TEMP TABLE temp_identity_invoice_info AS
    SELECT DISTINCT
        -- Colonnes principales
        COALESCE(f.company, 'TRIMET') as COMPANY,
        f.numero_compte_fournisseur as IDENTITY,
        public.get_default_value('clean_data.identity_invoice_info', 'party_type') as PARTY_TYPE,
        public.get_default_value('clean_data.identity_invoice_info', 'party_type_db') as PARTY_TYPE_DB,
        -- Colonnes spécifiées uniquement
        public.get_default_value('clean_data.identity_invoice_info', 'invoice_fee') as INVOICE_FEE,
        COALESCE(NULLIF(TRIM(sf.condition_paiement_ifs), ''), f.conditions_paiement_achats, 'NET30') as PAY_TERM_ID,
        COALESCE(NULLIF(TRIM(sf.code_tva_ifs), ''), '') as DEF_VAT_CODE,
        -- Numero fiscal = numero de TVA intracommunautaire resolu par le script 01
        -- (selection_fournisseurs.numero_tva_intra > lfa1.stceg).
        -- fiscal_no est un VARCHAR(16) : 3 fournisseurs (1 FR, 2 CN) portent un
        -- numero de 18 caracteres et sont tronques.
        SUBSTRING(NULLIF(TRIM(f.tva), '') FROM 1 FOR 16) as FISCAL_NO,
        -- ifs_fournisseurs.devise_principale a été supprimée (colonne KPI jamais
        -- alimentée) : le COALESCE retombait toujours sur 'EUR'.
        public.get_default_value('clean_data.identity_invoice_info', 'def_currency') as DEF_CURRENCY,
        public.get_default_value('clean_data.identity_invoice_info', 'identity_type') as IDENTITY_TYPE,
        public.get_default_value('clean_data.identity_invoice_info', 'voting_share_percentage') as VOTING_SHARE_PERCENTAGE,
        public.get_default_value('clean_data.identity_invoice_info', 'automatic_invoice') as AUTOMATIC_INVOICE,
        public.get_default_value('clean_data.identity_invoice_info', 'ncf_reference_check') as NCF_REFERENCE_CHECK,
        public.get_default_value('clean_data.identity_invoice_info', 'tax_exempt') as TAX_EXEMPT,
        public.get_default_value('clean_data.identity_invoice_info', 'second_tin') as SECOND_TIN,
        public.get_default_value('clean_data.identity_invoice_info', 'report_and_withhold') as REPORT_AND_WITHHOLD,
        public.get_default_value('clean_data.identity_invoice_info', 'print_tax_code_text') as PRINT_TAX_CODE_TEXT,
        public.get_default_value('clean_data.identity_invoice_info', 'withholding_base_amount') as WITHHOLDING_BASE_AMOUNT,
        public.get_default_value('clean_data.identity_invoice_info', 'matching_level') as MATCHING_LEVEL,
        public.get_default_value('clean_data.identity_invoice_info', 'allow_tolerance') as ALLOW_TOLERANCE,
        public.get_default_value('clean_data.identity_invoice_info', 'create_tolerance_posting') as CREATE_TOLERANCE_POSTING,
        public.get_default_value('clean_data.identity_invoice_info', 'allow_quantity_diff') as ALLOW_QUANTITY_DIFF,
        public.get_default_value('clean_data.identity_invoice_info', 'tax_certificate_form') as TAX_CERTIFICATE_FORM,
        public.get_default_value('clean_data.identity_invoice_info', 'legal_identity') as LEGAL_IDENTITY,
        public.get_default_value('clean_data.identity_invoice_info', 'po_ref_rec_ref_val_method') as PO_REF_REC_REF_VAL_METHOD,
        CURRENT_TIMESTAMP as BI_TIMESTAMP,
        public.get_default_value('clean_data.identity_invoice_info', 'invoice_recipient_from') as INVOICE_RECIPIENT_FROM,
        public.get_default_value('clean_data.identity_invoice_info', 'exc_from_spesometro_dec') as EXC_FROM_SPESOMETRO_DEC,
        public.get_default_value('clean_data.identity_invoice_info', 'service_code_required') as SERVICE_CODE_REQUIRED,
        public.get_default_value('clean_data.identity_invoice_info', 'inc_inv_curr_rate_base') as INC_INV_CURR_RATE_BASE,
        public.get_default_value('clean_data.identity_invoice_info', 'tax_buy_curr_rate_base') as TAX_BUY_CURR_RATE_BASE,
        public.get_default_value('clean_data.identity_invoice_info', 'exclude_posting_auth') as EXCLUDE_POSTING_AUTH,
        public.get_default_value('clean_data.identity_invoice_info', 'exclude_invoice_image') as EXCLUDE_INVOICE_IMAGE,
        public.get_default_value('clean_data.identity_invoice_info', 'utility_bill_provider') as UTILITY_BILL_PROVIDER,
        public.get_default_value('clean_data.identity_invoice_info', 'digital_invoice') as DIGITAL_INVOICE,
        CASE 
            WHEN f.cle_pays IN ('FR', 'DE', 'IT', 'ES', 'NL', 'BE', 'AT', 'PT', 'IE', 'FI', 'SE', 'DK') 
                 THEN 'TRUE'
            ELSE 'FALSE'
        END as COUNTRY_TAX_REGISTERED,
        
        -- Colonnes de métadonnées ETL
        CURRENT_TIMESTAMP as CREATED_TIMESTAMP,
        CURRENT_TIMESTAMP as UPDATED_TIMESTAMP,
        CASE 
            WHEN lb.lifnr IS NOT NULL THEN 'etl_supplier_base_with_bank'
            ELSE 'etl_supplier_base'
        END as CREATED_BY,
        CASE 
            WHEN lb.lifnr IS NOT NULL THEN 'etl_supplier_base_with_bank'
            ELSE 'etl_supplier_base'
        END as UPDATED_BY,
        FALSE as IS_DELETED
    FROM clean_data.ifs_fournisseurs f
    LEFT JOIN raw_data.selection_fournisseurs sf 
        ON f.numero_compte_fournisseur = sf.numero_compte_sap
    LEFT JOIN raw_data.lfbk lb ON f.numero_compte_fournisseur = lb.lifnr
    LEFT JOIN raw_data.lfm1 m ON f.numero_compte_fournisseur = m.lifnr 
        AND m.ekorg = f.organisation_achats;
    
    RAISE NOTICE 'Table temporaire créée avec % enregistrements', (SELECT COUNT(*) FROM temp_identity_invoice_info);
    
    -- Insertion depuis la table temporaire vers la table finale - Colonnes essentielles uniquement
    INSERT INTO clean_data.IDENTITY_INVOICE_INFO (
        COMPANY,
        IDENTITY,
        PARTY_TYPE,
        PARTY_TYPE_DB,
        INVOICE_FEE,
        PAY_TERM_ID,
        DEF_VAT_CODE,
        FISCAL_NO,
        DEF_CURRENCY,
        IDENTITY_TYPE,
        VOTING_SHARE_PERCENTAGE,
        AUTOMATIC_INVOICE,
        NCF_REFERENCE_CHECK,
        TAX_EXEMPT,
        SECOND_TIN,
        REPORT_AND_WITHHOLD,
        PRINT_TAX_CODE_TEXT,
        WITHHOLDING_BASE_AMOUNT,
        MATCHING_LEVEL,
        ALLOW_TOLERANCE,
        CREATE_TOLERANCE_POSTING,
        ALLOW_QUANTITY_DIFF,
        TAX_CERTIFICATE_FORM,
        LEGAL_IDENTITY,
        PO_REF_REC_REF_VAL_METHOD,
        BI_TIMESTAMP,
        INVOICE_RECIPIENT_FROM,
        EXC_FROM_SPESOMETRO_DEC,
        SERVICE_CODE_REQUIRED,
        INC_INV_CURR_RATE_BASE,
        TAX_BUY_CURR_RATE_BASE,
        EXCLUDE_POSTING_AUTH,
        EXCLUDE_INVOICE_IMAGE,
        UTILITY_BILL_PROVIDER,
        DIGITAL_INVOICE,
        COUNTRY_TAX_REGISTERED,
        CREATED_TIMESTAMP,
        UPDATED_TIMESTAMP,
        CREATED_BY,
        UPDATED_BY,
        IS_DELETED
    )
    SELECT 
        COMPANY,
        IDENTITY,
        PARTY_TYPE,
        PARTY_TYPE_DB,
        INVOICE_FEE,
        PAY_TERM_ID,
        DEF_VAT_CODE,
        FISCAL_NO,
        DEF_CURRENCY,
        IDENTITY_TYPE,
        VOTING_SHARE_PERCENTAGE,
        AUTOMATIC_INVOICE,
        NCF_REFERENCE_CHECK,
        TAX_EXEMPT,
        SECOND_TIN,
        REPORT_AND_WITHHOLD,
        PRINT_TAX_CODE_TEXT,
        WITHHOLDING_BASE_AMOUNT,
        MATCHING_LEVEL,
        ALLOW_TOLERANCE,
        CREATE_TOLERANCE_POSTING,
        ALLOW_QUANTITY_DIFF,
        TAX_CERTIFICATE_FORM,
        LEGAL_IDENTITY,
        PO_REF_REC_REF_VAL_METHOD,
        COALESCE(BI_TIMESTAMP, CURRENT_TIMESTAMP),
        INVOICE_RECIPIENT_FROM,
        EXC_FROM_SPESOMETRO_DEC,
        SERVICE_CODE_REQUIRED,
        INC_INV_CURR_RATE_BASE,
        TAX_BUY_CURR_RATE_BASE,
        EXCLUDE_POSTING_AUTH,
        EXCLUDE_INVOICE_IMAGE,
        UTILITY_BILL_PROVIDER,
        DIGITAL_INVOICE,
        COUNTRY_TAX_REGISTERED,
        CREATED_TIMESTAMP,
        UPDATED_TIMESTAMP,
        CREATED_BY,
        UPDATED_BY,
        IS_DELETED
    FROM temp_identity_invoice_info;
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    
    RAISE NOTICE 'Enregistrements traités (insertions + mises à jour): %', v_processed_count;
    
    -- Compter les fournisseurs avec et sans données bancaires
    SELECT COUNT(*) INTO v_with_bank_count 
    FROM clean_data.identity_invoice_info 
    WHERE created_by = 'etl_supplier_base_with_bank';
    
    SELECT COUNT(*) INTO v_without_bank_count 
    FROM clean_data.identity_invoice_info 
    WHERE created_by = 'etl_supplier_base';
    
    RAISE NOTICE '';
    RAISE NOTICE '=== INSERTION IDENTITY_INVOICE_INFO TERMINÉE ===';
    RAISE NOTICE 'Durée: % secondes', EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time));
    RAISE NOTICE 'Total enregistrements traités: %', v_processed_count;
    RAISE NOTICE '';
    RAISE NOTICE '=== STATISTIQUES DONNÉES BANCAIRES ===';
    RAISE NOTICE 'Fournisseurs AVEC données bancaires: %', v_with_bank_count;
    RAISE NOTICE 'Fournisseurs SANS données bancaires: %', v_without_bank_count;
    RAISE NOTICE '';
    RAISE NOTICE '=== STATISTIQUES PAR SOCIÉTÉ ===';
    FOR rec IN (
        SELECT company, COUNT(*) as nb_fournisseurs
        FROM clean_data.identity_invoice_info 
        GROUP BY company
        ORDER BY company
    ) LOOP
        RAISE NOTICE 'Société %: % fournisseurs', rec.company, rec.nb_fournisseurs;
    END LOOP;
    RAISE NOTICE '';
    RAISE NOTICE '=== STATISTIQUES PAYS ===';
    RAISE NOTICE 'Fournisseurs UE (country_tax_registered=TRUE): %', 
        (SELECT COUNT(*) FROM clean_data.identity_invoice_info WHERE country_tax_registered = 'TRUE');
    RAISE NOTICE 'Fournisseurs hors UE (country_tax_registered=FALSE): %', 
        (SELECT COUNT(*) FROM clean_data.identity_invoice_info WHERE country_tax_registered = 'FALSE');
    
    -- Nettoyer la table temporaire
    DROP TABLE IF EXISTS temp_identity_invoice_info;
    RAISE NOTICE 'Table temporaire nettoyée';
    
EXCEPTION
    WHEN OTHERS THEN
        -- Nettoyer la table temporaire en cas d'erreur
        DROP TABLE IF EXISTS temp_identity_invoice_info;
        RAISE EXCEPTION 'Erreur lors de l''INSERT identity invoice info avec banque: %', SQLERRM;
END;
$procedure$
;
