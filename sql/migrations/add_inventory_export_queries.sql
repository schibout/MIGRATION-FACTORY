-- Migration: Ajout des requêtes d'export pour les tables d'inventaire (articles)
-- Date: 2025-02-12
-- Description: Ajouter les tables inventory dans etl_export_queries pour l'export

-- Supprimer les anciennes entrées si elles existent
DELETE FROM etl_export_queries WHERE table_schema = 'clean_data' AND category = 'inventory';

-- ifs_article_maitre
INSERT INTO etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by) 
VALUES (
    'ifs_article_maitre',
    'clean_data',
    'Articles Maîtres IFS',
    'numero_article, designation, designation_courte, ancien_numero, type_article, libelle_type_article, groupe_article, libelle_groupe_article, secteur_activite, unite_base, unite_commande, nombre_centres_actifs, centres_list, groupes_achat_list, strategies_list, stock_minimum_total, stock_securite_total, stock_maximum_total, avec_gestion_lot, profils_serie_list, organisations_commerciales_list, canaux_distribution_list, statuts_commerciaux_list, cercles_evaluation_list, prix_moyen_pondere_moyen, prix_standard_moyen, stock_quantite_total, valeur_stock_total, classes_evaluation_list, nombre_magasins, stock_total_libre, stock_total_bloque, stock_total_controle, valeur_stock_magasins_total, fournisseur_principal, unite_commande_achat, nom_fournisseur_principal, pays_fournisseur_principal, ville_fournisseur_principal, actif_dans_centre, actif_commercial, actif_evaluation, actif_achat, avec_stock, statut_utilisation, date_creation, createur, date_modification, modificateur, langue, codification_id',
    'Table des articles maîtres SAP pour migration vers IFS',
    'inventory',
    true,
    'admin',
    'admin'
);

-- part_catalog
INSERT INTO etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by) 
VALUES (
    'part_catalog',
    'clean_data',
    'Catalogue des pièces',
    'part_no, description, unit_code, lot_tracking_code_db, serial_rule_db, serial_tracking_code_db, eng_serial_tracking_code_db, configurable_db, condition_code_usage_db, sub_lot_rule_db, lot_quantity_rule_db, position_part_db, catch_unit_enabled_db, multilevel_tracking_db, component_lot_rule_db, stop_arrival_issued_serial_db, allow_as_not_consumed_db, receipt_issue_serial_track_db, stop_new_serial_in_rma_db',
    'Catalogue des pièces IFS avec règles de gestion (lots, séries, configuration)',
    'inventory',
    true,
    'admin',
    'admin'
);

-- inventory_part
INSERT INTO etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by) 
VALUES (
    'inventory_part',
    'clean_data',
    'Articles en stock',
    'contract, part_no, description, unit_meas, part_status, planner_buyer, asset_class, country_of_origin, type_code_db, supply_code_db, expected_leadtime, manuf_leadtime, purch_leadtime, lead_time_code_db, inventory_valuation_method_db, count_variance, cycle_code_db, cycle_period, qty_calc_rounding, zero_cost_flag_db, oe_alloc_assign_flag_db, onhand_analysis_flag_db, shortage_flag_db, forecast_consumption_flag_db, stock_management_db, dop_connection_db, negative_on_hand_db, invoice_consideration_db, inventory_part_cost_level_db, ext_service_cost_method_db, automatic_capability_check_db, dop_netting_db, co_reserve_onh_analys_flag_db, mandatory_expiration_date_db, excl_ship_pack_proposal_db, lifecycle_stage_db, frequency_class_db, avail_activity_status_db, abc_class, hsn_sac_code',
    'Articles en stock IFS avec valorisation, délais et flags de gestion',
    'inventory',
    true,
    'admin',
    'admin'
);

-- invent_part_plan (inventory_part_planning)
INSERT INTO etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by) 
VALUES (
    'invent_part_plan',
    'clean_data',
    'Planification articles en stock',
    'contract, part_no, last_activity_date, lot_size, lot_size_auto, lot_size_auto_db, max_order_qty, min_order_qty, mul_order_qty, std_order_size, order_point_qty, order_point_qty_auto, order_point_qty_auto_db, safety_stock, safety_stock_auto, safety_stock_auto_db, safety_lead_time, maxweek_supply, setup_cost, carry_rate, service_rate, shrinkage_fac, planning_method, planning_method_auto, planning_method_auto_db, order_requisition, order_requisition_db, proposal_release, proposal_release_db, percent_manufactured, percent_acquired, split_manuf_acquired, split_manuf_acquired_db, acquired_supply_type, acquired_supply_type_db, manuf_supply_type, manuf_supply_type_db, sched_capacity, sched_capacity_db',
    'Planification des articles en stock (lots, points de commande, méthode MRP)',
    'inventory',
    true,
    'admin',
    'admin'
);

-- purchase_part
INSERT INTO etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by) 
VALUES (
    'purchase_part',
    'clean_data',
    'Articles achat',
    'contract, part_no, description, default_buy_unit_meas, close_code_db, close_tolerance, inventory_flag_db, over_delivery_tolerance, over_delivery_db, process_type, standard_pack_size, taxable_db, dop_pegged_po_update_flag_db, acquisition_type_db, action_non_authorized_db, action_authorized_db, external_resource_db, qualified_manufacturer_db, qualified_supplier_db',
    'Articles achat IFS avec paramètres de réception et tolérance',
    'inventory',
    true,
    'admin',
    'admin'
);

-- purchase_part_supplier
INSERT INTO etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by) 
VALUES (
    'purchase_part_supplier',
    'clean_data',
    'Fournisseurs par article achat',
    'contract, part_no, vendor_no, buy_unit_meas, currency_code, status_code, primary_vendor_db, leadtime_auto_db, receive_case_db, external_service_allowed_db, part_ownership_db, dist_order_receipt_type_db, multisite_planned_part_db, quick_registered_part_db, purchase_payment_type_db, acquisition_type_db, rental_primary_vendor_db, use_price_incl_tax_db, qualified_supplier_db, ext_svc_primary_vendor_db, issue_packaging_material_db',
    'Relations article-fournisseur pour les achats (depuis EINA/EINE SAP)',
    'inventory',
    true,
    'admin',
    'admin'
);

-- sales_part
INSERT INTO etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by) 
VALUES (
    'sales_part',
    'clean_data',
    'Articles de vente',
    'contract, catalog_no, catalog_desc, sales_unit_meas, catalog_group, sales_price_group_id, part_no, activeind_db, catalog_type_db, conv_factor, inverted_conv_factor, price_conv_factor, price_unit_meas, list_price, list_price_incl_tax, rental_list_price, rental_list_price_incl_tax, cost, expected_average_price, taxable_db, tax_code, tax_class_id, use_price_incl_tax_db, date_entered, price_change_date, close_tolerance, minimum_qty, sourcing_option_db, create_sm_object_option_db, quick_registered_part_db, export_to_external_app_db, allow_inc_pkg_rsrv_picklst, allow_incomp_pkg_delivery, pack_comp_in_shpmnt, sales_type_db, primary_catalog_db, delivery_type, non_inv_part_type_db, customs_stat_no, country_of_origin, statistical_code',
    'Articles de vente IFS avec prix, taxes et options commerciales',
    'inventory',
    true,
    'admin',
    'admin'
);

-- Vérification
SELECT id, table_name, display_name, category, is_active 
FROM etl_export_queries 
WHERE category = 'inventory' 
ORDER BY table_name;
