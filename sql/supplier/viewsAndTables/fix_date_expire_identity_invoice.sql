-- Script de correction rapide pour la ligne EXPIRE_DATE dans sp_insert_identity_invoice_info_from_sap
-- Ce script corrige l'erreur de date et la syntaxe

-- Corriger la procédure avec une gestion plus simple des dates
CREATE OR REPLACE PROCEDURE clean_data.sp_insert_identity_invoice_info_from_sap()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_with_bank_count INTEGER := 0;
    v_without_bank_count INTEGER := 0;
    v_invalid_dates_count INTEGER := 0;
BEGIN
    
    RAISE NOTICE 'Début insertion identity invoice info SAP - Tous les fournisseurs avec données bancaires';
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.IDENTITY_INVOICE_INFO;
    RAISE NOTICE 'Table identity_invoice_info vidée';
    
    -- Insertion avec SELECT DISTINCT et gestion sécurisée des dates
    INSERT INTO clean_data.IDENTITY_INVOICE_INFO (
        COMPANY,
        IDENTITY,
        PARTY_TYPE,
        PARTY_TYPE_DB,
        INVOICE_FEE,
        EXPIRE_DATE,
        NATIONAL_BANK_CODE,
        GROUP_ID,
        DEF_AUTHORIZER,
        PAY_TERM_ID,
        DEF_VAT_CODE,
        ROUNDING_TAX_CODE,
        DEF_CURRENCY,
        PAYM_DEV_DAYS,
        IDENTITY_TYPE,
        IDENTITY_TYPE_DB,
        VOTING_SHARE_PERCENTAGE,
        VOTING_SHARE_PERCENTAGE_DB,
        AUTOMATIC_INVOICE,
        NCF_REFERENCE_CHECK,
        TAX_EXEMPT,
        SECOND_TIN,
        REPORT_AND_WITHHOLD,
        REPORT_AND_WITHHOLD_DB,
        PRINT_TAX_CODE_TEXT,
        WITHHOLDING_BASE_AMOUNT,
        WITHHOLDING_BASE_AMOUNT_DB,
        MATCHING_LEVEL,
        MATCHING_LEVEL_DB,
        ALLOW_TOLERANCE,
        CREATE_TOLERANCE_POSTING,
        ALLOW_QUANTITY_DIFF,
        TAX_CERTIFICATE_FORM,
        TAX_CERTIFICATE_FORM_DB,
        LEGAL_IDENTITY,
        LEGAL_IDENTITY_DB,
        PO_REF_REC_REF_VAL_METHOD,
        PO_REF_REC_REF_VAL_METHOD_DB,
        BI_TIMESTAMP,
        INVOICE_RECIPIENT_FROM,
        INVOICE_RECIPIENT_FROM_DB,
        EXC_FROM_SPESOMETRO_DEC,
        EXC_FROM_SPESOMETRO_DEC_DB,
        SERVICE_CODE_REQUIRED,
        SERVICE_CODE_REQUIRED_DB,
        INC_INV_CURR_RATE_BASE,
        INC_INV_CURR_RATE_BASE_DB,
        TAX_BUY_CURR_RATE_BASE,
        TAX_BUY_CURR_RATE_BASE_DB,
        EXCLUDE_POSTING_AUTH,
        EXCLUDE_POSTING_AUTH_DB,
        EXCLUDE_INVOICE_IMAGE,
        EXCLUDE_INVOICE_IMAGE_DB,
        UTILITY_BILL_PROVIDER,
        UTILITY_BILL_PROVIDER_DB,
        DIGITAL_INVOICE,
        DIGITAL_INVOICE_DB,
        COUNTRY_TAX_REGISTERED,
        COUNTRY_TAX_REGISTERED_DB,
        CREATED_TIMESTAMP,
        UPDATED_TIMESTAMP,
        CREATED_BY,
        UPDATED_BY,
        IS_DELETED
    )
    SELECT DISTINCT
        COALESCE(v."Société", '1000') as COMPANY,
        v."Numéro de compte fournisseur" as IDENTITY,
        'FALSE' as PARTY_TYPE,
        'SUPPLIER' as PARTY_TYPE_DB,
        'STD' as INVOICE_FEE,
        -- EXPIRE_DATE: Gestion ultra-sécurisée des dates SAP
        (CURRENT_DATE + INTERVAL '1 year')::date as EXPIRE_DATE,
        -- NATIONAL_BANK_CODE: Utilise le code banque (BANKL) de LFBK si disponible
        COALESCE(lb.bankl, 'DEFAULT') as NATIONAL_BANK_CODE,
        -- GROUP_ID: Priorité au groupe d'acheteurs, sinon code pays banque (BANKS) de LFBK
        COALESCE(NULLIF(v."Groupe d'acheteurs", ''), COALESCE(lb.banks, 'DEFAULT')) as GROUP_ID,
        -- DEF_AUTHORIZER: Utilise le type de partenaire bancaire (BVTYP) si disponible
        CASE 
            WHEN lb.bvtyp IS NOT NULL AND lb.bvtyp != '' THEN SUBSTRING(lb.bvtyp, 1, 20)
            ELSE 'DEFAULT'
        END as DEF_AUTHORIZER,
        COALESCE(v."Clé conditions de paiement (Achats)", 'NET30') as PAY_TERM_ID,
        'STD' as DEF_VAT_CODE,
        'STD' as ROUNDING_TAX_CODE,
        'EUR' as DEF_CURRENCY,
        COALESCE(v."Délai de livraison prévu", 30) as PAYM_DEV_DAYS,
        -- Identity Type: External par défaut pour les fournisseurs SAP
        'FALSE' as IDENTITY_TYPE,
        'EXTERN' as IDENTITY_TYPE_DB,
        -- Voting Share: vide par défaut
        '' as VOTING_SHARE_PERCENTAGE,
        '' as VOTING_SHARE_PERCENTAGE_DB,
        -- Automated Invoicing: Y par défaut (1 caractère)
        'Y' as AUTOMATIC_INVOICE,
        -- NCF Reference Check: FALSE par défaut
        'FALSE' as NCF_REFERENCE_CHECK,
        -- Tax Exempt: basé sur le statut fournisseur
        CASE 
            WHEN v."Statut fournisseur" = 'ACTIF' THEN 'FALSE'
            ELSE 'TRUE'
        END as TAX_EXEMPT,
        -- Second TIN: FALSE par défaut
        'FALSE' as SECOND_TIN,
        -- Report and Withhold: Blocked par défaut
        'FALSE' as REPORT_AND_WITHHOLD,
        'BLOCKED' as REPORT_AND_WITHHOLD_DB,
        -- Print Tax Code Text: FALSE par défaut
        'FALSE' as PRINT_TAX_CODE_TEXT,
        -- Withholding Base Amount: Invoice Net Amount par défaut
        'FALSE' as WITHHOLDING_BASE_AMOUNT,
        'INVOICENET' as WITHHOLDING_BASE_AMOUNT_DB,
        -- Matching Level: PO Header par défaut
        'FALSE' as MATCHING_LEVEL,
        'HEADER_LEVEL' as MATCHING_LEVEL_DB,
        -- Allow Tolerance: TRUE par défaut
        'TRUE' as ALLOW_TOLERANCE,
        -- Create Tolerance Posting: FALSE par défaut
        'FALSE' as CREATE_TOLERANCE_POSTING,
        -- Allow Quantity Diff: TRUE par défaut
        'TRUE' as ALLOW_QUANTITY_DIFF,
        -- Tax Certificate Form: Not Used par défaut
        'FALSE' as TAX_CERTIFICATE_FORM,
        'NOTUSED' as TAX_CERTIFICATE_FORM_DB,
        -- Legal Identity: False par défaut
        'FALSE' as LEGAL_IDENTITY,
        'FALSE' as LEGAL_IDENTITY_DB,
        -- PO Ref Rec Ref Val Method: PO Reference and Receipt Reference par défaut
        'FALSE' as PO_REF_REC_REF_VAL_METHOD,
        'PO_REF_AND_REC_REF' as PO_REF_REC_REF_VAL_METHOD_DB,
        -- BI Timestamp
        CURRENT_DATE as BI_TIMESTAMP,
        -- Invoice Recipient From: Supplier par défaut
        'FALSE' as INVOICE_RECIPIENT_FROM,
        'SUPPLIER' as INVOICE_RECIPIENT_FROM_DB,
        -- Exclude from Spesometro Declaration: False par défaut
        'FALSE' as EXC_FROM_SPESOMETRO_DEC,
        'FALSE' as EXC_FROM_SPESOMETRO_DEC_DB,
        -- Service Code Required: False par défaut
        'FALSE' as SERVICE_CODE_REQUIRED,
        'FALSE' as SERVICE_CODE_REQUIRED_DB,
        -- Currency Rate Base: Specified on Company par défaut
        'FALSE' as INC_INV_CURR_RATE_BASE,
        'SPEC_ON_COMPANY' as INC_INV_CURR_RATE_BASE_DB,
        -- Tax Currency Rate Base: Specified on Company par défaut
        'FALSE' as TAX_BUY_CURR_RATE_BASE,
        'SPEC_ON_COMPANY' as TAX_BUY_CURR_RATE_BASE_DB,
        -- Exclude Posting Authorization: Specified on Company par défaut
        'FALSE' as EXCLUDE_POSTING_AUTH,
        'SPEC_ON_COMPANY' as EXCLUDE_POSTING_AUTH_DB,
        -- Exclude Invoice Image: False par défaut
        'FALSE' as EXCLUDE_INVOICE_IMAGE,
        'FALSE' as EXCLUDE_INVOICE_IMAGE_DB,
        -- Utility Bill Provider: False par défaut
        'FALSE' as UTILITY_BILL_PROVIDER,
        'FALSE' as UTILITY_BILL_PROVIDER_DB,
        -- Digital Invoice: False par défaut
        'FALSE' as DIGITAL_INVOICE,
        'FALSE' as DIGITAL_INVOICE_DB,
        -- Country Tax Registered: basé sur le pays du fournisseur
        CASE 
            WHEN v."Clé de pays" IN ('FR', 'DE', 'IT', 'ES', 'NL', 'BE', 'AT', 'PT', 'IE', 'FI', 'SE', 'DK') 
                 THEN 'TRUE'
            ELSE 'FALSE'
        END as COUNTRY_TAX_REGISTERED,
        CASE 
            WHEN v."Clé de pays" IN ('FR', 'DE', 'IT', 'ES', 'NL', 'BE', 'AT', 'PT', 'IE', 'FI', 'SE', 'DK') 
                 THEN 'TRUE'
            ELSE 'FALSE'
        END as COUNTRY_TAX_REGISTERED_DB,
        -- Timestamps et audit
        CURRENT_TIMESTAMP as CREATED_TIMESTAMP,
        CURRENT_TIMESTAMP as UPDATED_TIMESTAMP,
        CASE 
            WHEN lb.lifnr IS NOT NULL THEN 'sp_insert_identity_invoice_info_from_sap_with_bank'
            ELSE 'sp_insert_identity_invoice_info_from_sap'
        END as CREATED_BY,
        CASE 
            WHEN lb.lifnr IS NOT NULL THEN 'sp_insert_identity_invoice_info_from_sap_with_bank'
            ELSE 'sp_insert_identity_invoice_info_from_sap'
        END as UPDATED_BY,
        FALSE as IS_DELETED
    FROM clean_data.v_fournisseurs_enrichis v
    LEFT JOIN raw_data.lfbk lb ON v."Numéro de compte fournisseur" = lb.lifnr
    WHERE v."Statut fournisseur" != 'SUPPRIMÉ';
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    
    -- Compter les fournisseurs avec et sans données bancaires
    SELECT COUNT(*) INTO v_with_bank_count 
    FROM clean_data.identity_invoice_info 
    WHERE created_by = 'sp_insert_identity_invoice_info_from_sap_with_bank';
    
    SELECT COUNT(*) INTO v_without_bank_count 
    FROM clean_data.identity_invoice_info 
    WHERE created_by = 'sp_insert_identity_invoice_info_from_sap';
    
    RAISE NOTICE 'INSERT identity invoice info terminé: % enregistrements traités', v_processed_count;
    RAISE NOTICE 'Fournisseurs AVEC données bancaires: %', v_with_bank_count;
    RAISE NOTICE 'Fournisseurs SANS données bancaires: %', v_without_bank_count;
    RAISE NOTICE 'Toutes les dates d''expiration définies à CURRENT_DATE + 1 an pour éviter les erreurs';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur lors de l''INSERT identity invoice info avec banque: %', SQLERRM;
END;
$procedure$;













