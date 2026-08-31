CREATE OR REPLACE PROCEDURE clean_data.sp_insert_cus_identity_pay_info_from_client_phl()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion infos paiement clients PHL - %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.cus_identity_pay_info;
    RAISE NOTICE 'Table cus_identity_pay_info vidée';
    
    -- Insertion des données PHL
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
    SELECT DISTINCT ON (cp.customer_id)
        public.get_default_value('clean_data.cus_identity_pay_info', 'company', 'TRIMET') as company,
        cp.customer_id as identity,
        public.get_default_value('clean_data.cus_identity_pay_info', 'party_type', 'Customer') as party_type,
        public.get_default_value('clean_data.cus_identity_pay_info', 'party_type_db', 'CUSTOMER') as party_type_db,
        public.get_default_value('clean_data.cus_identity_pay_info', 'priority', NULL)::numeric as priority,
        public.get_default_value('clean_data.cus_identity_pay_info', 'blocked_for_payment', 'FALSE') as blocked_for_payment,
        public.get_default_value('clean_data.cus_identity_pay_info', 'other_payee_identity', NULL) as other_payee_identity,
        public.get_default_value('clean_data.cus_identity_pay_info', 'interest_template', NULL) as interest_template,
        public.get_default_value('clean_data.cus_identity_pay_info', 'reminder_template', '0', 'CUSTOMER_PHL') as reminder_template,
        public.get_default_value('clean_data.cus_identity_pay_info', 'payment_delay', NULL)::numeric as payment_delay,
        public.get_default_value('clean_data.cus_identity_pay_info', 'amount_tolerance', NULL)::numeric as amount_tolerance,
        public.get_default_value('clean_data.cus_identity_pay_info', 'percent_tolerance', NULL)::numeric as percent_tolerance,
        public.get_default_value('clean_data.cus_identity_pay_info', 'disc_days_tolerance', NULL)::numeric as disc_days_tolerance,
        public.get_default_value('clean_data.cus_identity_pay_info', 'netting_allowed', 'FALSE') as netting_allowed,
        public.get_default_value('clean_data.cus_identity_pay_info', 'format_no', NULL)::numeric as format_no,
        public.get_default_value('clean_data.cus_identity_pay_info', 'payment_advice', NULL) as payment_advice,
        public.get_default_value('clean_data.cus_identity_pay_info', 'payment_advice_db', NULL) as payment_advice_db,
        public.get_default_value('clean_data.cus_identity_pay_info', 'deduction_group', NULL) as deduction_group,
        public.get_default_value('clean_data.cus_identity_pay_info', 'corporation_id', NULL) as corporation_id,
        public.get_default_value('clean_data.cus_identity_pay_info', 'member_id', NULL) as member_id,
        public.get_default_value('clean_data.cus_identity_pay_info', 'send_reminder_to_payer', NULL) as send_reminder_to_payer,
        public.get_default_value('clean_data.cus_identity_pay_info', 'send_interest_inv_to_payer', NULL) as send_interest_inv_to_payer,
        public.get_default_value('clean_data.cus_identity_pay_info', 'rule_id', NULL) as rule_id,
        public.get_default_value('clean_data.cus_identity_pay_info', 'payment_receipt_type', NULL, 'CUSTOMER_PHL') as payment_receipt_type,
        public.get_default_value('clean_data.cus_identity_pay_info', 'payment_receipt_type_db', 'NO_RECEIPT', 'CUSTOMER_PHL') as payment_receipt_type_db,
        public.get_default_value('clean_data.cus_identity_pay_info', 'template_id', NULL) as template_id,
        public.get_default_value('clean_data.cus_identity_pay_info', 'check_recipient', NULL) as check_recipient,
        public.get_default_value('clean_data.cus_identity_pay_info', 'check_recipient_db', NULL) as check_recipient_db,
        public.get_default_value('clean_data.cus_identity_pay_info', 'send_stmt_of_acc_to_payer', NULL) as send_stmt_of_acc_to_payer,
        public.get_default_value('clean_data.cus_identity_pay_info', 'ar_contact', NULL) as ar_contact,
        public.get_default_value('clean_data.cus_identity_pay_info', 'comm_id', NULL)::numeric as comm_id,
        public.get_default_value('clean_data.cus_identity_pay_info', 'output_media', NULL) as output_media,
        public.get_default_value('clean_data.cus_identity_pay_info', 'output_media_db', NULL) as output_media_db,
        public.get_default_value('clean_data.cus_identity_pay_info', 'default_payment_method', 'TRANSFER') as default_payment_method,
        public.get_default_value('clean_data.cus_identity_pay_info', 'next_payment_matching_id', NULL)::numeric as next_payment_matching_id,
        public.get_default_value('clean_data.cus_identity_pay_info', 'is_one_inv_per_pay', NULL) as is_one_inv_per_pay,
        public.get_default_value('clean_data.cus_identity_pay_info', 'is_one_inv_per_pay_db', NULL) as is_one_inv_per_pay_db,
        public.get_default_value('clean_data.cus_identity_pay_info', 'payment_mode', NULL) as payment_mode,
        public.get_default_value('clean_data.cus_identity_pay_info', 'payment_mode_db', NULL) as payment_mode_db,
        public.get_default_value('clean_data.cus_identity_pay_info', 'predicted_payment_delay', NULL) as predicted_payment_delay,
        public.get_default_value('clean_data.cus_identity_pay_info', 'predicted_payment_delay_db', NULL) as predicted_payment_delay_db,
        public.get_default_value('clean_data.cus_identity_pay_info', 'business_category', NULL) as business_category
    FROM raw_data.client_phl cp
    WHERE cp.customer_id IS NOT NULL
    ORDER BY cp.customer_id;
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();
    
    RAISE NOTICE 'INSERT infos paiement terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT infos paiement depuis client_phl - %: %', 
            TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
