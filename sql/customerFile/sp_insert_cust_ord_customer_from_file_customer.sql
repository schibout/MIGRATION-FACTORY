CREATE OR REPLACE PROCEDURE clean_data.sp_insert_cust_ord_customer_from_file_customer()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion cust ord customer file_customer - %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');

    TRUNCATE TABLE clean_data.cust_ord_customer;
    RAISE NOTICE 'Table cust_ord_customer vidée';

    INSERT INTO clean_data.cust_ord_customer (
        customer_no,
        cust_grp,
        cycle_period,
        currency_code,
        category_db,
        customer_no_pay,
        cust_price_group_id,
        salesman_code,
        market_code,
        print_control_code,
        cr_stop_db,
        cust_ref,
        date_del,
        invoice_sort_db,
        last_ivc_date,
        note_text,
        order_conf_flag_db,
        pack_list_flag_db,
        acquisition_site,
        order_id,
        edi_auto_order_approval_db,
        edi_auto_change_approval_db,
        edi_authorize_code,
        edi_site,
        edi_auto_approval_user,
        template_id,
        discount,
        discount_type,
        min_sales_amount,
        note_id,
        template_customer_desc,
        template_customer_db,
        quick_registered_customer_db,
        commission_receiver_db,
        no_delnote_copies,
        forward_agent_id,
        auto_despatch_adv_send,
        mul_tier_del_notification_db,
        match_type_db,
        print_amounts_incl_tax_db,
        confirm_deliveries_db,
        check_sales_grp_deliv_conf_db,
        handl_unit_at_co_delivery_db,
        update_price_from_sbi_db,
        rec_adv_auto_match_diff_db,
        rec_adv_auto_matching_db,
        rec_adv_matching_option_db,
        receiving_advice_type_db,
        self_billing_match_option_db,
        sbi_auto_approval_user,
        rec_adv_auto_approval_user,
        adv_inv_full_pay_db,
        release_internal_order_db,
        credit_control_group_id,
        backorder_option_db,
        priority,
        receive_pack_size_chg_db,
        summarized_freight_charges_db,
        print_delivered_lines_db,
        email_order_conf_db,
        email_invoice_db,
        allow_auto_sub_of_parts_db,
        b2b_auto_create_co_from_sq_db,
        print_withholding_tax_db,
        consol_rental_ivc_serial_db,
        exclude_from_scan_order,
        default_inv_currency,
        confirm_direct_deliveries,
        summarized_source_lines_db,
        send_change_message_db,
        replicate_doc_text_db,
        -- colonnes affichage
        cr_stop,
        invoice_sort,
        order_conf_flag,
        pack_list_flag,
        category,
        edi_auto_order_approval,
        edi_auto_change_approval,
        template_customer,
        quick_registered_customer,
        commission_receiver,
        summarized_source_lines,
        send_change_message,
        replicate_doc_text,
        mul_tier_del_notification,
        match_type,
        print_amounts_incl_tax,
        confirm_deliveries,
        check_sales_grp_deliv_conf,
        handl_unit_at_co_delivery,
        update_price_from_sbi,
        rec_adv_auto_match_diff,
        rec_adv_auto_matching,
        rec_adv_matching_option,
        receiving_advice_type,
        self_billing_match_option,
        adv_inv_full_pay,
        release_internal_order,
        backorder_option,
        receive_pack_size_chg,
        summarized_freight_charges,
        print_delivered_lines,
        email_order_conf,
        email_invoice,
        allow_auto_sub_of_parts,
        b2b_auto_create_co_from_sq,
        print_withholding_tax,
        consol_rental_ivc_serial,
        name
    )
    WITH fc AS (
        -- Source unifiee : fichier + clients PHL absents du fichier.
        -- customer_id et address_id sont deja calcules par la vue.
        SELECT *
        FROM clean_data.v_customer_source
        WHERE customer_id IS NOT NULL
    )
    SELECT DISTINCT
        fc.customer_id AS customer_no,
        public.get_default_value('clean_data.cust_ord_customer', 'cust_grp', NULL) AS cust_grp,                                                          -- -> NULL (réf. IFS CustomerGroup absente)
        public.get_default_value('clean_data.cust_ord_customer', 'cycle_period', '0')::numeric AS cycle_period,
        SUBSTRING(COALESCE(MAX(knvv.WAERS), 'EUR'), 1, 3) AS currency_code,
        public.get_default_value('clean_data.cust_ord_customer', 'category_db', 'E') AS category_db,
        fc.customer_id AS customer_no_pay,
        public.get_default_value('clean_data.cust_ord_customer', 'cust_price_group_id', NULL) AS cust_price_group_id,                                               -- -> NULL (réf. IFS absente)
        public.get_default_value('clean_data.cust_ord_customer', 'salesman_code', NULL) AS salesman_code,                                                     -- -> NULL (réf. IFS absente)
        public.get_default_value('clean_data.cust_ord_customer', 'market_code', NULL) AS market_code,                                                       -- -> NULL (réf. IFS SalesMarket absente)
        public.get_default_value('clean_data.cust_ord_customer', 'print_control_code', NULL) AS print_control_code,                                                -- -> NULL (réf. IFS absente)
        CASE WHEN fc.sales_order_block IS NOT NULL AND fc.sales_order_block != ''
             THEN 'Y' ELSE 'N' END::VARCHAR(1) AS cr_stop_db,
        SUBSTRING(COALESCE(fc.customer_classification, ''), 1, 100) AS cust_ref,
        public.get_default_value('clean_data.cust_ord_customer', 'date_del', NULL)::date AS date_del,
        public.get_default_value('clean_data.cust_ord_customer', 'invoice_sort_db', 'N') AS invoice_sort_db,
        public.get_default_value('clean_data.cust_ord_customer', 'last_ivc_date', NULL)::date AS last_ivc_date,
        SUBSTRING(COALESCE(fc.name_1, ''), 1, 2000) AS note_text,
        public.get_default_value('clean_data.cust_ord_customer', 'order_conf_flag_db', 'Y') AS order_conf_flag_db,
        public.get_default_value('clean_data.cust_ord_customer', 'pack_list_flag_db', 'Y') AS pack_list_flag_db,
        public.get_default_value('clean_data.cust_ord_customer', 'acquisition_site', NULL) AS acquisition_site,
        public.get_default_value('clean_data.cust_ord_customer', 'order_id', NULL) AS order_id,
        public.get_default_value('clean_data.cust_ord_customer', 'edi_auto_order_approval_db', 'MANUALLY') AS edi_auto_order_approval_db,
        public.get_default_value('clean_data.cust_ord_customer', 'edi_auto_change_approval_db', 'MANUALLY') AS edi_auto_change_approval_db,
        public.get_default_value('clean_data.cust_ord_customer', 'edi_authorize_code', NULL) AS edi_authorize_code,
        public.get_default_value('clean_data.cust_ord_customer', 'edi_site', NULL) AS edi_site,
        public.get_default_value('clean_data.cust_ord_customer', 'edi_auto_approval_user', NULL) AS edi_auto_approval_user,
        public.get_default_value('clean_data.cust_ord_customer', 'template_id', NULL) AS template_id,
        public.get_default_value('clean_data.cust_ord_customer', 'discount', '0')::numeric AS discount,
        public.get_default_value('clean_data.cust_ord_customer', 'discount_type', 'G', 'CUSTOMERFILE') AS discount_type,                                                      -- (valeur par défaut G)
        public.get_default_value('clean_data.cust_ord_customer', 'min_sales_amount', NULL)::numeric AS min_sales_amount,
        public.get_default_value('clean_data.cust_ord_customer', 'note_id', NULL)::numeric AS note_id,
        public.get_default_value('clean_data.cust_ord_customer', 'template_customer_desc', NULL) AS template_customer_desc,
        public.get_default_value('clean_data.cust_ord_customer', 'template_customer_db', 'NOT_TEMPLATE') AS template_customer_db,
        public.get_default_value('clean_data.cust_ord_customer', 'quick_registered_customer_db', 'NORMAL') AS quick_registered_customer_db,
        public.get_default_value('clean_data.cust_ord_customer', 'commission_receiver_db', 'DONOTCREATE') AS commission_receiver_db,
        public.get_default_value('clean_data.cust_ord_customer', 'no_delnote_copies', NULL)::numeric AS no_delnote_copies,
        public.get_default_value('clean_data.cust_ord_customer', 'forward_agent_id', NULL) AS forward_agent_id,
        public.get_default_value('clean_data.cust_ord_customer', 'auto_despatch_adv_send', NULL) AS auto_despatch_adv_send,
        public.get_default_value('clean_data.cust_ord_customer', 'mul_tier_del_notification_db', 'FALSE') AS mul_tier_del_notification_db,
        public.get_default_value('clean_data.cust_ord_customer', 'match_type_db', NULL) AS match_type_db,
        public.get_default_value('clean_data.cust_ord_customer', 'print_amounts_incl_tax_db', 'FALSE') AS print_amounts_incl_tax_db,
        public.get_default_value('clean_data.cust_ord_customer', 'confirm_deliveries_db', 'FALSE') AS confirm_deliveries_db,
        public.get_default_value('clean_data.cust_ord_customer', 'check_sales_grp_deliv_conf_db', 'FALSE') AS check_sales_grp_deliv_conf_db,
        public.get_default_value('clean_data.cust_ord_customer', 'handl_unit_at_co_delivery_db', NULL) AS handl_unit_at_co_delivery_db,
        public.get_default_value('clean_data.cust_ord_customer', 'update_price_from_sbi_db', 'FALSE') AS update_price_from_sbi_db,
        public.get_default_value('clean_data.cust_ord_customer', 'rec_adv_auto_match_diff_db', 'FALSE') AS rec_adv_auto_match_diff_db,
        public.get_default_value('clean_data.cust_ord_customer', 'rec_adv_auto_matching_db', 'FALSE') AS rec_adv_auto_matching_db,
        public.get_default_value('clean_data.cust_ord_customer', 'rec_adv_matching_option_db', NULL) AS rec_adv_matching_option_db,
        public.get_default_value('clean_data.cust_ord_customer', 'receiving_advice_type_db', NULL) AS receiving_advice_type_db,
        public.get_default_value('clean_data.cust_ord_customer', 'self_billing_match_option_db', NULL) AS self_billing_match_option_db,
        public.get_default_value('clean_data.cust_ord_customer', 'sbi_auto_approval_user', NULL) AS sbi_auto_approval_user,
        public.get_default_value('clean_data.cust_ord_customer', 'rec_adv_auto_approval_user', NULL) AS rec_adv_auto_approval_user,
        public.get_default_value('clean_data.cust_ord_customer', 'adv_inv_full_pay_db', 'FALSE') AS adv_inv_full_pay_db,
        public.get_default_value('clean_data.cust_ord_customer', 'release_internal_order_db', 'MANUALLY') AS release_internal_order_db,
        public.get_default_value('clean_data.cust_ord_customer', 'credit_control_group_id', NULL) AS credit_control_group_id,                                           -- -> NULL (réf. IFS absente)
        public.get_default_value('clean_data.cust_ord_customer', 'backorder_option_db', NULL) AS backorder_option_db,
        public.get_default_value('clean_data.cust_ord_customer', 'priority', NULL)::numeric AS priority,
        public.get_default_value('clean_data.cust_ord_customer', 'receive_pack_size_chg_db', 'FALSE') AS receive_pack_size_chg_db,
        public.get_default_value('clean_data.cust_ord_customer', 'summarized_freight_charges_db', 'Y') AS summarized_freight_charges_db,
        public.get_default_value('clean_data.cust_ord_customer', 'print_delivered_lines_db', 'SHIPMENT') AS print_delivered_lines_db,
        public.get_default_value('clean_data.cust_ord_customer', 'email_order_conf_db', 'TRUE') AS email_order_conf_db,
        public.get_default_value('clean_data.cust_ord_customer', 'email_invoice_db', 'FALSE') AS email_invoice_db,
        public.get_default_value('clean_data.cust_ord_customer', 'allow_auto_sub_of_parts_db', 'FALSE') AS allow_auto_sub_of_parts_db,
        public.get_default_value('clean_data.cust_ord_customer', 'b2b_auto_create_co_from_sq_db', 'FALSE') AS b2b_auto_create_co_from_sq_db,
        public.get_default_value('clean_data.cust_ord_customer', 'print_withholding_tax_db', 'FALSE') AS print_withholding_tax_db,
        public.get_default_value('clean_data.cust_ord_customer', 'consol_rental_ivc_serial_db', 'SPECIFIED ON COMPANY') AS consol_rental_ivc_serial_db,
        public.get_default_value('clean_data.cust_ord_customer', 'exclude_from_scan_order', NULL) AS exclude_from_scan_order,
        public.get_default_value('clean_data.cust_ord_customer', 'default_inv_currency', NULL) AS default_inv_currency,
        public.get_default_value('clean_data.cust_ord_customer', 'confirm_direct_deliveries', NULL) AS confirm_direct_deliveries,
        public.get_default_value('clean_data.cust_ord_customer', 'summarized_source_lines_db', 'Y') AS summarized_source_lines_db,
        public.get_default_value('clean_data.cust_ord_customer', 'send_change_message_db', 'N') AS send_change_message_db,
        public.get_default_value('clean_data.cust_ord_customer', 'replicate_doc_text_db', NULL) AS replicate_doc_text_db,
        -- colonnes affichage
        CASE WHEN fc.sales_order_block IS NOT NULL AND fc.sales_order_block != ''
             THEN 'TRUE' ELSE 'FALSE' END AS cr_stop,
        public.get_default_value('clean_data.cust_ord_customer', 'invoice_sort', 'N') AS invoice_sort,
        public.get_default_value('clean_data.cust_ord_customer', 'order_conf_flag', 'Y') AS order_conf_flag,
        public.get_default_value('clean_data.cust_ord_customer', 'pack_list_flag', 'Y') AS pack_list_flag,
        public.get_default_value('clean_data.cust_ord_customer', 'category', 'E') AS category,
        public.get_default_value('clean_data.cust_ord_customer', 'edi_auto_order_approval', 'MANUALLY') AS edi_auto_order_approval,
        public.get_default_value('clean_data.cust_ord_customer', 'edi_auto_change_approval', 'MANUALLY') AS edi_auto_change_approval,
        public.get_default_value('clean_data.cust_ord_customer', 'template_customer', 'NOT_TEMPLATE') AS template_customer,
        public.get_default_value('clean_data.cust_ord_customer', 'quick_registered_customer', 'NORMAL') AS quick_registered_customer,
        public.get_default_value('clean_data.cust_ord_customer', 'commission_receiver', 'DONOTCREATE') AS commission_receiver,
        public.get_default_value('clean_data.cust_ord_customer', 'summarized_source_lines', 'Y') AS summarized_source_lines,
        public.get_default_value('clean_data.cust_ord_customer', 'send_change_message', 'N') AS send_change_message,
        public.get_default_value('clean_data.cust_ord_customer', 'replicate_doc_text', NULL) AS replicate_doc_text,
        public.get_default_value('clean_data.cust_ord_customer', 'mul_tier_del_notification', 'FALSE') AS mul_tier_del_notification,
        public.get_default_value('clean_data.cust_ord_customer', 'match_type', NULL) AS match_type,
        public.get_default_value('clean_data.cust_ord_customer', 'print_amounts_incl_tax', 'FALSE') AS print_amounts_incl_tax,
        public.get_default_value('clean_data.cust_ord_customer', 'confirm_deliveries', 'FALSE') AS confirm_deliveries,
        public.get_default_value('clean_data.cust_ord_customer', 'check_sales_grp_deliv_conf', 'FALSE') AS check_sales_grp_deliv_conf,
        public.get_default_value('clean_data.cust_ord_customer', 'handl_unit_at_co_delivery', NULL) AS handl_unit_at_co_delivery,
        public.get_default_value('clean_data.cust_ord_customer', 'update_price_from_sbi', 'FALSE') AS update_price_from_sbi,
        public.get_default_value('clean_data.cust_ord_customer', 'rec_adv_auto_match_diff', 'FALSE') AS rec_adv_auto_match_diff,
        public.get_default_value('clean_data.cust_ord_customer', 'rec_adv_auto_matching', 'FALSE') AS rec_adv_auto_matching,
        public.get_default_value('clean_data.cust_ord_customer', 'rec_adv_matching_option', NULL) AS rec_adv_matching_option,
        public.get_default_value('clean_data.cust_ord_customer', 'receiving_advice_type', NULL) AS receiving_advice_type,
        public.get_default_value('clean_data.cust_ord_customer', 'self_billing_match_option', NULL) AS self_billing_match_option,
        public.get_default_value('clean_data.cust_ord_customer', 'adv_inv_full_pay', 'FALSE') AS adv_inv_full_pay,
        public.get_default_value('clean_data.cust_ord_customer', 'release_internal_order', 'MANUALLY') AS release_internal_order,
        public.get_default_value('clean_data.cust_ord_customer', 'backorder_option', NULL) AS backorder_option,
        public.get_default_value('clean_data.cust_ord_customer', 'receive_pack_size_chg', 'FALSE') AS receive_pack_size_chg,
        public.get_default_value('clean_data.cust_ord_customer', 'summarized_freight_charges', 'Y') AS summarized_freight_charges,
        public.get_default_value('clean_data.cust_ord_customer', 'print_delivered_lines', 'SHIPMENT') AS print_delivered_lines,
        public.get_default_value('clean_data.cust_ord_customer', 'email_order_conf', 'TRUE') AS email_order_conf,
        public.get_default_value('clean_data.cust_ord_customer', 'email_invoice', 'FALSE') AS email_invoice,
        public.get_default_value('clean_data.cust_ord_customer', 'allow_auto_sub_of_parts', 'FALSE') AS allow_auto_sub_of_parts,
        public.get_default_value('clean_data.cust_ord_customer', 'b2b_auto_create_co_from_sq', 'FALSE') AS b2b_auto_create_co_from_sq,
        public.get_default_value('clean_data.cust_ord_customer', 'print_withholding_tax', 'FALSE') AS print_withholding_tax,
        public.get_default_value('clean_data.cust_ord_customer', 'consol_rental_ivc_serial', 'SPECIFIED ON COMPANY') AS consol_rental_ivc_serial,
        SUBSTRING(TRIM(COALESCE(fc.name_1, '')), 1, 100) AS name
    FROM fc
    LEFT JOIN raw_data.knvv knvv
        ON fc.kunnr = knvv.KUNNR
        AND fc.vkorg = knvv.VKORG
        AND (knvv.LOEVM IS NULL OR knvv.LOEVM = '')
    GROUP BY fc.customer_id, fc.customer_group, fc.sales_district, fc.sales_order_block,
             fc.customer_classification, fc.name_1;

    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();
    RAISE NOTICE 'INSERT cust ord customer terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));

EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT cust ord customer - %: %', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
