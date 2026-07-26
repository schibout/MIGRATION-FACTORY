-- ============================================================================
-- Script d'insertion des requêtes d'export PM Actions dans etl_export_queries
-- Description : enregistre les 7 tables cibles PM Action (schéma clean_data) pour
--               l'export dynamique (catégorie "PM Action"). L'export côté frontend
--               (exportPmActionData -> /export/maintenance) s'appuie sur ces entrées.
--
--               Le module ETL (etl_pm_action.py) n'alimente que 4 de ces tables
--               (pm_action, pm_action_work_step, pm_action_resource, pm_action_role) ;
--               les 3 autres (job, planning, spare_part) restent exportables (vides
--               tant qu'elles ne sont pas alimentées).
--
-- Idempotent : supprime puis réinsère toutes les entrées de la catégorie "PM Action".
-- ============================================================================

-- Supprimer les anciennes entrées de la catégorie pour éviter les doublons
DELETE FROM public.etl_export_queries WHERE category = 'PM Action';

-- 1. pm_action (table principale)
INSERT INTO public.etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by)
VALUES (
    'pm_action',
    'clean_data',
    'Plans de Maintenance Préventive',
    'pm_no, pm_revision, mch_code_contract, mch_code, equipment_object_seq, test_point_id, signature, action_code_id, work_type_id, org_contract, org_code, op_status_id, rounddef_id, priority_id, call_code, testnumber, latest_pm, start_value, pm_start_unit, pm_start_unit_db, interval, pm_interval_unit, pm_interval_unit_db, last_changed, vendor_no, pm_order_no, plan_men, plan_hrs, note, alternate_designation, instruction, materials, description, pm_generateable, pm_generateable_db, pm_performed_date_based, pm_performed_date_based_db, date_value, start_date, customer_no, currency_code, valid_from, valid_to, calendar_id, contract_id, line_no, reason, done_by, rev_cre_date, revision_control, connection_type, connection_type_db, err_location_descr, elimination_value, old_revision, resource_seq, test_pnt_seq, sched_maint_win, sched_maint_win_db, pm_program_id, pm_program_rev, pm_prog_applied_date, pm_merge, auto_find_ser_contract, grouping_rule_id, pm_criteria_config, pm_criteria_config_db, fwd_window_length, bwd_window_length, wo_gen_lead_time, move_serial_repl, fmeca_anal_id, fmeca_anal_revision, fmeca_event_trigger_seq, fmeca_calendar_trigger_seq',
    'Table principale des plans de maintenance préventive IFS. Contient la définition des PM (numéro, révision, équipement rattaché, code action, type de travail, organisation, périodicité, heures planifiées et paramètres de génération des OT).',
    'PM Action',
    true,
    'ETL_SYSTEM',
    'ETL_SYSTEM'
);

-- 2. pm_action_work_step
INSERT INTO public.etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by)
VALUES (
    'pm_action_work_step',
    'clean_data',
    'Étapes de Travail des Plans de Maintenance',
    'pm_no, pm_revision, work_list_no, pm_action_work_step_seq, description, order_no, note_id, task_temp_work_step_seq, remark, mch_code_contract, mch_code, equipment_object_seq, connection_type, connection_type_db, linast_linear_asset_sq, linast_linear_asset_rev_no, resource_seq',
    'Étapes opérationnelles séquentielles d''un plan de maintenance préventive. Chaque étape porte une description détaillée, un numéro d''ordre, des remarques et un lien optionnel vers l''équipement concerné.',
    'PM Action',
    true,
    'ETL_SYSTEM',
    'ETL_SYSTEM'
);

-- 3. pm_action_resource
INSERT INTO public.etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by)
VALUES (
    'pm_action_resource',
    'clean_data',
    'Ressources Planifiées des Plans de Maintenance',
    'pm_no, pm_revision, work_list_no, pm_action_resource_seq, demand_type, demand_type_db, resource_group_seq, resource_group, resource_group_description, resource_seq, resource_id, resource_description, planned_hours, planned_quantity, remark, fixed_resource, fixed_resource_db, plan_line_no, task_temp_resource_seq',
    'Ressources humaines et matérielles planifiées pour chaque plan de maintenance. Inclut le type de besoin (LABOR / TOOL), le groupe de ressources, l''identifiant ressource, les heures et quantités planifiées ainsi que l''indicateur de ressource fixe.',
    'PM Action',
    true,
    'ETL_SYSTEM',
    'ETL_SYSTEM'
);

-- 4. pm_action_role
INSERT INTO public.etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by)
VALUES (
    'pm_action_role',
    'clean_data',
    'Rôles et Équipes des Plans de Maintenance',
    'pm_no, pm_revision, row_no, description, duration, remark, org_contract, org_code, job_id, std_row_no, company, team_contract, team_id, op_status_id, work_stage_id',
    'Définition des rôles (profils de compétence, équipes) requis pour l''exécution d''un plan de maintenance. Associé à un job via job_id. Inclut la durée planifiée par rôle et le statut opérationnel.',
    'PM Action',
    true,
    'ETL_SYSTEM',
    'ETL_SYSTEM'
);

-- 5. pm_action_job (non alimenté par l'ETL, exportable)
INSERT INTO public.etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by)
VALUES (
    'pm_action_job',
    'clean_data',
    'Travaux Standards des Plans de Maintenance',
    'pm_no, pm_revision, job_id, std_job_id, std_job_contract, std_job_revision, qty, description, company',
    'Travaux (jobs) associés à chaque plan de maintenance préventive. Référence optionnelle vers un Standard Job IFS. Un PM peut comporter plusieurs jobs ordonnés.',
    'PM Action',
    true,
    'ETL_SYSTEM',
    'ETL_SYSTEM'
);

-- 6. pm_action_planning (non alimenté par l'ETL, exportable)
INSERT INTO public.etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by)
VALUES (
    'pm_action_planning',
    'clean_data',
    'Lignes de Planification et de Coûts des PM',
    'pm_no, pm_revision, plan_line_no, quantity, qty_to_invoice, cost, sales_price, discount, price_list_no, cost_flag, work_order_cost_type, work_order_cost_type_db, work_order_invoice_type, work_order_invoice_type_db, std_row_no, catalog_contract, catalog_no, from_srv_line, price_source_db, price_source_id, markup, work_list_no',
    'Lignes de planification budgétaire et de coûts associées aux plans de maintenance préventive. Distingue les coûts main-d''œuvre (LABOR) et fournitures (MATERIAL). Utilisé pour la valorisation des OT générés et la facturation éventuelle.',
    'PM Action',
    true,
    'ETL_SYSTEM',
    'ETL_SYSTEM'
);

-- 7. pm_action_spare_part (non alimenté par l'ETL, exportable)
INSERT INTO public.etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by)
VALUES (
    'pm_action_spare_part',
    'clean_data',
    'Pièces de Rechange des Plans de Maintenance',
    'pm_no, pm_revision, pm_spare_seq, part_no, qty_plan, spare_contract, contract, catalog_no, revenue, condition_code, part_ownership, part_ownership_db, owner, std_row_no, plan_line_no, cost, operation_no, price_source_db, price_source_id, markup',
    'Nomenclature des pièces de rechange planifiées pour chaque PM. Contient la référence article (part_no), le site de stockage (spare_contract), la quantité planifiée et les informations de propriété et de coût.',
    'PM Action',
    true,
    'ETL_SYSTEM',
    'ETL_SYSTEM'
);

-- Vérification
SELECT id, table_name, display_name, category, is_active
FROM public.etl_export_queries
WHERE category = 'PM Action'
ORDER BY table_name;
