-- Procédure pour insérer les informations de paiement clients depuis le fichier file_customer
-- Utilise clean_data.v_customer_source (fichier + clients PHL absents du fichier) comme table maître

CREATE OR REPLACE PROCEDURE clean_data.sp_insert_cus_identity_pay_info_from_file_customer()
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN

    v_start_time := NOW();
    RAISE NOTICE 'Début insertion infos paiement clients SAP - % - Basé sur file_customer', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');

    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.cus_identity_pay_info;
    RAISE NOTICE 'Table cus_identity_pay_info vidée';

    -- Insertion directe après TRUNCATE
    WITH fc AS (
        -- Source unifiee : fichier + clients PHL absents du fichier.
        -- customer_id et address_id sont deja calcules par la vue.
        SELECT *
        FROM clean_data.v_customer_source
        WHERE customer_id IS NOT NULL
    )
    INSERT INTO clean_data.cus_identity_pay_info (
        company,
        identity,
        party_type,
        party_type_db,
        priority,
        blocked_for_payment,
        other_payee_identity,
        interest_template,
        reminder_template,
        payment_delay,
        amount_tolerance,
        percent_tolerance,
        disc_days_tolerance,
        netting_allowed,
        format_no,
        payment_advice,
        payment_advice_db,
        deduction_group,
        corporation_id,
        member_id,
        send_reminder_to_payer,
        send_interest_inv_to_payer,
        rule_id,
        payment_receipt_type,
        payment_receipt_type_db,
        template_id,
        check_recipient,
        check_recipient_db,
        send_stmt_of_acc_to_payer,
        ar_contact,
        comm_id,
        output_media,
        output_media_db,
        default_payment_method,
        next_payment_matching_id,
        is_one_inv_per_pay,
        is_one_inv_per_pay_db,
        payment_mode,
        payment_mode_db,
        predicted_payment_delay,
        predicted_payment_delay_db,
        business_category
    )
    SELECT DISTINCT ON (fc.bukrs, fc.customer_id)
        'TRIMET' as company,
        fc.customer_id as identity,
        'Customer' as party_type,
        'CUSTOMER' as party_type_db,
        NULL as priority,
        COALESCE(knb1.SPERR, 'FALSE') as blocked_for_payment,
        NULL as other_payee_identity,
        NULL as interest_template,
        '1' as reminder_template,   -- champ obligatoire dans IFS
        NULL as payment_delay,
        NULL as amount_tolerance,
        NULL as percent_tolerance,
        NULL as disc_days_tolerance,
        'FALSE' as netting_allowed,
        NULL as format_no,
        NULL as payment_advice,
        NULL as payment_advice_db,
        NULL as deduction_group,
        NULL as corporation_id,
        NULL as member_id,
        NULL as send_reminder_to_payer,
        NULL as send_interest_inv_to_payer,
        NULL as rule_id,
        -- champ obligatoire dans IFS → valeur neutre NO_RECEIPT
        'No Receipt' as payment_receipt_type,
        'NO_RECEIPT' as payment_receipt_type_db,
        NULL as template_id,
        NULL as check_recipient,
        NULL as check_recipient_db,
        NULL as send_stmt_of_acc_to_payer,
        NULL as ar_contact,
        NULL as comm_id,
        NULL as output_media,
        NULL as output_media_db,
        COALESCE(NULLIF(TRIM(fc.payment_methods),''), knb1.ZWELS, 'TRANSFER') as default_payment_method,
        NULL as next_payment_matching_id,
        NULL as is_one_inv_per_pay,
        NULL as is_one_inv_per_pay_db,
        NULL as payment_mode,
        NULL as payment_mode_db,
        NULL as predicted_payment_delay,
        NULL as predicted_payment_delay_db,
        NULL as business_category
    FROM fc
    LEFT JOIN raw_data.KNB1 knb1
        ON fc.kunnr = knb1.KUNNR
        AND fc.bukrs = knb1.BUKRS
        AND (knb1.LOEVM IS NULL OR knb1.LOEVM = '')
    ORDER BY fc.bukrs, fc.customer_id;

    GET DIAGNOSTICS v_processed_count = ROW_COUNT;

    v_end_time := NOW();
    RAISE NOTICE 'INSERT infos paiement terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));

EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT infos paiement - %: %', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$;
