-- Script: Ajout de la table ACTIVITY pour l'export
-- Date: 2025-01-06
-- Description: Ajouter la table ACTIVITY dans etl_export_queries

-- ACTIVITY
INSERT INTO etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by) 
VALUES (
    'activity',
    'clean_data',
    'Projets - Activités',
    'activity_seq, project_id, activity_no, description, progress_method, planned_cost_driver, exclude_periodical_cap, exclude_resource_progress, exclude_from_integrations, node_type, mandatory_invoice_comment, sub_project_id, total_key_path, activity_responsible, manual_progress_level, manual_progress_level_db, estimated_progress, manual_progress_cost, manual_progress_hours, total_duration_days, total_work_days, note, early_start, early_finish, late_start, late_finish, actual_start, actual_finish, cancel_date, short_name, released_date, completed_date, closed_date, progress_method_db, planned_cost_driver_db, progress_template, progress_template_step, date_created, created_by, date_modified, modified_by, set_in_baseline, set_activity_changed, set_activity_changed_db, case_id, task_id, baseline_pcd, baseline_pcd_db, financially_responsible, amount_planned, amount_used, exclude_from_wad, exclude_from_wad_db, generate_safety_stock, hours_planned, address_id, exclude_periodical_cap_db, financially_completed, financially_completed_db, exclude_resource_progress_db, free_float, total_float, constraint_type, constraint_type_db, constraint_date, exclude_from_integrations_db, node_type_db, mandatory_invoice_comment_db',
    'Table des activités projet IFS Cloud',
    'project',
    true,
    'admin',
    'admin'
)
ON CONFLICT (table_name, table_schema) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    column_list = EXCLUDED.column_list,
    description = EXCLUDED.description,
    category = EXCLUDED.category,
    is_active = EXCLUDED.is_active,
    updated_by = EXCLUDED.updated_by,
    updated_at = CURRENT_TIMESTAMP;

-- Vérification
SELECT id, table_name, display_name, category, is_active 
FROM etl_export_queries 
WHERE table_name = 'activity' AND table_schema = 'clean_data';

