-- Transposition de sp_insert_cust_ord_customer_from_sap pour le module customerFile.
-- Table maître ifs_customer remplacée par une CTE sur clean_data.v_customer_source (fichier + clients PHL absents du fichier).
-- Le fichier fait autorité : les COALESCE préfèrent le fichier puis retombent sur SAP.

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
        fc.customer_id,                                                                  -- customer_no
        NULL::VARCHAR(10),          -- cust_grp -> NULL (réf. IFS CustomerGroup absente)
        0::NUMERIC(3,0),                                                                 -- cycle_period
        SUBSTRING(COALESCE(MAX(knvv.WAERS), 'EUR'), 1, 3),                              -- currency_code
        'E'::VARCHAR(2),                                                                 -- category_db
        fc.customer_id,                                                                  -- customer_no_pay
        NULL::VARCHAR(10),                            -- cust_price_group_id -> NULL (réf. IFS absente)
        NULL::VARCHAR(20),                        -- salesman_code -> NULL (réf. IFS absente)
        NULL::VARCHAR(10),     -- market_code -> NULL (réf. IFS SalesMarket absente)
        NULL::VARCHAR(10),                                                              -- print_control_code -> NULL (réf. IFS absente)
        CASE WHEN fc.sales_order_block IS NOT NULL AND fc.sales_order_block != ''
             THEN 'Y' ELSE 'N' END::VARCHAR(1),                                         -- cr_stop_db
        SUBSTRING(COALESCE(fc.customer_classification, ''), 1, 100),                   -- cust_ref
        NULL::DATE,                                                                      -- date_del
        'N'::VARCHAR(2),                                                                 -- invoice_sort_db
        NULL::DATE,                                                                      -- last_ivc_date
        SUBSTRING(COALESCE(fc.name_1, ''), 1, 2000),                                   -- note_text
        'Y'::VARCHAR(1),                                                                 -- order_conf_flag_db
        'Y'::VARCHAR(1),                                                                 -- pack_list_flag_db
        NULL::VARCHAR(5),                                                                -- acquisition_site
        NULL::VARCHAR(3),                                                                -- order_id
        'MANUALLY'::VARCHAR(20),                                                         -- edi_auto_order_approval_db
        'MANUALLY'::VARCHAR(20),                                                         -- edi_auto_change_approval_db
        NULL::VARCHAR(20),                                                               -- edi_authorize_code
        NULL::VARCHAR(5),                                                                -- edi_site
        NULL::VARCHAR(30),                                                               -- edi_auto_approval_user
        NULL::VARCHAR(12),                                                               -- template_id
        0::NUMERIC(20,2),                                                                -- discount
        'G'::VARCHAR(25),                                                          -- discount_type (valeur par défaut G)
        NULL::NUMERIC(20,2),                                                             -- min_sales_amount
        NULL::NUMERIC(20,2),                                                             -- note_id
        NULL::VARCHAR(35),                                                               -- template_customer_desc
        'NOT_TEMPLATE'::VARCHAR(20),                                                     -- template_customer_db
        'NORMAL'::VARCHAR(20),                                                           -- quick_registered_customer_db
        'DONOTCREATE'::VARCHAR(20),                                                      -- commission_receiver_db
        NULL::NUMERIC(20,2),                                                             -- no_delnote_copies
        NULL::VARCHAR(20),                                                               -- forward_agent_id
        NULL::VARCHAR(1),                                                                -- auto_despatch_adv_send
        'FALSE'::VARCHAR(20),                                                            -- mul_tier_del_notification_db
        NULL::VARCHAR(15),                                                               -- match_type_db
        'FALSE'::VARCHAR(20),                                                            -- print_amounts_incl_tax_db
        'FALSE'::VARCHAR(20),                                                            -- confirm_deliveries_db
        'FALSE'::VARCHAR(20),                                                            -- check_sales_grp_deliv_conf_db
        NULL::VARCHAR(20),                                                               -- handl_unit_at_co_delivery_db
        'FALSE'::VARCHAR(20),                                                            -- update_price_from_sbi_db
        'FALSE'::VARCHAR(20),                                                            -- rec_adv_auto_match_diff_db
        'FALSE'::VARCHAR(20),                                                            -- rec_adv_auto_matching_db
        NULL::VARCHAR(25),                                                               -- rec_adv_matching_option_db
        NULL::VARCHAR(30),                                                               -- receiving_advice_type_db
        NULL::VARCHAR(30),                                                               -- self_billing_match_option_db
        NULL::VARCHAR(30),                                                               -- sbi_auto_approval_user
        NULL::VARCHAR(30),                                                               -- rec_adv_auto_approval_user
        'FALSE'::VARCHAR(20),                                                            -- adv_inv_full_pay_db
        'MANUALLY'::VARCHAR(20),                                                         -- release_internal_order_db
        NULL::VARCHAR(10),                                                                -- credit_control_group_id -> NULL (réf. IFS absente)
        NULL::VARCHAR(40),                                                               -- backorder_option_db
        NULL::NUMERIC(20,2),                                                             -- priority
        'FALSE'::VARCHAR(20),                                                            -- receive_pack_size_chg_db
        'Y'::VARCHAR(20),                                                                -- summarized_freight_charges_db
        'SHIPMENT'::VARCHAR(23),                                                         -- print_delivered_lines_db
        'TRUE'::VARCHAR(20),                                                             -- email_order_conf_db
        'FALSE'::VARCHAR(20),                                                            -- email_invoice_db
        'FALSE'::VARCHAR(5),                                                             -- allow_auto_sub_of_parts_db
        'FALSE'::VARCHAR(20),                                                            -- b2b_auto_create_co_from_sq_db
        'FALSE'::VARCHAR(5),                                                             -- print_withholding_tax_db
        'SPECIFIED ON COMPANY'::VARCHAR(20),                                             -- consol_rental_ivc_serial_db
        NULL::VARCHAR(5),                                                                -- exclude_from_scan_order
        NULL::VARCHAR(5),                                                                -- default_inv_currency
        NULL::VARCHAR(5),                                                                -- confirm_direct_deliveries
        'Y'::VARCHAR(20),                                                                -- summarized_source_lines_db
        'N'::VARCHAR(20),                                                                -- send_change_message_db
        NULL::VARCHAR(20),                                                               -- replicate_doc_text_db
        -- colonnes affichage
        CASE WHEN fc.sales_order_block IS NOT NULL AND fc.sales_order_block != ''
             THEN 'TRUE' ELSE 'FALSE' END,                                               -- cr_stop
        'N',                                                                             -- invoice_sort
        'Y',                                                                             -- order_conf_flag
        'Y',                                                                             -- pack_list_flag
        'E',                                                                             -- category
        'MANUALLY',                                                                      -- edi_auto_order_approval
        'MANUALLY',                                                                      -- edi_auto_change_approval
        'NOT_TEMPLATE',                                                                  -- template_customer
        'NORMAL',                                                                        -- quick_registered_customer
        'DONOTCREATE',                                                                   -- commission_receiver
        'Y',                                                                             -- summarized_source_lines
        'N',                                                                             -- send_change_message
        NULL,                                                                            -- replicate_doc_text
        'FALSE',                                                                         -- mul_tier_del_notification
        NULL,                                                                            -- match_type
        'FALSE',                                                                         -- print_amounts_incl_tax
        'FALSE',                                                                         -- confirm_deliveries
        'FALSE',                                                                         -- check_sales_grp_deliv_conf
        NULL,                                                                            -- handl_unit_at_co_delivery
        'FALSE',                                                                         -- update_price_from_sbi
        'FALSE',                                                                         -- rec_adv_auto_match_diff
        'FALSE',                                                                         -- rec_adv_auto_matching
        NULL,                                                                            -- rec_adv_matching_option
        NULL,                                                                            -- receiving_advice_type
        NULL,                                                                            -- self_billing_match_option
        'FALSE',                                                                         -- adv_inv_full_pay
        'MANUALLY',                                                                      -- release_internal_order
        NULL,                                                                            -- backorder_option
        'FALSE',                                                                         -- receive_pack_size_chg
        'Y',                                                                             -- summarized_freight_charges
        'SHIPMENT',                                                                      -- print_delivered_lines
        'TRUE',                                                                          -- email_order_conf
        'FALSE',                                                                         -- email_invoice
        'FALSE',                                                                         -- allow_auto_sub_of_parts
        'FALSE',                                                                         -- b2b_auto_create_co_from_sq
        'FALSE',                                                                         -- print_withholding_tax
        'SPECIFIED ON COMPANY',                                                          -- consol_rental_ivc_serial
        SUBSTRING(TRIM(COALESCE(fc.name_1, '')), 1, 100)                                -- name
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
$procedure$;
