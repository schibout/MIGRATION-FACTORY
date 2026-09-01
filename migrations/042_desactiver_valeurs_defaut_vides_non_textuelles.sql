-- =====================================================
-- 042 - Desactiver les valeurs par defaut CONSTANTE vides ('')
--       ciblant une colonne NON textuelle
--
-- public.get_default_value renvoie du TEXT et PostgreSQL n'a aucun cast
-- implicite ''->numeric/date/timestamp : une ligne CONSTANTE de valeur ''
-- sur une colonne numerique fait echouer le chargement avec
--   invalid input syntax for type numeric: ""
-- (constate le 2026-09-01 sur clean_data.sp_insert_customer_info_from_file_customer,
--  colonne clean_data.customer_info.picture_id).
--
-- On desactive ces lignes : get_default_value retombe alors sur le repli code
-- en dur de l'appel (NULL pour picture_id), qui est le comportement attendu.
-- Les lignes restent VISIBLES dans /configuration/valeurs-defaut.
--
-- Perimetre mesure sur la base le 2026-09-01 : 1 seule ligne
-- (clean_data.customer_info / picture_id / STANDARD, type numeric).
-- La requete reste generique pour rester valable si d'autres apparaissent.
--
-- Idempotent : ne touche que les lignes encore actives.
-- Rollback en bas de fichier.
-- =====================================================

BEGIN;

UPDATE public.etl_default_values v
SET is_active  = false,
    updated_at = CURRENT_TIMESTAMP,
    updated_by = 'migration_042'
FROM information_schema.columns c
WHERE c.table_schema = split_part(v.table_cible, '.', 1)
  AND c.table_name   = split_part(v.table_cible, '.', 2)
  AND c.column_name  = v.colonne
  AND c.data_type NOT IN ('character varying', 'text', 'character')
  AND v.valeur = ''
  AND v.is_active IS DISTINCT FROM false;

-- Controle : doit afficher 0 ligne
SELECT v.table_cible, v.colonne, v.variante, c.data_type
FROM public.etl_default_values v
JOIN information_schema.columns c
  ON  c.table_schema = split_part(v.table_cible, '.', 1)
  AND c.table_name   = split_part(v.table_cible, '.', 2)
  AND c.column_name  = v.colonne
WHERE v.is_active
  AND v.valeur = ''
  AND c.data_type NOT IN ('character varying', 'text', 'character');

COMMIT;

-- =====================================================
-- ROLLBACK (a jouer manuellement si besoin) :
--
-- BEGIN;
-- UPDATE public.etl_default_values
-- SET is_active  = true,
--     updated_at = CURRENT_TIMESTAMP,
--     updated_by = 'rollback_042'
-- WHERE updated_by = 'migration_042';
-- COMMIT;
-- =====================================================
