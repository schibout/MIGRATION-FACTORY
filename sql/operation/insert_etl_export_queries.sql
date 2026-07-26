-- ============================================================================
-- Script d'insertion des requêtes d'export Opérations de maintenance dans etl_export_queries
-- Description : enregistre les 3 tables cibles Opérations (schéma clean_data) pour
--               l'export dynamique (catégorie "Operation"). L'export côté frontend
--               (exportOperationData -> /export/maintenance) s'appuie sur ces entrées.
--
--               Les 3 tables sont alimentées par le module ETL etl_operation.pyCréer modules ETL pour opérations de maintenance
--               (fonctions clean_data.alimenter_jt_task / alimenter_jt_task_resource /
--               alimenter_maint_material_req_line, voir sql/operation/).
--
-- Idempotent : supprime puis réinsère toutes les entrées de la catégorie "Operation".
-- ============================================================================

-- Supprimer les anciennes entrées de la catégorie pour éviter les doublons
DELETE FROM public.etl_export_queries WHERE category = 'Operation';

-- 1. jt_task (table principale)
INSERT INTO public.etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by)
VALUES (
    'jt_task',
    'clean_data',
    'Opérations de Bons de Travail (JT Task)',
    'task_seq, order_no, wo_no, site, company, organization_site, organization_id, priority_id, work_type_id, description, long_description, created_by, created_date, prepared_by, reported_by, reported_date, mpb_latest_update, planned_start, planned_finish, duration, actual_start, actual_finish, earliest_start, latest_start, latest_finish, fixed_start, sla_order_no, sla_order_line_no, sla_latest_start, sla_latest_finish, responded_date, resolved_date, exclude_from_scheduling, exclude_from_scheduling_db, adjusted_duration, remark, internal_remark, action_taken, cancel_cause, source_connection_lu_name, source_connection_lu_name_db, source_connection_rowkey, reported_connection_type, reported_connection_type_db, reported_obj_conn_lu_name, reported_obj_conn_lu_name_db, reported_obj_conn_rowkey, actual_connection_type, actual_connection_type_db, actual_obj_conn_lu_name, actual_obj_conn_lu_name_db, actual_obj_conn_rowkey, operational_status_id, test_point_seq, error_cause_long, error_type, error_class, error_discover_code, error_symptom, item_class_id, error_cause, item_class_function, failing_component, performed_action_id, performed_work, customer_no, vendor_no, contract_id, line_no, contact, contact_phone_no, e_mail, cust_order_type, currency_code, delivery_address, cust_order_no, authorize_code, reference_no, cust_warr_type, cust_warranty, obj_cust_warranty, sup_warr_type, sup_warranty, obj_sup_warranty, contractor_owner, job_id, maint_team_site, team_id, pre_accounting_id, note_id, source_ref1, source_ref2, source_ref3, source_ref4, master_task_seq, duplicate_type, duplicate_type_db, cost_code, project_id, activity_seq, quotation_no, quotation_rev, quo_task_seq, mobile_task_id, inspection_note, generate_note, work_stage_id, pm_group_id, changed_date, allow_multiple_visits, allow_multiple_visits_db, min_visit_duration, srv_request_scope_id, event_id, event_period_seq, hm_contract_id, hm_contract_line_no, postponed_reason, original_latest_finish, split_min_priority, interrupt_priority, interrupt_multiplier, interrupt, interrupt_db, duration_override, activity_type_id, service_organization_id, service_delivery_unit, displacement_priority, dataset_id, fmeca_anal_id, fmeca_anal_revision, function_id, functional_failure_id, failure_mode_id, fmeca_failing_component, trigger_seq_no, effect, fmeca_cause, fmeca_symptom, external_id, created_date_ofs, reported_date_ofs, mpb_latest_update_ofs, planned_start_ofs, planned_finish_ofs, actual_start_ofs, actual_finish_ofs, earliest_start_ofs, latest_start_ofs, latest_finish_ofs, fixed_start_ofs, changed_date_ofs, original_latest_finish_ofs, custom_metric_id, custom_metric_value, report_proj_planned_cost, report_proj_planned_cost_db, appointment_required, warranty_assessment_id, remotely_fulfilled, scheduled_manually, c_part_no, c_serial_no, c_risk_level, state, objtype, objversion, objid',
    'Table principale des opérations de maintenance IFS (JT_TASK). Contient les tâches/opérations des bons de travail alimentées depuis SAP AFVC/AFKO (task_seq = aufpl*100000000 + aplzl, wo_no = n° d''ordre SAP), avec description, site, organisation, type de travail, dates planifiées/réelles et durée.',
    'Operation',
    true,
    'ETL_SYSTEM',
    'ETL_SYSTEM'
);

-- 2. jt_task_resource
INSERT INTO public.etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by)
VALUES (
    'jt_task_resource',
    'clean_data',
    'Ressources des Opérations de Bons de Travail',
    'task_seq, task_resource_seq, planned_hours, planned_quantity, offset, remark, created_by, created_date, demand_type, demand_type_db, resource_seq, resource_group_seq, wo_no, task_plan_line_seq, plan_line_no, modified_by, modified_date, sourcing_option, sourcing_option_db, rental_supply_option, rental_supply_option_db, rental_site, rental_part_no, quotation_no, quotation_rev, quo_task_seq, quo_task_res_seq, pool_allocated_qty, crew_time_invoicing, external_id, objversion, objid',
    'Demandes de ressources des tâches de bon de travail (JT_TASK_RESOURCE), alimentées depuis SAP AFVC/AFKO/CRHD. Chaque ligne référence une tâche (task_seq) avec le type de besoin (PERSON/EQUIPMENT), le groupe de ressources (via resource_detail_file et transcodification RESOURCE_GROUP/ARBPL) et la quantité planifiée.',
    'Operation',
    true,
    'ETL_SYSTEM',
    'ETL_SYSTEM'
);

-- 3. maint_material_req_line
INSERT INTO public.etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by)
VALUES (
    'maint_material_req_line',
    'clean_data',
    'Besoins Matière des Opérations de Maintenance',
    'maint_material_order_no, line_item_no, part_no, spare_contract, date_required, plan_qty, qty, qty_short, qty_assigned, qty_returned, catalog_contract, catalog_no, price_list_no, list_price, list_price_curr, sale_unit_price, sale_unit_price_curr, discount, qty_to_invoice, cost, wo_no, plan_line_no, task_plan_line_seq, serial_no, condition_code, part_ownership, part_ownership_db, owner, supply_code, supply_code_db, job_id, is_closed, pegged_qty, repair_part_flag, manual_line, rwo_equip_object_seq, rwo_mch_contract, rwo_mch_code, rwo_contract, rwo_org_code, rwo_lot_batch_no, rwo_err_descr, rwo_copy_prepost, rwo_copy_prepost_db, price_source_db, price_source_id, generated, markup, rental, rental_db, rental_task_res_seq, price_effective_date, quotation_no, quotation_rev, wo_quo_no, quo_spare_seq, change_reason, changes_line_item_no, qty_changed, task_seq, quo_task_seq, tool_fac_row_no, place_in_facility_db, swap_part_db, serial_in, serial_in_contract, vendor_no, supply_source_ref1, supply_source_ref2, supply_source_ref3, supply_source_ref4, supply_source_ref_state, supply_source_ref_type, supply_source_ref_type_db, delivery, delivery_db, part_type, part_type_db, mobile_created, mobile_created_db, objid, objversion, cf_alt_on_hand_qty, cf_ecartqtedispo, cf_on_supply_qty, no_part_description, buy_unit_meas, pickup_task_id, consumed_qty, fbuy_unit_price, external_id, sender_type, sender_type_db, sender_id, supply_site, mobile_warranty, mobile_warranty_db, purchase_method, purchase_method_db, service_type, note',
    'Lignes de besoin matière maintenance IFS (MAINT_MATERIAL_REQ_LINE), alimentées depuis SAP RESB (réservations de composants des ordres PM). Chaque ligne porte l''article (part_no), le site (spare_contract), la quantité prévue, la date demandée et le lien vers la tâche (task_seq) et le bon de travail (wo_no).',
    'Operation',
    true,
    'ETL_SYSTEM',
    'ETL_SYSTEM'
);

-- Vérification
SELECT id, table_name, display_name, category, is_active
FROM public.etl_export_queries
WHERE category = 'Operation'
ORDER BY table_name;
