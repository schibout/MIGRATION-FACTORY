-- Migration 090 : pm_action.state / objstate (valeurs par defaut Actif / Active)
--
-- Colonnes absentes de clean_data.pm_action : ajoutees ici, alimentees par
-- clean_data.populate_pm_action() via public.get_default_value et ajoutees a
-- l'export (etl_export_queries, categorie PM Action).
-- A jouer AVANT sql/pm_actions/compile.sh.

BEGIN;

ALTER TABLE clean_data.pm_action ADD COLUMN IF NOT EXISTS state    varchar(50);
ALTER TABLE clean_data.pm_action ADD COLUMN IF NOT EXISTS objstate varchar(50);

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action', 'state', 'STANDARD', 'CONSTANTE', 'Actif', 'Etat IFS (libelle) des actions preventives. Source : 01_populate_pm_action.sql', 'migration_090')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('pm_actions', 'clean_data.pm_action', 'objstate', 'STANDARD', 'CONSTANTE', 'Active', 'Etat IFS (OBJSTATE) des actions preventives. Source : 01_populate_pm_action.sql', 'migration_090')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

UPDATE public.etl_export_queries
SET column_list = column_list || ', state, objstate'
WHERE table_schema = 'clean_data' AND table_name = 'pm_action'
  AND column_list NOT LIKE '%objstate%';

COMMIT;
