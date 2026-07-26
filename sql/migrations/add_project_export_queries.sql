-- Migration: Ajout des requêtes d'export pour les tables projet
-- Date: 2024-12-11
-- Description: Ajouter les tables PROJECT_BASE, PROJECT_SITE_EXT et PROJECT_MARGIN_MATRIX pour l'export

-- Supprimer les anciennes entrées si elles existent
DELETE FROM etl_export_queries WHERE table_schema = 'clean_data' AND category = 'project';

-- PROJECT_BASE
INSERT INTO etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by) 
VALUES (
    'project_base',
    'clean_data',
    'Projets - Informations de Base',
    'project_id, name, manager, company, calendar_id, access_on_off, baseline_revision_number, earned_value_method, material_allocation, multi_currency_budgeting, project_misc_comp_method, work_day_to_hours_conv, description, plan_start, plan_finish, actual_start, actual_finish, frozen_date, close_date, cancel_date, approved_date, customer_id, customer_responsible, customer_project_id, program_id, category1_id, category2_id, planned_revenue, planned_cost, currency_type, probability_to_win, default_char_temp, date_created, created_by, date_modified, modified_by, earned_value_method_db, material_allocation_db, financially_responsible, budget_control_on, budget_control_on_db, control_as_budgeted, control_as_budgeted_db, control_on_total_budget, control_on_total_budget_db, copied_project, proj_unique_purchase, proj_unique_purchase_db, proj_unique_sale, proj_unique_sale_db, multi_currency_budgeting_db, cost_structure_id, project_currency_type, budget_currency_type, project_currency_code, project_misc_comp_method_db, plan_project_transaction_db, cl_investment_code, created_at, updated_at',
    'Table de base des projets IFS Cloud - Données nettoyées et transformées depuis ASAP',
    'project',
    true,
    'admin',
    'admin'
);

-- PROJECT_SITE_EXT
INSERT INTO etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by) 
VALUES (
    'project_site_ext',
    'clean_data',
    'Projets - Association Sites',
    'company, project_id, site, project_site_type, project_site_type_db, use_std_inv_in_pmrp_db, auto_trans_from_std_inv_db',
    'Table d''association entre projets et sites IFS',
    'project',
    true,
    'admin',
    'admin'
);

-- PROJECT_ROLE
INSERT INTO etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by) 
VALUES (
    'project_role',
    'clean_data',
    'Projets - Rôles',
    'project_id, company, role_id',
    'Table des rôles affectés aux projets',
    'project',
    true,
    'admin',
    'admin'
);

-- PROJECT_ROLE_ASSIGNMENT
INSERT INTO etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by) 
VALUES (
    'project_role_assignment',
    'clean_data',
    'Projets - Affectation des Rôles',
    'assign_seq_no, project_id, company, role_id, sub_project_id, activity_seq, person_id, system_generated',
    'Affectation des rôles aux personnes dans les projets',
    'project',
    true,
    'admin',
    'admin'
);

-- SUB_PROJECT
INSERT INTO etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by) 
VALUES (
    'sub_project',
    'clean_data',
    'Projets - Sous-Projets',
    'project_id, sub_project_id, parent_sub_project_id, description, manager, department, date_created, created_by, date_modified, modified_by, financially_responsible, exclude_from_wad, exclude_from_wad_db, address_id, financially_completed, financially_completed_db, exclude_from_integrations, exclude_from_integrations_db',
    'Table des sous-projets (10=Suivi des portes, 20=Suivi des coûts CAPEX, 30=Suivi des coûts OPEX)',
    'project',
    true,
    'admin',
    'admin'
);

-- Vérification
SELECT id, table_name, display_name, category, is_active 
FROM etl_export_queries 
WHERE category = 'project' 
ORDER BY table_name;
