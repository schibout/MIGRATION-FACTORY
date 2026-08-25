CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_delivery_fee_code_from_client_adresse_phl()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion delivery fee code clients PHL - %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.customer_delivery_fee_code;
    RAISE NOTICE 'Table customer_delivery_fee_code vidée';
    
    -- Insertion des données PHL
    INSERT INTO clean_data.customer_delivery_fee_code (
        customer_id,
        address_id,
        company,
        supply_country,
        fee_code,
        tax_id_number,
        tax_code_selection
    )
    SELECT DISTINCT ON (cp.customer_id, cap.address_id, COALESCE(tc.supply_country, cap.country_db, 'FR'))
        cp.customer_id as customer_id,
        cap.address_id as address_id,
        COALESCE(tc.company, 'TRIMET') as company,
        COALESCE(tc.supply_country, cap.country_db, 'FR') as supply_country,
        COALESCE(tc.fee_code, 'C05') as fee_code,
        tc.tax_id_number as tax_id_number,
        tc.tax_code_selection as tax_code_selection
    FROM raw_data.client_phl cp
    INNER JOIN raw_data.client_adresse_phl cap ON cap.customer_id = cp.customer_id
    LEFT JOIN raw_data.tax_client tc ON tc.customer_id = cp.customer_id AND tc.address_id = cap.address_id
    WHERE cp.customer_id IS NOT NULL
    AND cap.address_id IS NOT NULL
    ORDER BY cp.customer_id, cap.address_id, COALESCE(tc.supply_country, cap.country_db, 'FR');
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();
    
    RAISE NOTICE 'INSERT delivery fee code terminé - %: % enregistrements insérés', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT delivery fee code depuis client_adresse_phl - %: %', 
            TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
