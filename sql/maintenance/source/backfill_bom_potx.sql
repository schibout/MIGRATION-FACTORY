-- =====================================================================
-- Backfill : ajoute les textes composant (potx1 / potx2) aux lignes
-- BOM_ITEM DEJA chargees dans clean_data.maintenance_object.
--
-- A executer UNE FOIS, apres avoir ajoute potx1/potx2 dans la procedure
-- load_maintenance_object (pour les futurs chargements). Ici on met a jour
-- l'existant SANS relancer le CALL -> aucune modif manuelle n'est ecrasee.
--
-- Appariement stable par (stlty, stlnr, stlkn, mandt) — stlkn est
-- l'identifiant de position stable dans STPO.
-- =====================================================================

UPDATE clean_data.maintenance_object b
SET attributes = b.attributes || jsonb_strip_nulls(jsonb_build_object(
        'potx1', NULLIF(TRIM(p.potx1), ''),
        'potx2', NULLIF(TRIM(p.potx2), '')
    ))
FROM raw_data.stpo p
WHERE b.object_type = 'BOM_ITEM'
  AND b.attributes->>'stlty' = p.stlty
  AND b.attributes->>'stlnr' = p.stlnr
  AND b.attributes->>'stlkn' = p.stlkn
  AND b.attributes->>'mandt' = p.mandt
  AND (NULLIF(TRIM(p.potx1), '') IS NOT NULL OR NULLIF(TRIM(p.potx2), '') IS NOT NULL);

-- Verification :
--   SELECT sap_key, attributes->>'potx1' AS potx1, attributes->>'potx2' AS potx2
--   FROM clean_data.maintenance_object
--   WHERE object_type='BOM_ITEM' AND attributes ? 'potx1' LIMIT 20;
