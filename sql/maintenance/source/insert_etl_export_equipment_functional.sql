INSERT INTO public.etl_export_queries (
    table_name,
    table_schema,
    display_name,
    column_list,
    description,
    category,
    is_active,
    created_at,
    created_by
)
VALUES (
    'equipment_functional',
    'clean_data',
    'Objets fonctionnels (équipements)',
    'EQUIPMENT_OBJECT_SEQ,	CONTRACT,	MCH_CODE,	MCH_NAME,	MCH_LOC,	MCH_POS,	EQUIPMENT_MAIN_POSITION,	EQUIPMENT_MAIN_POSITION_DB,	GROUP_ID,	MCH_TYPE,	COST_CENTER,	OBJECT_NO,	CATEGORY_ID,	MANUFACTURER_NO,	SERIAL_NO,	TYPE,	PART_NO,	IS_CATEGORY_OBJECT,	IS_GEOGRAPHIC_OBJECT,	CRITICALITY,	ITEM_CLASS_ID,	CLUSTER_ID,	LOCATION_ID,	APPLIED_PM_PROGRAM_ID,	APPLIED_PM_PROGRAM_REV,	APPLIED_DATE,	PM_PROG_APPLICATION_STATUS,	NOT_APPLICABLE_REASON,	NOT_APPLICABLE_SET_USER,	NOT_APPLICABLE_SET_DATE,	SAFE_ACCESS_CODE,	SAFE_ACCESS_CODE_DB,	PROCESS_CLASS_ID,	FUNCTIONAL_OBJECT_SEQ,	LOCATION_OBJECT_SEQ,	FROM_OBJECT_SEQ,	TO_OBJECT_SEQ,	PROCESS_OBJECT_SEQ,	PIPE_OBJECT_SEQ,	CIRCUIT_OBJECT_SEQ,	MODEL_ID,	SAFETY_CRITICAL_ELEMENT,	SAFETY_CRITICAL_ELEMENT_DB,	AREA_ID,	DECK_ID,	MAINTENANCE_STRATEGY_ID,	OBJ_LEVEL,	MCH_DOC,	PURCH_PRICE,	PURCH_DATE,	WARR_EXP,	NOTE,	INFO,	DATA,	PRODUCTION_DATE,	TECHNICAL_LIFETIME,	VENDOR_NO,	PLANT_DESIGN_ID,	OPERATIONAL_STATUS,	OPERATIONAL_STATUS_DB,	PLANT_DESIGN_PROJPHASE,	PLANT_DESIGN_COTPROJ_PROJID,	MANUFACTURED_DATE,	SUP_CONTRACT,	SUP_MCH_CODE',
    'Table des objets fonctionnels IFS (postes techniques + équipements). Source: iflot/iflotx/iflos/iloa + itob',
    'Structure Maintenance',
    true,
    NOW(),
    'system'
)
ON CONFLICT (table_name, category) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    column_list = EXCLUDED.column_list,
    description = EXCLUDED.description,
    category = EXCLUDED.category,
    is_active = EXCLUDED.is_active,
    updated_at = NOW(),
    updated_by = 'system';


-- =====================================================================
-- EQUIPMENT_SPARE_STRUCTURE : structure kit -> composants (nomenclature matière)
-- Source : clean_data.load_equipment_spare_structure
-- =====================================================================

-- Supprime l'ancienne entrée doublon (catégorie 'maintenance',
-- cf. add_equipment_spare_structure_export.sql) pour éviter un double export.
DELETE FROM public.etl_export_queries
WHERE table_name = 'equipment_spare_structure' AND category = 'maintenance';

INSERT INTO public.etl_export_queries (
    table_name,
    table_schema,
    display_name,
    column_list,
    description,
    category,
    is_active,
    created_at,
    created_by
)
VALUES (
    'equipment_spare_structure',
    'clean_data',
    'Structure des pièces de rechange (kit → composants)',
    'SPARE_SEQ,	SPARE_CONTRACT,	SPARE_ID,	COMPONENT_SPARE_ID,	COMPONENT_SPARE_CONTRACT,	QTY,	PART_OWNERSHIP_DB',
    'Structure hiérarchique des pièces de rechange (kit → composants, explosion récursive) depuis la nomenclature matière SAP (MAST/STKO/STPO stlty=M). Source: load_equipment_spare_structure',
    'Structure Maintenance',
    true,
    NOW(),
    'system'
)
ON CONFLICT (table_name, category) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    column_list = EXCLUDED.column_list,
    description = EXCLUDED.description,
    category = EXCLUDED.category,
    is_active = EXCLUDED.is_active,
    updated_at = NOW(),
    updated_by = 'system';
