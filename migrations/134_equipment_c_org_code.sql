-- 134 : organisation de maintenance (C_ORG_CODE) sur les exports IFS
-- equipment_functional et equipment_serial, demande du 2026-11-15.
-- Alimentee par alimenter_equipment_functional / alimenter_equipment_serial :
-- poste responsable (maintenance_object.resp_work_center, 7.MATC) transcode
-- via la categorie 'Organization' (SJ-MATC). Les memes loaders alimentent aussi
-- criticality (facteur de risque), area_id (zone) et mch_loc (salle ILOA-MSGRP),
-- colonnes deja presentes dans les tables et les exports.
-- Rejouable.

BEGIN;

ALTER TABLE clean_data.equipment_functional ADD COLUMN IF NOT EXISTS c_org_code varchar(8);
ALTER TABLE clean_data.equipment_serial     ADD COLUMN IF NOT EXISTS c_org_code varchar(8);

UPDATE public.etl_export_queries
SET column_list = column_list || ',C_ORG_CODE',
    updated_at  = now(),
    updated_by  = 'migration_134'
WHERE table_schema = 'clean_data'
  AND table_name IN ('equipment_functional', 'equipment_serial')
  AND column_list NOT ILIKE '%C_ORG_CODE%';

COMMIT;

-- ROLLBACK
-- BEGIN;
-- UPDATE public.etl_export_queries SET column_list = replace(column_list, ',C_ORG_CODE', '')
--  WHERE table_schema = 'clean_data' AND table_name IN ('equipment_functional', 'equipment_serial');
-- ALTER TABLE clean_data.equipment_functional DROP COLUMN IF EXISTS c_org_code;
-- ALTER TABLE clean_data.equipment_serial     DROP COLUMN IF EXISTS c_org_code;
-- COMMIT;
