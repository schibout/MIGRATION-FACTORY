-- ============================================================================
-- DROP ET RECRÉATION DE LA TABLE clean_data.project_role_assignment
-- ============================================================================

-- DROP de la table existante
DROP TABLE IF EXISTS clean_data.project_role_assignment CASCADE;

-- Recréation de la table avec les nouveaux éléments
CREATE TABLE clean_data.project_role_assignment (
    -- Clé primaire
    assign_seq_no         NUMERIC NOT NULL,
    
    -- Colonnes obligatoires (Flags: MI = Mandatory, Insertable)
    project_id            VARCHAR(10) NOT NULL,
    company               VARCHAR(20) NOT NULL,
    role_id               VARCHAR(20) NOT NULL,
    
    -- Colonnes optionnelles (Flags: IU = Insertable, Updatable)
    sub_project_id        VARCHAR(10),
    activity_seq          NUMERIC,
    person_id             VARCHAR(20),
    system_generated      VARCHAR(20),
    
    -- Clé primaire
    CONSTRAINT pk_project_role_assignment PRIMARY KEY (assign_seq_no)
);

-- Index pour optimiser les recherches
CREATE INDEX idx_proj_role_assign_project ON clean_data.project_role_assignment(project_id);
CREATE INDEX idx_proj_role_assign_company ON clean_data.project_role_assignment(company);
CREATE INDEX idx_proj_role_assign_role ON clean_data.project_role_assignment(role_id);
CREATE INDEX idx_proj_role_assign_person ON clean_data.project_role_assignment(person_id);
CREATE INDEX idx_proj_role_assign_subproj ON clean_data.project_role_assignment(sub_project_id);

-- Commentaires
COMMENT ON TABLE clean_data.project_role_assignment IS 'Affectation des rôles aux personnes dans les projets';

COMMENT ON COLUMN clean_data.project_role_assignment.assign_seq_no IS 'Assign Seq No - Numéro de séquence d''affectation (Key)';
COMMENT ON COLUMN clean_data.project_role_assignment.project_id IS 'Project ID - Identifiant du projet (Mandatory, Insertable)';
COMMENT ON COLUMN clean_data.project_role_assignment.sub_project_id IS 'Sub Project ID - ID du sous-projet (Insertable, Updatable)';
COMMENT ON COLUMN clean_data.project_role_assignment.activity_seq IS 'Proj Activity Seq No - Numéro de séquence de l''activité (Insertable, Updatable)';
COMMENT ON COLUMN clean_data.project_role_assignment.company IS 'Company - Société (Mandatory, Insertable)';
COMMENT ON COLUMN clean_data.project_role_assignment.role_id IS 'Role ID - ID rôle (Mandatory, Insertable)';
COMMENT ON COLUMN clean_data.project_role_assignment.person_id IS 'Person ID - ID personne (Insertable, Updatable)';
COMMENT ON COLUMN clean_data.project_role_assignment.system_generated IS 'System Generated - Généré par le système (Insertable, Updatable)';