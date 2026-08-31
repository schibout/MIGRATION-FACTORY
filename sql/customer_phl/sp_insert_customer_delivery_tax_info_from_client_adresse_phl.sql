CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_delivery_tax_info_from_client_adresse_phl()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion delivery tax info clients PHL - %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.customer_delivery_tax_info;
    RAISE NOTICE 'Table customer_delivery_tax_info vidée';
    
    -- Insertion des données PHL
    INSERT INTO clean_data.customer_delivery_tax_info (
        CUSTOMER_ID,
        ADDRESS_ID,
        COMPANY,
        SUPPLY_COUNTRY,
        SUPPLY_COUNTRY_DB,
        CUS_COUNTRY_CODE,
        TAX_LIABILITY,
        TAX_BOOK_ID,
        TAX_BOOK_TYPE,
        TAX_STRUCTURE_ID,
        TAX_CALC_STRUCTURE_ID
    )
    SELECT DISTINCT ON (cp.customer_id, cap.address_id, COALESCE(cap.country_db, 'FR'))
        cp.customer_id as CUSTOMER_ID,
        cap.address_id as ADDRESS_ID,
        public.get_default_value('clean_data.customer_delivery_tax_info', 'company', 'TRIMET') as COMPANY,
        public.get_default_value('clean_data.customer_delivery_tax_info', 'supply_country', NULL) as SUPPLY_COUNTRY,
        COALESCE(cap.country_db, 'FR') as SUPPLY_COUNTRY_DB,
        COALESCE(cap.country_db, 'FR') as CUS_COUNTRY_CODE,
        public.get_default_value('clean_data.customer_delivery_tax_info', 'tax_liability', 'TAX') as TAX_LIABILITY,
        public.get_default_value('clean_data.customer_delivery_tax_info', 'tax_book_id', NULL) as TAX_BOOK_ID,
        public.get_default_value('clean_data.customer_delivery_tax_info', 'tax_book_type', NULL)::numeric as TAX_BOOK_TYPE,
        public.get_default_value('clean_data.customer_delivery_tax_info', 'tax_structure_id', NULL) as TAX_STRUCTURE_ID,
        public.get_default_value('clean_data.customer_delivery_tax_info', 'tax_calc_structure_id', NULL) as TAX_CALC_STRUCTURE_ID
    FROM raw_data.client_phl cp
    INNER JOIN raw_data.client_adresse_phl cap ON cap.customer_id = cp.customer_id
    WHERE cp.customer_id IS NOT NULL
    AND cap.address_id IS NOT NULL
    ORDER BY cp.customer_id, cap.address_id, COALESCE(cap.country_db, 'FR');
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();
    
    RAISE NOTICE 'INSERT delivery tax info terminé - %: % enregistrements insérés', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT delivery tax info depuis client_adresse_phl - %: %', 
            TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
