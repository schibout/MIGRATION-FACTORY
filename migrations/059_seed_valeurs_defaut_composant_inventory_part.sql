-- =====================================================================
-- Valeurs par defaut INVENTORY_PART du module articleComposant
--
-- Source : sql/ArticleComposant/valeurParDefaut/inventoryPartStjn.csv et
-- inventoryPartCastel.csv (gabarits de chargement IFS fournis par le metier).
-- Les deux gabarits sont identiques a l'exception de la methode de valorisation
-- (SJ = Standard Cost / ST, CS = Weighted Average / AV) -> variante par site.
--
-- Le module lit desormais TOUTES ses constantes en variante COMPOSANT : il ne
-- depend plus des lignes STANDARD d'autres modules, dont plusieurs divergeaient
-- du gabarit (company SJM vs TRIMET, type_code_db 1 vs 4, lead_time_code_db Y vs P,
-- shortage_flag_db Y vs N, forecast_consumption_flag_db FORECAST vs NOFORECAST,
-- stock_management_db Y vs SYSTEM MANAGED INVENTORY, invoice_consideration_db
-- TRANSACTION BASED vs IGNORE INVOICE PRICE, qty_calc_rounding 0 vs 16).
--
-- INSERT ... ON CONFLICT DO NOTHING : rejouable, ne remplace jamais une valeur
-- ajustee depuis l'ecran /configuration/valeurs-defaut.
-- =====================================================================

BEGIN;

-- La migration 055 avait pose ces deux valeurs par alignement sur le module PHL,
-- avant reception des gabarits metier qui les contredisent (type_code_db 1 -> 4,
-- lead_time_code_db Y -> P). On les retire pour que les INSERT ci-dessous prennent.
DELETE FROM public.etl_default_values
WHERE table_cible = 'clean_data.inventory_part'
  AND colonne IN ('type_code_db', 'lead_time_code_db')
  AND variante = 'COMPOSANT';

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'abc_class', 'COMPOSANT', 'CONSTANTE', 'C', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'asset_class', 'COMPOSANT', 'CONSTANTE', 'S', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'automatic_capability_check', 'COMPOSANT', 'CONSTANTE', 'No Automatic Capability Check', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'automatic_capability_check_db', 'COMPOSANT', 'CONSTANTE', 'NO AUTOMATIC CAPABILITY CHECK', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'avail_activity_status', 'COMPOSANT', 'CONSTANTE', 'Changed', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'avail_activity_status_db', 'COMPOSANT', 'CONSTANTE', 'CHANGED', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'c_is_green', 'COMPOSANT', 'CONSTANTE', 'False', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'c_is_green_db', 'COMPOSANT', 'CONSTANTE', 'FALSE', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'co_reserve_onh_analys_flag', 'COMPOSANT', 'CONSTANTE', 'No Availability Check', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'co_reserve_onh_analys_flag_db', 'COMPOSANT', 'CONSTANTE', 'N', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'company', 'COMPOSANT', 'CONSTANTE', 'TRIMET', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'consumption_tax', 'COMPOSANT', 'CONSTANTE', 'False', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'consumption_tax_db', 'COMPOSANT', 'CONSTANTE', 'FALSE', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'count_variance', 'COMPOSANT', 'CONSTANTE', '0', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'cycle_code', 'COMPOSANT', 'CONSTANTE', 'Not Cyclic Counting', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'cycle_code_db', 'COMPOSANT', 'CONSTANTE', 'N', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'cycle_period', 'COMPOSANT', 'CONSTANTE', '0', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'dop_connection', 'COMPOSANT', 'CONSTANTE', 'Automatic DOP', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'dop_connection_db', 'COMPOSANT', 'CONSTANTE', 'AUT', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'dop_netting', 'COMPOSANT', 'CONSTANTE', 'No Netting', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'dop_netting_db', 'COMPOSANT', 'CONSTANTE', 'NONET', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'estimated_material_cost', 'COMPOSANT', 'CONSTANTE', '0', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'excl_ship_pack_proposal', 'COMPOSANT', 'CONSTANTE', 'False', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'excl_ship_pack_proposal_db', 'COMPOSANT', 'CONSTANTE', 'FALSE', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'expected_leadtime', 'COMPOSANT', 'CONSTANTE', '0', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'ext_service_cost_method', 'COMPOSANT', 'CONSTANTE', 'Exclude Service Cost', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'ext_service_cost_method_db', 'COMPOSANT', 'CONSTANTE', 'EXCLUDE SERVICE COST', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'forecast_consumption_flag', 'COMPOSANT', 'CONSTANTE', 'No Online Consumption', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'forecast_consumption_flag_db', 'COMPOSANT', 'CONSTANTE', 'NOFORECAST', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'frequency_class', 'COMPOSANT', 'CONSTANTE', 'Very Slow Mover', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'frequency_class_db', 'COMPOSANT', 'CONSTANTE', 'VERY SLOW MOVER', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_part_cost_level', 'COMPOSANT', 'CONSTANTE', 'Cost Per Part', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_part_cost_level_db', 'COMPOSANT', 'CONSTANTE', 'COST PER PART', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'invoice_consideration', 'COMPOSANT', 'CONSTANTE', 'Ignore Invoice Price', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'invoice_consideration_db', 'COMPOSANT', 'CONSTANTE', 'IGNORE INVOICE PRICE', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'lead_time_code', 'COMPOSANT', 'CONSTANTE', 'Purchased', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'lead_time_code_db', 'COMPOSANT', 'CONSTANTE', 'P', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'lifecycle_stage', 'COMPOSANT', 'CONSTANTE', 'Development', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'lifecycle_stage_db', 'COMPOSANT', 'CONSTANTE', 'DEVELOPMENT', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'mandatory_expiration_date', 'COMPOSANT', 'CONSTANTE', 'False', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'mandatory_expiration_date_db', 'COMPOSANT', 'CONSTANTE', 'FALSE', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'manuf_leadtime', 'COMPOSANT', 'CONSTANTE', '0', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'min_durab_days_co_deliv', 'COMPOSANT', 'CONSTANTE', '0', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'min_durab_days_planning', 'COMPOSANT', 'CONSTANTE', '0', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'negative_on_hand', 'COMPOSANT', 'CONSTANTE', 'Negative On Hand Not Allowed', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'negative_on_hand_db', 'COMPOSANT', 'CONSTANTE', 'NEG ONHAND NOT OK', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'oe_alloc_assign_flag', 'COMPOSANT', 'CONSTANTE', 'Normal reservation', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'oe_alloc_assign_flag_db', 'COMPOSANT', 'CONSTANTE', 'N', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'onhand_analysis_flag', 'COMPOSANT', 'CONSTANTE', 'No Availability Check', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'onhand_analysis_flag_db', 'COMPOSANT', 'CONSTANTE', 'N', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'part_catalog_configurable', 'COMPOSANT', 'CONSTANTE', 'Not Configured', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'part_catalog_configurable_db', 'COMPOSANT', 'CONSTANTE', 'NOT CONFIGURED', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'part_catalog_std_name_id', 'COMPOSANT', 'CONSTANTE', '0', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'part_status', 'COMPOSANT', 'CONSTANTE', 'A', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'planner_buyer', 'COMPOSANT', 'CONSTANTE', '*', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'purch_leadtime', 'COMPOSANT', 'CONSTANTE', '0', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'qty_calc_rounding', 'COMPOSANT', 'CONSTANTE', '16', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'reset_config_std_cost', 'COMPOSANT', 'CONSTANTE', 'False', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'reset_config_std_cost_db', 'COMPOSANT', 'CONSTANTE', 'FALSE', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'shortage_flag', 'COMPOSANT', 'CONSTANTE', 'No Shortage Notation', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'shortage_flag_db', 'COMPOSANT', 'CONSTANTE', 'N', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'stock_management', 'COMPOSANT', 'CONSTANTE', 'System Managed Inventory', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'stock_management_db', 'COMPOSANT', 'CONSTANTE', 'SYSTEM MANAGED INVENTORY', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'supply_code', 'COMPOSANT', 'CONSTANTE', 'Inventory Order', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'supply_code_db', 'COMPOSANT', 'CONSTANTE', 'IO', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'tax_manuf_equivalent', 'COMPOSANT', 'CONSTANTE', 'False', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'tax_manuf_equivalent_db', 'COMPOSANT', 'CONSTANTE', 'FALSE', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'type_code', 'COMPOSANT', 'CONSTANTE', 'Purchased', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'type_code_db', 'COMPOSANT', 'CONSTANTE', '4', 'Source : inventoryPartStjn.csv / inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method', 'COMPOSANT_SJ', 'CONSTANTE', 'Standard Cost', 'Source : inventoryPartStjn.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method_db', 'COMPOSANT_SJ', 'CONSTANTE', 'ST', 'Source : inventoryPartStjn.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method', 'COMPOSANT_CS', 'CONSTANTE', 'Weighted Average', 'Source : inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method_db', 'COMPOSANT_CS', 'CONSTANTE', 'AV', 'Source : inventoryPartCastel.csv', 'migration_059')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

COMMIT;
