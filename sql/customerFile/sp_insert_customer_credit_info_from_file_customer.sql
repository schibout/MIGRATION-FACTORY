CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_credit_info_from_file_customer()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN

    v_start_time := NOW();
    RAISE NOTICE 'Début insertion infos crédit clients SAP - % - Basé sur file_customer', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');

    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.customer_credit_info;
    RAISE NOTICE 'Table customer_credit_info vidée';

    -- Insertion directe après TRUNCATE
    WITH fc AS (
        -- Source unifiee : fichier + clients PHL absents du fichier.
        -- customer_id et address_id sont deja calcules par la vue.
        SELECT *
        FROM clean_data.v_customer_source
        WHERE customer_id IS NOT NULL
    )
    INSERT INTO clean_data.customer_credit_info (
        company,
        identity,
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
        credit_relationship_type_db,
        parent_company,
        parent_identity,
        allowed_due_days,
        allowed_due_amount
    )
    SELECT DISTINCT ON (fc.bukrs, fc.customer_id)
        public.get_default_value('clean_data.customer_credit_info', 'company')  as company,
        fc.customer_id as identity,
        public.get_default_value('clean_data.customer_credit_info', 'party_type_db') as party_type_db,
        public.get_default_value('clean_data.customer_credit_info', 'last4q_sales')::numeric as last4q_sales,
        public.get_default_value('clean_data.customer_credit_info', 'note_text') as note_text,
        knb1.KNRZE as credit_number,
        public.get_default_value('clean_data.customer_credit_info', 'credit_rating') as credit_rating,
        public.get_default_value('clean_data.customer_credit_info', 'avg_days_for_payment') as avg_days_for_payment,
        public.get_default_value('clean_data.customer_credit_info', 'credit_comments') as credit_comments,
        public.get_default_value('clean_data.customer_credit_info', 'credit_analyst_code') as credit_analyst_code,
        public.get_default_value('clean_data.customer_credit_info', 'message_type') as message_type,
        public.get_default_value('clean_data.customer_credit_info', 'credit_limit')::numeric as credit_limit,
        knb1.SPERR as credit_block,
        public.get_default_value('clean_data.customer_credit_info', 'next_review_date')::date as next_review_date,
        public.get_default_value('clean_data.customer_credit_info', 'corp_credit_relation_exist') as corp_credit_relation_exist,
        public.get_default_value('clean_data.customer_credit_info', 'credit_relationship_type_db') as credit_relationship_type_db,
        public.get_default_value('clean_data.customer_credit_info', 'parent_company') as parent_company,
        public.get_default_value('clean_data.customer_credit_info', 'parent_identity') as parent_identity,
        public.get_default_value('clean_data.customer_credit_info', 'allowed_due_days')::numeric as allowed_due_days,
        public.get_default_value('clean_data.customer_credit_info', 'allowed_due_amount')::numeric as allowed_due_amount
    FROM fc
    LEFT JOIN raw_data.KNB1 knb1
        ON fc.kunnr = knb1.KUNNR
        AND (knb1.LOEVM IS NULL OR knb1.LOEVM = '')
    ORDER BY fc.bukrs, fc.customer_id;

    GET DIAGNOSTICS v_processed_count = ROW_COUNT;

    v_end_time := NOW();
    RAISE NOTICE 'INSERT infos crédit terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));

EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT infos crédit - %: %', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
