-- 119 : export IFS EQUIPMENT_SERIAL (equipements), categorie « Structure Maintenance »
-- a cote de equipment_functional. Table alimentee par clean_data.alimenter_equipment_serial()
-- (module ETL Structures de maintenance). column_list = les 83 colonnes de la table, dans l'ordre.

INSERT INTO public.etl_export_queries
    (table_name, table_schema, display_name, column_list, description, category, is_active, created_at, created_by)
VALUES
    ('equipment_serial', 'clean_data', 'Objets série (équipements)',
     'EQUIPMENT_OBJECT_SEQ,CONTRACT,MCH_CODE,MCH_NAME,PART_NO,MCH_LOC,AREA_ID,DECK_ID,MCH_POS,MCH_DOC,MAINTENANCE_STRATEGY_ID,TECHNICAL_LIFETIME,MODEL_ID,MODEL_VER,SAFETY_CRITICAL_ELEMENT_DB,FUNCTIONAL_OBJECT_SEQ,PURCH_PRICE,PURCH_DATE,WARR_EXP,NOTE,INFO,DATA,PRODUCTION_DATE,COMPANY,HAS_STRUCTURE,HAS_CONNECTION,MCH_CODE_KEY_VALUE,TYPE_KEY_VALUE,SERIAL_NO,MANUFACTURER_NO,VENDOR_NO,PART_REV,EQUIPMENT_MAIN_POSITION,EQUIPMENT_MAIN_POSITION_DB,TYPE,MCH_TYPE,OBJ_LEVEL,GROUP_ID,COST_CENTER,OBJECT_NO,CATEGORY_ID,SUP_MCH_CODE,SUP_CONTRACT,LU_NAME,KEY_REF,CRITICALITY,LATEST_TRANSACTION,SERIAL_STATE,OPERATIONAL_CONDITION,OPERATIONAL_STATUS,OPERATIONAL_STATUS_DB,MANUFACTURED_DATE,OWNER,OWNERSHIP_DB,OWNERSHIP,LOCATION_MCH_CODE,LOCATION_CONTRACT,FROM_MCH_CODE,FROM_CONTRACT,TO_MCH_CODE,TO_CONTRACT,PROCESS_MCH_CODE,PROCESS_CONTRACT,PIPE_MCH_CODE,PIPE_CONTRACT,CIRCUIT_MCH_CODE,CIRCUIT_CONTRACT,LOCATION_ID,ITEM_CLASS_ID,SAFE_ACCESS_CODE,SAFE_ACCESS_CODE_DB,PROCESS_CLASS_ID,NOT_APPLICABLE_SET_DATE,NOT_APPLICABLE_SET_USER,NOT_APPLICABLE_REASON,PM_PROG_APPLICATION_STATUS,APPLIED_DATE,APPLIED_PM_PROGRAM_REV,APPLIED_PM_PROGRAM_ID,IS_GEOGRAPHIC_OBJECT,IS_CATEGORY_OBJECT,CLUSTER_ID,PROXY_OBJECT_SEQ',
     'Équipements IFS (EQUIPMENT_SERIAL) : équipements sous un poste technique ou portant un code article, puis leurs équipements enfants ; ni postes techniques ni articles. Source : alimenter_equipment_serial',
     'Structure Maintenance', TRUE, now(), 'migration_119')
ON CONFLICT (table_name, category) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    column_list  = EXCLUDED.column_list,
    description  = EXCLUDED.description,
    is_active    = EXCLUDED.is_active,
    updated_at   = now(),
    updated_by   = 'migration_119';
