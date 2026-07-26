CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_tax_info_from_client_adresse_phl()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion tax info clients PHL - %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.CUSTOMER_TAX_INFO;
    RAISE NOTICE 'Table customer_tax_info vidée';
    
    -- Insertion des données PHL
    INSERT INTO clean_data.CUSTOMER_TAX_INFO (
        CUSTOMER_ID,
        ADDRESS_ID,
        COMPANY,
        TAX_WITHHOLDING,
        TAX_WITHHOLDING_DB,
        TAX_ROUNDING_METHOD,
        TAX_ROUNDING_METHOD_DB,
        TAX_ROUNDING_LEVEL,
        TAX_ROUNDING_LEVEL_DB,
        WITHHOLDING_BASE_AMOUNT,
        WITHHOLDING_BASE_AMOUNT_DB,
        TAX_EXEMPT,
        TAX_EXEMPT_DB,
        TAX_EXEMPT_VALID_FROM,
        TAX_EXEMPT_VALID_TO,
        TAX_OFFICE_ID,
        FISCAL_NO,
        EXC_FROM_SPESOMETRO_DEC,
        EXC_FROM_SPESOMETRO_DEC_DB,
        ICMS_TAX_PAYER,
        ICMS_TAX_PAYER_DB,
        PERMANENT_ESTABLISHMENT,
        PERMANENT_ESTABLISHMENT_DB,
        OUT_INV_VOU_DATE_BASE,
        OUT_INV_VOU_DATE_BASE_DB,
        OUT_INV_CURR_RATE_BASE,
        OUT_INV_CURR_RATE_BASE_DB,
        TAX_SELL_CURR_RATE_BASE,
        TAX_SELL_CURR_RATE_BASE_DB,
        ENABLE_FOR_TCS,
        ENABLE_FOR_TCS_DB,
        BUSINESS_TRANSACTION_ID,
        COMPONENT_A,
        COMPONENT_A_IDENTITY
    )
    SELECT DISTINCT ON (cp.customer_id, cap.address_id)
        cp.customer_id as CUSTOMER_ID,
        cap.address_id as ADDRESS_ID,
        'TRIMET' as COMPANY,
        'Blocked' as TAX_WITHHOLDING,
        'BLOCKED' as TAX_WITHHOLDING_DB,
        'Round to the Nearest' as TAX_ROUNDING_METHOD,
        'ROUND_NEAREST' as TAX_ROUNDING_METHOD_DB,
        'Line Level' as TAX_ROUNDING_LEVEL,
        'LINE_LEVEL' as TAX_ROUNDING_LEVEL_DB,
        'Invoice Net Amount' as WITHHOLDING_BASE_AMOUNT,
        'INVOICENET' as WITHHOLDING_BASE_AMOUNT_DB,
        'False' as TAX_EXEMPT,
        'FALSE' as TAX_EXEMPT_DB,
        NULL as TAX_EXEMPT_VALID_FROM,
        NULL as TAX_EXEMPT_VALID_TO,
        NULL as TAX_OFFICE_ID,
        NULL as FISCAL_NO,
        'False' as EXC_FROM_SPESOMETRO_DEC,
        'FALSE' as EXC_FROM_SPESOMETRO_DEC_DB,
        'False' as ICMS_TAX_PAYER,
        'FALSE' as ICMS_TAX_PAYER_DB,
        'False' as PERMANENT_ESTABLISHMENT,
        'FALSE' as PERMANENT_ESTABLISHMENT_DB,
        'Invoice Date' as OUT_INV_VOU_DATE_BASE,
        'INVOICE_DATE' as OUT_INV_VOU_DATE_BASE_DB,
        'Invoice Date' as OUT_INV_CURR_RATE_BASE,
        'INVOICE_DATE' as OUT_INV_CURR_RATE_BASE_DB,
        'Invoice Date' as TAX_SELL_CURR_RATE_BASE,
        'INVOICE_DATE' as TAX_SELL_CURR_RATE_BASE_DB,
        'False' as ENABLE_FOR_TCS,
        'FALSE' as ENABLE_FOR_TCS_DB,
        NULL as BUSINESS_TRANSACTION_ID,
        NULL as COMPONENT_A,
        NULL as COMPONENT_A_IDENTITY
    FROM raw_data.client_phl cp
    INNER JOIN raw_data.client_adresse_phl cap ON cap.customer_id = cp.customer_id
    WHERE cp.customer_id IS NOT NULL
    AND cap.address_id IS NOT NULL
    ORDER BY cp.customer_id, cap.address_id;
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();
    
    RAISE NOTICE 'INSERT tax info terminé - %: % enregistrements insérés', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT tax info depuis client_adresse_phl - %: %', 
            TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
