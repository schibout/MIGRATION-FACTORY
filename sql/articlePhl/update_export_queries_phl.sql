-- Export des articles PHL
-- =========================
-- Les articles PHL sont charges dans les MEMES tables clean_data que les articles SAP
-- (part_catalog, inventory_part, sales_part, purchase_part). La table etl_export_queries
-- a une contrainte UNIQUE (table_schema, table_name) : on ne peut donc PAS creer d'entrees
-- d'export dediees PHL pour ces tables.
--
-- => Les articles PHL sont DEJA exportes via les entrees existantes de la categorie
--    'inventory' (l'export lit toute la table, lignes SAP + PHL confondues).
--
-- Ce script se contente de rafraichir le column_list de inventory_part pour y inclure
-- la colonne reset_config_std_cost_db ajoutee recemment (sinon elle n'est pas exportee).

UPDATE etl_export_queries
SET column_list =
    'contract, part_no, description, unit_meas, part_status, planner_buyer, asset_class, '
    'country_of_origin, type_code_db, supply_code_db, expected_leadtime, manuf_leadtime, '
    'purch_leadtime, lead_time_code_db, inventory_valuation_method_db, count_variance, '
    'cycle_code_db, cycle_period, qty_calc_rounding, zero_cost_flag_db, oe_alloc_assign_flag_db, '
    'onhand_analysis_flag_db, shortage_flag_db, forecast_consumption_flag_db, stock_management_db, '
    'dop_connection_db, negative_on_hand_db, invoice_consideration_db, inventory_part_cost_level_db, '
    'ext_service_cost_method_db, automatic_capability_check_db, dop_netting_db, '
    'co_reserve_onh_analys_flag_db, mandatory_expiration_date_db, excl_ship_pack_proposal_db, '
    'reset_config_std_cost_db, lifecycle_stage_db, frequency_class_db, avail_activity_status_db, '
    'abc_class, hsn_sac_code',
    updated_by = 'phl_migration',
    updated_at = CURRENT_TIMESTAMP
WHERE table_schema = 'clean_data'
  AND table_name = 'inventory_part';

-- Verification
SELECT table_name, table_schema, category, is_active,
       (column_list LIKE '%reset_config_std_cost_db%') AS contient_reset_config
FROM etl_export_queries
WHERE table_schema = 'clean_data'
  AND table_name IN ('part_catalog', 'inventory_part', 'sales_part', 'purchase_part')
ORDER BY table_name;
