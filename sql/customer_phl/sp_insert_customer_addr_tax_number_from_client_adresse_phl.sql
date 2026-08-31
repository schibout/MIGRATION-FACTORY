CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_addr_tax_number_from_client_adresse_phl()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion addr tax number clients PHL - %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.CUSTOMER_ADDR_TAX_NUMBER;
    RAISE NOTICE 'Table customer_addr_tax_number vidée';
    
    -- Insertion des données PHL
    INSERT INTO clean_data.CUSTOMER_ADDR_TAX_NUMBER (
        CUSTOMER_ID,
        ADDRESS_ID,
        COMPANY,
        SUPPLY_COUNTRY,
        DELIVERY_COUNTRY,
        TAX_ID_TYPE,
        TAX_ID_NUMBER,
        DEFAULT_TAX_ID_NUMBER,
        DEFAULT_TAX_ID_NUMBER_DB
    )
    SELECT DISTINCT ON (cp.customer_id, cap.address_id, COALESCE(cap.country_db, 'FR'))
        cp.customer_id as CUSTOMER_ID,
        cap.address_id as ADDRESS_ID,
        public.get_default_value('clean_data.customer_addr_tax_number', 'company', 'TRIMET') as COMPANY,
        COALESCE(cap.country_db, 'FR') as SUPPLY_COUNTRY,
        COALESCE(cap.country_db, 'FR') as DELIVERY_COUNTRY,
        public.get_default_value('clean_data.customer_addr_tax_number', 'tax_id_type', '') as TAX_ID_TYPE,
        public.get_default_value('clean_data.customer_addr_tax_number', 'tax_id_number', 'NO_TAX_ID') as TAX_ID_NUMBER,
        public.get_default_value('clean_data.customer_addr_tax_number', 'default_tax_id_number', 'True') as DEFAULT_TAX_ID_NUMBER,
        public.get_default_value('clean_data.customer_addr_tax_number', 'default_tax_id_number_db', 'TRUE') as DEFAULT_TAX_ID_NUMBER_DB
    FROM raw_data.client_phl cp
    INNER JOIN raw_data.client_adresse_phl cap ON cap.customer_id = cp.customer_id
    WHERE cp.customer_id IS NOT NULL
    AND cap.address_id IS NOT NULL
    ORDER BY cp.customer_id, cap.address_id, COALESCE(cap.country_db, 'FR');
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();
    
    RAISE NOTICE 'INSERT addr tax number PHL terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT addr tax number depuis client_adresse_phl - %: %', 
            TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
