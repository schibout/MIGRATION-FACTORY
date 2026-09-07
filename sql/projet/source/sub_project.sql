-- Création de la table sub_project
CREATE TABLE clean_data.sub_project (
    project_id VARCHAR(10) NOT NULL,
    sub_project_id VARCHAR(10) NOT NULL,
    parent_sub_project_id VARCHAR(4000),
    description VARCHAR(255) NOT NULL,
    manager VARCHAR(20),
    department VARCHAR(35),
    date_created DATE,
    created_by VARCHAR(35),
    date_modified DATE,
    modified_by VARCHAR(35),
    financially_responsible VARCHAR(20),
    exclude_from_wad VARCHAR(4000) DEFAULT 'False',
    exclude_from_wad_db VARCHAR(5) DEFAULT 'FALSE',
    address_id VARCHAR(50),
    financially_completed VARCHAR(4000),
    financially_completed_db VARCHAR(5),
    exclude_from_integrations VARCHAR(4000) DEFAULT 'False',
    exclude_from_integrations_db VARCHAR(20) DEFAULT 'FALSE',
    
    -- Clé primaire composite
    CONSTRAINT pk_sub_project PRIMARY KEY (project_id, sub_project_id)
);

-- Commentaires sur la table
COMMENT ON TABLE clean_data.sub_project IS 'Table des sous-projets';

-- Commentaires sur les colonnes principales
COMMENT ON COLUMN clean_data.sub_project.project_id IS 'Project ID';
COMMENT ON COLUMN clean_data.sub_project.sub_project_id IS 'Sub Project ID';
COMMENT ON COLUMN clean_data.sub_project.parent_sub_project_id IS 'Parent Sub Project ID';
COMMENT ON COLUMN clean_data.sub_project.description IS 'Description';
COMMENT ON COLUMN clean_data.sub_project.manager IS 'Manager';
COMMENT ON COLUMN clean_data.sub_project.department IS 'Department';
COMMENT ON COLUMN clean_data.sub_project.financially_responsible IS 'Financially Responsible';
COMMENT ON COLUMN clean_data.sub_project.exclude_from_wad IS 'Excluded from WAD (Client values: False/True)';
COMMENT ON COLUMN clean_data.sub_project.exclude_from_wad_db IS 'Exclude From Wad (DB values: FALSE/TRUE)';
COMMENT ON COLUMN clean_data.sub_project.financially_completed IS 'Financially Completed (Client values: False/True)';
COMMENT ON COLUMN clean_data.sub_project.financially_completed_db IS 'Financially Completed (DB values: FALSE/TRUE)';
COMMENT ON COLUMN clean_data.sub_project.exclude_from_integrations IS 'Exclude from Import and Export (Client values: False/True)';
COMMENT ON COLUMN clean_data.sub_project.exclude_from_integrations_db IS 'Exclude from Import and Export (DB values: FALSE/TRUE)';