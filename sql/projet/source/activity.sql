-- Création de la table activity
CREATE TABLE clean_data.activity (
    -- Clé primaire
    activity_seq NUMERIC(20) NOT NULL,
    -- Colonnes obligatoires (flag M)
    project_id VARCHAR(10) NOT NULL,
    activity_no VARCHAR(10) NOT NULL,
    description VARCHAR(200) NOT NULL,
    progress_method VARCHAR(4000) NOT NULL,
    planned_cost_driver VARCHAR(4000) NOT NULL,
    exclude_periodical_cap VARCHAR(4000) NOT NULL,
    exclude_resource_progress VARCHAR(4000) NOT NULL,
    exclude_from_integrations VARCHAR(4000) NOT NULL,
    node_type VARCHAR(4000) NOT NULL,
    mandatory_invoice_comment VARCHAR(4000) NOT NULL,
    -- Autres colonnes
    sub_project_id VARCHAR(10),
    total_key_path VARCHAR(200),
    activity_responsible VARCHAR(20),
    manual_progress_level VARCHAR(4000),
    manual_progress_level_db VARCHAR(20),
    estimated_progress NUMERIC(20),
    manual_progress_cost NUMERIC(20),
    manual_progress_hours NUMERIC(20),
    total_duration_days NUMERIC(20),
    total_work_days NUMERIC(20),
    note VARCHAR(2000),
    early_start DATE,
    early_finish DATE,
    late_start DATE,
    late_finish DATE,
    actual_start DATE,
    actual_finish DATE,
    cancel_date DATE,
    short_name VARCHAR(50),
    released_date DATE,
    completed_date DATE,
    closed_date DATE,
    progress_method_db VARCHAR(30),
    planned_cost_driver_db VARCHAR(30),
    progress_template VARCHAR(10),
    progress_template_step VARCHAR(10),
    date_created DATE,
    created_by VARCHAR(35),
    date_modified DATE,
    modified_by VARCHAR(35),
    set_in_baseline NUMERIC(20),
    set_activity_changed VARCHAR(4000),
    set_activity_changed_db VARCHAR(4000),
    case_id NUMERIC(20),
    task_id NUMERIC(20),
    baseline_pcd VARCHAR(4000),
    baseline_pcd_db VARCHAR(30),
    financially_responsible VARCHAR(20),
    amount_planned NUMERIC(20),
    amount_used NUMERIC(20),
    exclude_from_wad VARCHAR(4000),
    exclude_from_wad_db VARCHAR(5),
    generate_safety_stock VARCHAR(10),
    hours_planned NUMERIC(20),
    address_id VARCHAR(50),
    exclude_periodical_cap_db VARCHAR(20),
    financially_completed VARCHAR(4000),
    financially_completed_db VARCHAR(5),
    exclude_resource_progress_db VARCHAR(20),
    free_float NUMERIC(20),
    total_float NUMERIC(20),
    constraint_type VARCHAR(4000),
    constraint_type_db VARCHAR(25),
    constraint_date DATE,
    exclude_from_integrations_db VARCHAR(20),
    node_type_db VARCHAR(20),
    mandatory_invoice_comment_db VARCHAR(10),
    
    -- Contrainte de clé primaire
    CONSTRAINT pk_activity PRIMARY KEY (activity_seq)
);

-- Commentaires sur la table
COMMENT ON TABLE clean_data.activity IS 'Table des activités projet';

-- Commentaires sur les colonnes principales
COMMENT ON COLUMN clean_data.activity.activity_seq IS 'Activity Sequence';
COMMENT ON COLUMN clean_data.activity.project_id IS 'Project ID';
COMMENT ON COLUMN clean_data.activity.sub_project_id IS 'Sub Project ID';
COMMENT ON COLUMN clean_data.activity.activity_no IS 'Activity ID';
COMMENT ON COLUMN clean_data.activity.description IS 'Description';
COMMENT ON COLUMN clean_data.activity.activity_responsible IS 'Responsible ID';
COMMENT ON COLUMN clean_data.activity.progress_method IS 'Progress Method';
COMMENT ON COLUMN clean_data.activity.planned_cost_driver IS 'Planned Cost Driver';
COMMENT ON COLUMN clean_data.activity.exclude_periodical_cap IS 'Exclude from Periodical Capitalization';
COMMENT ON COLUMN clean_data.activity.exclude_resource_progress IS 'Exclude Activity Resource Progress';
COMMENT ON COLUMN clean_data.activity.exclude_from_integrations IS 'Exclude from Import and Export';
COMMENT ON COLUMN clean_data.activity.node_type IS 'Node Type';
COMMENT ON COLUMN clean_data.activity.mandatory_invoice_comment IS 'Mandatory Invoice Comment';