-- Procédure pour insérer les informations de crédit clients depuis le fichier file_customer
-- Utilise clean_data.v_customer_source (fichier + clients PHL absents du fichier) comme table maître

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
    SELECT DISTINCT ON (fc.bukrs, fc.customer_id)
        'TRIMET'  as company,
        fc.customer_id as identity,
        'Customer' as party_type,
        'CUSTOMER' as party_type_db,
        NULL as last4q_sales,
        NULL as note_text,
        knb1.KNRZE as credit_number,
        NULL as credit_rating,
        NULL as avg_days_for_payment,
        NULL as credit_comments,
        NULL as credit_analyst_code,
        NULL as message_type,
        NULL as credit_limit,
        knb1.SPERR as credit_block,
        NULL as next_review_date,
        NULL as corp_credit_relation_exist,
        NULL as credit_relationship_type,
        NULL as credit_relationship_type_db,
        NULL as parent_company,
        NULL as parent_identity,
        NULL as allowed_due_days,
        NULL as allowed_due_amount
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
$procedure$;
