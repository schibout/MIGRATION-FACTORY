CREATE OR REPLACE PROCEDURE clean_data.sp_insert_cust_ord_customer_from_sap()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion cust ord customer SAP - %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.cust_ord_customer;
    RAISE NOTICE 'Table cust_ord_customer vidée';
    INSERT INTO clean_data.cust_ord_customer (
        customer_no,
        customer_no_pay,
        cust_grp,
        cust_price_group_id,
        salesman_code,
        market_code,
        print_control_code,
        cr_stop,
        cr_stop_db,
        cust_ref,
        cycle_period,
        date_del,
        invoice_sort,
        invoice_sort_db,
        last_ivc_date,
        note_text,
        order_conf_flag,
        order_conf_flag_db,
        pack_list_flag,
        pack_list_flag_db,
        acquisition_site,
        category,
        category_db,
        currency_code,
        order_id,
        forward_agent_id,
        discount,
        discount_type,
        commission_receiver,
        commission_receiver_db,
        name
    )
    SELECT DISTINCT
        ic.customer_number as customer_no,
        ic.customer_number as customer_no_pay,
        SUBSTRING(COALESCE(ic.customer_group, 'STD'), 1, 10) as cust_grp,
        SUBSTRING(COALESCE(MAX(knvv.PLTYP), 'STD'), 1, 10) as cust_price_group_id,
        SUBSTRING(COALESCE(MAX(knvv.VKGRP), 'DEFAULT'), 1, 20) as salesman_code,
        SUBSTRING(COALESCE(ic.sales_district, 'DEFAULT'), 1, 10) as market_code,
        SUBSTRING('STD', 1, 10) as print_control_code,
        CASE WHEN ic.sales_order_block IS NOT NULL AND ic.sales_order_block != '' THEN 'TRUE' ELSE 'FALSE' END as cr_stop,
        CASE WHEN ic.sales_order_block IS NOT NULL AND ic.sales_order_block != '' THEN 'Y' ELSE 'N' END as cr_stop_db,
        SUBSTRING(COALESCE(ic.customer_classification, ''), 1, 100) as cust_ref,
        0::integer as cycle_period,
        NULL::DATE as date_del,
        'N' as invoice_sort,
        'N' as invoice_sort_db,
        NULL::DATE as last_ivc_date,
        SUBSTRING(COALESCE(ic.name_1, ''), 1, 2000) as note_text,
        'Y' as order_conf_flag,
        'Y' as order_conf_flag_db,
        'Y' as pack_list_flag,
        'Y' as pack_list_flag_db,
        NULL::varchar(5) as acquisition_site,
        'E' as category,
        'E' as category_db,
        SUBSTRING(COALESCE(MAX(knvv.WAERS), 'EUR'), 1, 3) as currency_code,
        NULL as order_id,
        NULL as forward_agent_id,
        0 as discount,
        'Standard' as discount_type,
        'DONOTCREATE' as commission_receiver,
        'DONOTCREATE' as commission_receiver_db,
        SUBSTRING(TRIM(COALESCE(ic.name_1, '')), 1, 100) as name
    FROM clean_data.ifs_customer ic
    LEFT JOIN raw_data.knvv knvv
        ON ic.customer_number = knvv.KUNNR
        AND ic.sales_organization = knvv.VKORG
        AND (knvv.LOEVM IS NULL OR knvv.LOEVM = '')
    GROUP BY ic.customer_number, ic.customer_group, ic.sales_district, ic.sales_order_block, 
             ic.customer_classification, ic.name_1;
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
