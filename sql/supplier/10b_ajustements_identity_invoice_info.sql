-- ============================================================================
-- Ajustements de sp_insert_identity_invoice_info_from_sap
-- Comparaison du 2026-11-05 avec les donnees validees en UAT par le metier.
-- Remplace la fonction du script d'origine : a jouer APRES lui (cf. compile.sh).
-- Ne fait que recompiler : le rechargement des tables reste a lancer.
-- Les colonnes libelle d'un couple <col>/<col>_db restent regies par la regle du depot.
--
--   pay_term_id : conditions de paiement comptables du perimetre ; def_vat_code : code TVA IFS du perimetre
--   country_tax_registered : lu dans etl_default_values (au lieu du pays)
--   ajoutes : colonnes _db, group_id, is_note, tax_liability, currency_code, automatic_pay_auth_flag, codes pays
--   vides : fiscal_no, bi_timestamp
-- ============================================================================
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
        -- IDENTITY = numéro IFS du fichier de sélection (voir script 02).
        f.numero_compte_ifs as IDENTITY,
        public.get_default_value('clean_data.identity_invoice_info', 'party_type') as PARTY_TYPE,
        public.get_default_value('clean_data.identity_invoice_info', 'party_type_db') as PARTY_TYPE_DB,
        -- Colonnes spécifiées uniquement
        public.get_default_value('clean_data.identity_invoice_info', 'invoice_fee') as INVOICE_FEE,
        COALESCE(NULLIF(TRIM(f.conditions_paiement_compta), ''), NULLIF(TRIM(sf.condition_paiement_ifs), ''), f.conditions_paiement_achats, 'NET30') as PAY_TERM_ID,
        NULLIF(TRIM(f.code_tva_ifs), '') as DEF_VAT_CODE,
        -- Numero fiscal = numero de TVA intracommunautaire resolu par le script 01
        -- (selection_fournisseurs.numero_tva_intra > lfa1.stceg).
        -- fiscal_no est un VARCHAR(16) : 3 fournisseurs (1 FR, 2 CN) portent un
        -- numero de 18 caracteres et sont tronques.
        NULL::text as FISCAL_NO,
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
        NULL::timestamp as BI_TIMESTAMP,
        public.get_default_value('clean_data.identity_invoice_info', 'invoice_recipient_from') as INVOICE_RECIPIENT_FROM,
        public.get_default_value('clean_data.identity_invoice_info', 'exc_from_spesometro_dec') as EXC_FROM_SPESOMETRO_DEC,
        public.get_default_value('clean_data.identity_invoice_info', 'service_code_required') as SERVICE_CODE_REQUIRED,
        public.get_default_value('clean_data.identity_invoice_info', 'inc_inv_curr_rate_base') as INC_INV_CURR_RATE_BASE,
        public.get_default_value('clean_data.identity_invoice_info', 'tax_buy_curr_rate_base') as TAX_BUY_CURR_RATE_BASE,
        public.get_default_value('clean_data.identity_invoice_info', 'exclude_posting_auth') as EXCLUDE_POSTING_AUTH,
        public.get_default_value('clean_data.identity_invoice_info', 'exclude_invoice_image') as EXCLUDE_INVOICE_IMAGE,
        public.get_default_value('clean_data.identity_invoice_info', 'utility_bill_provider') as UTILITY_BILL_PROVIDER,
        public.get_default_value('clean_data.identity_invoice_info', 'digital_invoice') as DIGITAL_INVOICE,
        public.get_default_value('clean_data.identity_invoice_info', 'country_tax_registered') as COUNTRY_TAX_REGISTERED,
        public.get_default_value('clean_data.identity_invoice_info', 'identity_type_db') as IDENTITY_TYPE_DB,
        public.get_default_value('clean_data.identity_invoice_info', 'voting_share_percentage_db') as VOTING_SHARE_PERCENTAGE_DB,
        public.get_default_value('clean_data.identity_invoice_info', 'report_and_withhold_db') as REPORT_AND_WITHHOLD_DB,
        public.get_default_value('clean_data.identity_invoice_info', 'withholding_base_amount_db') as WITHHOLDING_BASE_AMOUNT_DB,
        public.get_default_value('clean_data.identity_invoice_info', 'matching_level_db') as MATCHING_LEVEL_DB,
        public.get_default_value('clean_data.identity_invoice_info', 'tax_certificate_form_db') as TAX_CERTIFICATE_FORM_DB,
        public.get_default_value('clean_data.identity_invoice_info', 'automatic_pay_auth_flag') as AUTOMATIC_PAY_AUTH_FLAG,
        public.get_default_value('clean_data.identity_invoice_info', 'automatic_pay_auth_flag_db') as AUTOMATIC_PAY_AUTH_FLAG_DB,
        public.get_default_value('clean_data.identity_invoice_info', 'legal_identity_db') as LEGAL_IDENTITY_DB,
        public.get_default_value('clean_data.identity_invoice_info', 'po_ref_rec_ref_val_method_db') as PO_REF_REC_REF_VAL_METHOD_DB,
        public.get_default_value('clean_data.identity_invoice_info', 'invoice_recipient_from_db') as INVOICE_RECIPIENT_FROM_DB,
        public.get_default_value('clean_data.identity_invoice_info', 'exc_from_spesometro_dec_db') as EXC_FROM_SPESOMETRO_DEC_DB,
        public.get_default_value('clean_data.identity_invoice_info', 'service_code_required_db') as SERVICE_CODE_REQUIRED_DB,
        public.get_default_value('clean_data.identity_invoice_info', 'inc_inv_curr_rate_base_db') as INC_INV_CURR_RATE_BASE_DB,
        public.get_default_value('clean_data.identity_invoice_info', 'tax_buy_curr_rate_base_db') as TAX_BUY_CURR_RATE_BASE_DB,
        public.get_default_value('clean_data.identity_invoice_info', 'exclude_posting_auth_db') as EXCLUDE_POSTING_AUTH_DB,
        public.get_default_value('clean_data.identity_invoice_info', 'exclude_invoice_image_db') as EXCLUDE_INVOICE_IMAGE_DB,
        public.get_default_value('clean_data.identity_invoice_info', 'utility_bill_provider_db') as UTILITY_BILL_PROVIDER_DB,
        public.get_default_value('clean_data.identity_invoice_info', 'digital_invoice_db') as DIGITAL_INVOICE_DB,
        public.get_default_value('clean_data.identity_invoice_info', 'country_tax_registered_db') as COUNTRY_TAX_REGISTERED_DB,
        public.get_default_value('clean_data.identity_invoice_info', 'group_id') as GROUP_ID,
        public.get_default_value('clean_data.identity_invoice_info', 'is_note') as IS_NOTE,
        public.get_default_value('clean_data.identity_invoice_info', 'tax_liability') as TAX_LIABILITY,
        public.get_default_value('clean_data.identity_invoice_info', 'currency_code') as CURRENCY_CODE,
        f.cle_pays as SUP_COUNTRY_CODE,
        f.cle_pays as COUNTRY_CODE,
        
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
        IDENTITY_TYPE_DB,
        VOTING_SHARE_PERCENTAGE_DB,
        REPORT_AND_WITHHOLD_DB,
        WITHHOLDING_BASE_AMOUNT_DB,
        MATCHING_LEVEL_DB,
        TAX_CERTIFICATE_FORM_DB,
        AUTOMATIC_PAY_AUTH_FLAG,
        AUTOMATIC_PAY_AUTH_FLAG_DB,
        LEGAL_IDENTITY_DB,
        PO_REF_REC_REF_VAL_METHOD_DB,
        INVOICE_RECIPIENT_FROM_DB,
        EXC_FROM_SPESOMETRO_DEC_DB,
        SERVICE_CODE_REQUIRED_DB,
        INC_INV_CURR_RATE_BASE_DB,
        TAX_BUY_CURR_RATE_BASE_DB,
        EXCLUDE_POSTING_AUTH_DB,
        EXCLUDE_INVOICE_IMAGE_DB,
        UTILITY_BILL_PROVIDER_DB,
        DIGITAL_INVOICE_DB,
        COUNTRY_TAX_REGISTERED_DB,
        GROUP_ID,
        IS_NOTE,
        TAX_LIABILITY,
        CURRENCY_CODE,
        SUP_COUNTRY_CODE,
        COUNTRY_CODE,
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
        IDENTITY_TYPE_DB,
        VOTING_SHARE_PERCENTAGE_DB,
        REPORT_AND_WITHHOLD_DB,
        WITHHOLDING_BASE_AMOUNT_DB,
        MATCHING_LEVEL_DB,
        TAX_CERTIFICATE_FORM_DB,
        AUTOMATIC_PAY_AUTH_FLAG,
        AUTOMATIC_PAY_AUTH_FLAG_DB,
        LEGAL_IDENTITY_DB,
        PO_REF_REC_REF_VAL_METHOD_DB,
        INVOICE_RECIPIENT_FROM_DB,
        EXC_FROM_SPESOMETRO_DEC_DB,
        SERVICE_CODE_REQUIRED_DB,
        INC_INV_CURR_RATE_BASE_DB,
        TAX_BUY_CURR_RATE_BASE_DB,
        EXCLUDE_POSTING_AUTH_DB,
        EXCLUDE_INVOICE_IMAGE_DB,
        UTILITY_BILL_PROVIDER_DB,
        DIGITAL_INVOICE_DB,
        COUNTRY_TAX_REGISTERED_DB,
        GROUP_ID,
        IS_NOTE,
        TAX_LIABILITY,
        CURRENCY_CODE,
        SUP_COUNTRY_CODE,
        COUNTRY_CODE,
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
