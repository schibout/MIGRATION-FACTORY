-- Migration 095 : clean_data.jt_task.company = 'TRIMET'
--
-- La procedure lit deja public.get_default_value('clean_data.jt_task', 'company') ;
-- la ligne seedee par la 032 valait 'TRIM'. Le seed etant en ON CONFLICT DO NOTHING,
-- la valeur se corrige par UPDATE. Equivalent a la saisie dans l'ecran
-- Valeurs par defaut ; effet au prochain chargement ETL.

BEGIN;

UPDATE public.etl_default_values
SET valeur = 'TRIMET', is_active = TRUE, updated_at = CURRENT_TIMESTAMP, updated_by = 'migration_095'
WHERE table_cible = 'clean_data.jt_task' AND colonne = 'company' AND variante = 'STANDARD';

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : create_alimenter_jt_task.sql', 'migration_095')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

COMMIT;
