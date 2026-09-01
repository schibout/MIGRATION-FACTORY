-- =====================================================
-- 040 - Desactiver toutes les valeurs par defaut "NULL explicite"
--
-- Decoche (is_active = false) les 308 lignes public.etl_default_values dont
-- type_valeur = 'NULL'. Elles restent VISIBLES dans l'ecran
-- /configuration/valeurs-defaut, simplement inactives.
--
-- NEUTRE POUR L'ETL : public.get_default_value renvoie le repli code en dur
-- (p_fallback) des qu'aucune ligne ACTIVE ne correspond, et le repli de ces
-- appels est lui-meme NULL (verifie : sql/config/verifier_valeurs_defaut.py
-- ne signale aucune divergence repli/seed). Le chargement produit donc
-- exactement les memes donnees qu'avant.
--
-- Idempotent : ne touche que les lignes encore actives.
-- Rollback en bas de fichier.
-- =====================================================

BEGIN;

UPDATE public.etl_default_values
SET is_active  = false,
    updated_at = CURRENT_TIMESTAMP,
    updated_by = 'migration_040'
WHERE type_valeur = 'NULL'
  AND is_active IS DISTINCT FROM false;

-- Controle : doit afficher 0 ligne NULL active
SELECT type_valeur,
       is_active,
       count(*) AS lignes
FROM public.etl_default_values
GROUP BY type_valeur, is_active
ORDER BY type_valeur, is_active;

COMMIT;

-- =====================================================
-- ROLLBACK (a jouer manuellement si besoin) :
--
-- BEGIN;
-- UPDATE public.etl_default_values
-- SET is_active  = true,
--     updated_at = CURRENT_TIMESTAMP,
--     updated_by = 'rollback_040'
-- WHERE type_valeur = 'NULL'
--   AND updated_by = 'migration_040';
-- COMMIT;
-- =====================================================
