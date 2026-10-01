-- Migration 088 : pm_action.pm_start_unit_db passe par une valeur par defaut
--
-- clean_data.populate_pm_action() lit desormais pm_start_unit_db via
-- public.get_default_value('clean_data.pm_action', 'pm_start_unit_db') : DAY par defaut.
-- A jouer AVANT sql/pm_actions/compile.sh.

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action', 'pm_start_unit_db', 'STANDARD', 'CONSTANTE', 'DAY', 'Unite de depart IFS (PM_START_UNIT_DB) des actions preventives. Source : 01_populate_pm_action.sql', 'migration_088')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
