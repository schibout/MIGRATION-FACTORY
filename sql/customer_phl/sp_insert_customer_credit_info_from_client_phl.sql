CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_credit_info_from_client_phl()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion infos crédit clients PHL - %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.customer_credit_info;
    RAISE NOTICE 'Table customer_credit_info vidée';
    
    -- Insertion des données PHL
    INSERT INTO clean_data.customer_credit_info (
        company,
        identity,
        party_type,
        party_type_db,
        last4q_sales,
        note_text,
        credit_number,
        credit_rating,
        avg_days_for_payment,
        credit_comments,
        credit_analyst_code,
        message_type,
        credit_limit,
        credit_block,
        next_review_date,
        corp_credit_relation_exist,
        credit_relationship_type,
        credit_relationship_type_db,
        parent_company,
        parent_identity,
        allowed_due_days,
        allowed_due_amount
    )
    SELECT DISTINCT ON (cp.customer_id)
        public.get_default_value('clean_data.customer_credit_info', 'company', 'TRIMET') as company,
        cp.customer_id as identity,
        public.get_default_value('clean_data.customer_credit_info', 'party_type', 'Customer') as party_type,
        public.get_default_value('clean_data.customer_credit_info', 'party_type_db', 'CUSTOMER') as party_type_db,
        public.get_default_value('clean_data.customer_credit_info', 'last4q_sales', NULL)::numeric as last4q_sales,
        public.get_default_value('clean_data.customer_credit_info', 'note_text', NULL) as note_text,
        public.get_default_value('clean_data.customer_credit_info', 'credit_number', NULL) as credit_number,
        public.get_default_value('clean_data.customer_credit_info', 'credit_rating', NULL) as credit_rating,
        public.get_default_value('clean_data.customer_credit_info', 'avg_days_for_payment', NULL) as avg_days_for_payment,
        public.get_default_value('clean_data.customer_credit_info', 'credit_comments', NULL) as credit_comments,
        public.get_default_value('clean_data.customer_credit_info', 'credit_analyst_code', NULL) as credit_analyst_code,
        public.get_default_value('clean_data.customer_credit_info', 'message_type', NULL) as message_type,
        public.get_default_value('clean_data.customer_credit_info', 'credit_limit', NULL)::numeric as credit_limit,
        public.get_default_value('clean_data.customer_credit_info', 'credit_block', NULL) as credit_block,
        public.get_default_value('clean_data.customer_credit_info', 'next_review_date', NULL)::date as next_review_date,
        public.get_default_value('clean_data.customer_credit_info', 'corp_credit_relation_exist', NULL) as corp_credit_relation_exist,
        public.get_default_value('clean_data.customer_credit_info', 'credit_relationship_type', NULL) as credit_relationship_type,
        public.get_default_value('clean_data.customer_credit_info', 'credit_relationship_type_db', NULL) as credit_relationship_type_db,
        public.get_default_value('clean_data.customer_credit_info', 'parent_company', NULL) as parent_company,
        public.get_default_value('clean_data.customer_credit_info', 'parent_identity', NULL) as parent_identity,
        public.get_default_value('clean_data.customer_credit_info', 'allowed_due_days', NULL)::numeric as allowed_due_days,
        public.get_default_value('clean_data.customer_credit_info', 'allowed_due_amount', NULL)::numeric as allowed_due_amount
    FROM raw_data.client_phl cp
    WHERE cp.customer_id IS NOT NULL
    ORDER BY cp.customer_id;
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();
    
    RAISE NOTICE 'INSERT infos crédit terminé - %: % enregistrements insérés', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT infos crédit depuis client_phl - %: %', 
            TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
