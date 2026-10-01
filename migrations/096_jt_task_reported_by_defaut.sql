-- Migration 096 : valeur par defaut de clean_data.jt_task.reported_by
--
-- Repli quand public.get_username ne resout ni le createur de l'ordre (AUFK.ERNAM)
-- ni l'auteur de la confirmation (AFRU.ERNAM) : 'LOIC.DECHALOU' (personne IFS),
-- au lieu de l'ancien litteral 'KAPEIFS'. Modifiable dans l'ecran Valeurs par
-- defaut. A jouer AVANT sql/operation/compile.sh, sinon reported_by sort NULL.

BEGIN;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task', 'reported_by', 'STANDARD', 'CONSTANTE', 'LOIC.DECHALOU', 'Source : create_alimenter_jt_task.sql (repli de get_username)', 'migration_096')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

COMMIT;
