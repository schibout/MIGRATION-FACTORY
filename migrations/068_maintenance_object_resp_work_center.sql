-- ============================================================================
-- 068 : poste de travail RESPONSABLE sur clean_data.maintenance_object
--
-- Constat (IH02, 2026-09-15) : l'ecran affichait le meme code dans "Poste de
-- travail" et "Poste responsable" car une seule colonne (work_center) portait
-- les deux notions SAP :
--   * Poste de travail   = onglet Localisation, ILOA/IFLO-PPSID   (ex. 7.PSCT)
--   * Poste responsable  = onglet Organisation, ITOBATTR-GEWRK     (ex. 7.MSCT)
--     -> stocke dans IFLOT-LGWID (postes techniques) / EQUZ-GEWRK (equipements)
--
-- IFLOT-LGWID n'etait pas extrait (absent de la liste de champs de
-- l'extracteur pyrfc) : champ ajoute a la config le 2026-09-15 et IFLOT
-- re-extraite AVANT de rejouer les loaders.
--
-- Apres cette migration : recompiler proc_load_maintenance_object[_merge]
-- (cd sql/maintenance ; psql -f proc_load_maintenance_object.sql ;
--  psql -f proc_load_maintenance_object_merge.sql) puis rechargement SAP en
-- mode FUSION depuis l'ecran Maintenance.
-- ============================================================================

ALTER TABLE clean_data.maintenance_object
    ADD COLUMN IF NOT EXISTS resp_work_center     TEXT,
    ADD COLUMN IF NOT EXISTS resp_work_center_txt TEXT;

COMMENT ON COLUMN clean_data.maintenance_object.work_center IS
    'Poste de travail (onglet Localisation) : arbpl resolu depuis iflo.ppsid | iloa.ppsid -> crhd';
COMMENT ON COLUMN clean_data.maintenance_object.resp_work_center IS
    'Poste de travail responsable (onglet Organisation, ITOBATTR-GEWRK) : arbpl resolu depuis iflot.lgwid | equz.gewrk -> crhd';
COMMENT ON COLUMN clean_data.maintenance_object.resp_work_center_txt IS
    'Designation (crtx.ktext F) du poste responsable';
