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
        supplier_group,
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
        public.get_default_value('clean_data.supplier', 'buyer_code') as buyer_code,
        -- ifs_fournisseurs.devise_principale a été supprimée (colonne KPI jamais
        -- alimentée : le bloc de calcul est commenté dans le script 01). Le
        -- COALESCE retombait donc toujours sur 'EUR' -> valeur inchangée.
        public.get_default_value('clean_data.supplier', 'currency_code') as currency_code,
        public.get_default_value('clean_data.supplier', 'supp_grp') as supp_grp,
        public.get_default_value('clean_data.supplier', 'supplier_group') as supplier_group,
        public.get_default_value('clean_data.supplier', 'additional_cost_amount')::numeric as additional_cost_amount,
        public.get_default_value('clean_data.supplier', 'cr_check_db') as cr_check_db,
        public.get_default_value('clean_data.supplier', 'discount')::numeric as discount,
        public.get_default_value('clean_data.supplier', 'pack_list_flag_db') as pack_list_flag_db,
        public.get_default_value('clean_data.supplier', 'purch_order_flag_db') as purch_order_flag_db,
        public.get_default_value('clean_data.supplier', 'qc_approval_db') as qc_approval_db,
        public.get_default_value('clean_data.supplier', 'ord_conf_rem_interval')::numeric as ord_conf_rem_interval,
        public.get_default_value('clean_data.supplier', 'delivery_rem_interval')::numeric as delivery_rem_interval,
        COALESCE(m.plifz::numeric, 30) as days_before_delivery,
        COALESCE(m.plifz::numeric, 30) as days_before_arrival,
        public.get_default_value('clean_data.supplier', 'ord_conf_reminder_db') as ord_conf_reminder_db,
        public.get_default_value('clean_data.supplier', 'delivery_reminder_db') as delivery_reminder_db,
        public.get_default_value('clean_data.supplier', 'category_db') as category_db,
        public.get_default_value('clean_data.supplier', 'environmental_approval_db') as environmental_approval_db,
        public.get_default_value('clean_data.supplier', 'coc_approval_db') as coc_approval_db,
        public.get_default_value('clean_data.supplier', 'template_supplier_db') as template_supplier_db,
        public.get_default_value('clean_data.supplier', 'quick_registered_supplier_db') as quick_registered_supplier_db,
        public.get_default_value('clean_data.supplier', 'blanket_date_db') as blanket_date_db,
        public.get_default_value('clean_data.supplier', 'express_order_allowed_db') as express_order_allowed_db,
        public.get_default_value('clean_data.supplier', 'pricat_automatic_approval_db') as pricat_automatic_approval_db,
        public.get_default_value('clean_data.supplier', 'receipt_ref_reminder_db') as receipt_ref_reminder_db,
        public.get_default_value('clean_data.supplier', 'print_amounts_incl_tax_db') as print_amounts_incl_tax_db,
        public.get_default_value('clean_data.supplier', 'receiving_advice_type_db') as receiving_advice_type_db,
        public.get_default_value('clean_data.supplier', 'rec_adv_self_billing_db') as rec_adv_self_billing_db,
        public.get_default_value('clean_data.supplier', 'po_change_management_db') as po_change_management_db,
        public.get_default_value('clean_data.supplier', 'create_confirmation_chg_ord_db') as create_confirmation_chg_ord_db,
        public.get_default_value('clean_data.supplier', 'email_purchase_order_db') as email_purchase_order_db,
        public.get_default_value('clean_data.supplier', 'dir_del_approval_db') as dir_del_approval_db,
        public.get_default_value('clean_data.supplier', 'order_conf_approval_db') as order_conf_approval_db,
        public.get_default_value('clean_data.supplier', 'order_conf_diff_approval_db') as order_conf_diff_approval_db,
        public.get_default_value('clean_data.supplier', 'adhoc_pur_rqst_approval_db') as adhoc_pur_rqst_approval_db,
        CASE
            WHEN f.cle_pays IN ('FR', 'DE', 'IT', 'ES', 'NL', 'BE', 'AT', 'PT', 'IE', 'FI', 'SE', 'DK')
                 THEN 'EU_TAX'
            ELSE 'NON_EU'
        END as tax_liability,
        public.get_default_value('clean_data.supplier', 'b2b_conf_order_with_diff_db') as b2b_conf_order_with_diff_db,
        public.get_default_value('clean_data.supplier', 'rec_adv_sb_consignment_db') as rec_adv_sb_consignment_db,
        public.get_default_value('clean_data.supplier', 'rec_adv_sb_mix_ownership_db') as rec_adv_sb_mix_ownership_db,
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
$procedure$
;
