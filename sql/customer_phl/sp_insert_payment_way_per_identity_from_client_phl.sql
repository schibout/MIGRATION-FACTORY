CREATE OR REPLACE PROCEDURE clean_data.sp_insert_payment_way_per_identity_from_client_phl()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion payment way per identity clients PHL - %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.payment_way_per_identity;
    RAISE NOTICE 'Table payment_way_per_identity vidée';
    
    -- Insertion des données PHL
    INSERT INTO clean_data.payment_way_per_identity (
        company,
        identity,
        party_type,
        party_type_db,
        way_id,
        default_payment_way,
        created_timestamp,
        updated_timestamp,
        created_by,
        updated_by,
        is_deleted
    )
    SELECT DISTINCT ON (cp.customer_id)
        public.get_default_value('clean_data.payment_way_per_identity', 'company', 'TRIMET') as company,
        cp.customer_id as identity,
        public.get_default_value('clean_data.payment_way_per_identity', 'party_type', 'Customer', 'CUSTOMER_PHL') as party_type,
        public.get_default_value('clean_data.payment_way_per_identity', 'party_type_db', 'CUSTOMER', 'CUSTOMER_PHL') as party_type_db,
        public.get_default_value('clean_data.payment_way_per_identity', 'way_id', 'BANK_TRANSFER', 'CUSTOMER_PHL') as way_id,
        public.get_default_value('clean_data.payment_way_per_identity', 'default_payment_way', 'TRUE') as default_payment_way,
        CURRENT_TIMESTAMP as created_timestamp,
        CURRENT_TIMESTAMP as updated_timestamp,
        'SYSTEM' as created_by,
        'SYSTEM' as updated_by,
        FALSE as is_deleted
    FROM raw_data.client_phl cp
    WHERE cp.customer_id IS NOT NULL
    ORDER BY cp.customer_id;
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();
    
    RAISE NOTICE 'INSERT payment way per identity terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT payment way per identity depuis client_phl - %: %', 
            TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
