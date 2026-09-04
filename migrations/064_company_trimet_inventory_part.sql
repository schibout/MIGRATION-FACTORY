-- =====================================================================
-- COMPANY = TRIMET pour inventory_part
--
-- Regle metier (2026-09-04) : la societe est TOUJOURS TRIMET. Le site, lui,
-- est porte par la colonne CONTRACT (CS = Castel, SJ = Saint-Jean) et par
-- elle seule.
--
-- La variante STANDARD de clean_data.inventory_part.company valait SJM, valeur
-- heritee du module articlePhl (seul appelant de cette cle pour inventory_part
-- ; les composants passent deja par la variante COMPOSANT, qui vaut TRIMET).
--
-- UPDATE cible et rejouable : ne touche que la ligne restee a SJM.
-- =====================================================================

BEGIN;

UPDATE public.etl_default_values
SET valeur = 'TRIMET',
    description = 'Societe TRIMET (le site est porte par CONTRACT) - regle metier 2026-09-04',
    updated_by = 'migration_064',
    updated_at = CURRENT_TIMESTAMP
WHERE table_cible = 'clean_data.inventory_part'
  AND colonne = 'company'
  AND variante = 'STANDARD'
  AND valeur IS DISTINCT FROM 'TRIMET';

COMMIT;
