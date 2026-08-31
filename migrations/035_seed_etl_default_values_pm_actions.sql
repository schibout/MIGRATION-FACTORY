-- Migration 035 : seed des valeurs par defaut ETL du module pm_actions
--
-- Les procedures clean_data.populate_pm_action* portaient ces constantes IFS dans leur
-- bloc DECLARE (`v_org_code VARCHAR := 'FR_MAINT'`), une forme que l'inventaire
-- automatique (extract_default_values.py, qui ne voit que les projections
-- `<litteral> as <colonne>`) ne detectait pas. Les initialiseurs passent desormais par
-- public.get_default_value() avec l'ancienne valeur en repli : chargement inchange.
--
-- Ces lignes rendent les valeurs visibles et modifiables depuis l'ecran
-- Configuration > Valeurs par defaut, sans retoucher les procedures.

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action', 'org_contract', 'STANDARD', 'CONSTANTE', 'SJ', 'Source : 01_populate_pm_action.sql (site des objets fonctionnels)', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action', 'org_code', 'STANDARD', 'CONSTANTE', 'FR_MAINT', 'Source : 01_populate_pm_action.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action', 'pm_revision', 'STANDARD', 'CONSTANTE', '1', 'Source : 01_populate_pm_action.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action', 'connection_type', 'STANDARD', 'CONSTANTE', 'Functional Object', 'Source : 01_populate_pm_action.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action', 'connection_type_db', 'STANDARD', 'CONSTANTE', 'FUNCTIONAL', 'Source : 01_populate_pm_action.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action_work_step', 'mch_code_contract', 'STANDARD', 'CONSTANTE', 'SJ', 'Source : 02_populate_pm_action_work_step.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action_work_step', 'pm_revision', 'STANDARD', 'CONSTANTE', '1', 'Source : 02_populate_pm_action_work_step.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action_work_step', 'connection_type', 'STANDARD', 'CONSTANTE', 'Functional Object', 'Source : 02_populate_pm_action_work_step.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action_work_step', 'connection_type_db', 'STANDARD', 'CONSTANTE', 'FUNCTIONAL', 'Source : 02_populate_pm_action_work_step.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action_resource', 'pm_revision', 'STANDARD', 'CONSTANTE', '1', 'Source : 03_populate_pm_action_resource.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action_resource', 'demand_type', 'STANDARD', 'CONSTANTE', 'Work Order', 'Source : 03_populate_pm_action_resource.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action_resource', 'demand_type_db', 'STANDARD', 'CONSTANTE', 'WORK_ORDER', 'Source : 03_populate_pm_action_resource.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action_role', 'org_contract', 'STANDARD', 'CONSTANTE', 'SJ', 'Source : 04_populate_pm_action_role.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action_role', 'org_code', 'STANDARD', 'CONSTANTE', 'FR_MAINT', 'Source : 04_populate_pm_action_role.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action_role', 'pm_revision', 'STANDARD', 'CONSTANTE', '1', 'Source : 04_populate_pm_action_role.sql', 'migration_035')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
