-- Migration 086 : pm_action.work_type_id passe par une valeur par defaut
--
-- clean_data.populate_pm_action() lit desormais work_type_id via
-- public.get_default_value('clean_data.pm_action', 'work_type_id').
-- Valeur a saisir dans Configuration > Valeurs par defaut (vide -> NULL au chargement).
-- A jouer AVANT sql/pm_actions/compile.sh.

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action', 'work_type_id', 'STANDARD', 'CONSTANTE', NULL, 'Type de travail IFS (varchar 20) des actions preventives. Source : 01_populate_pm_action.sql', 'migration_086')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- Delai de generation BT (IFS WO_GEN_LEAD_TIME, en jours) : 30 par defaut
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action', 'wo_gen_lead_time', 'STANDARD', 'CONSTANTE', '30', 'Delai de generation BT (jours). Source : 01_populate_pm_action.sql', 'migration_086')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
