-- =====================================================
-- 099 : valeurs par defaut de clean_data.part_catalog (ecran /configuration/valeurs-defaut)
-- 2026-10-07, demande explicite :
--   1. suppression des variantes COMPOSANT, COMPOSANT_CS, COMPOSANT_SJ et
--      ARTICLEPHL : depuis les migrations 071/072, les modules articlePhl et
--      articleComposant lisent la MATRICE Site x Famille (get_matrix_value),
--      ces lignes n'etaient plus lues par aucune procedure ;
--   2. toutes les lignes restantes de part_catalog passent dans le module
--      inventory (lues par alimenter_part_catalog() et
--      alimenter_part_catalog_sap(), variantes STANDARD / INVENTORY).
-- Idempotent.
-- =====================================================

BEGIN;

DELETE FROM public.etl_default_values
WHERE table_cible = 'clean_data.part_catalog'
  AND variante IN ('COMPOSANT', 'COMPOSANT_CS', 'COMPOSANT_SJ', 'ARTICLEPHL');

UPDATE public.etl_default_values
SET module = 'inventory',
    updated_at = CURRENT_TIMESTAMP
WHERE table_cible = 'clean_data.part_catalog'
  AND module IS DISTINCT FROM 'inventory';

COMMIT;

SELECT module, variante, count(*) AS lignes
FROM public.etl_default_values
WHERE table_cible = 'clean_data.part_catalog'
GROUP BY module, variante
ORDER BY module, variante;
