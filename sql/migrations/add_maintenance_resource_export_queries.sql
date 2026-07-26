-- Migration: Ajout des requêtes d'export pour les tables de ressources (maintenance)
-- Date: 2024-12-10
-- Description: Ajouter les tables resource_* et maint_person_resource pour l'export

-- Supprimer les anciennes entrées si elles existent
DELETE FROM etl_export_queries WHERE table_schema = 'clean_data' AND category = 'maintenance';

-- resource_detail_file
INSERT INTO etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by) 
VALUES (
    'resource_detail_file',
    'clean_data',
    'Détails des ressources',
    'resource_seq, resource_id, description, resource_type, resource_type_db, used_in_maintenance, used_in_manufacturing, used_in_projects, used_in_service, use_shift_pattern, resource_origin, calendar_id, resource_category, note, sched_capacity, capacity_calc_base, utilization, service_organization_id, service_delivery_unit, companies, sites, loaded_at, source_file',
    'Table des détails des fichiers de ressources IFS',
    'maintenance',
    true,
    'admin',
    'admin'
);

-- resource_connection
INSERT INTO etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by) 
VALUES (
    'resource_connection',
    'clean_data',
    'Connexions des ressources',
    'resource_connection_seq, resource_seq, primary_parent_resource_seq, connection_type, connection_type_db, company, site, employee_id, calendar_id, org_code, quantity, sched_capacity, capacity_calc_base, primary_scheduling, resource_id, resource_type, loaded_at, source_file',
    'Table des connexions entre ressources IFS',
    'maintenance',
    true,
    'admin',
    'admin'
);

-- resource_availability
INSERT INTO etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by) 
VALUES (
    'resource_availability',
    'clean_data',
    'Disponibilité des ressources',
    'resource_availability_seq, resource_parent_seq, resource_seq, company, site, start_date, end_date, available_percentage, efficiency, loaded_at, source_file',
    'Table de disponibilité des ressources IFS',
    'maintenance',
    true,
    'admin',
    'admin'
);

-- resource_parent
INSERT INTO etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by) 
VALUES (
    'resource_parent',
    'clean_data',
    'Hiérarchie des ressources',
    'resource_parent_seq, resource_seq, scheduling_proficiency, loaded_at, source_file',
    'Table de hiérarchie des ressources parentes IFS',
    'maintenance',
    true,
    'admin',
    'admin'
);

-- maint_person_resource
INSERT INTO etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by) 
VALUES (
    'maint_person_resource',
    'clean_data',
    'Ressources de maintenance par personne',
    'maint_resource_seq, resource_connection_seq, company, contract, connection_type, connection_type_db, org_code, secondment_company, secondment_employee, vendor_no, remark, filter_id, disable_operation_costs, mob_user, mob_user_type, default_time_type, default_travel_time_type, disable_transfer_mobile, primary_resource, avail_for_scheduling, travel_resource_group_seq, primary_contract, crew_time_invoicing, loaded_at, source_file',
    'Table des ressources de maintenance associées aux personnes IFS',
    'maintenance',
    true,
    'admin',
    'admin'
);

-- Vérification
SELECT id, table_name, display_name, category, is_active 
FROM etl_export_queries 
WHERE category = 'maintenance' 
ORDER BY table_name;

