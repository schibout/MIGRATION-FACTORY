-- ============================================================================
-- 078 : Centre de couts des postes techniques (FUNC_LOC) -- rattrapage
--
-- Constat du 2026-09-17 : aucun des 11 080 postes techniques actifs de
-- clean_data.maintenance_object ne porte de centre de couts, alors que 10 967
-- en ont un dans SAP (iflot.iloan -> iloa.kostl, onglet Localisation).
-- Les passes FUNC_LOC de load_maintenance_object et _merge joignaient deja
-- raw_data.iloa mais n'en lisaient que ppsid (poste de charge) ; kostl n'etait
-- ecrit que pour les EQUIPMENT. Les deux procedures sont corrigees dans
-- sql/maintenance/ (a recompiler) : cette migration ne fait que remplir les
-- lignes deja chargees.
--
-- Perimetre : tout FUNC_LOC actif dont cost_center est NULL ou vide, y
-- compris les postes modifies a la main (updated_by IS NOT NULL) que la
-- fusion ne toucherait pas : la valeur n'ayant jamais ete chargee, un
-- cost_center vide ne peut pas etre une saisie utilisateur. Un centre de
-- couts saisi a l'ecran (non vide) n'est jamais ecrase.
--
-- Idempotente : rejouable sans effet une fois les lignes remplies.
-- Verification : SELECT count(*) FILTER (WHERE cost_center IS NOT NULL), count(*)
--                FROM clean_data.maintenance_object
--                WHERE object_type = 'FUNC_LOC' AND is_active;   -- ~10 917 / 11 080
-- ============================================================================
BEGIN;

UPDATE clean_data.maintenance_object mo
SET cost_center = src.kostl
FROM (
    -- iflot porte une ligne par (tplnr, mandt) ; on prend la premiere iloa.
    SELECT DISTINCT ON (i.tplnr)
           i.tplnr, NULLIF(TRIM(l.kostl), '') AS kostl
    FROM raw_data.iflot i
    JOIN raw_data.iloa l ON l.iloan = i.iloan AND l.mandt = i.mandt
    WHERE NULLIF(TRIM(l.kostl), '') IS NOT NULL
    ORDER BY i.tplnr, i.mandt
) src
WHERE mo.object_type = 'FUNC_LOC'
  AND mo.is_active
  AND mo.sap_key = src.tplnr
  AND NULLIF(TRIM(mo.cost_center), '') IS NULL;

COMMIT;
