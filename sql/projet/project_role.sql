CREATE TABLE clean_data.project_role (
    project_id VARCHAR(10) NOT NULL,
    company VARCHAR(20) NOT NULL,
    role_id VARCHAR(20) NOT NULL,
    
    -- Clé primaire composite
    CONSTRAINT pk_project_role PRIMARY KEY (project_id, company, role_id)
);

-- Index pour optimiser les recherches
CREATE INDEX idx_project_role_project_id ON clean_data.project_role(project_id);
CREATE INDEX idx_project_role_role_id ON clean_data.project_role(role_id);

-- Commentaires
COMMENT ON TABLE clean_data.project_role IS 'Table des rôles affectés aux projets';
COMMENT ON COLUMN clean_data.project_role.project_id IS 'Project ID';
COMMENT ON COLUMN clean_data.project_role.company IS 'Company';
COMMENT ON COLUMN clean_data.project_role.role_id IS 'Role ID';