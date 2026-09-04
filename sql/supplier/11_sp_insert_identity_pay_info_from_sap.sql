CREATE OR REPLACE PROCEDURE clean_data.sp_insert_identity_pay_info_from_sap()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    RAISE NOTICE '=== DÉBUT INSERTION IDENTITY_PAY_INFO ===';
    RAISE NOTICE 'Heure de début: %', v_start_time;
    
    -- Note: Utilisation de TRUNCATE puis INSERT pour vider et réinsérer toutes les données
    RAISE NOTICE 'Début de l''insertion avec TRUNCATE puis INSERT';
    
    -- Créer une table temporaire pour dédupliquer les données avec ROW_NUMBER
    CREATE TEMP TABLE temp_identity_pay_info AS
    SELECT 
        COMPANY,
        IDENTITY,
        PARTY_TYPE,
        PARTY_TYPE_DB,
        PRIORITY,
        BLOCKED_FOR_PAYMENT,
        OTHER_PAYEE_IDENTITY,
        INTEREST_TEMPLATE,
        REMINDER_TEMPLATE,
        PAYMENT_DELAY,
        AMOUNT_TOLERANCE,
        PERCENT_TOLERANCE,
        DISC_DAYS_TOLERANCE,
        NETTING_ALLOWED,
        FORMAT_NO,
        PAYMENT_ADVICE,
        PAYMENT_ADVICE_DB,
        DEDUCTION_GROUP,
        CORPORATION_ID,
        MEMBER_ID,
        SEND_REMINDER_TO_PAYER,
        SEND_INTEREST_INV_TO_PAYER,
        RULE_ID,
        PAYMENT_RECEIPT_TYPE,
        PAYMENT_RECEIPT_TYPE_DB,
        TEMPLATE_ID,
        CHECK_RECIPIENT,
        CHECK_RECIPIENT_DB,
        SEND_STMT_OF_ACC_TO_PAYER,
        AR_CONTACT,
        COMM_ID,
        OUTPUT_MEDIA,
        OUTPUT_MEDIA_DB,
        DEFAULT_PAYMENT_METHOD,
        CUSTOMER_ID,
        SUPPLIER_ID,
        NEXT_PAYMENT_MATCHING_ID,
        IS_ONE_INV_PER_PAY,
        IS_ONE_INV_PER_PAY_DB,
        PAYMENT_MODE,
        PAYMENT_MODE_DB,
        PREDICTED_PAYMENT_DELAY,
        PREDICTED_PAYMENT_DELAY_DB,
        BUSINESS_CATEGORY
    FROM (
        SELECT 
            COALESCE(f.company, 'TRIMET') as COMPANY,
            -- IDENTITY / SUPPLIER_ID = numéro IFS du fichier (voir script 02).
            f.numero_compte_ifs as IDENTITY,
            public.get_default_value('clean_data.identity_pay_info', 'party_type') as PARTY_TYPE,
            public.get_default_value('clean_data.identity_pay_info', 'party_type_db') as PARTY_TYPE_DB,
            public.get_default_value('clean_data.identity_pay_info', 'priority')::numeric as PRIORITY,
            CASE
                WHEN COALESCE(b.sperr, '') != '' OR COALESCE(m.sperm, '') != '' THEN 'TRUE'
                ELSE 'FALSE'
            END as BLOCKED_FOR_PAYMENT,
            public.get_default_value('clean_data.identity_pay_info', 'other_payee_identity') as OTHER_PAYEE_IDENTITY,
            public.get_default_value('clean_data.identity_pay_info', 'interest_template') as INTEREST_TEMPLATE,
            public.get_default_value('clean_data.identity_pay_info', 'reminder_template') as REMINDER_TEMPLATE,
            COALESCE(m.plifz::numeric, 30) as PAYMENT_DELAY,
            COALESCE(m.minbw::numeric, 100) as AMOUNT_TOLERANCE,
            public.get_default_value('clean_data.identity_pay_info', 'percent_tolerance')::numeric as PERCENT_TOLERANCE,
            public.get_default_value('clean_data.identity_pay_info', 'disc_days_tolerance')::numeric as DISC_DAYS_TOLERANCE,
            public.get_default_value('clean_data.identity_pay_info', 'netting_allowed') as NETTING_ALLOWED,
            public.get_default_value('clean_data.identity_pay_info', 'format_no')::numeric as FORMAT_NO,
            public.get_default_value('clean_data.identity_pay_info', 'payment_advice') as PAYMENT_ADVICE,
            public.get_default_value('clean_data.identity_pay_info', 'payment_advice_db') as PAYMENT_ADVICE_DB,
            public.get_default_value('clean_data.identity_pay_info', 'deduction_group') as DEDUCTION_GROUP,
            public.get_default_value('clean_data.identity_pay_info', 'corporation_id') as CORPORATION_ID,
            public.get_default_value('clean_data.identity_pay_info', 'member_id') as MEMBER_ID,
            public.get_default_value('clean_data.identity_pay_info', 'send_reminder_to_payer') as SEND_REMINDER_TO_PAYER,
            public.get_default_value('clean_data.identity_pay_info', 'send_interest_inv_to_payer') as SEND_INTEREST_INV_TO_PAYER,
            public.get_default_value('clean_data.identity_pay_info', 'rule_id') as RULE_ID,
            public.get_default_value('clean_data.identity_pay_info', 'payment_receipt_type') as PAYMENT_RECEIPT_TYPE,
            public.get_default_value('clean_data.identity_pay_info', 'payment_receipt_type_db') as PAYMENT_RECEIPT_TYPE_DB,
            public.get_default_value('clean_data.identity_pay_info', 'template_id') as TEMPLATE_ID,
            public.get_default_value('clean_data.identity_pay_info', 'check_recipient') as CHECK_RECIPIENT,
            public.get_default_value('clean_data.identity_pay_info', 'check_recipient_db') as CHECK_RECIPIENT_DB,
            public.get_default_value('clean_data.identity_pay_info', 'send_stmt_of_acc_to_payer') as SEND_STMT_OF_ACC_TO_PAYER,
            public.get_default_value('clean_data.identity_pay_info', 'ar_contact') as AR_CONTACT,
            public.get_default_value('clean_data.identity_pay_info', 'comm_id')::numeric as COMM_ID,
            public.get_default_value('clean_data.identity_pay_info', 'output_media') as OUTPUT_MEDIA,
            public.get_default_value('clean_data.identity_pay_info', 'output_media_db') as OUTPUT_MEDIA_DB,
            public.get_default_value('clean_data.identity_pay_info', 'default_payment_method') as DEFAULT_PAYMENT_METHOD,
            public.get_default_value('clean_data.identity_pay_info', 'customer_id') as CUSTOMER_ID,
            f.numero_compte_ifs as SUPPLIER_ID,
            public.get_default_value('clean_data.identity_pay_info', 'next_payment_matching_id')::numeric as NEXT_PAYMENT_MATCHING_ID,
            public.get_default_value('clean_data.identity_pay_info', 'is_one_inv_per_pay') as IS_ONE_INV_PER_PAY,
            public.get_default_value('clean_data.identity_pay_info', 'is_one_inv_per_pay_db') as IS_ONE_INV_PER_PAY_DB,
            public.get_default_value('clean_data.identity_pay_info', 'payment_mode') as PAYMENT_MODE,
            public.get_default_value('clean_data.identity_pay_info', 'payment_mode_db') as PAYMENT_MODE_DB,
            public.get_default_value('clean_data.identity_pay_info', 'predicted_payment_delay') as PREDICTED_PAYMENT_DELAY,
            public.get_default_value('clean_data.identity_pay_info', 'predicted_payment_delay_db') as PREDICTED_PAYMENT_DELAY_DB,
            public.get_default_value('clean_data.identity_pay_info', 'business_category') as BUSINESS_CATEGORY,
            ROW_NUMBER() OVER (
                PARTITION BY 
                    COALESCE(f.company, 'TRIMET'), 
                    f.numero_compte_fournisseur, 
                    'SUPPLIER'
                ORDER BY f.numero_compte_fournisseur
            ) as rn
        FROM clean_data.ifs_fournisseurs f
        LEFT JOIN raw_data.lfb1 b ON f.numero_compte_fournisseur = b.lifnr
        LEFT JOIN raw_data.lfm1 m ON f.numero_compte_fournisseur = m.lifnr 
            AND m.ekorg = f.organisation_achats
    ) ranked_data
    WHERE rn = 1;
    
    RAISE NOTICE 'Table temporaire créée avec % enregistrements', (SELECT COUNT(*) FROM temp_identity_pay_info);
    
    -- Vider la table avant insertion (TRUNCATE supprime toutes les données)
    TRUNCATE TABLE clean_data.IDENTITY_PAY_INFO;
    RAISE NOTICE 'Table IDENTITY_PAY_INFO vidée';
    
    -- Insertion depuis la table temporaire vers la table finale
    INSERT INTO clean_data.IDENTITY_PAY_INFO (
        COMPANY,
        IDENTITY,
        PARTY_TYPE,
        PARTY_TYPE_DB,
        PRIORITY,
        BLOCKED_FOR_PAYMENT,
        OTHER_PAYEE_IDENTITY,
        INTEREST_TEMPLATE,
        REMINDER_TEMPLATE,
        PAYMENT_DELAY,
        AMOUNT_TOLERANCE,
        PERCENT_TOLERANCE,
        DISC_DAYS_TOLERANCE,
        NETTING_ALLOWED,
        FORMAT_NO,
        PAYMENT_ADVICE,
        PAYMENT_ADVICE_DB,
        DEDUCTION_GROUP,
        CORPORATION_ID,
        MEMBER_ID,
        SEND_REMINDER_TO_PAYER,
        SEND_INTEREST_INV_TO_PAYER,
        RULE_ID,
        PAYMENT_RECEIPT_TYPE,
        PAYMENT_RECEIPT_TYPE_DB,
        TEMPLATE_ID,
        CHECK_RECIPIENT,
        CHECK_RECIPIENT_DB,
        SEND_STMT_OF_ACC_TO_PAYER,
        AR_CONTACT,
        COMM_ID,
        OUTPUT_MEDIA,
        OUTPUT_MEDIA_DB,
        DEFAULT_PAYMENT_METHOD,
        CUSTOMER_ID,
        SUPPLIER_ID,
        NEXT_PAYMENT_MATCHING_ID,
        IS_ONE_INV_PER_PAY,
        IS_ONE_INV_PER_PAY_DB,
        PAYMENT_MODE,
        PAYMENT_MODE_DB,
        PREDICTED_PAYMENT_DELAY,
        PREDICTED_PAYMENT_DELAY_DB,
        BUSINESS_CATEGORY
    )
    SELECT 
        COMPANY,
        IDENTITY,
        PARTY_TYPE,
        PARTY_TYPE_DB,
        PRIORITY,
        BLOCKED_FOR_PAYMENT,
        OTHER_PAYEE_IDENTITY,
        INTEREST_TEMPLATE,
        REMINDER_TEMPLATE,
        PAYMENT_DELAY,
        AMOUNT_TOLERANCE,
        PERCENT_TOLERANCE,
        DISC_DAYS_TOLERANCE,
        NETTING_ALLOWED,
        FORMAT_NO,
        PAYMENT_ADVICE,
        PAYMENT_ADVICE_DB,
        DEDUCTION_GROUP,
        CORPORATION_ID,
        MEMBER_ID,
        SEND_REMINDER_TO_PAYER,
        SEND_INTEREST_INV_TO_PAYER,
        RULE_ID,
        PAYMENT_RECEIPT_TYPE,
        PAYMENT_RECEIPT_TYPE_DB,
        TEMPLATE_ID,
        CHECK_RECIPIENT,
        CHECK_RECIPIENT_DB,
        SEND_STMT_OF_ACC_TO_PAYER,
        AR_CONTACT,
        COMM_ID,
        OUTPUT_MEDIA,
        OUTPUT_MEDIA_DB,
        DEFAULT_PAYMENT_METHOD,
        CUSTOMER_ID,
        SUPPLIER_ID,
        NEXT_PAYMENT_MATCHING_ID,
        IS_ONE_INV_PER_PAY,
        IS_ONE_INV_PER_PAY_DB,
        PAYMENT_MODE,
        PAYMENT_MODE_DB,
        PREDICTED_PAYMENT_DELAY,
        PREDICTED_PAYMENT_DELAY_DB,
        BUSINESS_CATEGORY
    FROM temp_identity_pay_info;
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== INSERTION IDENTITY_PAY_INFO TERMINÉE ===';
    RAISE NOTICE 'Durée: % secondes', EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time));
    RAISE NOTICE 'Total enregistrements insérés: %', v_processed_count;
    RAISE NOTICE '';
    RAISE NOTICE '=== STATISTIQUES BLOCAGES PAIEMENT ===';
    RAISE NOTICE 'Fournisseurs bloqués pour paiement: %', 
        (SELECT COUNT(*) FROM clean_data.identity_pay_info WHERE blocked_for_payment = 'TRUE');
    RAISE NOTICE 'Fournisseurs non bloqués: %', 
        (SELECT COUNT(*) FROM clean_data.identity_pay_info WHERE blocked_for_payment = 'FALSE');
    RAISE NOTICE '';
    RAISE NOTICE '=== STATISTIQUES PAR SOCIÉTÉ ===';
    RAISE NOTICE 'Répartition: %', 
        (SELECT STRING_AGG(company || '=' || count_records::text, ', ') 
         FROM (SELECT company, COUNT(*) as count_records 
               FROM clean_data.identity_pay_info 
               GROUP BY company) company_stats);
    
    -- Nettoyer la table temporaire
    DROP TABLE IF EXISTS temp_identity_pay_info;
    RAISE NOTICE 'Table temporaire nettoyée';
    
EXCEPTION
    WHEN OTHERS THEN
        -- Nettoyer la table temporaire en cas d'erreur
        DROP TABLE IF EXISTS temp_identity_pay_info;
        RAISE EXCEPTION 'Erreur lors de l''INSERT identity pay info: %', SQLERRM;
END;
$procedure$
;
