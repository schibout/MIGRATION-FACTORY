-- Migration: Ajouter les colonnes manquantes à raw_data.sharepoint_projets
-- Date: 2025-10-08
-- Description: Ajout des colonnes structurées pour les données importantes de SharePoint

-- Créer le schéma raw_data s'il n'existe pas
CREATE SCHEMA IF NOT EXISTS raw_data;

-- Supprimer la table si elle existe (pour recréation complète)
DROP TABLE IF EXISTS raw_data.sharepoint_projets CASCADE;

-- Créer la table avec toutes les colonnes nécessaires
CREATE TABLE raw_data.sharepoint_projets (
    -- Colonnes de base
    id SERIAL PRIMARY KEY,
    sharepoint_id INTEGER UNIQUE NOT NULL,
    
    -- Informations principales du projet
    title TEXT,
    code TEXT,
    project_number TEXT,
    description TEXT,
    
    -- Statut et progression
    global_status TEXT,
    phase_text TEXT,
    percent_completed NUMERIC(5,2),
    health TEXT,
    planning TEXT,
    cost TEXT,
    
    -- Dates
    start_date TIMESTAMP,
    estimated_end_date TIMESTAMP,
    last_status_report_date TIMESTAMP,
    opening_date TIMESTAMP,
    modified TIMESTAMP,
    created TIMESTAMP,
    imported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Budget
    budget_initial NUMERIC(15,2),
    budget_total_sap NUMERIC(15,2),
    budget_actual NUMERIC(15,2),
    budget_at_completion NUMERIC(15,2),
    budget_demanded NUMERIC(15,2),
    budget_delivered NUMERIC(15,2),
    budget_im_sap NUMERIC(15,2),
    budget_ex_sap NUMERIC(15,2),
    
    -- Organisation
    sector TEXT,
    group_name TEXT,
    template TEXT,
    
    -- IDs de référence
    pm_id INTEGER,
    client_correspondent_id INTEGER,
    project_team_id INTEGER,
    acheteur_capex_id INTEGER,
    maintenance_correspondent_id INTEGER,
    sponsor_id INTEGER,
    author_id INTEGER,
    editor_id INTEGER,
    
    -- Jalons (Gates)
    passing_gate TEXT,
    end_p0 TIMESTAMP,
    end_p1 TIMESTAMP,
    end_p2 TIMESTAMP,
    end_p3 TIMESTAMP,
    end_p4 TIMESTAMP,
    end_p5 TIMESTAMP,
    end_p6 TIMESTAMP,
    
    -- Dates spécifiques
    last_milestone_passed TIMESTAMP,
    conception_date TIMESTAMP,
    mise_en_service_date TIMESTAMP,
    achevement_industriel_date TIMESTAMP,
    
    -- États
    conception_state TEXT,
    mise_en_service_state TEXT,
    achevement_industriel_state TEXT,
    
    -- Flags
    project_ahead BOOLEAN DEFAULT FALSE,
    retroplanning BOOLEAN DEFAULT FALSE,
    attachments BOOLEAN DEFAULT FALSE,
    pris_en_charge TEXT,
    end_project_mark TEXT,
    
    -- URL et IDs spéciaux
    site_url TEXT,
    site_url_description TEXT,
    validation_id TEXT,
    content_type_id TEXT,
    guid TEXT,
    static_id NUMERIC,
    
    -- Champ JSONB pour toutes les données brutes (flexibilité)
    raw_data JSONB,
    
    -- Métadonnées
    file_system_object_type INTEGER,
    ui_version_string TEXT,
    priority TEXT
);

-- Index pour améliorer les performances
CREATE INDEX idx_sharepoint_projets_sharepoint_id ON raw_data.sharepoint_projets(sharepoint_id);
CREATE INDEX idx_sharepoint_projets_code ON raw_data.sharepoint_projets(code);
CREATE INDEX idx_sharepoint_projets_project_number ON raw_data.sharepoint_projets(project_number);
CREATE INDEX idx_sharepoint_projets_global_status ON raw_data.sharepoint_projets(global_status);
CREATE INDEX idx_sharepoint_projets_sector ON raw_data.sharepoint_projets(sector);
CREATE INDEX idx_sharepoint_projets_imported_at ON raw_data.sharepoint_projets(imported_at);
CREATE INDEX idx_sharepoint_projets_raw_data ON raw_data.sharepoint_projets USING gin(raw_data);

-- Commentaires sur la table
COMMENT ON TABLE raw_data.sharepoint_projets IS 'Données des projets importées depuis SharePoint ASAP';
COMMENT ON COLUMN raw_data.sharepoint_projets.sharepoint_id IS 'ID unique du projet dans SharePoint';
COMMENT ON COLUMN raw_data.sharepoint_projets.raw_data IS 'Données brutes complètes en JSON depuis SharePoint';
COMMENT ON COLUMN raw_data.sharepoint_projets.imported_at IS 'Date et heure de l''import dans PostgreSQL';

