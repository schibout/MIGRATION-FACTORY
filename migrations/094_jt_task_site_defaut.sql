-- Migration 094 : valeur par defaut de clean_data.jt_task.site
--
-- Comme organization_site (migration 093) : site recevait la division SAP
-- (werks, 9200) ou 'SJM' a defaut, inconnues cote IFS. Elle lit desormais
-- public.get_default_value('clean_data.jt_task', 'site') = 'SJ', modifiable dans
-- l'ecran Valeurs par defaut. A jouer AVANT sql/operation/compile.sh, sinon NULL.

BEGIN;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task', 'site', 'STANDARD', 'CONSTANTE', 'SJ', 'Source : create_alimenter_jt_task.sql', 'migration_094')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

COMMIT;
