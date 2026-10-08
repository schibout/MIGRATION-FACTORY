-- Migration 104 : sap_key des lignes de nomenclature de poste technique ('T:')
--
-- La cle etait 'T:' || stlnr || ':' || stlal || ':' || posnr. Or SAP met souvent
-- plusieurs articles sous le meme numero de poste (T110-K041-4005 : 3 articles en
-- 0110, 4 en 0310...) : le ON CONFLICT DO NOTHING n'en gardait qu'un (51 lignes
-- perdues sur la base). Les passes 'M:' / 'S:' portaient deja le noeud stlkn.
--
-- Nouvelle cle = ancienne || ':' || stlkn. Les lignes deja chargees sont renommees
-- ici (stlkn est dans attributes pour 100 % d'entre elles) pour que le rechargement
-- en mode fusion les reconnaisse et conserve le travail utilisateur ; il ajoute
-- ensuite les articles manquants.
--
-- Ordre : cette migration, puis sql/maintenance/compile.sh, puis rechargement
-- maintenance en mode fusion.

BEGIN;

UPDATE clean_data.maintenance_object
SET sap_key = sap_key || ':' || (attributes->>'stlkn')
WHERE object_type = 'BOM_ITEM'
  AND sap_key ~ '^T:[^:]+:[^:]+:[^:]+$'
  AND attributes->>'stlkn' IS NOT NULL;

COMMIT;
