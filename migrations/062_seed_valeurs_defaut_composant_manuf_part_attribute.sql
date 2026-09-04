-- =====================================================================
-- Valeurs par defaut MANUF_PART_ATTRIBUTE du module articleComposant
--
-- Source : sql/ArticleComposant/valeurParDefaut/manuf_part_attribute.csv
-- (gabarit de chargement IFS fourni par le metier : une ligne SJ et une ligne CS,
-- identiques hors CONTRACT et PART_NO -> variante COMPOSANT unique).
--
-- Ce gabarit documente deux composants ACHETES (ALBE et DC1000) : la table est
-- donc alimentee pour TOUS les composants, et non pour les seuls articles
-- fabriques comme le faisait la version heritee du module PHL.
--
-- Le module lit toutes ses constantes en variante COMPOSANT ; trois lignes
-- STANDARD contredisaient le gabarit (prod_part_as_supply_in_mrp_db FALSE vs TRUE,
-- plan_manuf_sup_on_due_date_db TRUE vs FALSE, overhaul_scrap_rule DIRECT vs
-- "Direct Scrap", le code DIRECT allant desormais dans overhaul_scrap_rule_db).
--
-- INSERT ... ON CONFLICT DO NOTHING : rejouable, ne remplace jamais une valeur
-- ajustee depuis l'ecran /configuration/valeurs-defaut.
-- =====================================================================

BEGIN;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation', 'COMPOSANT', 'CONSTANTE', 'False', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation_db', 'COMPOSANT', 'CONSTANTE', 'FALSE', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'auto_replace_alt_comp', 'COMPOSANT', 'CONSTANTE', 'False', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'auto_replace_alt_comp_db', 'COMPOSANT', 'CONSTANTE', 'FALSE', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'backflush_part', 'COMPOSANT', 'CONSTANTE', 'All Locations', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'backflush_part_db', 'COMPOSANT', 'CONSTANTE', 'Y', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'close_tolerance', 'COMPOSANT', 'CONSTANTE', '0', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'component_scrap', 'COMPOSANT', 'CONSTANTE', '0', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'configuration_usage', 'COMPOSANT', 'CONSTANTE', 'Common', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'configuration_usage_db', 'COMPOSANT', 'CONSTANTE', 'Common', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'consider_lead_time', 'COMPOSANT', 'CONSTANTE', 'True', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'consider_lead_time_db', 'COMPOSANT', 'CONSTANTE', 'TRUE', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'cum_leadtime', 'COMPOSANT', 'CONSTANTE', '0', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag', 'COMPOSANT', 'CONSTANTE', 'Planned', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag_db', 'COMPOSANT', 'CONSTANTE', 'PLANNED', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'engineering_info', 'COMPOSANT', 'CONSTANTE', 'Not Mandatory', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'engineering_info_db', 'COMPOSANT', 'CONSTANTE', '0', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'fixed_leadtime_day', 'COMPOSANT', 'CONSTANTE', '0', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'fixed_leadtime_hour', 'COMPOSANT', 'CONSTANTE', '0', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'include_firm_demands', 'COMPOSANT', 'CONSTANTE', 'TRUE', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'include_firm_supplies', 'COMPOSANT', 'CONSTANTE', 'TRUE', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_overreported_qty', 'COMPOSANT', 'CONSTANTE', 'False', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_overreported_qty_db', 'COMPOSANT', 'CONSTANTE', 'FALSE', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_planned_scrap', 'COMPOSANT', 'CONSTANTE', 'True', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_planned_scrap_db', 'COMPOSANT', 'CONSTANTE', 'TRUE', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type', 'COMPOSANT', 'CONSTANTE', 'Reserve And Backflush', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type_db', 'COMPOSANT', 'CONSTANTE', 'RESERVE_AND_BACKFLUSH', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'low_level', 'COMPOSANT', 'CONSTANTE', '0', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'mrp_control_flag', 'COMPOSANT', 'CONSTANTE', 'True', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'mrp_control_flag_db', 'COMPOSANT', 'CONSTANTE', 'TRUE', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'optimize_new_delivery_date', 'COMPOSANT', 'CONSTANTE', 'FALSE', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'order_gap_time', 'COMPOSANT', 'CONSTANTE', '0', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'over_reporting', 'COMPOSANT', 'CONSTANTE', 'Allowed', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'over_reporting_db', 'COMPOSANT', 'CONSTANTE', 'ALLOWED', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule', 'COMPOSANT', 'CONSTANTE', 'Direct Scrap', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule_db', 'COMPOSANT', 'CONSTANTE', 'DIRECT', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date', 'COMPOSANT', 'CONSTANTE', 'False', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date_db', 'COMPOSANT', 'CONSTANTE', 'FALSE', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp', 'COMPOSANT', 'CONSTANTE', 'True', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp_db', 'COMPOSANT', 'CONSTANTE', 'TRUE', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'promise_planned', 'COMPOSANT', 'CONSTANTE', 'Promised', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'promise_planned_db', 'COMPOSANT', 'CONSTANTE', 'Promised', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'routing_effectivity', 'COMPOSANT', 'CONSTANTE', 'Date', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'routing_effectivity_db', 'COMPOSANT', 'CONSTANTE', 'DATE', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'run_crp', 'COMPOSANT', 'CONSTANTE', 'FALSE', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'run_in_background', 'COMPOSANT', 'CONSTANTE', 'FALSE', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'run_mrp', 'COMPOSANT', 'CONSTANTE', 'FALSE', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'ship_dirty', 'COMPOSANT', 'CONSTANTE', 'False', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'ship_dirty_db', 'COMPOSANT', 'CONSTANTE', 'FALSE', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'shrinkage_factor', 'COMPOSANT', 'CONSTANTE', '0', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'structure_effectivity', 'COMPOSANT', 'CONSTANTE', 'Date', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'structure_effectivity_db', 'COMPOSANT', 'CONSTANTE', 'DATE', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'unprotected_lead_time', 'COMPOSANT', 'CONSTANTE', '0', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'use_theoritical_density', 'COMPOSANT', 'CONSTANTE', 'False', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'use_theoritical_density_db', 'COMPOSANT', 'CONSTANTE', 'FALSE', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'variable_leadtime_day', 'COMPOSANT', 'CONSTANTE', '0', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'variable_leadtime_hour', 'COMPOSANT', 'CONSTANTE', '0', 'Source : manuf_part_attribute.csv', 'migration_062')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

COMMIT;
