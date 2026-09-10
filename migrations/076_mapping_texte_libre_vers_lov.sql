-- ============================================================================
-- 076 : bascule des saisies en texte libre vers les codes LOV (ecran IH02)
--
-- Les colonnes risk_factor / zone (migration 074) ont ete ouvertes en saisie
-- LIBRE avant que les listes de valeurs n'existent. Depuis que la fiche du
-- poste technique utilise des combobox, la valeur stockee doit etre le CODE
-- LOV, pas le libelle : sinon l'ecran affiche la valeur en « (hors liste) ».
--
-- Une seule ligne est concernee a ce jour (T060-J) :
--     zone        = 'Maintenance ELY'  -> 'Z-17' (libelle identique)
--     risk_factor = '1'                -> 'CR1'  (Criticite Niveau 1)
--
-- Les deux UPDATE sont ecrits en JOINTURE sur les libelles / codes LOV, pas
-- avec les valeurs en dur : ils restent justes si d'autres postes ont ete
-- saisis en texte libre entre-temps, et ne font rien si tout est deja propre.
-- Rejouable. Rollback en bas de fichier.
-- ============================================================================
BEGIN;

-- Zone : le texte libre a ete saisi en recopiant le LIBELLE de la zone.
UPDATE clean_data.maintenance_object m
SET zone = v.code
FROM public.maintenance_lov_value v
JOIN public.maintenance_lov_type t ON t.id = v.lov_type_id AND t.code = 'ZONE'
WHERE m.object_type = 'FUNC_LOC'
  AND m.zone IS NOT NULL
  AND TRIM(m.zone) <> ''
  -- deja un code LOV : ne pas y toucher
  AND NOT EXISTS (
      SELECT 1 FROM public.maintenance_lov_value v2
      JOIN public.maintenance_lov_type t2 ON t2.id = v2.lov_type_id AND t2.code = 'ZONE'
      WHERE v2.code = m.zone)
  AND LOWER(TRIM(m.zone)) = LOWER(TRIM(v.libelle));

-- Facteur de risque : le texte libre est le NIVEAU de criticite ('1' -> 'CR1').
UPDATE clean_data.maintenance_object m
SET risk_factor = 'CR' || TRIM(m.risk_factor)
WHERE m.object_type = 'FUNC_LOC'
  AND TRIM(COALESCE(m.risk_factor, '')) IN ('1', '2', '3', '4')
  AND EXISTS (
      SELECT 1 FROM public.maintenance_lov_value v
      JOIN public.maintenance_lov_type t ON t.id = v.lov_type_id AND t.code = 'FACTEUR_RISQUE'
      WHERE v.code = 'CR' || TRIM(m.risk_factor));

-- Ce qui n'a pas pu etre mappe reste tel quel et s'affiche « (hors liste) »
-- dans la combobox : visible, modifiable, jamais efface en silence.
COMMIT;

-- ============================================================================
-- ROLLBACK (valeurs d'origine de la seule ligne concernee au 2026-09-10)
-- ============================================================================
-- BEGIN;
-- UPDATE clean_data.maintenance_object
--    SET zone = 'Maintenance ELY', risk_factor = '1'
--  WHERE object_type = 'FUNC_LOC' AND sap_key = 'T060-J';
-- COMMIT;
