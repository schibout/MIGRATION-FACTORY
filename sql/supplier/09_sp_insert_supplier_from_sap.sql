CREATE OR REPLACE PROCEDURE clean_data.sp_insert_supplier_from_sap()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    RAISE NOTICE 'Début insertion SUPPLIER depuis table ifs_fournisseurs - %', v_start_time;
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.supplier;
    RAISE NOTICE 'Table supplier vidée';
    
    -- Insertion des données
    INSERT INTO clean_data.supplier (
        vendor_no,
        buyer_code,
        currency_code,
        supp_grp,
        additional_cost_amount,
        cr_check_db,
        discount,
        pack_list_flag_db,
        purch_order_flag_db,
        qc_approval_db,
        ord_conf_rem_interval,
        delivery_rem_interval,
        days_before_delivery,
        days_before_arrival,
        ord_conf_reminder_db,
        delivery_reminder_db,
        category_db,
        environmental_approval_db,
        coc_approval_db,
        template_supplier_db,
        quick_registered_supplier_db,
        blanket_date_db,
        express_order_allowed_db,
        pricat_automatic_approval_db,
        receipt_ref_reminder_db,
        print_amounts_incl_tax_db,
        receiving_advice_type_db,
        rec_adv_self_billing_db,
        po_change_management_db,
        create_confirmation_chg_ord_db,
        email_purchase_order_db,
        dir_del_approval_db,
        order_conf_approval_db,
        order_conf_diff_approval_db,
        adhoc_pur_rqst_approval_db,
        tax_liability,
        b2b_conf_order_with_diff_db,
        rec_adv_sb_consignment_db,
        rec_adv_sb_mix_ownership_db,
        created_timestamp,
        updated_timestamp,
        created_by,
        updated_by,
        is_deleted
    )
    SELECT DISTINCT
        f.numero_compte_fournisseur as vendor_no,
        '*' as buyer_code,
        COALESCE(f.devise_principale, 'EUR') as currency_code,
        'DEFAULT' as supp_grp,
        0 as additional_cost_amount,
        'Y' as cr_check_db,
        0 as discount,
        'Y' as pack_list_flag_db,
        'Y' as purch_order_flag_db,
        'Y' as qc_approval_db,
        7 as ord_conf_rem_interval,
        3 as delivery_rem_interval,
        COALESCE(m.plifz::numeric, 30) as days_before_delivery,
        COALESCE(m.plifz::numeric, 30) as days_before_arrival,
        'CONFREM' as ord_conf_reminder_db,
        'DELIVREM' as delivery_reminder_db,
        'E' as category_db,
        'APPROVED' as environmental_approval_db,
        'Y' as coc_approval_db,
        'NOTEMPLATE' as template_supplier_db,
        'ORDINARY' as quick_registered_supplier_db,
        'ORDERDATE' as blanket_date_db,
        '1' as express_order_allowed_db,
        'NOT_APPLICABLE' as pricat_automatic_approval_db,
        'NO_RCPT_REMINDER' as receipt_ref_reminder_db,
        'FALSE' as print_amounts_incl_tax_db,
        'USE_CUSTOMER_DEFAULT' as receiving_advice_type_db,
        'FALSE' as rec_adv_self_billing_db,
        'USE_SITE_DEFAULT' as po_change_management_db,
        'FALSE' as create_confirmation_chg_ord_db,
        'TRUE' as email_purchase_order_db,
        'AUTOMATICALLY' as dir_del_approval_db,
        'AUTOMATICALLY' as order_conf_approval_db,
        'MANUALLY' as order_conf_diff_approval_db,
        'MANUALLY' as adhoc_pur_rqst_approval_db,
        CASE 
            WHEN f.cle_pays IN ('FR', 'DE', 'IT', 'ES', 'NL', 'BE', 'AT', 'PT', 'IE', 'FI', 'SE', 'DK') 
                 THEN 'EU_TAX'
            ELSE 'NON_EU'
        END as tax_liability,
        'FALSE' as b2b_conf_order_with_diff_db,
        'FALSE' as rec_adv_sb_consignment_db,
        'FALSE' as rec_adv_sb_mix_ownership_db,
        CURRENT_TIMESTAMP as created_timestamp,
        CURRENT_TIMESTAMP as updated_timestamp,
        'etl_supplier_base' as created_by,
        'etl_supplier_base' as updated_by,
        FALSE as is_deleted
    FROM clean_data.ifs_fournisseurs f
    LEFT JOIN raw_data.lfm1 m ON f.numero_compte_fournisseur = m.lifnr 
        AND m.ekorg = f.organisation_achats;
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    
    RAISE NOTICE '=== INSERTION SUPPLIER TERMINÉE ===';
    RAISE NOTICE 'Durée: % secondes', EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time));
    RAISE NOTICE 'Enregistrements insérés: %', v_processed_count;
    
    -- Statistiques détaillées
    RAISE NOTICE '=== STATISTIQUES DÉTAILLÉES ===';
    RAISE NOTICE 'Fournisseurs avec buyer_code = ''*'': %',
        (SELECT COUNT(*) FROM clean_data.supplier WHERE buyer_code = '*');
    RAISE NOTICE 'Fournisseurs externes (E): %', 
        (SELECT COUNT(*) FROM clean_data.supplier WHERE category_db = 'E');
    RAISE NOTICE 'Fournisseurs avec email activé: %', 
        (SELECT COUNT(*) FROM clean_data.supplier WHERE email_purchase_order_db = 'TRUE');
    RAISE NOTICE 'Fournisseurs avec crédit approuvé: %', 
        (SELECT COUNT(*) FROM clean_data.supplier WHERE cr_check_db = 'Y');
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur lors de l''insertion supplier: %', SQLERRM;
END;
$procedure$;
