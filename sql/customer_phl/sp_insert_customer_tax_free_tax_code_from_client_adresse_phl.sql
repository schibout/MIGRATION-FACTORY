CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_tax_free_tax_code_from_client_adresse_phl()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion tax free code clients PHL - %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.CUSTOMER_TAX_FREE_TAX_CODE;
    RAISE NOTICE 'Table customer_tax_free_tax_code vidée';
    
    -- Insertion des données PHL
    INSERT INTO clean_data.CUSTOMER_TAX_FREE_TAX_CODE (
        CUSTOMER_ID,
        ADDRESS_ID,
        COMPANY,
        SUPPLY_COUNTRY,
        DELIVERY_TYPE,
        VAT_FREE_VAT_CODE
    )
    SELECT DISTINCT ON (cp.customer_id, cap.address_id)
        cp.customer_id as CUSTOMER_ID,
        cap.address_id as ADDRESS_ID,
        'TRIMET' as COMPANY,
        COALESCE(cap.country_db, 'FR') as SUPPLY_COUNTRY,
        'Delivery Type' as DELIVERY_TYPE,
        NULL as VAT_FREE_VAT_CODE
    FROM raw_data.client_phl cp
    INNER JOIN raw_data.client_adresse_phl cap ON cap.customer_id = cp.customer_id
    WHERE cp.customer_id IS NOT NULL
    AND cap.address_id IS NOT NULL
    ORDER BY cp.customer_id, cap.address_id;
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();
    
    RAISE NOTICE 'INSERT tax free code terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT tax free code depuis client_adresse_phl - %: %', 
            TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
