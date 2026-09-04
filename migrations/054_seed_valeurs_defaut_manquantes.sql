-- =====================================================================
-- Rejeu complet des valeurs par defaut ETL
--
-- Genere par sql/config/generer_valeurs_defaut_manquantes.py
-- Chaque INSERT est en ON CONFLICT DO NOTHING : le script est rejouable
-- et ne remplace jamais une valeur ajustee depuis l'ecran
-- /configuration/valeurs-defaut.
-- =====================================================================

BEGIN;

-- --- module articlePhl (187 ligne(s)) ----------------------------------------
-- 4 de ces lignes ne sont appelees par aucun get_default_value du depot :
-- elles ne changent rien au chargement, elles rendent la constante visible et modifiable dans l'ecran.
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'abc_class', 'STANDARD', 'NULL', NULL, 'Source : ajouter_article_silicium.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'asset_class', 'STANDARD', 'CONSTANTE', 'S', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'automatic_capability_check_db', 'STANDARD', 'CONSTANTE', 'NO AUTOMATIC CAPABILITY CHECK', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'avail_activity_status_db', 'STANDARD', 'CONSTANTE', 'CHANGED', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'c_density', 'FIL', 'NULL', NULL, 'Densite non requise pour les articles FIL (familles 21, 22, 23, RF) - source : alimenter_inventory_part_phl.sql', 'TRUE')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'c_density', 'STANDARD', 'CONSTANTE', '2.7', 'Source : alimenter_inventory_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'c_spire_code', 'STANDARD', 'CONSTANTE', 'S', 'Source : alimenter_inventory_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'co_reserve_onh_analys_flag_db', 'STANDARD', 'CONSTANTE', 'N', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'company', 'STANDARD', 'CONSTANTE', 'SJM', 'Source : alimenter_inventory_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'contract', 'STANDARD', 'CONSTANTE', 'SJ', 'Source : alimenter_inventory_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'count_variance', 'STANDARD', 'CONSTANTE', '0', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'country_of_origin', 'STANDARD', 'NULL', NULL, 'Source : ajouter_article_silicium.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'cycle_code_db', 'STANDARD', 'CONSTANTE', 'N', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'cycle_period', 'STANDARD', 'CONSTANTE', '0', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'dop_connection_db', 'STANDARD', 'CONSTANTE', 'AUT', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'dop_netting_db', 'STANDARD', 'CONSTANTE', 'NONET', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'excl_ship_pack_proposal_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'expected_leadtime', 'STANDARD', 'CONSTANTE', '0', 'Source : ajouter_article_silicium.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'ext_service_cost_method_db', 'STANDARD', 'CONSTANTE', 'EXCLUDE SERVICE COST', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'forecast_consumption_flag_db', 'STANDARD', 'CONSTANTE', 'FORECAST', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'frequency_class_db', 'STANDARD', 'CONSTANTE', 'VERY SLOW MOVER', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'hsn_sac_code', 'STANDARD', 'NULL', NULL, 'Source : ajouter_article_silicium.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'intrastat_conv_factor', 'STANDARD', 'NULL', NULL, 'Source : alimenter_inventory_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'inventory_part_cost_level_db', 'STANDARD', 'CONSTANTE', 'COST PER PART', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'inventory_valuation_method_db', 'STANDARD', 'CONSTANTE', 'ST', 'Source : ajouter_article_silicium.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'invoice_consideration_db', 'STANDARD', 'CONSTANTE', 'TRANSACTION BASED', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'lead_time_code_db', 'ARTICLEPHL', 'CONSTANTE', 'Y', 'Source : alimenter_inventory_part_phl.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'lead_time_code_db', 'SILICIUM', 'CONSTANTE', 'P', 'Source : ajouter_article_silicium.sql (article achete)', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'lifecycle_stage_db', 'STANDARD', 'CONSTANTE', 'DEVELOPMENT', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'mandatory_expiration_date_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'manuf_leadtime', 'STANDARD', 'CONSTANTE', '0', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'negative_on_hand_db', 'STANDARD', 'CONSTANTE', 'NEG ONHAND NOT OK', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'oe_alloc_assign_flag_db', 'STANDARD', 'CONSTANTE', 'N', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'onhand_analysis_flag_db', 'STANDARD', 'CONSTANTE', 'N', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'part_status', 'STANDARD', 'CONSTANTE', 'A', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'planner_buyer', 'STANDARD', 'CONSTANTE', '*', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'purch_leadtime', 'STANDARD', 'CONSTANTE', '0', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'qty_calc_rounding', 'STANDARD', 'CONSTANTE', '0', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'reset_config_std_cost_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'shortage_flag_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'stock_management_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'supply_code_db', 'STANDARD', 'CONSTANTE', 'IO', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'type_code_db', 'ARTICLEPHL', 'CONSTANTE', '1', 'Source : alimenter_inventory_part_phl.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'type_code_db', 'SILICIUM', 'CONSTANTE', '3', 'Source : ajouter_article_silicium.sql (article achete)', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'zero_cost_flag_db', 'ARTICLEPHL', 'CONSTANTE', 'Y', 'Source : alimenter_inventory_part_phl.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'zero_cost_flag_db', 'SILICIUM', 'CONSTANTE', 'N', 'Source : ajouter_article_silicium.sql (article achete)', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'auto_replace_alt_comp_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'backflush_part_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'component_scrap', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'configuration_usage_db', 'STANDARD', 'CONSTANTE', 'Common', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'consider_lead_time_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'contract', 'STANDARD', 'CONSTANTE', 'SJ', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'cum_leadtime', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag_db', 'STANDARD', 'CONSTANTE', 'PLANNED', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'engineering_info_db', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'fixed_leadtime_day', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'fixed_leadtime_hour', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'include_firm_demands', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'include_firm_supplies', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'issue_overreported_qty_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'issue_planned_scrap_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'low_level', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'mrp_control_flag_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'optimize_new_delivery_date', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'order_gap_time', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'over_reporting_db', 'STANDARD', 'CONSTANTE', 'ALLOWED', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule', 'STANDARD', 'CONSTANTE', 'DIRECT', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'promise_planned_db', 'STANDARD', 'CONSTANTE', 'Promised', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'routing_effectivity_db', 'STANDARD', 'CONSTANTE', 'DATE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'run_crp', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'run_in_background', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'run_mrp', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'ship_dirty', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'ship_dirty_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'shrinkage_factor', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'structure_effectivity_db', 'STANDARD', 'CONSTANTE', 'DATE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'unprotected_lead_time', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'use_theoritical_density_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'variable_leadtime_day', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'variable_leadtime_hour', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'allow_as_not_consumed_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'catch_unit_enabled_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'component_lot_rule_db', 'ARTICLEPHL', 'CONSTANTE', 'MANY_LOTS_ALLOWED', 'Source : ajouter_article_silicium.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'condition_code_usage_db', 'STANDARD', 'CONSTANTE', 'NOT_ALLOW_COND_CODE', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'configurable_db', 'STANDARD', 'CONSTANTE', 'NOT CONFIGURED', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'eng_serial_tracking_code_db', 'STANDARD', 'CONSTANTE', 'NOT SERIAL TRACKING', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'lot_quantity_rule_db', 'STANDARD', 'CONSTANTE', 'MULTI_LOTS', 'Source : ajouter_article_silicium.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'lot_tracking_code_db', 'STANDARD', 'CONSTANTE', 'LOT TRACKING', 'Source : ajouter_article_silicium.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'multilevel_tracking_db', 'STANDARD', 'CONSTANTE', 'TRACKING_OFF', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'position_part_db', 'STANDARD', 'CONSTANTE', 'NOT POSITION PART', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'receipt_issue_serial_track_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'serial_rule_db', 'STANDARD', 'CONSTANTE', 'MANUAL', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'serial_tracking_code_db', 'STANDARD', 'CONSTANTE', 'NOT SERIAL TRACKING', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'stop_arrival_issued_serial_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'stop_new_serial_in_rma_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'sub_lot_rule_db', 'STANDARD', 'CONSTANTE', 'NO_SUBLOTS', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'acquisition_origin', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'acquisition_reason_id', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'acquisition_type', 'STANDARD', 'CONSTANTE', 'Purchase', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'acquisition_type_db', 'STANDARD', 'CONSTANTE', 'PURCHASE', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'action_authorized', 'STANDARD', 'CONSTANTE', 'Warning', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'action_authorized_db', 'STANDARD', 'CONSTANTE', 'WARNING', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'action_non_authorized', 'STANDARD', 'CONSTANTE', 'Warning', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'action_non_authorized_db', 'STANDARD', 'CONSTANTE', 'WARNING', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'buyer_code', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'close_code', 'STANDARD', 'CONSTANTE', 'Automatic', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'close_code_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'close_tolerance', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'contract', 'STANDARD', 'CONSTANTE', 'SJ', 'Source : alimenter_purchase_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'date_cre', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'dop_pegged_po_update_flag', 'STANDARD', 'CONSTANTE', 'Planned', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'dop_pegged_po_update_flag_db', 'STANDARD', 'CONSTANTE', 'PLANNED', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'eng_attribute', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'external_resource', 'STANDARD', 'CONSTANTE', 'No', 'Source : alimenter_purchase_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'external_resource_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_purchase_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'inventory_flag', 'STANDARD', 'CONSTANTE', 'Yes', 'Source : alimenter_purchase_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'inventory_flag_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : alimenter_purchase_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'nbs_code', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'note_id', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'note_text', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'objid', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'objversion', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'over_delivery', 'STANDARD', 'CONSTANTE', 'Yes', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'over_delivery_db', 'STANDARD', 'CONSTANTE', 'YES', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'over_delivery_tolerance', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'package_part_flag', 'STANDARD', 'CONSTANTE', 'No', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'package_part_flag_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'process_type', 'STANDARD', 'CONSTANTE', 'STD', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'qc_code', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'qc_date', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'qmr_approval_template', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'qsl_approval_template', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'qsr_approval_template', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'qualified_manufacturer', 'STANDARD', 'CONSTANTE', 'No', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'qualified_manufacturer_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'qualified_supplier', 'STANDARD', 'CONSTANTE', 'No', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'qualified_supplier_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'quality_system_level_id', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'standard_pack_size', 'STANDARD', 'CONSTANTE', '1', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'stat_grp', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'statistical_code', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'statistical_code_manuf', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'std_name_description', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'std_name_id', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'taxable', 'STANDARD', 'CONSTANTE', 'Yes', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'taxable_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'technical_coordinator_id', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'activeind_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'allow_inc_pkg_rsrv_picklst', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'allow_incomp_pkg_delivery', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'catalog_group', 'STANDARD', 'CONSTANTE', '903028', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'catalog_type_db', 'STANDARD', 'CONSTANTE', 'INV', 'Source : alimenter_sales_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'close_tolerance', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'contract', 'STANDARD', 'CONSTANTE', 'SJ', 'Source : alimenter_sales_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'conv_factor', 'STANDARD', 'CONSTANTE', '1', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'cost', 'STANDARD', 'NULL', NULL, 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'country_of_origin', 'STANDARD', 'CONSTANTE', 'FR', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'create_sm_object_option_db', 'STANDARD', 'CONSTANTE', 'DONOTCREATESMOBJECT', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'customs_stat_no', 'STANDARD', 'NULL', NULL, 'Source : alimenter_sales_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'delivery_type', 'STANDARD', 'NULL', NULL, 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'expected_average_price', 'STANDARD', 'NULL', NULL, 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'export_to_external_app_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'inverted_conv_factor', 'STANDARD', 'CONSTANTE', '1', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'list_price', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'list_price_incl_tax', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'minimum_qty', 'STANDARD', 'NULL', NULL, 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'non_inv_part_type_db', 'STANDARD', 'NULL', NULL, 'Source : alimenter_sales_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'pack_comp_in_shpmnt', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'price_change_date', 'STANDARD', 'NULL', NULL, 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'price_conv_factor', 'STANDARD', 'CONSTANTE', '1', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'primary_catalog_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'quick_registered_part_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'rental_list_price', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'rental_list_price_incl_tax', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'sales_price_group_id', 'STANDARD', 'CONSTANTE', '*', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'sales_type_db', 'STANDARD', 'CONSTANTE', 'SALES', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'sourcing_option_db', 'STANDARD', 'CONSTANTE', 'NOTSUPPLIED', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'statistical_code', 'STANDARD', 'NULL', NULL, 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'tax_class_id', 'STANDARD', 'NULL', NULL, 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'tax_code', 'STANDARD', 'CONSTANTE', 'C05', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'taxable_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'use_price_incl_tax_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- --- module customer (266 ligne(s)) ------------------------------------------
-- 88 de ces lignes ne sont appelees par aucun get_default_value du depot :
-- elles ne changent rien au chargement, elles rendent la constante visible et modifiable dans l'ecran.
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'address_default', 'EMAIL_PRINCIPAL', 'CONSTANTE', 'TRUE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'address_default', 'FAX', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'address_default', 'FAX_ADRESSE', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'address_default', 'PHONE_ADRESSE', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'address_default', 'PHONE_PRINCIPAL', 'CONSTANTE', 'TRUE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'address_default', 'PHONE_SECONDAIRE', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'address_default', 'TELETEX', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'address_default', 'TELEX', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'description', 'EMAIL_PRINCIPAL', 'CONSTANTE', 'Email principal', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'description', 'FAX', 'CONSTANTE', 'Fax', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'description', 'FAX_ADRESSE', 'CONSTANTE', 'Fax (adresse)', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'description', 'PHONE_ADRESSE', 'CONSTANTE', 'Téléphone (adresse)', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'description', 'PHONE_PRINCIPAL', 'CONSTANTE', 'Téléphone principal', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'description', 'PHONE_SECONDAIRE', 'CONSTANTE', 'Téléphone secondaire', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'description', 'TELETEX', 'CONSTANTE', 'Teletex', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'description', 'TELEX', 'CONSTANTE', 'Telex', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_default', 'EMAIL_PRINCIPAL', 'CONSTANTE', 'TRUE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_default', 'FAX', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_default', 'FAX_ADRESSE', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_default', 'PHONE_ADRESSE', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_default', 'PHONE_PRINCIPAL', 'CONSTANTE', 'TRUE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_default', 'PHONE_SECONDAIRE', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_default', 'TELETEX', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_default', 'TELEX', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id', 'EMAIL_PRINCIPAL', 'CONSTANTE', 'E-Mail', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id', 'FAX', 'CONSTANTE', 'Fax', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id', 'FAX_ADRESSE', 'CONSTANTE', 'Fax', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id', 'PHONE_ADRESSE', 'CONSTANTE', 'Phone', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id', 'PHONE_PRINCIPAL', 'CONSTANTE', 'Phone', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id', 'PHONE_SECONDAIRE', 'CONSTANTE', 'Phone', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id', 'TELETEX', 'CONSTANTE', 'Teletex', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id', 'TELEX', 'CONSTANTE', 'Telex', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id_db', 'EMAIL_PRINCIPAL', 'CONSTANTE', 'E_MAIL', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id_db', 'FAX', 'CONSTANTE', 'FAX', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id_db', 'FAX_ADRESSE', 'CONSTANTE', 'FAX', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id_db', 'PHONE_ADRESSE', 'CONSTANTE', 'PHONE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id_db', 'PHONE_PRINCIPAL', 'CONSTANTE', 'PHONE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id_db', 'PHONE_SECONDAIRE', 'CONSTANTE', 'PHONE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id_db', 'TELETEX', 'CONSTANTE', 'TELETEX', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id_db', 'TELEX', 'CONSTANTE', 'TELEX', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'party_type', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_comm_method_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'party_type_db', 'STANDARD', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_cus_comm_method_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'valid_to', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_comm_method_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'amount_tolerance', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'automatic_invoice', 'STANDARD', 'CONSTANTE', 'N', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'def_authorizer', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'def_preliminary_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'expire_date', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'identity_type', 'CUSTOMER', 'CONSTANTE', 'Customer', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'identity_type_db', 'CUSTOMER', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'invoice_fee', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'ncf_reference_check', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'no_invoice_copies', 'CUSTOMER', 'CONSTANTE', '1', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'numeration_group', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'party_type', 'STANDARD', 'CONSTANTE', 'Customer', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'party_type_db', 'STANDARD', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'paym_dev_days', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'percent_tolerance', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'print_tax_code_text', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'report_and_withhold', 'CUSTOMER', 'CONSTANTE', 'No Report', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'report_and_withhold_db', 'CUSTOMER', 'CONSTANTE', 'NO_REPORT', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'rounding_tax_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'second_tin', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'tax_book_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'tax_book_type', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'tax_exempt', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'tax_exempt_valid_from', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'tax_exempt_valid_to', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'tax_structure_id', 'STANDARD', 'CONSTANTE', 'DEFAULT', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'amount_tolerance', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'ar_contact', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'business_category', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'check_recipient', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'check_recipient_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'comm_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'corporation_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'deduction_group', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'disc_days_tolerance', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'format_no', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'interest_template', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'is_one_inv_per_pay', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'is_one_inv_per_pay_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'member_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'netting_allowed', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'next_payment_matching_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'other_payee_identity', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'output_media', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'output_media_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'party_type', 'STANDARD', 'CONSTANTE', 'Customer', 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'party_type_db', 'STANDARD', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'payment_advice', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'payment_advice_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'payment_delay', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'payment_mode', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'payment_mode_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'payment_receipt_type', 'CUSTOMER', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'payment_receipt_type_db', 'CUSTOMER', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'percent_tolerance', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'predicted_payment_delay', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'predicted_payment_delay_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'priority', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'reminder_template', 'CUSTOMER', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'rule_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'send_interest_inv_to_payer', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'send_reminder_to_payer', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'send_stmt_of_acc_to_payer', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'template_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_paym_way_per_ident', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_cus_paym_way_per_ident_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_paym_way_per_ident', 'default_payment_way', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : sp_insert_cus_paym_way_per_ident_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_paym_way_per_ident', 'party_type', 'STANDARD', 'CONSTANTE', 'Customer', 'Source : sp_insert_cus_paym_way_per_ident_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_paym_way_per_ident', 'party_type_db', 'STANDARD', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_cus_paym_way_per_ident_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_paym_way_per_ident', 'way_id', 'STANDARD', 'CONSTANTE', 'SEPA', 'Source : sp_insert_cus_paym_way_per_ident_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_payment_address', 'bank_account_valid_date', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_payment_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_payment_address', 'bank_account_validated', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_payment_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_payment_address', 'bank_account_validated_db', 'CUSTOMER', 'CONSTANTE', 'NOT VALIDATED', 'Source : sp_insert_cus_payment_address_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_payment_address', 'bic_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_payment_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_payment_address', 'blocked_for_use', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_payment_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_payment_address', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_cus_payment_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_payment_address', 'party_type', 'STANDARD', 'CONSTANTE', 'Customer', 'Source : sp_insert_cus_payment_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_payment_address', 'party_type_db', 'STANDARD', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_cus_payment_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_payment_address', 'way_id', 'STANDARD', 'CONSTANTE', 'SEPA', 'Source : sp_insert_cus_payment_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'acquisition_site', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'category', 'STANDARD', 'CONSTANTE', 'E', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'category_db', 'STANDARD', 'CONSTANTE', 'E', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'commission_receiver', 'STANDARD', 'CONSTANTE', 'DONOTCREATE', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'commission_receiver_db', 'STANDARD', 'CONSTANTE', 'DONOTCREATE', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'cycle_period', 'STANDARD', 'CONSTANTE', '0', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'date_del', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'discount', 'STANDARD', 'CONSTANTE', '0', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'discount_type', 'STANDARD', 'CONSTANTE', 'Standard', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'forward_agent_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'invoice_sort', 'STANDARD', 'CONSTANTE', 'N', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'invoice_sort_db', 'STANDARD', 'CONSTANTE', 'N', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'last_ivc_date', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'order_conf_flag', 'STANDARD', 'CONSTANTE', 'Y', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'order_conf_flag_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'order_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'pack_list_flag', 'STANDARD', 'CONSTANTE', 'Y', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'pack_list_flag_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer_address', 'contact', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer_address', 'cust_calendar_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer_address', 'delivery_time', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer_address', 'intrastat_exempt', 'CUSTOMER', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_address_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer_address', 'intrastat_exempt_db', 'CUSTOMER', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_address_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer_address', 'route_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer_address', 'shipment_type', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer_address', 'shipment_uncon_struct', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer_address', 'shipment_uncon_struct_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_addr_tax_number', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_customer_addr_tax_number_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_addr_tax_number', 'default_tax_id_number', 'STANDARD', 'CONSTANTE', 'True', 'Source : sp_insert_customer_addr_tax_number_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_addr_tax_number', 'default_tax_id_number_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : sp_insert_customer_addr_tax_number_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_addr_tax_number', 'tax_id_type', 'STANDARD', 'CONSTANTE', '', 'Source : sp_insert_customer_addr_tax_number_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'allowed_due_amount', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'allowed_due_days', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'avg_days_for_payment', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'corp_credit_relation_exist', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'credit_analyst_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'credit_comments', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'credit_limit', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'credit_rating', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'credit_relationship_type', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'credit_relationship_type_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'last4q_sales', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'message_type', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'next_review_date', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'note_text', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'parent_company', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'parent_identity', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'party_type', 'STANDARD', 'CONSTANTE', 'Customer', 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'party_type_db', 'STANDARD', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_del_tax_exempt', 'certificate_amount', 'STANDARD', 'CONSTANTE', '0', 'Source : sp_insert_customer_del_tax_exempt_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_del_tax_exempt', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_customer_del_tax_exempt_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_del_tax_exempt', 'exempt_certificate_type', 'STANDARD', 'CONSTANTE', '', 'Source : sp_insert_customer_del_tax_exempt_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_del_tax_exempt', 'exempt_certificate_type_db', 'STANDARD', 'CONSTANTE', 'BLANKET CERTIFICATE', 'Source : sp_insert_customer_del_tax_exempt_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_delivery_fee_code', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_customer_delivery_fee_code_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_delivery_fee_code', 'fee_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_delivery_fee_code_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_delivery_fee_code', 'tax_code_selection', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_delivery_fee_code_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_delivery_tax_info', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_customer_delivery_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_delivery_tax_info', 'supply_country', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_delivery_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_delivery_tax_info', 'tax_book_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_delivery_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_delivery_tax_info', 'tax_book_type', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_delivery_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_delivery_tax_info', 'tax_calc_structure_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_delivery_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_delivery_tax_info', 'tax_liability', 'STANDARD', 'CONSTANTE', 'TAX', 'Source : sp_insert_customer_delivery_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_delivery_tax_info', 'tax_structure_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_delivery_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_document_tax_info', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_customer_document_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_document_tax_info', 'delivery_country', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_document_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_document_tax_info', 'supply_country', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_document_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_document_tax_info', 'tax_id_error_message', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_document_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_document_tax_info', 'tax_id_type', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_document_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_document_tax_info', 'tax_office_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_document_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_document_tax_info', 'validated_date', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_document_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_document_tax_info', 'vat_no', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_document_tax_info_from_sap.sql (+ modules customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'b2b_customer', 'CUSTOMER', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_info_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'b2b_customer_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_info_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'business_classification', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_info_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'corporate_form', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_info_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'country', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'customer_category', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'customer_category_db', 'STANDARD', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_customer_info_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'customer_tax_usage_type', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_info_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'default_domain', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_info_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'default_language', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_info_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'identifier_ref_validation', 'CUSTOMER', 'CONSTANTE', '', 'Source : sp_insert_customer_info_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'identifier_ref_validation_db', 'STANDARD', 'CONSTANTE', '', 'Source : sp_insert_customer_info_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'main_representative', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'one_time', 'CUSTOMER', 'CONSTANTE', 'False', 'Source : sp_insert_customer_info_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'one_time_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_info_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'party_type', 'CUSTOMER', 'CONSTANTE', 'Customer', 'Source : sp_insert_customer_info_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'party_type_db', 'STANDARD', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_customer_info_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'picture_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_address', 'ean_location', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_address_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_address', 'jurisdiction_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_address_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_address', 'party_type', 'STANDARD', 'CONSTANTE', 'Customer', 'Source : sp_insert_customer_address_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_address', 'party_type_db', 'STANDARD', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_customer_address_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_address', 'primary_contact', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_address_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_address', 'secondary_contact', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_address_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_address', 'valid_to', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_contact', 'address_primary', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : sp_insert_customer_info_contact_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_contact', 'address_secondary', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_info_contact_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_contact', 'contact_email', 'STANDARD', 'CONSTANTE', 'customer@company.com', 'Source : sp_insert_customer_info_contact_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_contact', 'contact_title', 'STANDARD', 'CONSTANTE', 'Customer Representative', 'Source : sp_insert_customer_info_contact_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_contact', 'customer_primary', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : sp_insert_customer_info_contact_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_contact', 'customer_secondary', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_info_contact_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_contact', 'role', 'STANDARD', 'CONSTANTE', 'Primary Contact', 'Source : sp_insert_customer_info_contact_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_contact', 'role_db', 'STANDARD', 'CONSTANTE', 'PRIMARY', 'Source : sp_insert_customer_info_contact_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_free_tax_code', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_customer_tax_free_tax_code_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_free_tax_code', 'delivery_type', 'STANDARD', 'CONSTANTE', 'Delivery Type', 'Source : sp_insert_customer_tax_free_tax_code_from_sap.sql (+ modules customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_free_tax_code', 'vat_free_vat_code', 'CUSTOMER', 'NULL', NULL, 'Source : sp_insert_customer_tax_free_tax_code_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'business_transaction_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'component_a', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'component_a_identity', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'enable_for_tcs', 'STANDARD', 'CONSTANTE', 'False', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'enable_for_tcs_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'exc_from_spesometro_dec', 'STANDARD', 'CONSTANTE', 'False', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'exc_from_spesometro_dec_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'icms_tax_payer', 'STANDARD', 'CONSTANTE', 'False', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'icms_tax_payer_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'out_inv_curr_rate_base', 'STANDARD', 'CONSTANTE', 'Invoice Date', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'out_inv_curr_rate_base_db', 'STANDARD', 'CONSTANTE', 'INVOICE_DATE', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'out_inv_vou_date_base', 'STANDARD', 'CONSTANTE', 'Invoice Date', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'out_inv_vou_date_base_db', 'STANDARD', 'CONSTANTE', 'INVOICE_DATE', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'permanent_establishment', 'STANDARD', 'CONSTANTE', 'False', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'permanent_establishment_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_exempt', 'STANDARD', 'CONSTANTE', 'False', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_exempt_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_exempt_valid_from', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_exempt_valid_to', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_office_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_rounding_level', 'STANDARD', 'CONSTANTE', 'Line Level', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_rounding_level_db', 'STANDARD', 'CONSTANTE', 'LINE_LEVEL', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_rounding_method', 'STANDARD', 'CONSTANTE', 'Round to the Nearest', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_rounding_method_db', 'STANDARD', 'CONSTANTE', 'ROUND_NEAREST', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_sell_curr_rate_base', 'STANDARD', 'CONSTANTE', 'Invoice Date', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_sell_curr_rate_base_db', 'STANDARD', 'CONSTANTE', 'INVOICE_DATE', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_withholding', 'STANDARD', 'CONSTANTE', 'Blocked', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_withholding_db', 'STANDARD', 'CONSTANTE', 'BLOCKED', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'withholding_base_amount', 'STANDARD', 'CONSTANTE', 'Invoice Net Amount', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'withholding_base_amount_db', 'STANDARD', 'CONSTANTE', 'INVOICENET', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.payment_way_per_identity', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_payment_way_per_identity_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.payment_way_per_identity', 'party_type', 'CUSTOMER', 'CONSTANTE', 'Customer', 'Source : pipelines customer (STANDARD occupé par supplier=Supplier)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.payment_way_per_identity', 'party_type_db', 'CUSTOMER', 'CONSTANTE', 'CUSTOMER', 'Source : pipelines customer (STANDARD occupé par supplier=SUPPLIER)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.payment_way_per_identity', 'valid_to', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_payment_way_per_identity_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- --- module customerFile (104 ligne(s)) --------------------------------------
-- 40 de ces lignes ne sont appelees par aucun get_default_value du depot :
-- elles ne changent rien au chargement, elles rendent la constante visible et modifiable dans l'ecran.
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cus_ident_invoice_info', 'identity_type', 'CUSTOMERFILE', 'CONSTANTE', 'External', 'Source : sp_insert_cus_ident_invoice_info_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cus_ident_invoice_info', 'identity_type_db', 'CUSTOMERFILE', 'CONSTANTE', 'EXTERN', 'Source : sp_insert_cus_ident_invoice_info_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cus_ident_invoice_info', 'no_invoice_copies', 'CUSTOMERFILE', 'CONSTANTE', '1', 'Source : sp_insert_cus_ident_invoice_info_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cus_ident_invoice_info', 'report_and_withhold', 'CUSTOMERFILE', 'CONSTANTE', 'Blocked', 'Source : sp_insert_cus_ident_invoice_info_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cus_ident_invoice_info', 'report_and_withhold_db', 'CUSTOMERFILE', 'CONSTANTE', 'BLOCKED', 'Source : sp_insert_cus_ident_invoice_info_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cus_identity_pay_info', 'payment_receipt_type', 'CUSTOMERFILE', 'CONSTANTE', 'No Receipt', 'Source : sp_insert_cus_identity_pay_info_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cus_identity_pay_info', 'payment_receipt_type_db', 'CUSTOMERFILE', 'CONSTANTE', 'NO_RECEIPT', 'Source : sp_insert_cus_identity_pay_info_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cus_identity_pay_info', 'reminder_template', 'CUSTOMERFILE', 'CONSTANTE', '1', 'Source : sp_insert_cus_identity_pay_info_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cus_payment_address', 'bank_account_validated_db', 'CUSTOMERFILE', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_payment_address_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'adv_inv_full_pay', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'adv_inv_full_pay_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'allow_auto_sub_of_parts', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'allow_auto_sub_of_parts_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'auto_despatch_adv_send', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'b2b_auto_create_co_from_sq', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'b2b_auto_create_co_from_sq_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'backorder_option', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'backorder_option_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'check_sales_grp_deliv_conf', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'check_sales_grp_deliv_conf_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'confirm_deliveries', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'confirm_deliveries_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'confirm_direct_deliveries', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'consol_rental_ivc_serial', 'STANDARD', 'CONSTANTE', 'SPECIFIED ON COMPANY', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'consol_rental_ivc_serial_db', 'STANDARD', 'CONSTANTE', 'SPECIFIED ON COMPANY', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'credit_control_group_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'cust_grp', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'cust_price_group_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'default_inv_currency', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'discount_type', 'CUSTOMERFILE', 'CONSTANTE', 'G', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'edi_authorize_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'edi_auto_approval_user', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'edi_auto_change_approval', 'STANDARD', 'CONSTANTE', 'MANUALLY', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'edi_auto_change_approval_db', 'STANDARD', 'CONSTANTE', 'MANUALLY', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'edi_auto_order_approval', 'STANDARD', 'CONSTANTE', 'MANUALLY', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'edi_auto_order_approval_db', 'STANDARD', 'CONSTANTE', 'MANUALLY', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'edi_site', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'email_invoice', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'email_invoice_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'email_order_conf', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'email_order_conf_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'exclude_from_scan_order', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'handl_unit_at_co_delivery', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'handl_unit_at_co_delivery_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'market_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'match_type', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'match_type_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'min_sales_amount', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'mul_tier_del_notification', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'mul_tier_del_notification_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'no_delnote_copies', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'note_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'print_amounts_incl_tax', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'print_amounts_incl_tax_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'print_control_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'print_delivered_lines', 'STANDARD', 'CONSTANTE', 'SHIPMENT', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'print_delivered_lines_db', 'STANDARD', 'CONSTANTE', 'SHIPMENT', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'print_withholding_tax', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'print_withholding_tax_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'priority', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'quick_registered_customer', 'STANDARD', 'CONSTANTE', 'NORMAL', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'quick_registered_customer_db', 'STANDARD', 'CONSTANTE', 'NORMAL', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'rec_adv_auto_approval_user', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'rec_adv_auto_match_diff', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'rec_adv_auto_match_diff_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'rec_adv_auto_matching', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'rec_adv_auto_matching_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'rec_adv_matching_option', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'rec_adv_matching_option_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'receive_pack_size_chg', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'receive_pack_size_chg_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'receiving_advice_type', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'receiving_advice_type_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'release_internal_order', 'STANDARD', 'CONSTANTE', 'MANUALLY', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'release_internal_order_db', 'STANDARD', 'CONSTANTE', 'MANUALLY', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'replicate_doc_text', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'replicate_doc_text_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'salesman_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'sbi_auto_approval_user', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'self_billing_match_option', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'self_billing_match_option_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'send_change_message', 'STANDARD', 'CONSTANTE', 'N', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'send_change_message_db', 'STANDARD', 'CONSTANTE', 'N', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'summarized_freight_charges', 'STANDARD', 'CONSTANTE', 'Y', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'summarized_freight_charges_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'summarized_source_lines', 'STANDARD', 'CONSTANTE', 'Y', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'summarized_source_lines_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'template_customer', 'STANDARD', 'CONSTANTE', 'NOT_TEMPLATE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'template_customer_db', 'STANDARD', 'CONSTANTE', 'NOT_TEMPLATE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'template_customer_desc', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'template_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'update_price_from_sbi', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'update_price_from_sbi_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer_address', 'intrastat_exempt', 'CUSTOMERFILE', 'CONSTANTE', 'Include', 'Source : sp_insert_cust_ord_customer_address_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer_address', 'intrastat_exempt_db', 'CUSTOMERFILE', 'CONSTANTE', 'INCLUDE', 'Source : sp_insert_cust_ord_customer_address_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.customer_info', 'b2b_customer', 'CUSTOMERFILE', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_info_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.customer_info', 'identifier_ref_validation', 'CUSTOMERFILE', 'CONSTANTE', '', 'Source : sp_insert_customer_info_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.customer_info', 'one_time', 'CUSTOMERFILE', 'CONSTANTE', 'False', 'Source : sp_insert_customer_info_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.customer_info', 'party_type', 'CUSTOMERFILE', 'CONSTANTE', 'Customer', 'Source : sp_insert_customer_info_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.customer_info_address_type', 'default_domain', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_address_type_single_file.sql (+ modules customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.customer_tax_free_tax_code', 'vat_free_vat_code', 'CUSTOMERFILE', 'CONSTANTE', 'N', 'Source : sp_insert_customer_tax_free_tax_code_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.payment_way_per_identity', 'party_type', 'CUSTOMERFILE', 'CONSTANTE', 'Customer', 'Source : sp_insert_payment_way_per_identity_from_file_customer.sql (STANDARD occupe par supplier=Supplier)', 'migration_034')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.payment_way_per_identity', 'party_type_db', 'CUSTOMERFILE', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_payment_way_per_identity_from_file_customer.sql (STANDARD occupe par supplier=SUPPLIER)', 'migration_034')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.payment_way_per_identity', 'way_id', 'CUSTOMERFILE', 'CONSTANTE', 'BANK_TRANSFER', 'Source : pipelines customer (STANDARD occupé par supplier=1)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- --- module customer_phl (45 ligne(s)) --------------------------------------
-- 45 de ces lignes ne sont appelees par aucun get_default_value du depot :
-- elles ne changent rien au chargement, elles rendent la constante visible et modifiable dans l'ecran.
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_comm_method', 'address_default', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_comm_method', 'comm_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_comm_method_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_comm_method', 'description', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_comm_method_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_comm_method', 'method_default', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_comm_method', 'method_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_comm_method_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_comm_method', 'method_id_db', 'STANDARD', 'CONSTANTE', 'PHONE', 'Source : sp_insert_cus_comm_method_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_comm_method', 'valid_from', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_comm_method_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_comm_method', 'value', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_comm_method_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_ident_invoice_info', 'def_currency', 'STANDARD', 'CONSTANTE', 'EUR', 'Source : sp_insert_cus_ident_invoice_info_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_ident_invoice_info', 'def_vat_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_ident_invoice_info', 'group_id', 'STANDARD', 'CONSTANTE', '0', 'Source : sp_insert_cus_ident_invoice_info_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_ident_invoice_info', 'identity_type_db', 'CUSTOMER_PHL', 'CONSTANTE', 'EXTERN', 'Source : sp_insert_cus_ident_invoice_info_from_client_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_ident_invoice_info', 'national_bank_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_ident_invoice_info', 'no_invoice_copies', 'CUSTOMER_PHL', 'CONSTANTE', '0', 'Source : sp_insert_cus_ident_invoice_info_from_client_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_ident_invoice_info', 'pay_term_id', 'STANDARD', 'CONSTANTE', '30NETS', 'Source : sp_insert_cus_ident_invoice_info_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_ident_invoice_info', 'report_and_withhold_db', 'CUSTOMER_PHL', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_client_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_identity_pay_info', 'blocked_for_payment', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_identity_pay_info_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_identity_pay_info', 'default_payment_method', 'STANDARD', 'CONSTANTE', 'TRANSFER', 'Source : sp_insert_cus_identity_pay_info_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_identity_pay_info', 'payment_receipt_type', 'CUSTOMER_PHL', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_client_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_identity_pay_info', 'payment_receipt_type_db', 'CUSTOMER_PHL', 'CONSTANTE', 'NO_RECEIPT', 'Source : sp_insert_cus_identity_pay_info_from_client_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_identity_pay_info', 'reminder_template', 'CUSTOMER_PHL', 'CONSTANTE', '0', 'Source : sp_insert_cus_identity_pay_info_from_client_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_payment_address', 'account', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_payment_address_from_client_adresse_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_payment_address', 'bank_account_validated_db', 'CUSTOMER_PHL', 'CONSTANTE', 'NOT VALIDATED', 'Source : sp_insert_cus_payment_address_from_client_adresse_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cust_ord_customer_address', 'del_terms_location', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_address_from_client_adresse_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cust_ord_customer_address', 'delivery_terms', 'STANDARD', 'CONSTANTE', 'EXW', 'Source : sp_insert_cust_ord_customer_address_from_client_adresse_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cust_ord_customer_address', 'district_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_address_from_client_adresse_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cust_ord_customer_address', 'intrastat_exempt', 'CUSTOMER_PHL', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_address_from_client_adresse_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cust_ord_customer_address', 'intrastat_exempt_db', 'CUSTOMER_PHL', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_address_from_client_adresse_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cust_ord_customer_address', 'ship_via_code', 'STANDARD', 'CONSTANTE', '01', 'Source : sp_insert_cust_ord_customer_address_from_client_adresse_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_addr_tax_number', 'tax_id_number', 'STANDARD', 'CONSTANTE', 'NO_TAX_ID', 'Source : sp_insert_customer_addr_tax_number_from_client_adresse_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_credit_info', 'credit_block', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_credit_info', 'credit_number', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_info', 'b2b_customer', 'CUSTOMER_PHL', 'NULL', NULL, 'Source : sp_insert_customer_info_from_client_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_info', 'identifier_ref_validation', 'CUSTOMER_PHL', 'NULL', NULL, 'Source : sp_insert_customer_info_from_client_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_info', 'one_time', 'CUSTOMER_PHL', 'NULL', NULL, 'Source : sp_insert_customer_info_from_client_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_info', 'party_type', 'CUSTOMER_PHL', 'NULL', NULL, 'Source : sp_insert_customer_info_from_client_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_info_address', 'default_domain', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_info_address_from_client_adresse_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_info_address', 'valid_from', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_info_address_from_client_adresse_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_info_address_type', 'address_type_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_address_type_single_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_info_address_type', 'def_address', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : sp_insert_customer_address_type_single_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_tax_free_tax_code', 'vat_free_vat_code', 'CUSTOMER_PHL', 'NULL', NULL, 'Source : sp_insert_customer_tax_free_tax_code_from_client_adresse_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_tax_info', 'fiscal_no', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_tax_info_from_client_adresse_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.payment_way_per_identity', 'party_type', 'CUSTOMER_PHL', 'CONSTANTE', 'Customer', 'Source : sp_insert_payment_way_per_identity_from_client_phl.sql (STANDARD occupe par supplier=Supplier)', 'migration_034')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.payment_way_per_identity', 'party_type_db', 'CUSTOMER_PHL', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_payment_way_per_identity_from_client_phl.sql (STANDARD occupe par supplier=SUPPLIER)', 'migration_034')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.payment_way_per_identity', 'way_id', 'CUSTOMER_PHL', 'CONSTANTE', 'BANK_TRANSFER', 'Source : sp_insert_payment_way_per_identity_from_client_phl.sql (STANDARD occupe par supplier=1)', 'migration_034')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- --- module inventory (58 ligne(s)) -----------------------------------------
-- 12 de ces lignes ne sont appelees par aucun get_default_value du depot :
-- elles ne changent rien au chargement, elles rendent la constante visible et modifiable dans l'ecran.
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'actif_achat', 'STANDARD', 'CONSTANTE', 'NON', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'actif_commercial', 'STANDARD', 'CONSTANTE', 'NON', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'actif_dans_centre', 'STANDARD', 'CONSTANTE', 'NON', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'actif_evaluation', 'STANDARD', 'CONSTANTE', 'NON', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'avec_stock', 'STANDARD', 'CONSTANTE', 'NON', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'langue', 'STANDARD', 'CONSTANTE', 'FR', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'nombre_centres_actifs', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'nombre_magasins', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'stock_total_bloque', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'stock_total_controle', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'stock_total_libre', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'valeur_stock_magasins_total', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'acquired_supply_type', 'STANDARD', 'CONSTANTE', 'Requisition', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'acquired_supply_type_db', 'STANDARD', 'CONSTANTE', 'R', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'carry_rate', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'lot_size_auto', 'STANDARD', 'CONSTANTE', 'Manual Lot Size', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'lot_size_auto_db', 'STANDARD', 'CONSTANTE', 'N', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'manuf_supply_type', 'STANDARD', 'CONSTANTE', 'Requisition', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'manuf_supply_type_db', 'STANDARD', 'CONSTANTE', 'R', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'maxweek_supply', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'mul_order_qty', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'order_point_qty_auto', 'STANDARD', 'CONSTANTE', 'Manual Order Point', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'order_point_qty_auto_db', 'STANDARD', 'CONSTANTE', 'N', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'order_requisition', 'STANDARD', 'CONSTANTE', 'Requisition', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'order_requisition_db', 'STANDARD', 'CONSTANTE', 'R', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'planning_method_auto', 'STANDARD', 'CONSTANTE', 'True', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'planning_method_auto_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'proposal_release', 'STANDARD', 'CONSTANTE', 'Release', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'proposal_release_db', 'STANDARD', 'CONSTANTE', 'RELEASE', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'safety_stock_auto', 'STANDARD', 'CONSTANTE', 'Manual Safety Stock', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'safety_stock_auto_db', 'STANDARD', 'CONSTANTE', 'N', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'sched_capacity', 'STANDARD', 'CONSTANTE', 'Infinite Capacity', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'sched_capacity_db', 'STANDARD', 'CONSTANTE', 'I', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'service_rate', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'setup_cost', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'shrinkage_fac', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'split_manuf_acquired', 'STANDARD', 'CONSTANTE', 'No Split', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'split_manuf_acquired_db', 'STANDARD', 'CONSTANTE', 'NO_SPLIT', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.inventory_part', 'lead_time_code_db', 'STANDARD', 'CONSTANTE', 'P', 'Source : alimenter_inventory_part.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.inventory_part', 'type_code_db', 'STANDARD', 'CONSTANTE', '4', 'Source : alimenter_inventory_part.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.inventory_part', 'zero_cost_flag_db', 'STANDARD', 'CONSTANTE', 'N', 'Source : alimenter_inventory_part.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.part_catalog', 'component_lot_rule_db', 'INVENTORY', 'CONSTANTE', 'ONE_LOT_ALLOWED', 'Source : alimenter_part_catalog.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'acquisition_type_db', 'STANDARD', 'CONSTANTE', 'PURCHASE', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'dist_order_receipt_type_db', 'STANDARD', 'CONSTANTE', 'NO AUTOMATIC RECPT', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'ext_svc_primary_vendor_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'external_service_allowed_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'issue_packaging_material_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'leadtime_auto_db', 'STANDARD', 'CONSTANTE', 'N', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'multisite_planned_part_db', 'STANDARD', 'CONSTANTE', 'NOT_MULTISITE_PLAN', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'part_ownership_db', 'STANDARD', 'CONSTANTE', 'COMPANY OWNED', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'primary_vendor_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'purchase_payment_type_db', 'STANDARD', 'CONSTANTE', 'NORMAL', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'qualified_supplier_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'quick_registered_part_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'receive_case_db', 'STANDARD', 'CONSTANTE', 'INVDIR', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'rental_primary_vendor_db', 'STANDARD', 'CONSTANTE', 'N', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'status_code', 'STANDARD', 'CONSTANTE', '2', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'use_price_incl_tax_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- --- module operation (98 ligne(s)) -----------------------------------------
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task', 'adjusted_duration', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : create_alimenter_jt_task.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task', 'appointment_required', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : create_alimenter_jt_task.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task', 'company', 'STANDARD', 'CONSTANTE', 'TRIM', 'Source : create_alimenter_jt_task.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task', 'exclude_from_scheduling', 'STANDARD', 'CONSTANTE', 'False', 'Source : create_alimenter_jt_task.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task', 'exclude_from_scheduling_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : create_alimenter_jt_task.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task', 'fixed_start', 'STANDARD', 'NULL', NULL, 'Source : create_alimenter_jt_task.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task', 'objtype', 'STANDARD', 'CONSTANTE', 'JtTask', 'Source : create_alimenter_jt_task.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task', 'objversion', 'STANDARD', 'CONSTANTE', '1', 'Source : create_alimenter_jt_task.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task', 'remotely_fulfilled', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : create_alimenter_jt_task.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task', 'scheduled_manually', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : create_alimenter_jt_task.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task_resource', 'crew_time_invoicing', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : create_alimenter_jt_task_resource.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task_resource', 'offset_value', 'STANDARD', 'CONSTANTE', '0', 'Source : create_alimenter_jt_task_resource.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task_resource', 'sourcing_option_db', 'STANDARD', 'CONSTANTE', 'INTERNALLY_SOURCED', 'Source : create_alimenter_jt_task_resource.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'buy_unit_meas', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'catalog_no', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'cf_alt_on_hand_qty', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'cf_ecartqtedispo', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'cf_on_supply_qty', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'change_reason', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'changes_line_item_no', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'condition_code', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'consumed_qty', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'delivery', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'delivery_db', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'discount', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'external_id', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'fbuy_unit_price', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'generated', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'is_closed', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'job_id', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'list_price', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'list_price_curr', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'manual_line', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'markup', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'mobile_created', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'mobile_created_db', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'mobile_warranty', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'mobile_warranty_db', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'no_part_description', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'objversion', 'STANDARD', 'CONSTANTE', '1', 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'owner', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'part_ownership', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'part_ownership_db', 'STANDARD', 'CONSTANTE', 'COMPANY OWNED', 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'part_type', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'part_type_db', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'pegged_qty', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'pickup_task_id', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'place_in_facility_db', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'price_effective_date', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'price_list_no', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'price_source_db', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'price_source_id', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'purchase_method', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'purchase_method_db', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'qty', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'qty_assigned', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'qty_changed', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'qty_returned', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'qty_short', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'qty_to_invoice', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'quo_spare_seq', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'quo_task_seq', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'quotation_no', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'quotation_rev', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'rental', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'rental_db', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'rental_task_res_seq', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'repair_part_flag', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'rwo_contract', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'rwo_copy_prepost', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'rwo_copy_prepost_db', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'rwo_equip_object_seq', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'rwo_err_descr', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'rwo_lot_batch_no', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'rwo_mch_code', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'rwo_mch_contract', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'rwo_org_code', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'sale_unit_price', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'sale_unit_price_curr', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'sender_id', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'sender_type', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'sender_type_db', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'serial_in', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'serial_in_contract', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'service_type', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'supply_code', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'supply_code_db', 'STANDARD', 'CONSTANTE', 'INVENT_ORDER', 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'supply_source_ref1', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'supply_source_ref2', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'supply_source_ref3', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'supply_source_ref4', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'supply_source_ref_state', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'supply_source_ref_type', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'supply_source_ref_type_db', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'swap_part_db', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'task_plan_line_seq', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'tool_fac_row_no', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'wo_quo_no', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- --- module pm_actions (15 ligne(s)) ----------------------------------------
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action', 'connection_type', 'STANDARD', 'CONSTANTE', 'Functional Object', 'Source : 01_populate_pm_action.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action', 'connection_type_db', 'STANDARD', 'CONSTANTE', 'FUNCTIONAL', 'Source : 01_populate_pm_action.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action', 'org_code', 'STANDARD', 'CONSTANTE', 'FR_MAINT', 'Source : 01_populate_pm_action.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action', 'org_contract', 'STANDARD', 'CONSTANTE', 'SJ', 'Source : 01_populate_pm_action.sql (site des objets fonctionnels)', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action', 'pm_revision', 'STANDARD', 'CONSTANTE', '1', 'Source : 01_populate_pm_action.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action_resource', 'demand_type', 'STANDARD', 'CONSTANTE', 'Work Order', 'Source : 03_populate_pm_action_resource.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action_resource', 'demand_type_db', 'STANDARD', 'CONSTANTE', 'WORK_ORDER', 'Source : 03_populate_pm_action_resource.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action_resource', 'pm_revision', 'STANDARD', 'CONSTANTE', '1', 'Source : 03_populate_pm_action_resource.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action_role', 'org_code', 'STANDARD', 'CONSTANTE', 'FR_MAINT', 'Source : 04_populate_pm_action_role.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action_role', 'org_contract', 'STANDARD', 'CONSTANTE', 'SJ', 'Source : 04_populate_pm_action_role.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action_role', 'pm_revision', 'STANDARD', 'CONSTANTE', '1', 'Source : 04_populate_pm_action_role.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action_work_step', 'connection_type', 'STANDARD', 'CONSTANTE', 'Functional Object', 'Source : 02_populate_pm_action_work_step.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action_work_step', 'connection_type_db', 'STANDARD', 'CONSTANTE', 'FUNCTIONAL', 'Source : 02_populate_pm_action_work_step.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action_work_step', 'mch_code_contract', 'STANDARD', 'CONSTANTE', 'SJ', 'Source : 02_populate_pm_action_work_step.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action_work_step', 'pm_revision', 'STANDARD', 'CONSTANTE', '1', 'Source : 02_populate_pm_action_work_step.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- --- module projet (38 ligne(s)) --------------------------------------------
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'exclude_from_integrations', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'exclude_from_integrations_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'exclude_periodical_cap', 'STANDARD', 'CONSTANTE', 'INCLUDE', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'exclude_periodical_cap_db', 'STANDARD', 'CONSTANTE', 'INCLUDE', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'exclude_resource_progress', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'exclude_resource_progress_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'mandatory_invoice_comment', 'STANDARD', 'CONSTANTE', 'INHERIT', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'mandatory_invoice_comment_db', 'STANDARD', 'CONSTANTE', 'INHERIT', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'node_type', 'STANDARD', 'CONSTANTE', 'ACTIVITY', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'node_type_db', 'STANDARD', 'CONSTANTE', 'ACTIVITY', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'planned_cost_driver', 'STANDARD', 'CONSTANTE', 'CONNECTED_OBJECTS', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'planned_cost_driver_db', 'STANDARD', 'CONSTANTE', 'CONNECTED_OBJECTS', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'progress_method', 'STANDARD', 'CONSTANTE', 'ALL_CONNECTED_OBJECTS', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'progress_method_db', 'STANDARD', 'CONSTANTE', 'ALL_CONNECTED_OBJECTS', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'sub_project_id', 'STANDARD', 'CONSTANTE', '10', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_activity', 'exclude_from_integrations_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_project_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_activity', 'exclude_periodical_cap_db', 'STANDARD', 'CONSTANTE', 'INCLUDE', 'Source : alimenter_project_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_activity', 'exclude_resource_progress_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_project_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_activity', 'mandatory_invoice_comment_db', 'STANDARD', 'CONSTANTE', 'INHERIT', 'Source : alimenter_project_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_activity', 'node_type_db', 'STANDARD', 'CONSTANTE', 'ACTIVITY', 'Source : alimenter_project_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_activity', 'planned_cost_driver_db', 'STANDARD', 'CONSTANTE', 'CONNECTED_OBJECTS', 'Source : alimenter_project_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_activity', 'progress_method_db', 'STANDARD', 'CONSTANTE', 'ALL_CONNECTED_OBJECTS', 'Source : alimenter_project_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_activity', 'sub_project_id', 'STANDARD', 'CONSTANTE', '10', 'Source : alimenter_project_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_activity', 'task_id', 'STANDARD', 'NULL', NULL, 'Source : alimenter_project_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_base', 'baseline_revision_number', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_ifs_project_base.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_base', 'category2_id', 'STANDARD', 'CONSTANTE', 'MECA', 'Source : alimenter_ifs_project_base.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_base', 'earned_value_method', 'STANDARD', 'CONSTANTE', 'Planned', 'Source : alimenter_ifs_project_base.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_base', 'material_allocation', 'STANDARD', 'CONSTANTE', 'Within Project', 'Source : alimenter_ifs_project_base.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_base', 'multi_currency_budgeting', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_ifs_project_base.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_base', 'program_id', 'STANDARD', 'CONSTANTE', 'CAPEX', 'Source : alimenter_ifs_project_base.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_base', 'project_misc_comp_method', 'STANDARD', 'CONSTANTE', 'Manually Planned', 'Source : alimenter_ifs_project_base.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_base', 'work_day_to_hours_conv', 'STANDARD', 'CONSTANTE', '7', 'Source : alimenter_ifs_project_base.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_margin_matrix', 'objversion', 'STANDARD', 'CONSTANTE', '1', 'Source : alimenter_ifs_project_margin_matrix.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_site_ext', 'auto_trans_from_std_inv_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_ifs_project_site_ext.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_site_ext', 'project_site_type_db', 'STANDARD', 'CONSTANTE', 'DEFAULTSITE', 'Source : alimenter_ifs_project_site_ext.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_site_ext', 'use_std_inv_in_pmrp_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_ifs_project_site_ext.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.sub_project', 'exclude_from_integrations_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_sub_project.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.sub_project', 'financially_completed_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_sub_project.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- --- module supplier (218 ligne(s)) ------------------------------------------
-- 1 de ces lignes ne sont appelees par aucun get_default_value du depot :
-- elles ne changent rien au chargement, elles rendent la constante visible et modifiable dans l'ecran.
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'address_default', 'FAX', 'CONSTANTE', 'FALSE', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'address_default', 'PHONE', 'CONSTANTE', 'FALSE', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'method_id', 'E_MAIL', 'CONSTANTE', 'E-Mail', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'method_id', 'FAX', 'CONSTANTE', 'Fax', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'method_id', 'PHONE', 'CONSTANTE', 'Phone', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'method_id_db', 'E_MAIL', 'CONSTANTE', 'E_MAIL', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'method_id_db', 'FAX', 'CONSTANTE', 'FAX', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'method_id_db', 'PHONE', 'CONSTANTE', 'PHONE', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'party_type', 'E_MAIL', 'CONSTANTE', 'Supplier', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'party_type', 'FAX', 'CONSTANTE', 'Supplier', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'party_type', 'PHONE', 'CONSTANTE', 'Supplier', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'party_type_db', 'E_MAIL', 'CONSTANTE', 'SUPPLIER', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'party_type_db', 'FAX', 'CONSTANTE', 'SUPPLIER', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'party_type_db', 'PHONE', 'CONSTANTE', 'SUPPLIER', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'valid_to', 'E_MAIL', 'CONSTANTE', '2099-12-31', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'valid_to', 'FAX', 'CONSTANTE', '2099-12-31', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'valid_to', 'PHONE', 'CONSTANTE', '2099-12-31', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'allow_quantity_diff', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'allow_tolerance', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'automatic_invoice', 'STANDARD', 'CONSTANTE', 'N', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'create_tolerance_posting', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'def_currency', 'STANDARD', 'CONSTANTE', 'EUR', 'Devise par defaut de facturation. Source : 10_sp_insert_identity_invoice_info_from_sap.sql (remplace COALESCE(f.devise_principale, ''EUR''))', 'migration_043')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'digital_invoice', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'exc_from_spesometro_dec', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'exclude_invoice_image', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'exclude_posting_auth', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'identity_type', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'inc_inv_curr_rate_base', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'invoice_fee', 'STANDARD', 'NULL', NULL, 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'invoice_recipient_from', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'legal_identity', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'matching_level', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'ncf_reference_check', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'party_type', 'STANDARD', 'CONSTANTE', 'Supplier', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'party_type_db', 'STANDARD', 'CONSTANTE', 'SUPPLIER', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'po_ref_rec_ref_val_method', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'print_tax_code_text', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'report_and_withhold', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'second_tin', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'service_code_required', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'tax_buy_curr_rate_base', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'tax_certificate_form', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'tax_exempt', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'utility_bill_provider', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'voting_share_percentage', 'STANDARD', 'CONSTANTE', '', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'withholding_base_amount', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'ar_contact', 'STANDARD', 'NULL', NULL, 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'business_category', 'STANDARD', 'CONSTANTE', 'SUPPLIER', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'check_recipient', 'STANDARD', 'CONSTANTE', 'Payee', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'check_recipient_db', 'STANDARD', 'CONSTANTE', 'PAYEE', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'comm_id', 'STANDARD', 'CONSTANTE', '0', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'corporation_id', 'STANDARD', 'NULL', NULL, 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'customer_id', 'STANDARD', 'NULL', NULL, 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'deduction_group', 'STANDARD', 'NULL', NULL, 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'default_payment_method', 'STANDARD', 'CONSTANTE', 'BANK', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'disc_days_tolerance', 'STANDARD', 'CONSTANTE', '3', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'format_no', 'STANDARD', 'CONSTANTE', '1', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'interest_template', 'STANDARD', 'CONSTANTE', '1', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'is_one_inv_per_pay', 'STANDARD', 'CONSTANTE', 'False', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'is_one_inv_per_pay_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'member_id', 'STANDARD', 'NULL', NULL, 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'netting_allowed', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'next_payment_matching_id', 'STANDARD', 'CONSTANTE', '0', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'other_payee_identity', 'STANDARD', 'NULL', NULL, 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'output_media', 'STANDARD', 'CONSTANTE', 'Printout', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'output_media_db', 'STANDARD', 'CONSTANTE', '1', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'party_type', 'STANDARD', 'CONSTANTE', 'Supplier', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'party_type_db', 'STANDARD', 'CONSTANTE', 'SUPPLIER', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'payment_advice', 'STANDARD', 'CONSTANTE', 'No Advice', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'payment_advice_db', 'STANDARD', 'CONSTANTE', '1', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'payment_mode', 'STANDARD', 'CONSTANTE', 'Bank Transfer, Digital Wallet', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'payment_mode_db', 'STANDARD', 'CONSTANTE', '18', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'payment_receipt_type', 'STANDARD', 'CONSTANTE', 'No Receipt', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'payment_receipt_type_db', 'STANDARD', 'CONSTANTE', 'NO_RECEIPT', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'percent_tolerance', 'STANDARD', 'CONSTANTE', '5', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'predicted_payment_delay', 'STANDARD', 'CONSTANTE', 'False', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'predicted_payment_delay_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'priority', 'STANDARD', 'CONSTANTE', '1', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'reminder_template', 'STANDARD', 'CONSTANTE', 'DEFAULT', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'rule_id', 'STANDARD', 'NULL', NULL, 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'send_interest_inv_to_payer', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'send_reminder_to_payer', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'send_stmt_of_acc_to_payer', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'template_id', 'STANDARD', 'NULL', NULL, 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.ifs_fournisseurs', 'address_id', 'STANDARD', 'CONSTANTE', '01', 'Source : 01_alimenter_ifs_fournisseurs.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.ifs_fournisseurs', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : 01_alimenter_ifs_fournisseurs.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'account', 'ADRESSE_DEFAUT', 'NULL', NULL, 'Source : 14_fn_upsert_payment_address.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'bank_account_validated', 'ADRESSE_DEFAUT', 'CONSTANTE', 'Not Validated', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'bank_account_validated', 'BANQUE', 'CONSTANTE', 'Not Validated', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'bank_account_validated_db', 'ADRESSE_DEFAUT', 'CONSTANTE', 'FALSE', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'bank_account_validated_db', 'BANQUE', 'CONSTANTE', 'FALSE', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'bic_code', 'ADRESSE_DEFAUT', 'NULL', NULL, 'Source : 14_fn_upsert_payment_address.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'blocked_for_use', 'ADRESSE_DEFAUT', 'CONSTANTE', 'FALSE', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'blocked_for_use', 'BANQUE', 'CONSTANTE', 'FALSE', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'company', 'ADRESSE_DEFAUT', 'CONSTANTE', 'TRIMET', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'default_address', 'ADRESSE_DEFAUT', 'CONSTANTE', 'TRUE', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'description', 'ADRESSE_DEFAUT', 'CONSTANTE', 'Adresse de paiement par défaut', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'mapping_type', 'ADRESSE_DEFAUT', 'CONSTANTE', 'DEFAULT', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'mapping_type', 'BANQUE', 'CONSTANTE', 'BANK_TRANSFER', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'party_type', 'ADRESSE_DEFAUT', 'CONSTANTE', 'Supplier', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'party_type', 'BANQUE', 'CONSTANTE', 'Supplier', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'party_type_db', 'ADRESSE_DEFAUT', 'CONSTANTE', 'SUPPLIER', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'party_type_db', 'BANQUE', 'CONSTANTE', 'SUPPLIER', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'way_id', 'ADRESSE_DEFAUT', 'CONSTANTE', 'SEPA', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'way_id', 'BANQUE', 'CONSTANTE', 'SEPA', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_way_per_identity', 'default_payment_way', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : 12_fn_upsert_payment_way_per_identity.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_way_per_identity', 'party_type', 'STANDARD', 'CONSTANTE', 'Supplier', 'Source : 12_fn_upsert_payment_way_per_identity.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_way_per_identity', 'party_type_db', 'STANDARD', 'CONSTANTE', 'SUPPLIER', 'Source : 12_fn_upsert_payment_way_per_identity.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_way_per_identity', 'way_id', 'STANDARD', 'CONSTANTE', '1', 'Source : 12_fn_upsert_payment_way_per_identity.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'additional_cost_amount', 'STANDARD', 'CONSTANTE', '0', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'adhoc_pur_rqst_approval_db', 'STANDARD', 'CONSTANTE', 'MANUALLY', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'b2b_conf_order_with_diff_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'blanket_date_db', 'STANDARD', 'CONSTANTE', 'ORDERDATE', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'buyer_code', 'STANDARD', 'CONSTANTE', '*', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'category_db', 'STANDARD', 'CONSTANTE', 'E', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'coc_approval_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'cr_check_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'create_confirmation_chg_ord_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'currency_code', 'STANDARD', 'CONSTANTE', 'EUR', 'Devise du fournisseur. Source : 09_sp_insert_supplier_from_sap.sql (remplace COALESCE(f.devise_principale, ''EUR''))', 'migration_043')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'delivery_rem_interval', 'STANDARD', 'CONSTANTE', '3', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'delivery_reminder_db', 'STANDARD', 'CONSTANTE', 'DELIVREM', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'dir_del_approval_db', 'STANDARD', 'CONSTANTE', 'AUTOMATICALLY', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'discount', 'STANDARD', 'CONSTANTE', '0', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'email_purchase_order_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'environmental_approval_db', 'STANDARD', 'CONSTANTE', 'APPROVED', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'express_order_allowed_db', 'STANDARD', 'CONSTANTE', '1', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'ord_conf_rem_interval', 'STANDARD', 'CONSTANTE', '7', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'ord_conf_reminder_db', 'STANDARD', 'CONSTANTE', 'CONFREM', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'order_conf_approval_db', 'STANDARD', 'CONSTANTE', 'AUTOMATICALLY', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'order_conf_diff_approval_db', 'STANDARD', 'CONSTANTE', 'MANUALLY', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'pack_list_flag_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'po_change_management_db', 'STANDARD', 'CONSTANTE', 'USE_SITE_DEFAULT', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'pricat_automatic_approval_db', 'STANDARD', 'CONSTANTE', 'NOT_APPLICABLE', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'print_amounts_incl_tax_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'purch_order_flag_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'qc_approval_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'quick_registered_supplier_db', 'STANDARD', 'CONSTANTE', 'ORDINARY', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'rec_adv_sb_consignment_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'rec_adv_sb_mix_ownership_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'rec_adv_self_billing_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'receipt_ref_reminder_db', 'STANDARD', 'CONSTANTE', 'NO_RCPT_REMINDER', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'receiving_advice_type_db', 'STANDARD', 'CONSTANTE', 'USE_CUSTOMER_DEFAULT', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'supp_grp', 'STANDARD', 'CONSTANTE', 'DEFAULT', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'supplier_group', 'STANDARD', 'CONSTANTE', 'EXTERNAL', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'template_supplier_db', 'STANDARD', 'CONSTANTE', 'NOTEMPLATE', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_addr_tax_number', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Code societe', 'migration_045')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_addr_tax_number', 'default_tax_id_number_db', 'SIREN', 'CONSTANTE', 'FALSE', 'Le SIREN n''est pas le numero fiscal par defaut', 'migration_045')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_addr_tax_number', 'default_tax_id_number_db', 'SIRET', 'CONSTANTE', 'FALSE', 'Le SIRET n''est pas le numero fiscal par defaut', 'migration_045')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_addr_tax_number', 'default_tax_id_number_db', 'TVA_UE', 'CONSTANTE', 'TRUE', 'La TVA intracommunautaire est le numero fiscal par defaut du fournisseur', 'migration_045')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_addr_tax_number', 'tax_id_type', 'SIREN', 'CONSTANTE', 'SIREN', 'Type du numero SIREN (source : ifs_fournisseurs.numero_siren)', 'migration_045')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_addr_tax_number', 'tax_id_type', 'SIRET', 'CONSTANTE', 'SIRET', 'Type du numero SIRET (source : ifs_fournisseurs.siret)', 'migration_045')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_addr_tax_number', 'tax_id_type', 'TVA_UE', 'CONSTANTE', 'TVA UE', 'Type du numero de TVA intracommunautaire (source : ifs_fournisseurs.tva)', 'migration_045')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_address', 'delivery_terms', 'STANDARD', 'NULL', NULL, 'Source : 07_alimenter_supplier_address.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_address', 'route_id', 'STANDARD', 'NULL', NULL, 'Source : 07_alimenter_supplier_address.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_address', 'ship_via_code', 'STANDARD', 'NULL', NULL, 'Source : 07_alimenter_supplier_address.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_document_tax_info', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : 08_insert_supplier_document_tax_info.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_document_tax_info', 'company_addr_tax_id_type', 'STANDARD', 'CONSTANTE', '', 'Source : 08_insert_supplier_document_tax_info.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_document_tax_info', 'company_addr_tax_id_type_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 08_insert_supplier_document_tax_info.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_document_tax_info', 'reliability_status_db', 'STANDARD', 'CONSTANTE', 'NOT_SET', 'Source : 08_insert_supplier_document_tax_info.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_document_tax_info', 'tax_office_id', 'STANDARD', 'CONSTANTE', '', 'Source : 08_insert_supplier_document_tax_info.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address', 'address_id', 'STANDARD', 'CONSTANTE', '01', 'Source : 04_alimenter_supplier_info_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address', 'comm_id', 'STANDARD', 'NULL', NULL, 'Source : 04_alimenter_supplier_info_address.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address', 'default_domain', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : 04_alimenter_supplier_info_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address', 'output_media', 'STANDARD', 'CONSTANTE', '1', 'Source : 04_alimenter_supplier_info_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address', 'output_media_db', 'STANDARD', 'CONSTANTE', '1', 'Source : 04_alimenter_supplier_info_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address', 'party_type', 'STANDARD', 'CONSTANTE', 'Supplier', 'Source : 04_alimenter_supplier_info_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address', 'party_type_db', 'STANDARD', 'CONSTANTE', 'SUPPLIER', 'Source : 04_alimenter_supplier_info_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'address_type_code', 'DELIVERY', 'CONSTANTE', 'Delivery', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'address_type_code', 'INVOICE', 'CONSTANTE', 'Document', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'address_type_code', 'PAY', 'CONSTANTE', 'Pay', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'address_type_code', 'VISIT', 'CONSTANTE', 'Visit', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'address_type_code_db', 'DELIVERY', 'CONSTANTE', 'DELIVERY', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'address_type_code_db', 'INVOICE', 'CONSTANTE', 'INVOICE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'address_type_code_db', 'PAY', 'CONSTANTE', 'PAY', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'address_type_code_db', 'VISIT', 'CONSTANTE', 'VISIT', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'def_address', 'DELIVERY', 'CONSTANTE', 'TRUE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'def_address', 'INVOICE', 'CONSTANTE', 'TRUE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'def_address', 'PAY', 'CONSTANTE', 'TRUE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'def_address', 'VISIT', 'CONSTANTE', 'TRUE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'default_domain', 'DELIVERY', 'CONSTANTE', 'TRUE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'default_domain', 'INVOICE', 'CONSTANTE', 'TRUE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'default_domain', 'PAY', 'CONSTANTE', 'TRUE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'default_domain', 'VISIT', 'CONSTANTE', 'TRUE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'invoice', 'DELIVERY', 'CONSTANTE', 'FALSE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'invoice', 'INVOICE', 'CONSTANTE', 'TRUE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'invoice', 'PAY', 'CONSTANTE', 'FALSE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'invoice', 'VISIT', 'CONSTANTE', 'FALSE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'party', 'DELIVERY', 'CONSTANTE', '', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'party', 'INVOICE', 'CONSTANTE', 'FALSE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'party', 'PAY', 'CONSTANTE', 'FALSE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'party', 'VISIT', 'CONSTANTE', 'FALSE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'pay', 'DELIVERY', 'CONSTANTE', 'FALSE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'pay', 'INVOICE', 'CONSTANTE', 'FALSE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'pay', 'PAY', 'CONSTANTE', 'TRUE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'pay', 'VISIT', 'CONSTANTE', 'FALSE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'visit', 'DELIVERY', 'CONSTANTE', 'FALSE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'visit', 'INVOICE', 'CONSTANTE', 'FALSE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'visit', 'PAY', 'CONSTANTE', 'FALSE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'visit', 'VISIT', 'CONSTANTE', 'TRUE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'b2b_supplier', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'b2b_supplier_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'business_classification', 'STANDARD', 'NULL', NULL, 'Source : 02_alimenter_supplier_info_general.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'corporate_form', 'STANDARD', 'NULL', NULL, 'Source : 02_alimenter_supplier_info_general.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'default_domain', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'default_language', 'STANDARD', 'CONSTANTE', 'FR', 'Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'default_language_db', 'STANDARD', 'CONSTANTE', 'FR', 'Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'identifier_ref_validation_db', 'STANDARD', 'CONSTANTE', 'NONE', 'Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'one_time', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'one_time_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'party', 'STANDARD', 'NULL', NULL, 'Source : 02_alimenter_supplier_info_general.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'party_type', 'STANDARD', 'CONSTANTE', 'Supplier', 'Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'party_type_db', 'STANDARD', 'CONSTANTE', 'SUPPLIER', 'Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'picture_id', 'STANDARD', 'NULL', NULL, 'Source : 02_alimenter_supplier_info_general.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'supplier_category', 'STANDARD', 'CONSTANTE', 'Supplier', 'Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'supplier_category_db', 'STANDARD', 'CONSTANTE', 'SUPPLIER', 'Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_our_id', 'our_id_prefix', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Préfixe de OUR_ID (concaténé : <prefixe>-<numero_compte_fournisseur>)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_tax_info', 'use_supp_address_for_tax', 'STANDARD', 'CONSTANTE', 'True', 'Source : 15_fn_upsert_supplier_tax_info.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_tax_info', 'use_supp_address_for_tax_db', 'STANDARD', 'CONSTANTE', 'True', 'Source : 15_fn_upsert_supplier_tax_info.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- Controle : doit afficher 0 ligne manquante.
DO $$
DECLARE v_manquantes integer;
BEGIN
    SELECT count(*) INTO v_manquantes FROM (VALUES
        ('clean_data.supplier_info_our_id', 'our_id_prefix', 'STANDARD'),
        ('clean_data.ifs_fournisseurs', 'address_id', 'STANDARD'),
        ('clean_data.ifs_fournisseurs', 'company', 'STANDARD'),
        ('clean_data.supplier_info_general', 'b2b_supplier', 'STANDARD'),
        ('clean_data.supplier_info_general', 'b2b_supplier_db', 'STANDARD'),
        ('clean_data.supplier_info_general', 'business_classification', 'STANDARD'),
        ('clean_data.supplier_info_general', 'corporate_form', 'STANDARD'),
        ('clean_data.supplier_info_general', 'default_domain', 'STANDARD'),
        ('clean_data.supplier_info_general', 'default_language', 'STANDARD'),
        ('clean_data.supplier_info_general', 'default_language_db', 'STANDARD'),
        ('clean_data.supplier_info_general', 'identifier_ref_validation_db', 'STANDARD'),
        ('clean_data.supplier_info_general', 'one_time', 'STANDARD'),
        ('clean_data.supplier_info_general', 'one_time_db', 'STANDARD'),
        ('clean_data.supplier_info_general', 'party', 'STANDARD'),
        ('clean_data.supplier_info_general', 'party_type', 'STANDARD'),
        ('clean_data.supplier_info_general', 'party_type_db', 'STANDARD'),
        ('clean_data.supplier_info_general', 'picture_id', 'STANDARD'),
        ('clean_data.supplier_info_general', 'supplier_category', 'STANDARD'),
        ('clean_data.supplier_info_general', 'supplier_category_db', 'STANDARD'),
        ('clean_data.supplier_info_address', 'address_id', 'STANDARD'),
        ('clean_data.supplier_info_address', 'comm_id', 'STANDARD'),
        ('clean_data.supplier_info_address', 'default_domain', 'STANDARD'),
        ('clean_data.supplier_info_address', 'output_media', 'STANDARD'),
        ('clean_data.supplier_info_address', 'output_media_db', 'STANDARD'),
        ('clean_data.supplier_info_address', 'party_type', 'STANDARD'),
        ('clean_data.supplier_info_address', 'party_type_db', 'STANDARD'),
        ('clean_data.supplier_info_address_type', 'address_type_code', 'DELIVERY'),
        ('clean_data.supplier_info_address_type', 'address_type_code_db', 'DELIVERY'),
        ('clean_data.supplier_info_address_type', 'def_address', 'DELIVERY'),
        ('clean_data.supplier_info_address_type', 'default_domain', 'DELIVERY'),
        ('clean_data.supplier_info_address_type', 'invoice', 'DELIVERY'),
        ('clean_data.supplier_info_address_type', 'party', 'DELIVERY'),
        ('clean_data.supplier_info_address_type', 'pay', 'DELIVERY'),
        ('clean_data.supplier_info_address_type', 'visit', 'DELIVERY'),
        ('clean_data.supplier_info_address_type', 'address_type_code', 'INVOICE'),
        ('clean_data.supplier_info_address_type', 'address_type_code_db', 'INVOICE'),
        ('clean_data.supplier_info_address_type', 'def_address', 'INVOICE'),
        ('clean_data.supplier_info_address_type', 'default_domain', 'INVOICE'),
        ('clean_data.supplier_info_address_type', 'invoice', 'INVOICE'),
        ('clean_data.supplier_info_address_type', 'party', 'INVOICE'),
        ('clean_data.supplier_info_address_type', 'pay', 'INVOICE'),
        ('clean_data.supplier_info_address_type', 'visit', 'INVOICE'),
        ('clean_data.supplier_info_address_type', 'address_type_code', 'PAY'),
        ('clean_data.supplier_info_address_type', 'address_type_code_db', 'PAY'),
        ('clean_data.supplier_info_address_type', 'def_address', 'PAY'),
        ('clean_data.supplier_info_address_type', 'default_domain', 'PAY'),
        ('clean_data.supplier_info_address_type', 'invoice', 'PAY'),
        ('clean_data.supplier_info_address_type', 'party', 'PAY'),
        ('clean_data.supplier_info_address_type', 'pay', 'PAY'),
        ('clean_data.supplier_info_address_type', 'visit', 'PAY'),
        ('clean_data.supplier_info_address_type', 'address_type_code', 'VISIT'),
        ('clean_data.supplier_info_address_type', 'address_type_code_db', 'VISIT'),
        ('clean_data.supplier_info_address_type', 'def_address', 'VISIT'),
        ('clean_data.supplier_info_address_type', 'default_domain', 'VISIT'),
        ('clean_data.supplier_info_address_type', 'invoice', 'VISIT'),
        ('clean_data.supplier_info_address_type', 'party', 'VISIT'),
        ('clean_data.supplier_info_address_type', 'pay', 'VISIT'),
        ('clean_data.supplier_info_address_type', 'visit', 'VISIT'),
        ('clean_data.comm_method', 'method_id', 'E_MAIL'),
        ('clean_data.comm_method', 'method_id_db', 'E_MAIL'),
        ('clean_data.comm_method', 'party_type', 'E_MAIL'),
        ('clean_data.comm_method', 'party_type_db', 'E_MAIL'),
        ('clean_data.comm_method', 'valid_to', 'E_MAIL'),
        ('clean_data.comm_method', 'address_default', 'FAX'),
        ('clean_data.comm_method', 'method_id', 'FAX'),
        ('clean_data.comm_method', 'method_id_db', 'FAX'),
        ('clean_data.comm_method', 'party_type', 'FAX'),
        ('clean_data.comm_method', 'party_type_db', 'FAX'),
        ('clean_data.comm_method', 'valid_to', 'FAX'),
        ('clean_data.comm_method', 'address_default', 'PHONE'),
        ('clean_data.comm_method', 'method_id', 'PHONE'),
        ('clean_data.comm_method', 'method_id_db', 'PHONE'),
        ('clean_data.comm_method', 'party_type', 'PHONE'),
        ('clean_data.comm_method', 'party_type_db', 'PHONE'),
        ('clean_data.comm_method', 'valid_to', 'PHONE'),
        ('clean_data.supplier_address', 'delivery_terms', 'STANDARD'),
        ('clean_data.supplier_address', 'route_id', 'STANDARD'),
        ('clean_data.supplier_address', 'ship_via_code', 'STANDARD'),
        ('clean_data.supplier_document_tax_info', 'company', 'STANDARD'),
        ('clean_data.supplier_document_tax_info', 'company_addr_tax_id_type', 'STANDARD'),
        ('clean_data.supplier_document_tax_info', 'company_addr_tax_id_type_db', 'STANDARD'),
        ('clean_data.supplier_document_tax_info', 'reliability_status_db', 'STANDARD'),
        ('clean_data.supplier_document_tax_info', 'tax_office_id', 'STANDARD'),
        ('clean_data.supplier', 'additional_cost_amount', 'STANDARD'),
        ('clean_data.supplier', 'adhoc_pur_rqst_approval_db', 'STANDARD'),
        ('clean_data.supplier', 'b2b_conf_order_with_diff_db', 'STANDARD'),
        ('clean_data.supplier', 'blanket_date_db', 'STANDARD'),
        ('clean_data.supplier', 'buyer_code', 'STANDARD'),
        ('clean_data.supplier', 'category_db', 'STANDARD'),
        ('clean_data.supplier', 'coc_approval_db', 'STANDARD'),
        ('clean_data.supplier', 'cr_check_db', 'STANDARD'),
        ('clean_data.supplier', 'create_confirmation_chg_ord_db', 'STANDARD'),
        ('clean_data.supplier', 'delivery_rem_interval', 'STANDARD'),
        ('clean_data.supplier', 'delivery_reminder_db', 'STANDARD'),
        ('clean_data.supplier', 'dir_del_approval_db', 'STANDARD'),
        ('clean_data.supplier', 'discount', 'STANDARD'),
        ('clean_data.supplier', 'email_purchase_order_db', 'STANDARD'),
        ('clean_data.supplier', 'environmental_approval_db', 'STANDARD'),
        ('clean_data.supplier', 'express_order_allowed_db', 'STANDARD'),
        ('clean_data.supplier', 'ord_conf_rem_interval', 'STANDARD'),
        ('clean_data.supplier', 'ord_conf_reminder_db', 'STANDARD'),
        ('clean_data.supplier', 'order_conf_approval_db', 'STANDARD'),
        ('clean_data.supplier', 'order_conf_diff_approval_db', 'STANDARD'),
        ('clean_data.supplier', 'pack_list_flag_db', 'STANDARD'),
        ('clean_data.supplier', 'po_change_management_db', 'STANDARD'),
        ('clean_data.supplier', 'pricat_automatic_approval_db', 'STANDARD'),
        ('clean_data.supplier', 'print_amounts_incl_tax_db', 'STANDARD'),
        ('clean_data.supplier', 'purch_order_flag_db', 'STANDARD'),
        ('clean_data.supplier', 'qc_approval_db', 'STANDARD'),
        ('clean_data.supplier', 'quick_registered_supplier_db', 'STANDARD'),
        ('clean_data.supplier', 'rec_adv_sb_consignment_db', 'STANDARD'),
        ('clean_data.supplier', 'rec_adv_sb_mix_ownership_db', 'STANDARD'),
        ('clean_data.supplier', 'rec_adv_self_billing_db', 'STANDARD'),
        ('clean_data.supplier', 'receipt_ref_reminder_db', 'STANDARD'),
        ('clean_data.supplier', 'receiving_advice_type_db', 'STANDARD'),
        ('clean_data.supplier', 'supp_grp', 'STANDARD'),
        ('clean_data.supplier', 'supplier_group', 'STANDARD'),
        ('clean_data.supplier', 'template_supplier_db', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'allow_quantity_diff', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'allow_tolerance', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'automatic_invoice', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'create_tolerance_posting', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'digital_invoice', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'exc_from_spesometro_dec', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'exclude_invoice_image', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'exclude_posting_auth', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'identity_type', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'inc_inv_curr_rate_base', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'invoice_fee', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'invoice_recipient_from', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'legal_identity', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'matching_level', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'ncf_reference_check', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'party_type', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'party_type_db', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'po_ref_rec_ref_val_method', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'print_tax_code_text', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'report_and_withhold', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'second_tin', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'service_code_required', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'tax_buy_curr_rate_base', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'tax_certificate_form', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'tax_exempt', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'utility_bill_provider', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'voting_share_percentage', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'withholding_base_amount', 'STANDARD'),
        ('clean_data.identity_pay_info', 'ar_contact', 'STANDARD'),
        ('clean_data.identity_pay_info', 'business_category', 'STANDARD'),
        ('clean_data.identity_pay_info', 'check_recipient', 'STANDARD'),
        ('clean_data.identity_pay_info', 'check_recipient_db', 'STANDARD'),
        ('clean_data.identity_pay_info', 'comm_id', 'STANDARD'),
        ('clean_data.identity_pay_info', 'corporation_id', 'STANDARD'),
        ('clean_data.identity_pay_info', 'customer_id', 'STANDARD'),
        ('clean_data.identity_pay_info', 'deduction_group', 'STANDARD'),
        ('clean_data.identity_pay_info', 'default_payment_method', 'STANDARD'),
        ('clean_data.identity_pay_info', 'disc_days_tolerance', 'STANDARD'),
        ('clean_data.identity_pay_info', 'format_no', 'STANDARD'),
        ('clean_data.identity_pay_info', 'interest_template', 'STANDARD'),
        ('clean_data.identity_pay_info', 'is_one_inv_per_pay', 'STANDARD'),
        ('clean_data.identity_pay_info', 'is_one_inv_per_pay_db', 'STANDARD'),
        ('clean_data.identity_pay_info', 'member_id', 'STANDARD'),
        ('clean_data.identity_pay_info', 'netting_allowed', 'STANDARD'),
        ('clean_data.identity_pay_info', 'next_payment_matching_id', 'STANDARD'),
        ('clean_data.identity_pay_info', 'other_payee_identity', 'STANDARD'),
        ('clean_data.identity_pay_info', 'output_media', 'STANDARD'),
        ('clean_data.identity_pay_info', 'output_media_db', 'STANDARD'),
        ('clean_data.identity_pay_info', 'party_type', 'STANDARD'),
        ('clean_data.identity_pay_info', 'party_type_db', 'STANDARD'),
        ('clean_data.identity_pay_info', 'payment_advice', 'STANDARD'),
        ('clean_data.identity_pay_info', 'payment_advice_db', 'STANDARD'),
        ('clean_data.identity_pay_info', 'payment_mode', 'STANDARD'),
        ('clean_data.identity_pay_info', 'payment_mode_db', 'STANDARD'),
        ('clean_data.identity_pay_info', 'payment_receipt_type', 'STANDARD'),
        ('clean_data.identity_pay_info', 'payment_receipt_type_db', 'STANDARD'),
        ('clean_data.identity_pay_info', 'percent_tolerance', 'STANDARD'),
        ('clean_data.identity_pay_info', 'predicted_payment_delay', 'STANDARD'),
        ('clean_data.identity_pay_info', 'predicted_payment_delay_db', 'STANDARD'),
        ('clean_data.identity_pay_info', 'priority', 'STANDARD'),
        ('clean_data.identity_pay_info', 'reminder_template', 'STANDARD'),
        ('clean_data.identity_pay_info', 'rule_id', 'STANDARD'),
        ('clean_data.identity_pay_info', 'send_interest_inv_to_payer', 'STANDARD'),
        ('clean_data.identity_pay_info', 'send_reminder_to_payer', 'STANDARD'),
        ('clean_data.identity_pay_info', 'send_stmt_of_acc_to_payer', 'STANDARD'),
        ('clean_data.identity_pay_info', 'template_id', 'STANDARD'),
        ('clean_data.payment_way_per_identity', 'default_payment_way', 'STANDARD'),
        ('clean_data.payment_way_per_identity', 'party_type', 'STANDARD'),
        ('clean_data.payment_way_per_identity', 'party_type_db', 'STANDARD'),
        ('clean_data.payment_way_per_identity', 'way_id', 'STANDARD'),
        ('clean_data.payment_address', 'account', 'ADRESSE_DEFAUT'),
        ('clean_data.payment_address', 'bank_account_validated', 'ADRESSE_DEFAUT'),
        ('clean_data.payment_address', 'bank_account_validated_db', 'ADRESSE_DEFAUT'),
        ('clean_data.payment_address', 'bic_code', 'ADRESSE_DEFAUT'),
        ('clean_data.payment_address', 'blocked_for_use', 'ADRESSE_DEFAUT'),
        ('clean_data.payment_address', 'company', 'ADRESSE_DEFAUT'),
        ('clean_data.payment_address', 'default_address', 'ADRESSE_DEFAUT'),
        ('clean_data.payment_address', 'description', 'ADRESSE_DEFAUT'),
        ('clean_data.payment_address', 'mapping_type', 'ADRESSE_DEFAUT'),
        ('clean_data.payment_address', 'party_type', 'ADRESSE_DEFAUT'),
        ('clean_data.payment_address', 'party_type_db', 'ADRESSE_DEFAUT'),
        ('clean_data.payment_address', 'way_id', 'ADRESSE_DEFAUT'),
        ('clean_data.payment_address', 'bank_account_validated', 'BANQUE'),
        ('clean_data.payment_address', 'bank_account_validated_db', 'BANQUE'),
        ('clean_data.payment_address', 'blocked_for_use', 'BANQUE'),
        ('clean_data.payment_address', 'mapping_type', 'BANQUE'),
        ('clean_data.payment_address', 'party_type', 'BANQUE'),
        ('clean_data.payment_address', 'party_type_db', 'BANQUE'),
        ('clean_data.payment_address', 'way_id', 'BANQUE'),
        ('clean_data.supplier_tax_info', 'use_supp_address_for_tax', 'STANDARD'),
        ('clean_data.supplier_tax_info', 'use_supp_address_for_tax_db', 'STANDARD'),
        ('clean_data.payment_way_per_identity', 'party_type', 'CUSTOMER'),
        ('clean_data.payment_way_per_identity', 'party_type_db', 'CUSTOMER'),
        ('clean_data.payment_way_per_identity', 'way_id', 'CUSTOMERFILE'),
        ('clean_data.activity', 'exclude_from_integrations', 'STANDARD'),
        ('clean_data.activity', 'exclude_from_integrations_db', 'STANDARD'),
        ('clean_data.activity', 'exclude_periodical_cap', 'STANDARD'),
        ('clean_data.activity', 'exclude_periodical_cap_db', 'STANDARD'),
        ('clean_data.activity', 'exclude_resource_progress', 'STANDARD'),
        ('clean_data.activity', 'exclude_resource_progress_db', 'STANDARD'),
        ('clean_data.activity', 'mandatory_invoice_comment', 'STANDARD'),
        ('clean_data.activity', 'mandatory_invoice_comment_db', 'STANDARD'),
        ('clean_data.activity', 'node_type', 'STANDARD'),
        ('clean_data.activity', 'node_type_db', 'STANDARD'),
        ('clean_data.activity', 'planned_cost_driver', 'STANDARD'),
        ('clean_data.activity', 'planned_cost_driver_db', 'STANDARD'),
        ('clean_data.activity', 'progress_method', 'STANDARD'),
        ('clean_data.activity', 'progress_method_db', 'STANDARD'),
        ('clean_data.activity', 'sub_project_id', 'STANDARD'),
        ('clean_data.cus_comm_method', 'address_default', 'STANDARD'),
        ('clean_data.cus_comm_method', 'comm_id', 'STANDARD'),
        ('clean_data.cus_comm_method', 'description', 'STANDARD'),
        ('clean_data.cus_comm_method', 'method_default', 'STANDARD'),
        ('clean_data.cus_comm_method', 'method_id', 'STANDARD'),
        ('clean_data.cus_comm_method', 'method_id_db', 'STANDARD'),
        ('clean_data.cus_comm_method', 'party_type', 'STANDARD'),
        ('clean_data.cus_comm_method', 'party_type_db', 'STANDARD'),
        ('clean_data.cus_comm_method', 'valid_from', 'STANDARD'),
        ('clean_data.cus_comm_method', 'valid_to', 'STANDARD'),
        ('clean_data.cus_comm_method', 'value', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'amount_tolerance', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'automatic_invoice', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'company', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'def_authorizer', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'def_currency', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'def_preliminary_code', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'def_vat_code', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'expire_date', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'group_id', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'identity_type', 'CUSTOMER'),
        ('clean_data.cus_ident_invoice_info', 'identity_type', 'CUSTOMERFILE'),
        ('clean_data.cus_ident_invoice_info', 'identity_type_db', 'CUSTOMER'),
        ('clean_data.cus_ident_invoice_info', 'identity_type_db', 'CUSTOMERFILE'),
        ('clean_data.cus_ident_invoice_info', 'identity_type_db', 'CUSTOMER_PHL'),
        ('clean_data.cus_ident_invoice_info', 'invoice_fee', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'national_bank_code', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'ncf_reference_check', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'no_invoice_copies', 'CUSTOMER'),
        ('clean_data.cus_ident_invoice_info', 'no_invoice_copies', 'CUSTOMERFILE'),
        ('clean_data.cus_ident_invoice_info', 'no_invoice_copies', 'CUSTOMER_PHL'),
        ('clean_data.cus_ident_invoice_info', 'numeration_group', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'party_type', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'party_type_db', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'pay_term_id', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'paym_dev_days', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'percent_tolerance', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'print_tax_code_text', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'report_and_withhold', 'CUSTOMER'),
        ('clean_data.cus_ident_invoice_info', 'report_and_withhold', 'CUSTOMERFILE'),
        ('clean_data.cus_ident_invoice_info', 'report_and_withhold_db', 'CUSTOMER'),
        ('clean_data.cus_ident_invoice_info', 'report_and_withhold_db', 'CUSTOMERFILE'),
        ('clean_data.cus_ident_invoice_info', 'report_and_withhold_db', 'CUSTOMER_PHL'),
        ('clean_data.cus_ident_invoice_info', 'rounding_tax_code', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'second_tin', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'tax_book_id', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'tax_book_type', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'tax_exempt', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'tax_exempt_valid_from', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'tax_exempt_valid_to', 'STANDARD'),
        ('clean_data.cus_ident_invoice_info', 'tax_structure_id', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'amount_tolerance', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'ar_contact', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'blocked_for_payment', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'business_category', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'check_recipient', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'check_recipient_db', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'comm_id', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'company', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'corporation_id', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'deduction_group', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'default_payment_method', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'disc_days_tolerance', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'format_no', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'interest_template', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'is_one_inv_per_pay', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'is_one_inv_per_pay_db', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'member_id', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'netting_allowed', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'next_payment_matching_id', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'other_payee_identity', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'output_media', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'output_media_db', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'party_type', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'party_type_db', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'payment_advice', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'payment_advice_db', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'payment_delay', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'payment_mode', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'payment_mode_db', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'payment_receipt_type', 'CUSTOMER'),
        ('clean_data.cus_identity_pay_info', 'payment_receipt_type', 'CUSTOMERFILE'),
        ('clean_data.cus_identity_pay_info', 'payment_receipt_type', 'CUSTOMER_PHL'),
        ('clean_data.cus_identity_pay_info', 'payment_receipt_type_db', 'CUSTOMER'),
        ('clean_data.cus_identity_pay_info', 'payment_receipt_type_db', 'CUSTOMERFILE'),
        ('clean_data.cus_identity_pay_info', 'payment_receipt_type_db', 'CUSTOMER_PHL'),
        ('clean_data.cus_identity_pay_info', 'percent_tolerance', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'predicted_payment_delay', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'predicted_payment_delay_db', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'priority', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'reminder_template', 'CUSTOMER'),
        ('clean_data.cus_identity_pay_info', 'reminder_template', 'CUSTOMERFILE'),
        ('clean_data.cus_identity_pay_info', 'reminder_template', 'CUSTOMER_PHL'),
        ('clean_data.cus_identity_pay_info', 'rule_id', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'send_interest_inv_to_payer', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'send_reminder_to_payer', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'send_stmt_of_acc_to_payer', 'STANDARD'),
        ('clean_data.cus_identity_pay_info', 'template_id', 'STANDARD'),
        ('clean_data.cus_paym_way_per_ident', 'company', 'STANDARD'),
        ('clean_data.cus_paym_way_per_ident', 'default_payment_way', 'STANDARD'),
        ('clean_data.cus_paym_way_per_ident', 'party_type', 'STANDARD'),
        ('clean_data.cus_paym_way_per_ident', 'party_type_db', 'STANDARD'),
        ('clean_data.cus_paym_way_per_ident', 'way_id', 'STANDARD'),
        ('clean_data.cus_payment_address', 'account', 'STANDARD'),
        ('clean_data.cus_payment_address', 'bank_account_valid_date', 'STANDARD'),
        ('clean_data.cus_payment_address', 'bank_account_validated', 'STANDARD'),
        ('clean_data.cus_payment_address', 'bank_account_validated_db', 'CUSTOMER'),
        ('clean_data.cus_payment_address', 'bank_account_validated_db', 'CUSTOMERFILE'),
        ('clean_data.cus_payment_address', 'bank_account_validated_db', 'CUSTOMER_PHL'),
        ('clean_data.cus_payment_address', 'bic_code', 'STANDARD'),
        ('clean_data.cus_payment_address', 'blocked_for_use', 'STANDARD'),
        ('clean_data.cus_payment_address', 'company', 'STANDARD'),
        ('clean_data.cus_payment_address', 'party_type', 'STANDARD'),
        ('clean_data.cus_payment_address', 'party_type_db', 'STANDARD'),
        ('clean_data.cus_payment_address', 'way_id', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'acquisition_site', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'category', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'category_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'commission_receiver', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'commission_receiver_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'cycle_period', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'date_del', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'discount', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'discount_type', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'forward_agent_id', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'invoice_sort', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'invoice_sort_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'last_ivc_date', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'order_conf_flag', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'order_conf_flag_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'order_id', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'pack_list_flag', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'pack_list_flag_db', 'STANDARD'),
        ('clean_data.cust_ord_customer_address', 'contact', 'STANDARD'),
        ('clean_data.cust_ord_customer_address', 'cust_calendar_id', 'STANDARD'),
        ('clean_data.cust_ord_customer_address', 'del_terms_location', 'STANDARD'),
        ('clean_data.cust_ord_customer_address', 'delivery_terms', 'STANDARD'),
        ('clean_data.cust_ord_customer_address', 'delivery_time', 'STANDARD'),
        ('clean_data.cust_ord_customer_address', 'district_code', 'STANDARD'),
        ('clean_data.cust_ord_customer_address', 'intrastat_exempt', 'CUSTOMER'),
        ('clean_data.cust_ord_customer_address', 'intrastat_exempt', 'CUSTOMERFILE'),
        ('clean_data.cust_ord_customer_address', 'intrastat_exempt', 'CUSTOMER_PHL'),
        ('clean_data.cust_ord_customer_address', 'intrastat_exempt_db', 'CUSTOMER'),
        ('clean_data.cust_ord_customer_address', 'intrastat_exempt_db', 'CUSTOMERFILE'),
        ('clean_data.cust_ord_customer_address', 'intrastat_exempt_db', 'CUSTOMER_PHL'),
        ('clean_data.cust_ord_customer_address', 'route_id', 'STANDARD'),
        ('clean_data.cust_ord_customer_address', 'ship_via_code', 'STANDARD'),
        ('clean_data.cust_ord_customer_address', 'shipment_type', 'STANDARD'),
        ('clean_data.cust_ord_customer_address', 'shipment_uncon_struct', 'STANDARD'),
        ('clean_data.cust_ord_customer_address', 'shipment_uncon_struct_db', 'STANDARD'),
        ('clean_data.customer_addr_tax_number', 'company', 'STANDARD'),
        ('clean_data.customer_addr_tax_number', 'default_tax_id_number', 'STANDARD'),
        ('clean_data.customer_addr_tax_number', 'default_tax_id_number_db', 'STANDARD'),
        ('clean_data.customer_addr_tax_number', 'tax_id_number', 'STANDARD'),
        ('clean_data.customer_addr_tax_number', 'tax_id_type', 'STANDARD'),
        ('clean_data.customer_credit_info', 'allowed_due_amount', 'STANDARD'),
        ('clean_data.customer_credit_info', 'allowed_due_days', 'STANDARD'),
        ('clean_data.customer_credit_info', 'avg_days_for_payment', 'STANDARD'),
        ('clean_data.customer_credit_info', 'company', 'STANDARD'),
        ('clean_data.customer_credit_info', 'corp_credit_relation_exist', 'STANDARD'),
        ('clean_data.customer_credit_info', 'credit_analyst_code', 'STANDARD'),
        ('clean_data.customer_credit_info', 'credit_block', 'STANDARD'),
        ('clean_data.customer_credit_info', 'credit_comments', 'STANDARD'),
        ('clean_data.customer_credit_info', 'credit_limit', 'STANDARD'),
        ('clean_data.customer_credit_info', 'credit_number', 'STANDARD'),
        ('clean_data.customer_credit_info', 'credit_rating', 'STANDARD'),
        ('clean_data.customer_credit_info', 'credit_relationship_type', 'STANDARD'),
        ('clean_data.customer_credit_info', 'credit_relationship_type_db', 'STANDARD'),
        ('clean_data.customer_credit_info', 'last4q_sales', 'STANDARD'),
        ('clean_data.customer_credit_info', 'message_type', 'STANDARD'),
        ('clean_data.customer_credit_info', 'next_review_date', 'STANDARD'),
        ('clean_data.customer_credit_info', 'note_text', 'STANDARD'),
        ('clean_data.customer_credit_info', 'parent_company', 'STANDARD'),
        ('clean_data.customer_credit_info', 'parent_identity', 'STANDARD'),
        ('clean_data.customer_credit_info', 'party_type', 'STANDARD'),
        ('clean_data.customer_credit_info', 'party_type_db', 'STANDARD'),
        ('clean_data.customer_del_tax_exempt', 'certificate_amount', 'STANDARD'),
        ('clean_data.customer_del_tax_exempt', 'company', 'STANDARD'),
        ('clean_data.customer_del_tax_exempt', 'exempt_certificate_type', 'STANDARD'),
        ('clean_data.customer_del_tax_exempt', 'exempt_certificate_type_db', 'STANDARD'),
        ('clean_data.customer_delivery_fee_code', 'company', 'STANDARD'),
        ('clean_data.customer_delivery_fee_code', 'fee_code', 'STANDARD'),
        ('clean_data.customer_delivery_fee_code', 'tax_code_selection', 'STANDARD'),
        ('clean_data.customer_delivery_tax_info', 'company', 'STANDARD'),
        ('clean_data.customer_delivery_tax_info', 'supply_country', 'STANDARD'),
        ('clean_data.customer_delivery_tax_info', 'tax_book_id', 'STANDARD'),
        ('clean_data.customer_delivery_tax_info', 'tax_book_type', 'STANDARD'),
        ('clean_data.customer_delivery_tax_info', 'tax_calc_structure_id', 'STANDARD'),
        ('clean_data.customer_delivery_tax_info', 'tax_liability', 'STANDARD'),
        ('clean_data.customer_delivery_tax_info', 'tax_structure_id', 'STANDARD'),
        ('clean_data.customer_document_tax_info', 'company', 'STANDARD'),
        ('clean_data.customer_document_tax_info', 'delivery_country', 'STANDARD'),
        ('clean_data.customer_document_tax_info', 'supply_country', 'STANDARD'),
        ('clean_data.customer_document_tax_info', 'tax_id_error_message', 'STANDARD'),
        ('clean_data.customer_document_tax_info', 'tax_id_type', 'STANDARD'),
        ('clean_data.customer_document_tax_info', 'tax_office_id', 'STANDARD'),
        ('clean_data.customer_document_tax_info', 'validated_date', 'STANDARD'),
        ('clean_data.customer_document_tax_info', 'vat_no', 'STANDARD'),
        ('clean_data.customer_info', 'b2b_customer', 'CUSTOMER'),
        ('clean_data.customer_info', 'b2b_customer', 'CUSTOMERFILE'),
        ('clean_data.customer_info', 'b2b_customer', 'CUSTOMER_PHL'),
        ('clean_data.customer_info', 'b2b_customer_db', 'STANDARD'),
        ('clean_data.customer_info', 'business_classification', 'STANDARD'),
        ('clean_data.customer_info', 'corporate_form', 'STANDARD'),
        ('clean_data.customer_info', 'country', 'STANDARD'),
        ('clean_data.customer_info', 'customer_category', 'STANDARD'),
        ('clean_data.customer_info', 'customer_category_db', 'STANDARD'),
        ('clean_data.customer_info', 'customer_tax_usage_type', 'STANDARD'),
        ('clean_data.customer_info', 'default_domain', 'STANDARD'),
        ('clean_data.customer_info', 'default_language', 'STANDARD'),
        ('clean_data.customer_info', 'identifier_ref_validation', 'CUSTOMER'),
        ('clean_data.customer_info', 'identifier_ref_validation', 'CUSTOMERFILE'),
        ('clean_data.customer_info', 'identifier_ref_validation', 'CUSTOMER_PHL'),
        ('clean_data.customer_info', 'identifier_ref_validation_db', 'STANDARD'),
        ('clean_data.customer_info', 'main_representative', 'STANDARD'),
        ('clean_data.customer_info', 'one_time', 'CUSTOMER'),
        ('clean_data.customer_info', 'one_time', 'CUSTOMERFILE'),
        ('clean_data.customer_info', 'one_time', 'CUSTOMER_PHL'),
        ('clean_data.customer_info', 'one_time_db', 'STANDARD'),
        ('clean_data.customer_info', 'party_type', 'CUSTOMER'),
        ('clean_data.customer_info', 'party_type', 'CUSTOMERFILE'),
        ('clean_data.customer_info', 'party_type', 'CUSTOMER_PHL'),
        ('clean_data.customer_info', 'party_type_db', 'STANDARD'),
        ('clean_data.customer_info', 'picture_id', 'STANDARD'),
        ('clean_data.customer_info_address', 'default_domain', 'STANDARD'),
        ('clean_data.customer_info_address', 'ean_location', 'STANDARD'),
        ('clean_data.customer_info_address', 'jurisdiction_code', 'STANDARD'),
        ('clean_data.customer_info_address', 'party_type', 'STANDARD'),
        ('clean_data.customer_info_address', 'party_type_db', 'STANDARD'),
        ('clean_data.customer_info_address', 'primary_contact', 'STANDARD'),
        ('clean_data.customer_info_address', 'secondary_contact', 'STANDARD'),
        ('clean_data.customer_info_address', 'valid_from', 'STANDARD'),
        ('clean_data.customer_info_address', 'valid_to', 'STANDARD'),
        ('clean_data.customer_info_address_type', 'address_type_code', 'STANDARD'),
        ('clean_data.customer_info_address_type', 'def_address', 'STANDARD'),
        ('clean_data.customer_info_address_type', 'default_domain', 'STANDARD'),
        ('clean_data.customer_info_contact', 'address_primary', 'STANDARD'),
        ('clean_data.customer_info_contact', 'address_secondary', 'STANDARD'),
        ('clean_data.customer_info_contact', 'contact_email', 'STANDARD'),
        ('clean_data.customer_info_contact', 'contact_title', 'STANDARD'),
        ('clean_data.customer_info_contact', 'customer_primary', 'STANDARD'),
        ('clean_data.customer_info_contact', 'customer_secondary', 'STANDARD'),
        ('clean_data.customer_info_contact', 'role', 'STANDARD'),
        ('clean_data.customer_info_contact', 'role_db', 'STANDARD'),
        ('clean_data.customer_tax_free_tax_code', 'company', 'STANDARD'),
        ('clean_data.customer_tax_free_tax_code', 'delivery_type', 'STANDARD'),
        ('clean_data.customer_tax_free_tax_code', 'vat_free_vat_code', 'CUSTOMER'),
        ('clean_data.customer_tax_free_tax_code', 'vat_free_vat_code', 'CUSTOMERFILE'),
        ('clean_data.customer_tax_free_tax_code', 'vat_free_vat_code', 'CUSTOMER_PHL'),
        ('clean_data.customer_tax_info', 'business_transaction_id', 'STANDARD'),
        ('clean_data.customer_tax_info', 'company', 'STANDARD'),
        ('clean_data.customer_tax_info', 'component_a', 'STANDARD'),
        ('clean_data.customer_tax_info', 'component_a_identity', 'STANDARD'),
        ('clean_data.customer_tax_info', 'enable_for_tcs', 'STANDARD'),
        ('clean_data.customer_tax_info', 'enable_for_tcs_db', 'STANDARD'),
        ('clean_data.customer_tax_info', 'exc_from_spesometro_dec', 'STANDARD'),
        ('clean_data.customer_tax_info', 'exc_from_spesometro_dec_db', 'STANDARD'),
        ('clean_data.customer_tax_info', 'fiscal_no', 'STANDARD'),
        ('clean_data.customer_tax_info', 'icms_tax_payer', 'STANDARD'),
        ('clean_data.customer_tax_info', 'icms_tax_payer_db', 'STANDARD'),
        ('clean_data.customer_tax_info', 'out_inv_curr_rate_base', 'STANDARD'),
        ('clean_data.customer_tax_info', 'out_inv_curr_rate_base_db', 'STANDARD'),
        ('clean_data.customer_tax_info', 'out_inv_vou_date_base', 'STANDARD'),
        ('clean_data.customer_tax_info', 'out_inv_vou_date_base_db', 'STANDARD'),
        ('clean_data.customer_tax_info', 'permanent_establishment', 'STANDARD'),
        ('clean_data.customer_tax_info', 'permanent_establishment_db', 'STANDARD'),
        ('clean_data.customer_tax_info', 'tax_exempt', 'STANDARD'),
        ('clean_data.customer_tax_info', 'tax_exempt_db', 'STANDARD'),
        ('clean_data.customer_tax_info', 'tax_exempt_valid_from', 'STANDARD'),
        ('clean_data.customer_tax_info', 'tax_exempt_valid_to', 'STANDARD'),
        ('clean_data.customer_tax_info', 'tax_office_id', 'STANDARD'),
        ('clean_data.customer_tax_info', 'tax_rounding_level', 'STANDARD'),
        ('clean_data.customer_tax_info', 'tax_rounding_level_db', 'STANDARD'),
        ('clean_data.customer_tax_info', 'tax_rounding_method', 'STANDARD'),
        ('clean_data.customer_tax_info', 'tax_rounding_method_db', 'STANDARD'),
        ('clean_data.customer_tax_info', 'tax_sell_curr_rate_base', 'STANDARD'),
        ('clean_data.customer_tax_info', 'tax_sell_curr_rate_base_db', 'STANDARD'),
        ('clean_data.customer_tax_info', 'tax_withholding', 'STANDARD'),
        ('clean_data.customer_tax_info', 'tax_withholding_db', 'STANDARD'),
        ('clean_data.customer_tax_info', 'withholding_base_amount', 'STANDARD'),
        ('clean_data.customer_tax_info', 'withholding_base_amount_db', 'STANDARD'),
        ('clean_data.ifs_article_maitre', 'actif_achat', 'STANDARD'),
        ('clean_data.ifs_article_maitre', 'actif_commercial', 'STANDARD'),
        ('clean_data.ifs_article_maitre', 'actif_dans_centre', 'STANDARD'),
        ('clean_data.ifs_article_maitre', 'actif_evaluation', 'STANDARD'),
        ('clean_data.ifs_article_maitre', 'avec_stock', 'STANDARD'),
        ('clean_data.ifs_article_maitre', 'langue', 'STANDARD'),
        ('clean_data.ifs_article_maitre', 'nombre_centres_actifs', 'STANDARD'),
        ('clean_data.ifs_article_maitre', 'nombre_magasins', 'STANDARD'),
        ('clean_data.ifs_article_maitre', 'stock_total_bloque', 'STANDARD'),
        ('clean_data.ifs_article_maitre', 'stock_total_controle', 'STANDARD'),
        ('clean_data.ifs_article_maitre', 'stock_total_libre', 'STANDARD'),
        ('clean_data.ifs_article_maitre', 'valeur_stock_magasins_total', 'STANDARD'),
        ('clean_data.invent_part_plan', 'acquired_supply_type', 'STANDARD'),
        ('clean_data.invent_part_plan', 'acquired_supply_type_db', 'STANDARD'),
        ('clean_data.invent_part_plan', 'carry_rate', 'STANDARD'),
        ('clean_data.invent_part_plan', 'lot_size_auto', 'STANDARD'),
        ('clean_data.invent_part_plan', 'lot_size_auto_db', 'STANDARD'),
        ('clean_data.invent_part_plan', 'manuf_supply_type', 'STANDARD'),
        ('clean_data.invent_part_plan', 'manuf_supply_type_db', 'STANDARD'),
        ('clean_data.invent_part_plan', 'maxweek_supply', 'STANDARD'),
        ('clean_data.invent_part_plan', 'mul_order_qty', 'STANDARD'),
        ('clean_data.invent_part_plan', 'order_point_qty_auto', 'STANDARD'),
        ('clean_data.invent_part_plan', 'order_point_qty_auto_db', 'STANDARD'),
        ('clean_data.invent_part_plan', 'order_requisition', 'STANDARD'),
        ('clean_data.invent_part_plan', 'order_requisition_db', 'STANDARD'),
        ('clean_data.invent_part_plan', 'planning_method_auto', 'STANDARD'),
        ('clean_data.invent_part_plan', 'planning_method_auto_db', 'STANDARD'),
        ('clean_data.invent_part_plan', 'proposal_release', 'STANDARD'),
        ('clean_data.invent_part_plan', 'proposal_release_db', 'STANDARD'),
        ('clean_data.invent_part_plan', 'safety_stock_auto', 'STANDARD'),
        ('clean_data.invent_part_plan', 'safety_stock_auto_db', 'STANDARD'),
        ('clean_data.invent_part_plan', 'sched_capacity', 'STANDARD'),
        ('clean_data.invent_part_plan', 'sched_capacity_db', 'STANDARD'),
        ('clean_data.invent_part_plan', 'service_rate', 'STANDARD'),
        ('clean_data.invent_part_plan', 'setup_cost', 'STANDARD'),
        ('clean_data.invent_part_plan', 'shrinkage_fac', 'STANDARD'),
        ('clean_data.invent_part_plan', 'split_manuf_acquired', 'STANDARD'),
        ('clean_data.invent_part_plan', 'split_manuf_acquired_db', 'STANDARD'),
        ('clean_data.inventory_part', 'abc_class', 'STANDARD'),
        ('clean_data.inventory_part', 'asset_class', 'STANDARD'),
        ('clean_data.inventory_part', 'automatic_capability_check_db', 'STANDARD'),
        ('clean_data.inventory_part', 'avail_activity_status_db', 'STANDARD'),
        ('clean_data.inventory_part', 'c_density', 'STANDARD'),
        ('clean_data.inventory_part', 'c_spire_code', 'STANDARD'),
        ('clean_data.inventory_part', 'co_reserve_onh_analys_flag_db', 'STANDARD'),
        ('clean_data.inventory_part', 'company', 'STANDARD'),
        ('clean_data.inventory_part', 'contract', 'STANDARD'),
        ('clean_data.inventory_part', 'count_variance', 'STANDARD'),
        ('clean_data.inventory_part', 'country_of_origin', 'STANDARD'),
        ('clean_data.inventory_part', 'cycle_code_db', 'STANDARD'),
        ('clean_data.inventory_part', 'cycle_period', 'STANDARD'),
        ('clean_data.inventory_part', 'dop_connection_db', 'STANDARD'),
        ('clean_data.inventory_part', 'dop_netting_db', 'STANDARD'),
        ('clean_data.inventory_part', 'excl_ship_pack_proposal_db', 'STANDARD'),
        ('clean_data.inventory_part', 'expected_leadtime', 'STANDARD'),
        ('clean_data.inventory_part', 'ext_service_cost_method_db', 'STANDARD'),
        ('clean_data.inventory_part', 'forecast_consumption_flag_db', 'STANDARD'),
        ('clean_data.inventory_part', 'frequency_class_db', 'STANDARD'),
        ('clean_data.inventory_part', 'hsn_sac_code', 'STANDARD'),
        ('clean_data.inventory_part', 'intrastat_conv_factor', 'STANDARD'),
        ('clean_data.inventory_part', 'inventory_part_cost_level_db', 'STANDARD'),
        ('clean_data.inventory_part', 'inventory_valuation_method_db', 'STANDARD'),
        ('clean_data.inventory_part', 'invoice_consideration_db', 'STANDARD'),
        ('clean_data.inventory_part', 'lead_time_code_db', 'STANDARD'),
        ('clean_data.inventory_part', 'lifecycle_stage_db', 'STANDARD'),
        ('clean_data.inventory_part', 'mandatory_expiration_date_db', 'STANDARD'),
        ('clean_data.inventory_part', 'manuf_leadtime', 'STANDARD'),
        ('clean_data.inventory_part', 'negative_on_hand_db', 'STANDARD'),
        ('clean_data.inventory_part', 'oe_alloc_assign_flag_db', 'STANDARD'),
        ('clean_data.inventory_part', 'onhand_analysis_flag_db', 'STANDARD'),
        ('clean_data.inventory_part', 'part_status', 'STANDARD'),
        ('clean_data.inventory_part', 'planner_buyer', 'STANDARD'),
        ('clean_data.inventory_part', 'purch_leadtime', 'STANDARD'),
        ('clean_data.inventory_part', 'qty_calc_rounding', 'STANDARD'),
        ('clean_data.inventory_part', 'reset_config_std_cost_db', 'STANDARD'),
        ('clean_data.inventory_part', 'shortage_flag_db', 'STANDARD'),
        ('clean_data.inventory_part', 'stock_management_db', 'STANDARD'),
        ('clean_data.inventory_part', 'supply_code_db', 'STANDARD'),
        ('clean_data.inventory_part', 'type_code_db', 'STANDARD'),
        ('clean_data.inventory_part', 'zero_cost_flag_db', 'STANDARD'),
        ('clean_data.jt_task', 'adjusted_duration', 'STANDARD'),
        ('clean_data.jt_task', 'appointment_required', 'STANDARD'),
        ('clean_data.jt_task', 'company', 'STANDARD'),
        ('clean_data.jt_task', 'exclude_from_scheduling', 'STANDARD'),
        ('clean_data.jt_task', 'exclude_from_scheduling_db', 'STANDARD'),
        ('clean_data.jt_task', 'fixed_start', 'STANDARD'),
        ('clean_data.jt_task', 'objtype', 'STANDARD'),
        ('clean_data.jt_task', 'objversion', 'STANDARD'),
        ('clean_data.jt_task', 'remotely_fulfilled', 'STANDARD'),
        ('clean_data.jt_task', 'scheduled_manually', 'STANDARD'),
        ('clean_data.jt_task_resource', 'crew_time_invoicing', 'STANDARD'),
        ('clean_data.jt_task_resource', 'offset_value', 'STANDARD'),
        ('clean_data.jt_task_resource', 'sourcing_option_db', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'buy_unit_meas', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'catalog_no', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'cf_alt_on_hand_qty', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'cf_ecartqtedispo', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'cf_on_supply_qty', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'change_reason', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'changes_line_item_no', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'condition_code', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'consumed_qty', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'delivery', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'delivery_db', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'discount', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'external_id', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'fbuy_unit_price', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'generated', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'is_closed', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'job_id', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'list_price', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'list_price_curr', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'manual_line', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'markup', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'mobile_created', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'mobile_created_db', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'mobile_warranty', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'mobile_warranty_db', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'no_part_description', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'objversion', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'owner', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'part_ownership', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'part_ownership_db', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'part_type', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'part_type_db', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'pegged_qty', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'pickup_task_id', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'place_in_facility_db', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'price_effective_date', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'price_list_no', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'price_source_db', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'price_source_id', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'purchase_method', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'purchase_method_db', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'qty', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'qty_assigned', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'qty_changed', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'qty_returned', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'qty_short', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'qty_to_invoice', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'quo_spare_seq', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'quo_task_seq', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'quotation_no', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'quotation_rev', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'rental', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'rental_db', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'rental_task_res_seq', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'repair_part_flag', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'rwo_contract', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'rwo_copy_prepost', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'rwo_copy_prepost_db', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'rwo_equip_object_seq', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'rwo_err_descr', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'rwo_lot_batch_no', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'rwo_mch_code', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'rwo_mch_contract', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'rwo_org_code', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'sale_unit_price', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'sale_unit_price_curr', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'sender_id', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'sender_type', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'sender_type_db', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'serial_in', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'serial_in_contract', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'service_type', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'supply_code', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'supply_code_db', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'supply_source_ref1', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'supply_source_ref2', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'supply_source_ref3', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'supply_source_ref4', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'supply_source_ref_state', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'supply_source_ref_type', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'supply_source_ref_type_db', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'swap_part_db', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'task_plan_line_seq', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'tool_fac_row_no', 'STANDARD'),
        ('clean_data.maint_material_req_line', 'wo_quo_no', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation_db', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'auto_replace_alt_comp_db', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'backflush_part_db', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'component_scrap', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'configuration_usage_db', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'consider_lead_time_db', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'contract', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'cum_leadtime', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag_db', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'engineering_info_db', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'fixed_leadtime_day', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'fixed_leadtime_hour', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'include_firm_demands', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'include_firm_supplies', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'issue_overreported_qty_db', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'issue_planned_scrap_db', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'low_level', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'mrp_control_flag_db', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'optimize_new_delivery_date', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'order_gap_time', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'over_reporting_db', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'overhaul_scrap_rule', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date_db', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp_db', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'promise_planned_db', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'routing_effectivity_db', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'run_crp', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'run_in_background', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'run_mrp', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'ship_dirty', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'ship_dirty_db', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'shrinkage_factor', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'structure_effectivity_db', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'unprotected_lead_time', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'use_theoritical_density_db', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'variable_leadtime_day', 'STANDARD'),
        ('clean_data.manuf_part_attribute', 'variable_leadtime_hour', 'STANDARD'),
        ('clean_data.part_catalog', 'allow_as_not_consumed_db', 'STANDARD'),
        ('clean_data.part_catalog', 'catch_unit_enabled_db', 'STANDARD'),
        ('clean_data.part_catalog', 'component_lot_rule_db', 'ARTICLEPHL'),
        ('clean_data.part_catalog', 'component_lot_rule_db', 'INVENTORY'),
        ('clean_data.part_catalog', 'condition_code_usage_db', 'STANDARD'),
        ('clean_data.part_catalog', 'configurable_db', 'STANDARD'),
        ('clean_data.part_catalog', 'eng_serial_tracking_code_db', 'STANDARD'),
        ('clean_data.part_catalog', 'lot_quantity_rule_db', 'STANDARD'),
        ('clean_data.part_catalog', 'lot_tracking_code_db', 'STANDARD'),
        ('clean_data.part_catalog', 'multilevel_tracking_db', 'STANDARD'),
        ('clean_data.part_catalog', 'position_part_db', 'STANDARD'),
        ('clean_data.part_catalog', 'receipt_issue_serial_track_db', 'STANDARD'),
        ('clean_data.part_catalog', 'serial_rule_db', 'STANDARD'),
        ('clean_data.part_catalog', 'serial_tracking_code_db', 'STANDARD'),
        ('clean_data.part_catalog', 'stop_arrival_issued_serial_db', 'STANDARD'),
        ('clean_data.part_catalog', 'stop_new_serial_in_rma_db', 'STANDARD'),
        ('clean_data.part_catalog', 'sub_lot_rule_db', 'STANDARD'),
        ('clean_data.payment_way_per_identity', 'company', 'STANDARD'),
        ('clean_data.payment_way_per_identity', 'valid_to', 'STANDARD'),
        ('clean_data.project_activity', 'exclude_from_integrations_db', 'STANDARD'),
        ('clean_data.project_activity', 'exclude_periodical_cap_db', 'STANDARD'),
        ('clean_data.project_activity', 'exclude_resource_progress_db', 'STANDARD'),
        ('clean_data.project_activity', 'mandatory_invoice_comment_db', 'STANDARD'),
        ('clean_data.project_activity', 'node_type_db', 'STANDARD'),
        ('clean_data.project_activity', 'planned_cost_driver_db', 'STANDARD'),
        ('clean_data.project_activity', 'progress_method_db', 'STANDARD'),
        ('clean_data.project_activity', 'sub_project_id', 'STANDARD'),
        ('clean_data.project_activity', 'task_id', 'STANDARD'),
        ('clean_data.project_base', 'baseline_revision_number', 'STANDARD'),
        ('clean_data.project_base', 'category2_id', 'STANDARD'),
        ('clean_data.project_base', 'earned_value_method', 'STANDARD'),
        ('clean_data.project_base', 'material_allocation', 'STANDARD'),
        ('clean_data.project_base', 'multi_currency_budgeting', 'STANDARD'),
        ('clean_data.project_base', 'program_id', 'STANDARD'),
        ('clean_data.project_base', 'project_misc_comp_method', 'STANDARD'),
        ('clean_data.project_base', 'work_day_to_hours_conv', 'STANDARD'),
        ('clean_data.project_margin_matrix', 'objversion', 'STANDARD'),
        ('clean_data.project_site_ext', 'auto_trans_from_std_inv_db', 'STANDARD'),
        ('clean_data.project_site_ext', 'project_site_type_db', 'STANDARD'),
        ('clean_data.project_site_ext', 'use_std_inv_in_pmrp_db', 'STANDARD'),
        ('clean_data.purchase_part', 'acquisition_origin', 'STANDARD'),
        ('clean_data.purchase_part', 'acquisition_reason_id', 'STANDARD'),
        ('clean_data.purchase_part', 'acquisition_type', 'STANDARD'),
        ('clean_data.purchase_part', 'acquisition_type_db', 'STANDARD'),
        ('clean_data.purchase_part', 'action_authorized', 'STANDARD'),
        ('clean_data.purchase_part', 'action_authorized_db', 'STANDARD'),
        ('clean_data.purchase_part', 'action_non_authorized', 'STANDARD'),
        ('clean_data.purchase_part', 'action_non_authorized_db', 'STANDARD'),
        ('clean_data.purchase_part', 'buyer_code', 'STANDARD'),
        ('clean_data.purchase_part', 'close_code', 'STANDARD'),
        ('clean_data.purchase_part', 'close_code_db', 'STANDARD'),
        ('clean_data.purchase_part', 'close_tolerance', 'STANDARD'),
        ('clean_data.purchase_part', 'company', 'STANDARD'),
        ('clean_data.purchase_part', 'contract', 'STANDARD'),
        ('clean_data.purchase_part', 'date_cre', 'STANDARD'),
        ('clean_data.purchase_part', 'dop_pegged_po_update_flag', 'STANDARD'),
        ('clean_data.purchase_part', 'dop_pegged_po_update_flag_db', 'STANDARD'),
        ('clean_data.purchase_part', 'eng_attribute', 'STANDARD'),
        ('clean_data.purchase_part', 'external_resource', 'STANDARD'),
        ('clean_data.purchase_part', 'external_resource_db', 'STANDARD'),
        ('clean_data.purchase_part', 'inventory_flag', 'STANDARD'),
        ('clean_data.purchase_part', 'inventory_flag_db', 'STANDARD'),
        ('clean_data.purchase_part', 'nbs_code', 'STANDARD'),
        ('clean_data.purchase_part', 'note_id', 'STANDARD'),
        ('clean_data.purchase_part', 'note_text', 'STANDARD'),
        ('clean_data.purchase_part', 'objid', 'STANDARD'),
        ('clean_data.purchase_part', 'objversion', 'STANDARD'),
        ('clean_data.purchase_part', 'over_delivery', 'STANDARD'),
        ('clean_data.purchase_part', 'over_delivery_db', 'STANDARD'),
        ('clean_data.purchase_part', 'over_delivery_tolerance', 'STANDARD'),
        ('clean_data.purchase_part', 'package_part_flag', 'STANDARD'),
        ('clean_data.purchase_part', 'package_part_flag_db', 'STANDARD'),
        ('clean_data.purchase_part', 'process_type', 'STANDARD'),
        ('clean_data.purchase_part', 'qc_code', 'STANDARD'),
        ('clean_data.purchase_part', 'qc_date', 'STANDARD'),
        ('clean_data.purchase_part', 'qmr_approval_template', 'STANDARD'),
        ('clean_data.purchase_part', 'qsl_approval_template', 'STANDARD'),
        ('clean_data.purchase_part', 'qsr_approval_template', 'STANDARD'),
        ('clean_data.purchase_part', 'qualified_manufacturer', 'STANDARD'),
        ('clean_data.purchase_part', 'qualified_manufacturer_db', 'STANDARD'),
        ('clean_data.purchase_part', 'qualified_supplier', 'STANDARD'),
        ('clean_data.purchase_part', 'qualified_supplier_db', 'STANDARD'),
        ('clean_data.purchase_part', 'quality_system_level_id', 'STANDARD'),
        ('clean_data.purchase_part', 'standard_pack_size', 'STANDARD'),
        ('clean_data.purchase_part', 'stat_grp', 'STANDARD'),
        ('clean_data.purchase_part', 'statistical_code', 'STANDARD'),
        ('clean_data.purchase_part', 'statistical_code_manuf', 'STANDARD'),
        ('clean_data.purchase_part', 'std_name_description', 'STANDARD'),
        ('clean_data.purchase_part', 'std_name_id', 'STANDARD'),
        ('clean_data.purchase_part', 'taxable', 'STANDARD'),
        ('clean_data.purchase_part', 'taxable_db', 'STANDARD'),
        ('clean_data.purchase_part', 'technical_coordinator_id', 'STANDARD'),
        ('clean_data.purchase_part_supplier', 'acquisition_type_db', 'STANDARD'),
        ('clean_data.purchase_part_supplier', 'dist_order_receipt_type_db', 'STANDARD'),
        ('clean_data.purchase_part_supplier', 'ext_svc_primary_vendor_db', 'STANDARD'),
        ('clean_data.purchase_part_supplier', 'external_service_allowed_db', 'STANDARD'),
        ('clean_data.purchase_part_supplier', 'issue_packaging_material_db', 'STANDARD'),
        ('clean_data.purchase_part_supplier', 'leadtime_auto_db', 'STANDARD'),
        ('clean_data.purchase_part_supplier', 'multisite_planned_part_db', 'STANDARD'),
        ('clean_data.purchase_part_supplier', 'part_ownership_db', 'STANDARD'),
        ('clean_data.purchase_part_supplier', 'primary_vendor_db', 'STANDARD'),
        ('clean_data.purchase_part_supplier', 'purchase_payment_type_db', 'STANDARD'),
        ('clean_data.purchase_part_supplier', 'qualified_supplier_db', 'STANDARD'),
        ('clean_data.purchase_part_supplier', 'quick_registered_part_db', 'STANDARD'),
        ('clean_data.purchase_part_supplier', 'receive_case_db', 'STANDARD'),
        ('clean_data.purchase_part_supplier', 'rental_primary_vendor_db', 'STANDARD'),
        ('clean_data.purchase_part_supplier', 'status_code', 'STANDARD'),
        ('clean_data.purchase_part_supplier', 'use_price_incl_tax_db', 'STANDARD'),
        ('clean_data.sales_part', 'activeind_db', 'STANDARD'),
        ('clean_data.sales_part', 'allow_inc_pkg_rsrv_picklst', 'STANDARD'),
        ('clean_data.sales_part', 'allow_incomp_pkg_delivery', 'STANDARD'),
        ('clean_data.sales_part', 'catalog_group', 'STANDARD'),
        ('clean_data.sales_part', 'catalog_type_db', 'STANDARD'),
        ('clean_data.sales_part', 'close_tolerance', 'STANDARD'),
        ('clean_data.sales_part', 'contract', 'STANDARD'),
        ('clean_data.sales_part', 'conv_factor', 'STANDARD'),
        ('clean_data.sales_part', 'cost', 'STANDARD'),
        ('clean_data.sales_part', 'country_of_origin', 'STANDARD'),
        ('clean_data.sales_part', 'create_sm_object_option_db', 'STANDARD'),
        ('clean_data.sales_part', 'customs_stat_no', 'STANDARD'),
        ('clean_data.sales_part', 'delivery_type', 'STANDARD'),
        ('clean_data.sales_part', 'expected_average_price', 'STANDARD'),
        ('clean_data.sales_part', 'export_to_external_app_db', 'STANDARD'),
        ('clean_data.sales_part', 'inverted_conv_factor', 'STANDARD'),
        ('clean_data.sales_part', 'list_price', 'STANDARD'),
        ('clean_data.sales_part', 'list_price_incl_tax', 'STANDARD'),
        ('clean_data.sales_part', 'minimum_qty', 'STANDARD'),
        ('clean_data.sales_part', 'non_inv_part_type_db', 'STANDARD'),
        ('clean_data.sales_part', 'pack_comp_in_shpmnt', 'STANDARD'),
        ('clean_data.sales_part', 'price_change_date', 'STANDARD'),
        ('clean_data.sales_part', 'price_conv_factor', 'STANDARD'),
        ('clean_data.sales_part', 'primary_catalog_db', 'STANDARD'),
        ('clean_data.sales_part', 'quick_registered_part_db', 'STANDARD'),
        ('clean_data.sales_part', 'rental_list_price', 'STANDARD'),
        ('clean_data.sales_part', 'rental_list_price_incl_tax', 'STANDARD'),
        ('clean_data.sales_part', 'sales_price_group_id', 'STANDARD'),
        ('clean_data.sales_part', 'sales_type_db', 'STANDARD'),
        ('clean_data.sales_part', 'sourcing_option_db', 'STANDARD'),
        ('clean_data.sales_part', 'statistical_code', 'STANDARD'),
        ('clean_data.sales_part', 'tax_class_id', 'STANDARD'),
        ('clean_data.sales_part', 'tax_code', 'STANDARD'),
        ('clean_data.sales_part', 'taxable_db', 'STANDARD'),
        ('clean_data.sales_part', 'use_price_incl_tax_db', 'STANDARD'),
        ('clean_data.sub_project', 'exclude_from_integrations_db', 'STANDARD'),
        ('clean_data.sub_project', 'financially_completed_db', 'STANDARD'),
        ('clean_data.payment_way_per_identity', 'party_type', 'CUSTOMERFILE'),
        ('clean_data.payment_way_per_identity', 'party_type_db', 'CUSTOMERFILE'),
        ('clean_data.payment_way_per_identity', 'party_type', 'CUSTOMER_PHL'),
        ('clean_data.payment_way_per_identity', 'party_type_db', 'CUSTOMER_PHL'),
        ('clean_data.payment_way_per_identity', 'way_id', 'CUSTOMER_PHL'),
        ('clean_data.pm_action', 'org_contract', 'STANDARD'),
        ('clean_data.pm_action', 'org_code', 'STANDARD'),
        ('clean_data.pm_action', 'pm_revision', 'STANDARD'),
        ('clean_data.pm_action', 'connection_type', 'STANDARD'),
        ('clean_data.pm_action', 'connection_type_db', 'STANDARD'),
        ('clean_data.pm_action_work_step', 'mch_code_contract', 'STANDARD'),
        ('clean_data.pm_action_work_step', 'pm_revision', 'STANDARD'),
        ('clean_data.pm_action_work_step', 'connection_type', 'STANDARD'),
        ('clean_data.pm_action_work_step', 'connection_type_db', 'STANDARD'),
        ('clean_data.pm_action_resource', 'pm_revision', 'STANDARD'),
        ('clean_data.pm_action_resource', 'demand_type', 'STANDARD'),
        ('clean_data.pm_action_resource', 'demand_type_db', 'STANDARD'),
        ('clean_data.pm_action_role', 'org_contract', 'STANDARD'),
        ('clean_data.pm_action_role', 'org_code', 'STANDARD'),
        ('clean_data.pm_action_role', 'pm_revision', 'STANDARD'),
        ('clean_data.inventory_part', 'c_density', 'FIL'),
        ('clean_data.cus_comm_method', 'address_default', 'EMAIL_PRINCIPAL'),
        ('clean_data.cus_comm_method', 'address_default', 'FAX'),
        ('clean_data.cus_comm_method', 'address_default', 'FAX_ADRESSE'),
        ('clean_data.cus_comm_method', 'address_default', 'PHONE_ADRESSE'),
        ('clean_data.cus_comm_method', 'address_default', 'PHONE_PRINCIPAL'),
        ('clean_data.cus_comm_method', 'address_default', 'PHONE_SECONDAIRE'),
        ('clean_data.cus_comm_method', 'address_default', 'TELETEX'),
        ('clean_data.cus_comm_method', 'address_default', 'TELEX'),
        ('clean_data.cus_comm_method', 'description', 'EMAIL_PRINCIPAL'),
        ('clean_data.cus_comm_method', 'description', 'FAX'),
        ('clean_data.cus_comm_method', 'description', 'FAX_ADRESSE'),
        ('clean_data.cus_comm_method', 'description', 'PHONE_ADRESSE'),
        ('clean_data.cus_comm_method', 'description', 'PHONE_PRINCIPAL'),
        ('clean_data.cus_comm_method', 'description', 'PHONE_SECONDAIRE'),
        ('clean_data.cus_comm_method', 'description', 'TELETEX'),
        ('clean_data.cus_comm_method', 'description', 'TELEX'),
        ('clean_data.cus_comm_method', 'method_default', 'EMAIL_PRINCIPAL'),
        ('clean_data.cus_comm_method', 'method_default', 'FAX'),
        ('clean_data.cus_comm_method', 'method_default', 'FAX_ADRESSE'),
        ('clean_data.cus_comm_method', 'method_default', 'PHONE_ADRESSE'),
        ('clean_data.cus_comm_method', 'method_default', 'PHONE_PRINCIPAL'),
        ('clean_data.cus_comm_method', 'method_default', 'PHONE_SECONDAIRE'),
        ('clean_data.cus_comm_method', 'method_default', 'TELETEX'),
        ('clean_data.cus_comm_method', 'method_default', 'TELEX'),
        ('clean_data.cus_comm_method', 'method_id', 'EMAIL_PRINCIPAL'),
        ('clean_data.cus_comm_method', 'method_id', 'FAX'),
        ('clean_data.cus_comm_method', 'method_id', 'FAX_ADRESSE'),
        ('clean_data.cus_comm_method', 'method_id', 'PHONE_ADRESSE'),
        ('clean_data.cus_comm_method', 'method_id', 'PHONE_PRINCIPAL'),
        ('clean_data.cus_comm_method', 'method_id', 'PHONE_SECONDAIRE'),
        ('clean_data.cus_comm_method', 'method_id', 'TELETEX'),
        ('clean_data.cus_comm_method', 'method_id', 'TELEX'),
        ('clean_data.cus_comm_method', 'method_id_db', 'EMAIL_PRINCIPAL'),
        ('clean_data.cus_comm_method', 'method_id_db', 'FAX'),
        ('clean_data.cus_comm_method', 'method_id_db', 'FAX_ADRESSE'),
        ('clean_data.cus_comm_method', 'method_id_db', 'PHONE_ADRESSE'),
        ('clean_data.cus_comm_method', 'method_id_db', 'PHONE_PRINCIPAL'),
        ('clean_data.cus_comm_method', 'method_id_db', 'PHONE_SECONDAIRE'),
        ('clean_data.cus_comm_method', 'method_id_db', 'TELETEX'),
        ('clean_data.cus_comm_method', 'method_id_db', 'TELEX'),
        ('clean_data.inventory_part', 'type_code_db', 'ARTICLEPHL'),
        ('clean_data.inventory_part', 'lead_time_code_db', 'ARTICLEPHL'),
        ('clean_data.inventory_part', 'zero_cost_flag_db', 'ARTICLEPHL'),
        ('clean_data.inventory_part', 'type_code_db', 'SILICIUM'),
        ('clean_data.inventory_part', 'lead_time_code_db', 'SILICIUM'),
        ('clean_data.inventory_part', 'zero_cost_flag_db', 'SILICIUM'),
        ('clean_data.cust_ord_customer', 'adv_inv_full_pay', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'adv_inv_full_pay_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'allow_auto_sub_of_parts', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'allow_auto_sub_of_parts_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'auto_despatch_adv_send', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'b2b_auto_create_co_from_sq', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'b2b_auto_create_co_from_sq_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'backorder_option', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'backorder_option_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'check_sales_grp_deliv_conf', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'check_sales_grp_deliv_conf_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'confirm_deliveries', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'confirm_deliveries_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'confirm_direct_deliveries', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'consol_rental_ivc_serial', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'consol_rental_ivc_serial_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'credit_control_group_id', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'cust_grp', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'cust_price_group_id', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'default_inv_currency', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'discount_type', 'CUSTOMERFILE'),
        ('clean_data.cust_ord_customer', 'edi_authorize_code', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'edi_auto_approval_user', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'edi_auto_change_approval', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'edi_auto_change_approval_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'edi_auto_order_approval', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'edi_auto_order_approval_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'edi_site', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'email_invoice', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'email_invoice_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'email_order_conf', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'email_order_conf_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'exclude_from_scan_order', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'handl_unit_at_co_delivery', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'handl_unit_at_co_delivery_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'market_code', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'match_type', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'match_type_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'min_sales_amount', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'mul_tier_del_notification', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'mul_tier_del_notification_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'no_delnote_copies', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'note_id', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'print_amounts_incl_tax', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'print_amounts_incl_tax_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'print_control_code', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'print_delivered_lines', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'print_delivered_lines_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'print_withholding_tax', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'print_withholding_tax_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'priority', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'quick_registered_customer', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'quick_registered_customer_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'rec_adv_auto_approval_user', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'rec_adv_auto_match_diff', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'rec_adv_auto_match_diff_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'rec_adv_auto_matching', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'rec_adv_auto_matching_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'rec_adv_matching_option', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'rec_adv_matching_option_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'receive_pack_size_chg', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'receive_pack_size_chg_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'receiving_advice_type', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'receiving_advice_type_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'release_internal_order', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'release_internal_order_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'replicate_doc_text', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'replicate_doc_text_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'salesman_code', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'sbi_auto_approval_user', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'self_billing_match_option', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'self_billing_match_option_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'send_change_message', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'send_change_message_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'summarized_freight_charges', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'summarized_freight_charges_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'summarized_source_lines', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'summarized_source_lines_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'template_customer', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'template_customer_db', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'template_customer_desc', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'template_id', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'update_price_from_sbi', 'STANDARD'),
        ('clean_data.cust_ord_customer', 'update_price_from_sbi_db', 'STANDARD'),
        ('clean_data.supplier', 'currency_code', 'STANDARD'),
        ('clean_data.identity_invoice_info', 'def_currency', 'STANDARD'),
        ('clean_data.supplier_addr_tax_number', 'company', 'STANDARD'),
        ('clean_data.supplier_addr_tax_number', 'tax_id_type', 'TVA_UE'),
        ('clean_data.supplier_addr_tax_number', 'tax_id_type', 'SIREN'),
        ('clean_data.supplier_addr_tax_number', 'tax_id_type', 'SIRET'),
        ('clean_data.supplier_addr_tax_number', 'default_tax_id_number_db', 'TVA_UE'),
        ('clean_data.supplier_addr_tax_number', 'default_tax_id_number_db', 'SIREN'),
        ('clean_data.supplier_addr_tax_number', 'default_tax_id_number_db', 'SIRET')
    ) AS attendu(table_cible, colonne, variante)
    WHERE NOT EXISTS (
        SELECT 1 FROM public.etl_default_values d
        WHERE d.table_cible = attendu.table_cible
          AND d.colonne = attendu.colonne
          AND COALESCE(d.variante, 'STANDARD') = attendu.variante);
    IF v_manquantes > 0 THEN
        RAISE EXCEPTION 'Il reste % valeur(s) par defaut absente(s)', v_manquantes;
    END IF;
    RAISE NOTICE 'Valeurs par defaut : les % lignes attendues sont presentes', 1029;
END $$;

COMMIT;
