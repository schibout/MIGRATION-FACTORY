CREATE OR REPLACE PROCEDURE clean_data.sp_insert_cus_paym_way_per_ident_from_client_phl()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion moyens de paiement par identité clients PHL - %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    
    TRUNCATE TABLE clean_data.cus_paym_way_per_ident;
    RAISE NOTICE 'Table cus_paym_way_per_ident vidée';
    
    INSERT INTO clean_data.cus_paym_way_per_ident (
        company,
        identity,
        party_type,
        party_type_db,
        way_id,
        default_payment_way
    )
    SELECT DISTINCT ON (cp.customer_id)
        public.get_default_value('clean_data.cus_paym_way_per_ident', 'company', 'TRIMET') as company,
        cp.customer_id as identity,
        public.get_default_value('clean_data.cus_paym_way_per_ident', 'party_type', 'Customer') as party_type,
        public.get_default_value('clean_data.cus_paym_way_per_ident', 'party_type_db', 'CUSTOMER') as party_type_db,
        public.get_default_value('clean_data.cus_paym_way_per_ident', 'way_id', 'SEPA') as way_id,
        public.get_default_value('clean_data.cus_paym_way_per_ident', 'default_payment_way', 'TRUE') as default_payment_way
    FROM raw_data.client_phl cp
    WHERE cp.customer_id IS NOT NULL
    ORDER BY cp.customer_id;
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();
    
    RAISE NOTICE 'INSERT moyens de paiement terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT moyens de paiement depuis client_phl - %: %', 
            TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
