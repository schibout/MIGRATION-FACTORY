-- =====================================================
-- Aligne clean_data.equipment_functional et l'export
-- sur les 65 colonnes cibles IFS.
--   1) Ajoute les colonnes manquantes (toutes en TEXT, NULL autorise)
--   2) Met a jour column_list dans etl_export_queries
-- Idempotent (ADD COLUMN IF NOT EXISTS).
-- =====================================================

-- ----------------------------------------------------
-- 1. Schema : ajouter chaque colonne IFS si absente
-- ----------------------------------------------------
DO $$
DECLARE
    cols TEXT[] := ARRAY[
        'equipment_object_seq','contract','mch_code','mch_name','mch_loc','mch_pos',
        'equipment_main_position','equipment_main_position_db','group_id','mch_type',
        'cost_center','object_no','category_id','manufacturer_no','serial_no','type',
        'part_no','is_category_object','is_geographic_object','criticality',
        'item_class_id','cluster_id','location_id','applied_pm_program_id',
        'applied_pm_program_rev','applied_date','pm_prog_application_status',
        'not_applicable_reason','not_applicable_set_user','not_applicable_set_date',
        'safe_access_code','safe_access_code_db','process_class_id',
        'functional_object_seq','location_object_seq','from_object_seq','to_object_seq',
        'process_object_seq','pipe_object_seq','circuit_object_seq','model_id',
        'safety_critical_element','safety_critical_element_db','area_id','deck_id',
        'maintenance_strategy_id','obj_level','mch_doc','purch_price','purch_date',
        'warr_exp','note','info','data','production_date','technical_lifetime',
        'vendor_no','plant_design_id','operational_status','operational_status_db',
        'plant_design_projphase','plant_design_cotproj_projid','manufactured_date',
        'sup_contract','sup_mch_code'
    ];
    c TEXT;
BEGIN
    FOREACH c IN ARRAY cols LOOP
        EXECUTE format(
            'ALTER TABLE clean_data.equipment_functional ADD COLUMN IF NOT EXISTS %I TEXT',
            c
        );
    END LOOP;
END $$;

-- ----------------------------------------------------
-- 2. Mise a jour de column_list pour l'export
--    Categorie 'Structure Maintenance' (cf. import dans etl_export_queries).
--    Si la ligne actuelle est en categorie 'maintenance' (cf. screenshot),
--    on couvre les 2 cas via WHERE.
-- ----------------------------------------------------
UPDATE public.etl_export_queries
SET column_list = 'equipment_object_seq,contract,mch_code,mch_name,mch_loc,mch_pos,equipment_main_position,equipment_main_position_db,group_id,mch_type,cost_center,object_no,category_id,manufacturer_no,serial_no,type,part_no,is_category_object,is_geographic_object,criticality,item_class_id,cluster_id,location_id,applied_pm_program_id,applied_pm_program_rev,applied_date,pm_prog_application_status,not_applicable_reason,not_applicable_set_user,not_applicable_set_date,safe_access_code,safe_access_code_db,process_class_id,functional_object_seq,location_object_seq,from_object_seq,to_object_seq,process_object_seq,pipe_object_seq,circuit_object_seq,model_id,safety_critical_element,safety_critical_element_db,area_id,deck_id,maintenance_strategy_id,obj_level,mch_doc,purch_price,purch_date,warr_exp,note,info,data,production_date,technical_lifetime,vendor_no,plant_design_id,operational_status,operational_status_db,plant_design_projphase,plant_design_cotproj_projid,manufactured_date,sup_contract,sup_mch_code',
    updated_at = NOW(),
    updated_by = 'system'
WHERE table_name   = 'equipment_functional'
  AND table_schema = 'clean_data';

-- ----------------------------------------------------
-- 3. Verifications
-- ----------------------------------------------------
SELECT 'colonnes table' AS info, COUNT(*) AS total
FROM information_schema.columns
WHERE table_schema = 'clean_data' AND table_name = 'equipment_functional';

SELECT table_name, category, length(column_list) - length(replace(column_list, ',', '')) + 1 AS nb_cols
FROM public.etl_export_queries
WHERE table_name = 'equipment_functional'
  AND table_schema = 'clean_data';
