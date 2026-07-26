CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_document_tax_info_from_client_adresse_phl()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion document tax info clients PHL - %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.customer_document_tax_info;
    RAISE NOTICE 'Table customer_document_tax_info vidée';
    
    -- Insertion des données PHL
    INSERT INTO clean_data.customer_document_tax_info (
        CUSTOMER_ID,
        ADDRESS_ID,
        COMPANY,
        SUPPLY_COUNTRY,
        SUPPLY_COUNTRY_DB,
        DELIVERY_COUNTRY,
        DELIVERY_COUNTRY_DB,
        TAX_ID_TYPE,
        VAT_NO,
        VALIDATED_DATE,
        TAX_ID_ERROR_MESSAGE,
        TAX_OFFICE_ID
    )
    SELECT DISTINCT ON (cp.customer_id, cap.address_id, COALESCE(cap.country_db, 'FR'))
        cp.customer_id as CUSTOMER_ID,
        cap.address_id as ADDRESS_ID,
        'TRIMET' as COMPANY,
        NULL as SUPPLY_COUNTRY,
        COALESCE(cap.country_db, 'FR') as SUPPLY_COUNTRY_DB,
        NULL as DELIVERY_COUNTRY,
        COALESCE(cap.country_db, 'FR') as DELIVERY_COUNTRY_DB,
        NULL as TAX_ID_TYPE,
        NULL as VAT_NO,
        NULL as VALIDATED_DATE,
        NULL as TAX_ID_ERROR_MESSAGE,
        NULL as TAX_OFFICE_ID
    FROM raw_data.client_phl cp
    INNER JOIN raw_data.client_adresse_phl cap ON cap.customer_id = cp.customer_id
    WHERE cp.customer_id IS NOT NULL
    AND cap.address_id IS NOT NULL
    ORDER BY cp.customer_id, cap.address_id, COALESCE(cap.country_db, 'FR');
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();
    
    RAISE NOTICE 'INSERT document tax info terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT document tax info depuis client_adresse_phl - %: %', 
            TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
