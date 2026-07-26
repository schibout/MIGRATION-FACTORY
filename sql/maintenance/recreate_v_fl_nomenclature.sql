-- =====================================================================
-- clean_data.v_fl_nomenclature  (recree en VUE SIMPLE)
-- Compatibilite descendante : memes colonnes que l'ancienne vue
-- materialisee, mais lues depuis la table unique maintenance_object.
--
-- Avantages :
--   - plus de REFRESH MATERIALIZED VIEW apres chaque edition de BOM ;
--   - toujours a jour (vue simple).
--
-- Consommateurs a verifier :  grep -r v_fl_nomenclature backend/ sql/
--   - backend/api/ih02_hierarchy.py  (route /bom/<tplnr>, /bom-counts)
--   - sql/maintenance/proc_load_equipment_object_spare.sql
--   - sql/maintenance/proc_load_equipment_spare_structure.sql
--   - public.etl_export_queries (requetes d'export dynamiques)
-- =====================================================================

DROP MATERIALIZED VIEW IF EXISTS clean_data.v_fl_nomenclature CASCADE;
DROP VIEW IF EXISTS clean_data.v_fl_nomenclature CASCADE;

CREATE VIEW clean_data.v_fl_nomenclature AS
SELECT
    fl.sap_key                          AS tplnr,
    fl.code                             AS tplnr_display,
    fl.designation                      AS fl_designation,
    b.attributes->>'stlnr'              AS stlnr,
    b.attributes->>'stlal'              AS stlal,
    b.attributes->>'stlan'              AS stlan,
    b.attributes->>'base_quantity'      AS base_quantity,
    b.attributes->>'base_unit'          AS base_unit,
    b.attributes->>'posnr'              AS posnr,
    a.sap_key                           AS idnrk,
    a.code                              AS matnr_short,
    b.category                          AS item_category,
    b.quantity::text                    AS quantity,
    b.unit                              AS unit,
    a.type_code                         AS material_type,
    a.designation                       AS designation,
    b.sort_order                        AS sort_order
FROM clean_data.maintenance_object b
JOIN clean_data.maintenance_object fl
    ON fl.id = b.parent_id AND fl.object_type = 'FUNC_LOC'
JOIN clean_data.maintenance_object a
    ON a.id = b.ref_object_id AND a.object_type = 'ARTICLE'
WHERE b.object_type = 'BOM_ITEM'
  AND b.attributes->>'stlty' = 'T'
  AND b.is_active;

COMMENT ON VIEW clean_data.v_fl_nomenclature IS
'BOM des postes techniques (compat) : vue simple sur maintenance_object
 (BOM_ITEM stlty=T). Memes colonnes que l''ancienne vue materialisee.
 Plus de REFRESH necessaire.';

-- Verifications :
--   SELECT COUNT(*) FROM clean_data.v_fl_nomenclature;
--   SELECT * FROM clean_data.v_fl_nomenclature WHERE tplnr_display = 'T340-E100-1005';
