CREATE TABLE IF NOT EXISTS clean_data.jt_task_resource (
    task_seq numeric,
    task_resource_seq numeric,
    planned_hours numeric,
    planned_quantity numeric,
    "offset" numeric,
    remark varchar(2000),
    created_by varchar(30),
    created_date timestamp without time zone,
    demand_type varchar(4000),
    demand_type_db varchar(20),
    resource_seq varchar(20),
    resource_group_seq numeric,
    wo_no numeric,
    task_plan_line_seq numeric,
    plan_line_no numeric,
    modified_by varchar(30),
    modified_date timestamp without time zone,
    sourcing_option varchar(4000),
    sourcing_option_db varchar(20),
    rental_supply_option varchar(4000),
    rental_supply_option_db varchar(20),
    rental_site varchar(5),
    rental_part_no varchar(25),
    quotation_no varchar(12),
    quotation_rev numeric,
    quo_task_seq numeric,
    quo_task_res_seq numeric,
    pool_allocated_qty numeric,
    crew_time_invoicing varchar(20),
    external_id varchar(500),
    objversion varchar(14),
    objid varchar(10)
);

COMMENT ON TABLE clean_data.jt_task_resource IS 'IFS JT_TASK_RESOURCE - demandes ressources des tâches de bon de travail, alimentées depuis SAP AFVC/AFKO/CRHD.';
COMMENT ON COLUMN clean_data.jt_task_resource.task_seq IS 'Reprendre N° de la table JT_TASK';
COMMENT ON COLUMN clean_data.jt_task_resource.task_resource_seq IS 'No incrémental';
COMMENT ON COLUMN clean_data.jt_task_resource.planned_hours IS 'ne pas renseigner ; champ calculé';
COMMENT ON COLUMN clean_data.jt_task_resource.planned_quantity IS 'Quantité ressource';
COMMENT ON COLUMN clean_data.jt_task_resource."offset" IS '0';
COMMENT ON COLUMN clean_data.jt_task_resource.remark IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.created_by IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.created_date IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.demand_type IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.demand_type_db IS 'PERSON ou EQUIPMENT';
COMMENT ON COLUMN clean_data.jt_task_resource.resource_seq IS 'Organisation de maintenance de la tache (jt_task.organization_id, ex. SJ-MATC)';
COMMENT ON COLUMN clean_data.jt_task_resource.resource_group_seq IS 'Resource_Group_seq = groupe ressource ; info dans RESOURCE_DETAIL';
COMMENT ON COLUMN clean_data.jt_task_resource.wo_no IS '= No BT de JT_TASK';
COMMENT ON COLUMN clean_data.jt_task_resource.task_plan_line_seq IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.plan_line_no IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.modified_by IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.modified_date IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.sourcing_option IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.sourcing_option_db IS 'INTERNALLY_SOURCED';
COMMENT ON COLUMN clean_data.jt_task_resource.rental_supply_option IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.rental_supply_option_db IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.rental_site IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.rental_part_no IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.quotation_no IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.quotation_rev IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.quo_task_seq IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.quo_task_res_seq IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.pool_allocated_qty IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.crew_time_invoicing IS 'FALSE';
COMMENT ON COLUMN clean_data.jt_task_resource.external_id IS 'ne pas renseigner selon catalogue ; laissé NULL dans le loader';
COMMENT ON COLUMN clean_data.jt_task_resource.objversion IS 'champ technique IFS - ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.objid IS 'champ technique IFS - ne pas renseigner';
