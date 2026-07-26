-- Table pour stocker les états d'avancement des projets SharePoint
-- Source: http://asap.stjn.local/863/_api/web/lists(guid'0143FA81-887F-49BC-9878-C1BF871D7F3B')/items

CREATE TABLE IF NOT EXISTS raw_data.sharepoint_etats_avancement (
    id SERIAL PRIMARY KEY,
    sharepoint_id INTEGER UNIQUE NOT NULL,
    
    -- Informations principales
    title TEXT,
    status_date TIMESTAMP,
    percent_completed NUMERIC,
    global_status TEXT,
    health TEXT,
    planning TEXT,
    cost TEXT,
    update_text TEXT,  -- Le champ "Mise à jour" (HTML)
    current_phase_id INTEGER,
    end_project_mark TEXT,
    
    -- Métadonnées SharePoint
    content_type_id TEXT,
    guid UUID,
    created TIMESTAMP,
    modified TIMESTAMP,
    author_id INTEGER,
    editor_id INTEGER,
    ui_version_string TEXT,
    attachments BOOLEAN DEFAULT FALSE,
    file_system_object_type INTEGER,
    
    -- Import
    imported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    site_id TEXT,  -- ID du sous-site (ex: 863)
    raw_data JSONB
);

-- Index pour les recherches fréquentes
CREATE INDEX IF NOT EXISTS idx_etats_avancement_status_date ON raw_data.sharepoint_etats_avancement(status_date);
CREATE INDEX IF NOT EXISTS idx_etats_avancement_global_status ON raw_data.sharepoint_etats_avancement(global_status);
CREATE INDEX IF NOT EXISTS idx_etats_avancement_site_id ON raw_data.sharepoint_etats_avancement(site_id);

COMMENT ON TABLE raw_data.sharepoint_etats_avancement IS 'États d''avancement des projets importés depuis SharePoint (liste Status Reports)';
COMMENT ON COLUMN raw_data.sharepoint_etats_avancement.site_id IS 'ID du sous-site SharePoint (ex: 863 pour le projet)';
COMMENT ON COLUMN raw_data.sharepoint_etats_avancement.update_text IS 'Texte de mise à jour en format HTML';
