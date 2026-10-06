-- =====================================================
-- 100 : ecran /configuration/valeurs-defaut sans les modules articlePhl et
--       articleComposant (2026-10-07, demande explicite).
-- Depuis les migrations 071/072, ces deux modules lisent la MATRICE Site x
-- Famille (get_matrix_value) et plus jamais etl_default_values.
--
-- Piege : certaines lignes rangees sous articlePhl (variante STANDARD) sont
-- LUES par les procedures du module inventory (alimenter_inventory_part,
-- alimenter_purchase_part, alimenter_sales_part : 107 lignes au 2026-10-07).
-- Elles sont DEPLACEES dans inventory, pas supprimees. Detection par analyse
-- du code des fonctions en base (appels get_default_value[_ctx] litteraux,
-- variante STANDARD si absente) et non par une liste figee.
-- Toutes les autres lignes des deux modules sont supprimees.
-- Idempotent.
-- =====================================================

BEGIN;

CREATE TEMP TABLE tmp_appels ON COMMIT DROP AS
SELECT DISTINCT m[1] AS table_cible, m[2] AS colonne, COALESCE(m[3], 'STANDARD') AS variante
FROM pg_proc p,
     LATERAL regexp_matches(
         p.prosrc,
         $r$get_default_value(?:_ctx)?\(\s*'([^']+)'\s*,\s*'([^']+)'(?:\s*,\s*'([^']+)')?$r$,
         'g') m;

UPDATE public.etl_default_values d
SET module = 'inventory',
    updated_at = CURRENT_TIMESTAMP
FROM tmp_appels a
WHERE d.module IN ('articlePhl', 'articleComposant')
  AND a.table_cible = d.table_cible
  AND a.colonne = d.colonne
  AND a.variante = d.variante;

DELETE FROM public.etl_default_values
WHERE module IN ('articlePhl', 'articleComposant');

COMMIT;

SELECT module, count(*) AS lignes
FROM public.etl_default_values
GROUP BY module
ORDER BY module;
