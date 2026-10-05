-- Migration 097 : valeur par defaut de clean_data.jt_task.allow_multiple_visits_db = 'TRUE'
--
-- Colonne jusque-la non alimentee. Seule la colonne _db est renseignee (le libelle
-- allow_multiple_visits reste NULL, regle des couples <col>/<col>_db). Modifiable
-- dans l'ecran Valeurs par defaut. A jouer AVANT sql/operation/compile.sh, sinon NULL.

BEGIN;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task', 'allow_multiple_visits_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : create_alimenter_jt_task.sql', 'migration_097')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

COMMIT;
