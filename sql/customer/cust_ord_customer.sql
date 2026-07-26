CREATE TABLE clean_data.cust_ord_customer (
    customer_no VARCHAR(20) NOT NULL,
    cust_grp VARCHAR(10) NOT NULL,
    cycle_period NUMERIC(3,0) NOT NULL DEFAULT 0,
    currency_code VARCHAR(3) NOT NULL,
    category_db VARCHAR(2) NOT NULL DEFAULT 'E',
    customer_no_pay VARCHAR(20),
    cust_price_group_id VARCHAR(10),
    salesman_code VARCHAR(20),
    market_code VARCHAR(10),
    print_control_code VARCHAR(10),
    cr_stop_db VARCHAR(1) DEFAULT 'N',
    cust_ref VARCHAR(100),
    date_del DATE,
    invoice_sort_db VARCHAR(2) DEFAULT 'N',
    last_ivc_date DATE,
    note_text VARCHAR(2000),
    order_conf_flag_db VARCHAR(1) DEFAULT 'Y',
    pack_list_flag_db VARCHAR(1) DEFAULT 'Y',
    acquisition_site VARCHAR(5),
    order_id VARCHAR(3),
    edi_auto_order_approval_db VARCHAR(20) DEFAULT 'MANUALLY',
    edi_auto_change_approval_db VARCHAR(20) DEFAULT 'MANUALLY',
    edi_authorize_code VARCHAR(20),
    edi_site VARCHAR(5),
    edi_auto_approval_user VARCHAR(30),
    template_id VARCHAR(12),
    discount NUMERIC(20,2),
    discount_type VARCHAR(25),
    min_sales_amount NUMERIC(20,2),
    note_id NUMERIC(20,2),
    template_customer_desc VARCHAR(35),
    template_customer_db VARCHAR(20) DEFAULT 'NOT_TEMPLATE',
    quick_registered_customer_db VARCHAR(20) DEFAULT 'NORMAL',
    commission_receiver_db VARCHAR(20) DEFAULT 'DONOTCREATE',
    no_delnote_copies NUMERIC(20,2),
    forward_agent_id VARCHAR(20),
    auto_despatch_adv_send VARCHAR(1),
    mul_tier_del_notification_db VARCHAR(20) DEFAULT 'FALSE',
    match_type_db VARCHAR(15),
    print_amounts_incl_tax_db VARCHAR(20) DEFAULT 'FALSE',
    confirm_deliveries_db VARCHAR(20) DEFAULT 'FALSE',
    check_sales_grp_deliv_conf_db VARCHAR(20) DEFAULT 'FALSE',
    handl_unit_at_co_delivery_db VARCHAR(20),
    update_price_from_sbi_db VARCHAR(20) DEFAULT 'FALSE',
    rec_adv_auto_match_diff_db VARCHAR(20) DEFAULT 'FALSE',
    rec_adv_auto_matching_db VARCHAR(20) DEFAULT 'FALSE',
    rec_adv_matching_option_db VARCHAR(25),
    receiving_advice_type_db VARCHAR(30),
    self_billing_match_option_db VARCHAR(30),
    sbi_auto_approval_user VARCHAR(30),
    rec_adv_auto_approval_user VARCHAR(30),
    adv_inv_full_pay_db VARCHAR(20) DEFAULT 'FALSE',
    release_internal_order_db VARCHAR(20) DEFAULT 'MANUALLY',
    credit_control_group_id VARCHAR(10) DEFAULT '*',
    backorder_option_db VARCHAR(40),
    priority NUMERIC(20,2),
    receive_pack_size_chg_db VARCHAR(20) DEFAULT 'FALSE',
    summarized_freight_charges_db VARCHAR(20) DEFAULT 'Y',
    print_delivered_lines_db VARCHAR(23) DEFAULT 'SHIPMENT',
    email_order_conf_db VARCHAR(20) DEFAULT 'TRUE',
    email_invoice_db VARCHAR(20) DEFAULT 'FALSE',
    allow_auto_sub_of_parts_db VARCHAR(5) DEFAULT 'FALSE',
    b2b_auto_create_co_from_sq_db VARCHAR(20) DEFAULT 'FALSE',
    print_withholding_tax_db VARCHAR(5) DEFAULT 'FALSE',
    consol_rental_ivc_serial_db VARCHAR(20) DEFAULT 'SPECIFIED ON COMPANY',
    exclude_from_scan_order VARCHAR(5),
    default_inv_currency VARCHAR(5),
    confirm_direct_deliveries VARCHAR(5),
    cr_stop VARCHAR(4000),
    invoice_sort VARCHAR(4000),
    order_conf_flag VARCHAR(4000),
    pack_list_flag VARCHAR(4000),
    category VARCHAR(4000),
    edi_auto_order_approval VARCHAR(4000),
    edi_auto_change_approval VARCHAR(4000),
    template_customer VARCHAR(4000),
    quick_registered_customer VARCHAR(4000),
    commission_receiver VARCHAR(4000),
    summarized_source_lines VARCHAR(4000),
    summarized_source_lines_db VARCHAR(20) DEFAULT 'Y',
    send_change_message VARCHAR(4000),
    send_change_message_db VARCHAR(20) DEFAULT 'N',
    replicate_doc_text VARCHAR(4000),
    replicate_doc_text_db VARCHAR(20),
    mul_tier_del_notification VARCHAR(4000),
    match_type VARCHAR(4000),
    print_amounts_incl_tax VARCHAR(4000),
    confirm_deliveries VARCHAR(4000),
    check_sales_grp_deliv_conf VARCHAR(4000),
    handl_unit_at_co_delivery VARCHAR(4000),
    update_price_from_sbi VARCHAR(4000),
    rec_adv_auto_match_diff VARCHAR(4000),
    rec_adv_auto_matching VARCHAR(4000),
    rec_adv_matching_option VARCHAR(4000),
    receiving_advice_type VARCHAR(4000),
    self_billing_match_option VARCHAR(4000),
    adv_inv_full_pay VARCHAR(4000),
    release_internal_order VARCHAR(4000),
    backorder_option VARCHAR(4000),
    receive_pack_size_chg VARCHAR(4000),
    summarized_freight_charges VARCHAR(4000),
    print_delivered_lines VARCHAR(4000),
    email_order_conf VARCHAR(4000),
    email_invoice VARCHAR(4000),
    allow_auto_sub_of_parts VARCHAR(4000),
    b2b_auto_create_co_from_sq VARCHAR(4000),
    print_withholding_tax VARCHAR(4000),
    consol_rental_ivc_serial VARCHAR(4000),
    name VARCHAR(100),
    CONSTRAINT pk_cust_ord_customer PRIMARY KEY (customer_no)
);

COMMENT ON COLUMN clean_data.cust_ord_customer.customer_no IS 'N° Client - ID client';
COMMENT ON COLUMN clean_data.cust_ord_customer.cust_grp IS 'Groupe statistique client';
COMMENT ON COLUMN clean_data.cust_ord_customer.cycle_period IS 'Intervalle cyclique - Période entre comptages';
COMMENT ON COLUMN clean_data.cust_ord_customer.currency_code IS 'Code devise ISO';
COMMENT ON COLUMN clean_data.cust_ord_customer.category_db IS 'Client int. - E=External, I=Internal';
COMMENT ON COLUMN clean_data.cust_ord_customer.customer_no_pay IS 'Facture client';
COMMENT ON COLUMN clean_data.cust_ord_customer.cust_price_group_id IS 'N° Groupe de tarifs client';
COMMENT ON COLUMN clean_data.cust_ord_customer.salesman_code IS 'Code vendeur';
COMMENT ON COLUMN clean_data.cust_ord_customer.market_code IS 'Code marché';
COMMENT ON COLUMN clean_data.cust_ord_customer.print_control_code IS "Code d'impression";
COMMENT ON COLUMN clean_data.cust_ord_customer.cr_stop_db IS 'Crédit bloqué - Y=Oui, N=Non';
COMMENT ON COLUMN clean_data.cust_ord_customer.cust_ref IS 'Référence client';
COMMENT ON COLUMN clean_data.cust_ord_customer.date_del IS 'Date expiration';
COMMENT ON COLUMN clean_data.cust_ord_customer.invoice_sort_db IS 'Type facture - N=Normal, C=Collective, NC=Normal+Collective';
COMMENT ON COLUMN clean_data.cust_ord_customer.last_ivc_date IS 'Date facturation au plus tard';
COMMENT ON COLUMN clean_data.cust_ord_customer.note_text IS 'Notes';
COMMENT ON COLUMN clean_data.cust_ord_customer.order_conf_flag_db IS 'Confirmation cde - Y=Oui, N=Non';
COMMENT ON COLUMN clean_data.cust_ord_customer.pack_list_flag_db IS 'Bons de livraison - Y=Oui, N=Non';
COMMENT ON COLUMN clean_data.cust_ord_customer.acquisition_site IS 'Site du client';
COMMENT ON COLUMN clean_data.cust_ord_customer.order_id IS 'Type cde';
COMMENT ON COLUMN clean_data.cust_ord_customer.edi_auto_order_approval_db IS 'Approbation autom. sur cde EDI';
COMMENT ON COLUMN clean_data.cust_ord_customer.edi_auto_change_approval_db IS 'Demande changement entrante';
COMMENT ON COLUMN clean_data.cust_ord_customer.edi_authorize_code IS 'ID coordon. EDI';
COMMENT ON COLUMN clean_data.cust_ord_customer.edi_site IS 'Site EDI';
COMMENT ON COLUMN clean_data.cust_ord_customer.edi_auto_approval_user IS 'Approbateur EDI auto.';
COMMENT ON COLUMN clean_data.cust_ord_customer.template_id IS 'ID modèle';
COMMENT ON COLUMN clean_data.cust_ord_customer.discount IS 'Remise';
COMMENT ON COLUMN clean_data.cust_ord_customer.discount_type IS 'Type de remise';
COMMENT ON COLUMN clean_data.cust_ord_customer.min_sales_amount IS 'Mont. min. ventes';
COMMENT ON COLUMN clean_data.cust_ord_customer.note_id IS 'Id note';
COMMENT ON COLUMN clean_data.cust_ord_customer.template_customer_desc IS 'Nom client modèle';
COMMENT ON COLUMN clean_data.cust_ord_customer.template_customer_db IS 'Client modèle - TEMPLATE ou NOT_TEMPLATE';
COMMENT ON COLUMN clean_data.cust_ord_customer.quick_registered_customer_db IS 'Enreg. rapide du client - QUICK ou NORMAL';
COMMENT ON COLUMN clean_data.cust_ord_customer.commission_receiver_db IS 'Destinataire commission - CREATE ou DONOTCREATE';
COMMENT ON COLUMN clean_data.cust_ord_customer.no_delnote_copies IS 'Nbre de copies bon de livr.';
COMMENT ON COLUMN clean_data.cust_ord_customer.forward_agent_id IS 'ID expéditeur';
-- Commentaires sur les nouveaux champs
COMMENT ON COLUMN clean_data.cust_ord_customer.auto_despatch_adv_send IS 'Envoi autom. avis assignation';
COMMENT ON COLUMN clean_data.cust_ord_customer.mul_tier_del_notification_db IS 'Avis de livraison à plusieurs niveaux';
COMMENT ON COLUMN clean_data.cust_ord_customer.match_type_db IS 'Type de rapproch. - NOAUTO, AUTO, AUTOCREATE, AUTOCREATEPOST';
COMMENT ON COLUMN clean_data.cust_ord_customer.print_amounts_incl_tax_db IS 'Imprimer montants TTC';
COMMENT ON COLUMN clean_data.cust_ord_customer.confirm_deliveries_db IS 'Confirmer livraisons';
COMMENT ON COLUMN clean_data.cust_ord_customer.check_sales_grp_deliv_conf_db IS 'Vérifier param. grpe de vente';
COMMENT ON COLUMN clean_data.cust_ord_customer.handl_unit_at_co_delivery_db IS 'Unité manut à livraison cde client';
COMMENT ON COLUMN clean_data.cust_ord_customer.update_price_from_sbi_db IS 'MÀJ prix à partir de fact. auto.';
COMMENT ON COLUMN clean_data.cust_ord_customer.rec_adv_auto_match_diff_db IS 'Rapproch. autom. des écarts';
COMMENT ON COLUMN clean_data.cust_ord_customer.rec_adv_auto_matching_db IS 'Rapproch. autom.';
COMMENT ON COLUMN clean_data.cust_ord_customer.rec_adv_matching_option_db IS 'Option rappr.';
COMMENT ON COLUMN clean_data.cust_ord_customer.receiving_advice_type_db IS 'Type avis réception';
COMMENT ON COLUMN clean_data.cust_ord_customer.self_billing_match_option_db IS 'Option rapproch.autofact.';
COMMENT ON COLUMN clean_data.cust_ord_customer.sbi_auto_approval_user IS 'Signataire';
COMMENT ON COLUMN clean_data.cust_ord_customer.rec_adv_auto_approval_user IS 'Identité approbateur EDI avis réception';
COMMENT ON COLUMN clean_data.cust_ord_customer.adv_inv_full_pay_db IS 'Chèq. paiem. entier facture';
COMMENT ON COLUMN clean_data.cust_ord_customer.release_internal_order_db IS 'Release Internal Customer Order';
COMMENT ON COLUMN clean_data.cust_ord_customer.credit_control_group_id IS 'Gr. contrôle crédit';
COMMENT ON COLUMN clean_data.cust_ord_customer.backorder_option_db IS 'Option cde souffr.';
COMMENT ON COLUMN clean_data.cust_ord_customer.priority IS 'Priorité';
COMMENT ON COLUMN clean_data.cust_ord_customer.receive_pack_size_chg_db IS 'Recevoir frais/remise taille colis';
COMMENT ON COLUMN clean_data.cust_ord_customer.summarized_freight_charges_db IS 'Summarized Freight Charges';
COMMENT ON COLUMN clean_data.cust_ord_customer.print_delivered_lines_db IS 'Afficher uniquement lignes livrées avec bon de livraison';
COMMENT ON COLUMN clean_data.cust_ord_customer.email_order_conf_db IS 'Confirmation cde par email';
COMMENT ON COLUMN clean_data.cust_ord_customer.email_invoice_db IS 'Facture par email';
COMMENT ON COLUMN clean_data.cust_ord_customer.allow_auto_sub_of_parts_db IS 'Autoriser substitution auto articles';
COMMENT ON COLUMN clean_data.cust_ord_customer.b2b_auto_create_co_from_sq_db IS 'Création auto OM B2B depuis séq';
COMMENT ON COLUMN clean_data.cust_ord_customer.print_withholding_tax_db IS 'Imprimer taxe retenue';
COMMENT ON COLUMN clean_data.cust_ord_customer.consol_rental_ivc_serial_db IS 'Consolider lignes facture location articles sérialisés';
COMMENT ON COLUMN clean_data.cust_ord_customer.exclude_from_scan_order IS 'Exclure de scan order';
COMMENT ON COLUMN clean_data.cust_ord_customer.default_inv_currency IS 'Devise facture par défaut';
COMMENT ON COLUMN clean_data.cust_ord_customer.confirm_direct_deliveries IS 'Confirmer livraisons directes';
-- Commentaires champs affichage
COMMENT ON COLUMN clean_data.cust_ord_customer.cr_stop IS 'Crédit bloqué (affichage)';
COMMENT ON COLUMN clean_data.cust_ord_customer.invoice_sort IS 'Type facture (affichage)';
COMMENT ON COLUMN clean_data.cust_ord_customer.order_conf_flag IS 'Confirmation cde (affichage)';
COMMENT ON COLUMN clean_data.cust_ord_customer.pack_list_flag IS 'Bons de livraison (affichage)';
COMMENT ON COLUMN clean_data.cust_ord_customer.category IS 'Client int. (affichage)';
COMMENT ON COLUMN clean_data.cust_ord_customer.edi_auto_order_approval IS 'Approbation autom. EDI (affichage)';
COMMENT ON COLUMN clean_data.cust_ord_customer.edi_auto_change_approval IS 'Demande changement (affichage)';
COMMENT ON COLUMN clean_data.cust_ord_customer.template_customer IS 'Client modèle (affichage)';
COMMENT ON COLUMN clean_data.cust_ord_customer.quick_registered_customer IS 'Enreg. rapide (affichage)';
COMMENT ON COLUMN clean_data.cust_ord_customer.commission_receiver IS 'Destinataire commission (affichage)';
COMMENT ON COLUMN clean_data.cust_ord_customer.summarized_source_lines IS 'Lignes approvis. résumées (affichage)';
COMMENT ON COLUMN clean_data.cust_ord_customer.summarized_source_lines_db IS 'Lignes approvis. résumées';
COMMENT ON COLUMN clean_data.cust_ord_customer.send_change_message IS 'Envoyer Confirmation Cde (affichage)';
COMMENT ON COLUMN clean_data.cust_ord_customer.send_change_message_db IS 'Envoyer Confirmation Cde';
COMMENT ON COLUMN clean_data.cust_ord_customer.replicate_doc_text IS 'Répliquer text doc. (affichage)';
COMMENT ON COLUMN clean_data.cust_ord_customer.replicate_doc_text_db IS 'Répliquer text doc.';
COMMENT ON COLUMN clean_data.cust_ord_customer.name IS 'Nom';


