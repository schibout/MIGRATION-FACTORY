-- Migration: Création de la table etl_export_queries
-- Date: 2024-01-15
-- Description: Table pour stocker dynamiquement les requêtes d'export
-- Version: 1.1 - Correction des noms de tables (majuscules → minuscules)

-- Création de la table
CREATE TABLE IF NOT EXISTS etl_export_queries (
    id SERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    table_schema VARCHAR(50) NOT NULL DEFAULT 'public',
    display_name VARCHAR(255) NOT NULL,
    sql_query TEXT NOT NULL,
    description TEXT,
    category VARCHAR(50) DEFAULT 'supplier',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100) DEFAULT 'system',
    updated_by VARCHAR(100) DEFAULT 'system',
    
    -- Index pour optimiser les requêtes
    CONSTRAINT unique_table_schema_name UNIQUE (table_schema, table_name)
);

-- Création des index
CREATE INDEX IF NOT EXISTS idx_etl_export_queries_category ON etl_export_queries(category);
CREATE INDEX IF NOT EXISTS idx_etl_export_queries_active ON etl_export_queries(is_active);
CREATE INDEX IF NOT EXISTS idx_etl_export_queries_table_name ON etl_export_queries(table_name);
CREATE INDEX IF NOT EXISTS idx_etl_export_queries_schema ON etl_export_queries(table_schema);

-- Suppression des anciennes données pour éviter les conflits
DELETE FROM etl_export_queries WHERE table_schema = 'public';

-- Insertion des requêtes avec noms de tables corrigés (minuscules)
INSERT INTO etl_export_queries (table_name, table_schema, display_name, sql_query, description, category) VALUES 
(
    'supplier_info_general',
    'public',
    'Informations Générales Fournisseur',
    'SELECT 
      supplier_id, name, creation_date, association_no, party, default_domain,
      default_language, default_language_db, country, country_db, party_type,
      party_type_db, suppliers_own_id, corporate_form, identifier_reference,
      identifier_ref_validation, identifier_ref_validation_db, picture_id, one_time,
      one_time_db, supplier_category, supplier_category_db, b2b_supplier,
      b2b_supplier_db, business_classification
    FROM supplier_info_general',
    'Informations générales et métadonnées des fournisseurs',
    'supplier'
),
(
    'supplier_info_address',
    'public',
    'Adresses Fournisseur',
    'SELECT 
      supplier_id, address_id, name, address, ean_location, valid_from,
      valid_to, party, default_domain, country, country_db, party_type,
      party_type_db, address1, address2, address3, address4, address5,
      address6, zip_code, city, county, state, comm_id, output_media,
      output_media_db, supplier_branch
    FROM supplier_info_address',
    'Adresses et informations de localisation des fournisseurs',
    'supplier'
),
(
    'supplier_info_address_type',
    'public',
    'Types d''Adresses Fournisseur',
    'SELECT 
      supplier_id, address_id, address_type_code, address_type_code_db,
      party, def_address, default_domain
    FROM supplier_info_address_type',
    'Types et catégories d''adresses des fournisseurs',
    'supplier'
),
(
    'supplier_info_our_id',
    'public',
    'Identifiants Internes Fournisseur',
    'SELECT supplier_id, company FROM supplier_info_our_id',
    'Identifiants internes utilisés pour les fournisseurs',
    'supplier'
),
(
    'comm_method',
    'public',
    'Méthodes de Communication',
    'SELECT 
      party_type, party_type_db, identity, comm_id, value, description,
      valid_from, valid_to, method_default, address_default, name,
      method_id, method_id_db, address_id, customer_id, supplier_id,
      company_id, person_id, customs_id, forwarder_id, manufacturer_id,
      owner_id, tax_office_id
    FROM comm_method',
    'Méthodes de communication (email, téléphone, fax, etc.)',
    'communication'
),
(
    'supplier_address',
    'public',
    'Adresses de Livraison Fournisseur',
    'SELECT 
      vendor_no, addr_no, delivery_terms, ship_via_code, route_id,
      contact, intrastat_exempt, intrastat_exempt_db, del_terms_location,
      supplier_calendar_id
    FROM supplier_address',
    'Adresses de livraison et conditions logistiques',
    'supplier'
),
(
    'supplier_document_tax_info',
    'public',
    'Informations Fiscales Fournisseur',
    'SELECT 
      supplier_id, address_id, company, tax_id_type, vat_no,
      validated_date, reliability_status, reliability_status_db,
      declaration_date, last_modify_date, tax_office_id
    FROM supplier_document_tax_info',
    'Informations fiscales et documents tax des fournisseurs',
    'tax'
),
(
    'supplier_delivery_tax_code',
    'public',
    'Codes Fiscaux Livraison',
    'SELECT 
      supplier_id, address_id, company, tax_code
    FROM supplier_delivery_tax_code',
    'Codes fiscaux applicables aux livraisons',
    'tax'
),
(
    'supplier',
    'public',
    'Fournisseurs Principaux',
    'SELECT 
      vendor_no, name, buyer_code, currency_code, supp_grp, additional_cost_amount,
      contact, cr_check, cr_check_db, cr_date, cr_note_text, date_del,
      discount, note_text, our_customer_no, pack_list_flag, pack_list_flag_db,
      purch_order_flag, purch_order_flag_db, qc_approval, qc_approval_db,
      qc_date, qc_audit, qc_note_text, ord_conf_rem_interval, delivery_rem_interval,
      days_before_delivery, days_before_arrival, ord_conf_reminder, ord_conf_reminder_db,
      delivery_reminder, delivery_reminder_db, category, category_db, acquisition_site,
      company, pay_term_id, edi_auto_approval_user, qc_type, environment_date,
      environment_type, environmental_approval, environmental_approval_db, environment_audit,
      environment_note_text, coc_approval, coc_approval_db, coc_date, coc_type,
      coc_audit, coc_note_text, customer_no, note_id, supplier_template_desc,
      template_supplier, template_supplier_db, quick_registered_supplier,
      quick_registered_supplier_db, blanket_date, blanket_date_db, express_order_allowed,
      express_order_allowed_db, edi_pri_cat_app_user, pricat_automatic_approval,
      pricat_automatic_approval_db, automatic_repl_change, automatic_repl_change_db,
      send_change_message, send_change_message_db, receipt_ref_reminder,
      receipt_ref_reminder_db, print_amounts_incl_tax, print_amounts_incl_tax_db,
      closing_day, end_of_month, end_of_month_db, receiving_advice_type,
      receiving_advice_type_db, rec_adv_self_billing, rec_adv_self_billing_db,
      classification_standard, purchase_code, po_change_management, po_change_management_db,
      create_confirmation_chg_ord, create_confirmation_chg_ord_db, email_purchase_order,
      email_purchase_order_db, vendor_category_db, dir_del_approval, dir_del_approval_db,
      order_conf_approval, order_conf_approval_db, order_conf_diff_approval,
      order_conf_diff_approval_db, adhoc_pur_rqst_approval, adhoc_pur_rqst_approval_db,
      tax_liability, b2b_conf_order_with_diff, b2b_conf_order_with_diff_db,
      quality_system_level_id, quality_audit_id, environment_audit_id, coc_audit_id,
      rec_adv_sb_consignment, rec_adv_sb_consignment_db, rec_adv_sb_mix_ownership,
      rec_adv_sb_mix_ownership_db
    FROM supplier',
    'Table principale des fournisseurs avec toutes les informations détaillées',
    'supplier'
),
(
    'identity_invoice_info',
    'public',
    'Informations Facturation',
    'SELECT 
      company, identity, party_type, party_type_db, invoice_fee, expire_date,
      national_bank_code, group_id, def_authorizer, pay_term_id, def_vat_code,
      rounding_tax_code, def_currency, paym_dev_days, identity_type, identity_type_db,
      def_preliminary_code, automatic_invoice, percent_tolerance, amount_tolerance,
      ncf_reference_check, tax_exempt, tax_exempt_valid_from, tax_exempt_valid_to, 
      second_tin, report_and_withhold, report_and_withhold_db, supplier_tax_office_id,
      numeration_group, tax_book_id, tax_book_type, tax_structure_id,
      print_tax_code_text, no_invoice_copies
    FROM identity_invoice_info',
    'Informations de facturation et paramètres fiscaux',
    'payment'
),
(
    'identity_pay_info',
    'public',
    'Informations Paiement',
    'SELECT 
      company, identity, party_type, party_type_db, priority, blocked_for_payment,
      other_payee_identity, interest_template, reminder_template, payment_delay,
      amount_tolerance, percent_tolerance, disc_days_tolerance, netting_allowed,
      format_no, payment_advice, payment_advice_db, deduction_group, corporation_id,
      member_id, send_reminder_to_payer, send_interest_inv_to_payer, rule_id,
      payment_receipt_type, payment_receipt_type_db, template_id, check_recipient,
      check_recipient_db, send_stmt_of_acc_to_payer, ar_contact, comm_id,
      output_media, output_media_db, default_payment_method, customer_id,
      supplier_id, next_payment_matching_id, is_one_inv_per_pay, is_one_inv_per_pay_db,
      payment_mode, payment_mode_db
    FROM identity_pay_info',
    'Informations et conditions de paiement',
    'payment'
),
(
    'payment_way_per_identity',
    'public',
    'Méthodes de Paiement par Identité',
    'SELECT 
      identity, party_type, party_type_db, way_id, default_payment_way
    FROM payment_way_per_identity',
    'Méthodes de paiement associées à chaque identité',
    'payment'
),
(
    'payment_address',
    'public',
    'Adresses de Paiement',
    'SELECT 
      company, identity, party_type, party_type_db, way_id, address_id,
      description, default_address, account, data1, data2, data3, data4,
      data5, data6, data7, data8, data9, data10, data11, data12,
      data13, data14, data15, data16, data17, data18, data18_db,
      data19, data19_db, data20, data20_db, data21, data22, data23,
      data24, data25, data26, data27, data28, data29, data30,
      data31, data32, data33, data34, data35, data36, data37,
      data38, data39, data40, data41, bic_code, blocked_for_use,
      mapping_type, bank_account_validated, bank_account_validated_db,
      bank_account_valid_date
    FROM payment_address',
    'Adresses et informations bancaires pour les paiements',
    'payment'
),
(
    'supplier_tax_info',
    'public',
    'Informations Fiscales Fournisseur Avancées',
    'SELECT 
      supplier_id, address_id, company, use_supp_address_for_tax,
      use_supp_address_for_tax_db, tax_calc_structure_id, icms_tax_payer,
      icms_tax_payer_db, business_transaction_id
    FROM supplier_tax_info',
    'Informations fiscales avancées et paramètres de calcul',
    'tax'
),
(
    'supplier_info_contact',
    'public',
    'Contacts Fournisseur',
    'SELECT 
      supplier_id, person_id, guid, role, role_db, supplier_primary,
      supplier_primary_db, name, title, first_name, last_name, middle_name,
      initials, user_id, active, active_db, web_user, web_user_db,
      block_date, block_date_db, login_name, picture_id, mobile_phone,
      company_id, pager_number, fax, e_mail, intercom, www, messenger,
      valid_from, valid_to, person_type, person_type_db, category,
      category_db, default_domain, ext_identity, source_identity,
      source_key_reference, creation_date, party
    FROM supplier_info_contact',
    'Personnes de contact et informations de communication',
    'supplier'
);

-- Création d'un trigger pour mettre à jour automatiquement updated_at
CREATE OR REPLACE FUNCTION update_etl_export_queries_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER trigger_etl_export_queries_updated_at
    BEFORE UPDATE ON etl_export_queries
    FOR EACH ROW
    EXECUTE FUNCTION update_etl_export_queries_updated_at();

-- Commentaires sur la table
COMMENT ON TABLE etl_export_queries IS 'Table contenant les requêtes SQL configurables pour les exports de données';
COMMENT ON COLUMN etl_export_queries.table_name IS 'Nom de la table (unique par schéma)';
COMMENT ON COLUMN etl_export_queries.table_schema IS 'Schéma de la table (public, raw_data, etc.)';
COMMENT ON COLUMN etl_export_queries.display_name IS 'Nom affiché dans l''interface utilisateur';
COMMENT ON COLUMN etl_export_queries.sql_query IS 'Requête SQL SELECT à exécuter';
COMMENT ON COLUMN etl_export_queries.description IS 'Description de la table et de son contenu';
COMMENT ON COLUMN etl_export_queries.category IS 'Catégorie pour grouper les tables (supplier, payment, tax, etc.)';
COMMENT ON COLUMN etl_export_queries.is_active IS 'Indique si la requête est disponible pour l''export'; 