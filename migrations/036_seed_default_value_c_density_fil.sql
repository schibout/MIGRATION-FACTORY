-- ============================================================================
-- Migration 036 : valeur par defaut ETL de la densite des articles PHL de type FIL
--
-- 2026-08-27 : la densite n'est requise que pour les plaques / tes / lingots
-- (familles 20, 24, 19 -> variante STANDARD, valeur theorique 2.7). Les fils
-- (familles 21, 22, 23, RF) n'ont pas de densite : alimenter_inventory_part_phl
-- lit la variante 'FIL' de clean_data.inventory_part.c_density.
--
-- Cette ligne n'est pas obligatoire (sans elle, le fallback NULL code dans la
-- procedure donne deja le comportement attendu) : elle sert a rendre la valeur
-- visible et modifiable depuis l'ecran /configuration/valeurs-defaut.
-- ============================================================================

INSERT INTO public.etl_default_values
    (module, table_cible, colonne, variante, type_valeur, valeur, description, is_active, created_by)
VALUES
    ('articlePhl', 'clean_data.inventory_part', 'c_density', 'FIL', 'NULL', NULL,
     'Densite non requise pour les articles FIL (familles 21, 22, 23, RF) - source : alimenter_inventory_part_phl.sql',
     TRUE, 'migration_036')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
