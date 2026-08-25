CREATE OR REPLACE PROCEDURE clean_data.sp_insert_payment_way_per_identity_from_sap(IN p_client character varying DEFAULT '100'::character varying)
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
BEGIN
    
    RAISE NOTICE 'Début insertion payment way per identity SAP - Client: %', p_client;
    
    -- Insertion avec UPSERT
    INSERT INTO clean_data.PAYMENT_WAY_PER_IDENTITY (
        COMPANY,
        IDENTITY,
        PARTY_TYPE,
        PARTY_TYPE_DB,
        WAY_ID,
        DEFAULT_PAYMENT_WAY,
        VALID_FROM,
        VALID_TO,
        IS_ACTIVE,
        CREATED_AT,
        UPDATED_AT
    )
    SELECT 
        'TRIMET' as COMPANY,
        TRIM(k.KUNNR) as IDENTITY,
        'Customer' as PARTY_TYPE,
        'CUSTOMER' as PARTY_TYPE_DB,
        COALESCE(kb.ZTERM, 'BANK_TRANSFER') as WAY_ID,
        'TRUE' as DEFAULT_PAYMENT_WAY,
        TO_DATE(k.ERDAT, 'YYYYMMDD') as VALID_FROM,
        NULL as VALID_TO,
        TRUE as IS_ACTIVE,
        CURRENT_TIMESTAMP as CREATED_AT,
        CURRENT_TIMESTAMP as UPDATED_AT
    FROM raw_data.KNA1 k
    LEFT JOIN raw_data.KNB1 kb ON k.KUNNR = kb.KUNNR AND kb.MANDT = p_client
    WHERE k.MANDT = p_client
    AND (k.LOEVM IS NULL OR k.LOEVM = '')
    
    ON CONFLICT (COMPANY, IDENTITY, PARTY_TYPE_DB, WAY_ID, DEFAULT_PAYMENT_WAY) 
    DO UPDATE SET
        VALID_FROM = EXCLUDED.VALID_FROM,
        VALID_TO = EXCLUDED.VALID_TO,
        IS_ACTIVE = EXCLUDED.IS_ACTIVE,
        UPDATED_AT = CURRENT_TIMESTAMP;
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    
    RAISE NOTICE 'UPSERT payment way per identity terminé: % enregistrements traités', v_processed_count;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur lors de l''UPSERT payment way per identity: %', SQLERRM;
END;
$procedure$
