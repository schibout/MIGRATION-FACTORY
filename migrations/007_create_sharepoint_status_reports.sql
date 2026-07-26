-- =====================================================
-- Migration: Création table sharepoint_status_reports
-- Description: Table pour stocker les rapports d'états d'avancement des projets SharePoint
-- Date: 2026-01-13
-- =====================================================

-- Créer le schéma raw_data s'il n'existe pas
CREATE SCHEMA IF NOT EXISTS raw_data;

-- Supprimer la table si elle existe (ATTENTION: perte de données)
DROP TABLE IF EXISTS raw_data.sharepoint_status_reports CASCADE;

-- Créer la table pour les rapports d'états d'avancement
CREATE TABLE raw_data.sharepoint_status_reports (
    -- Clés primaires et identifiants
    id SERIAL PRIMARY KEY,
    sharepoint_item_id INTEGER UNIQUE NOT NULL,
    
    -- Métadonnées SharePoint
    content_type_id VARCHAR(255),
    guid UUID,
    file_system_object_type INTEGER,
    ui_version_string VARCHAR(50),
    
    -- Informations de base du rapport
    title VARCHAR(500),
    report_date DATE,                    -- Date de l'état
    percent_completed NUMERIC(5,2),      -- % Complété
    update_notes TEXT,                   -- Mise à jour (HTML)
    
    -- Statuts du projet
    health_status VARCHAR(100),          -- Statut Santé projet (Ok, Alerte, Problème)
    planning_status VARCHAR(100),        -- Statut Planning
    cost_status VARCHAR(100),            -- Statut Coût
    global_status VARCHAR(100),          -- Statut Global
    
    -- Phase et jalons
    current_phase VARCHAR(200),          -- Phase courante
    current_phase_id INTEGER,            -- ID de la phase (lookup)
    passing_gate VARCHAR(50),            -- Jalon en cours de passage
    
    -- Jalons (Gates) - Dates et statuts
    gate_p0_date DATE,
    gate_p0_status VARCHAR(100),
    gate_p0_note NUMERIC(5,2),
    gate_p0_classification VARCHAR(100),
    
    gate_p1_date DATE,
    gate_p1_status VARCHAR(100),
    gate_p1_note NUMERIC(5,2),
    gate_p1_classification VARCHAR(100),
    
    gate_p2_date DATE,
    gate_p2_status VARCHAR(100),
    gate_p2_note NUMERIC(5,2),
    gate_p2_classification VARCHAR(100),
    
    gate_p3_date DATE,
    gate_p3_status VARCHAR(100),
    gate_p3_note NUMERIC(5,2),
    gate_p3_classification VARCHAR(100),
    
    gate_p6_date DATE,
    gate_p6_status VARCHAR(100),
    gate_p6_note NUMERIC(5,2),
    gate_p6_classification VARCHAR(100),
    
    -- Autres jalons
    project_resume_date DATE,            -- Reprise du projet
    onsite_work_date DATE,               -- Travaux sur site
    
    -- Commissions Feu Vert
    conception_status VARCHAR(100),      -- État Conception
    conception_date DATE,
    
    mise_en_service_status VARCHAR(100), -- État Mise en service
    mise_en_service_date DATE,
    
    achevement_industriel_status VARCHAR(100), -- État Achèvement industriel
    achevement_industriel_date DATE,
    
    -- Informations budgétaires
    total_budget_sap NUMERIC(15,2),      -- Budget total SAP du projet
    note_end_project TEXT,               -- Note de fin de projet
    planning_status_project VARCHAR(100),-- Statut planning projet
    
    -- Coûts détaillés (WBS)
    wbs_1000_carbone_budget NUMERIC(15,2),
    wbs_1000_carbone_engaged NUMERIC(15,2),
    wbs_1000_carbone_received NUMERIC(15,2),
    wbs_1000_carbone_remaining NUMERIC(15,2),
    
    wbs_9999_total_budget NUMERIC(15,2),
    wbs_9999_total_engaged NUMERIC(15,2),
    wbs_9999_total_received NUMERIC(15,2),
    wbs_9999_total_remaining NUMERIC(15,2),
    
    -- Relation avec le projet
    project_id INTEGER,                  -- ID du projet SharePoint (FK vers sharepoint_projets)
    project_code VARCHAR(50),            -- Code du projet
    
    -- Métadonnées d'audit
    created TIMESTAMP,
    author_id INTEGER,
    modified TIMESTAMP,
    editor_id INTEGER,
    
    -- Import tracking
    imported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_file VARCHAR(255) DEFAULT 'sharepoint_api',
    import_batch_id VARCHAR(100),
    
    -- Données brutes complètes (JSONB pour flexibilité)
    raw_data JSONB
);

-- Créer les index pour optimiser les requêtes
CREATE INDEX idx_status_reports_sharepoint_item_id ON raw_data.sharepoint_status_reports(sharepoint_item_id);
CREATE INDEX idx_status_reports_project_id ON raw_data.sharepoint_status_reports(project_id);
CREATE INDEX idx_status_reports_project_code ON raw_data.sharepoint_status_reports(project_code);
CREATE INDEX idx_status_reports_report_date ON raw_data.sharepoint_status_reports(report_date DESC);
CREATE INDEX idx_status_reports_current_phase ON raw_data.sharepoint_status_reports(current_phase);
CREATE INDEX idx_status_reports_health_status ON raw_data.sharepoint_status_reports(health_status);
CREATE INDEX idx_status_reports_imported_at ON raw_data.sharepoint_status_reports(imported_at DESC);
CREATE INDEX idx_status_reports_raw_data_gin ON raw_data.sharepoint_status_reports USING gin(raw_data);

-- Ajouter des commentaires sur la table et les colonnes principales
COMMENT ON TABLE raw_data.sharepoint_status_reports IS 'Rapports d''états d''avancement des projets depuis SharePoint ASAP';
COMMENT ON COLUMN raw_data.sharepoint_status_reports.sharepoint_item_id IS 'ID unique de l''item dans SharePoint';
COMMENT ON COLUMN raw_data.sharepoint_status_reports.report_date IS 'Date de l''état d''avancement';
COMMENT ON COLUMN raw_data.sharepoint_status_reports.percent_completed IS 'Pourcentage de complétion du projet';
COMMENT ON COLUMN raw_data.sharepoint_status_reports.health_status IS 'Statut santé: Ok, Alerte, Problème';
COMMENT ON COLUMN raw_data.sharepoint_status_reports.current_phase IS 'Phase courante du projet';
COMMENT ON COLUMN raw_data.sharepoint_status_reports.project_id IS 'Référence vers sharepoint_projets.sharepoint_id';
COMMENT ON COLUMN raw_data.sharepoint_status_reports.raw_data IS 'Données brutes complètes au format JSON';

-- Afficher un message de confirmation
DO $$
BEGIN
    RAISE NOTICE '✅ Table raw_data.sharepoint_status_reports créée avec succès';
    RAISE NOTICE '📊 Colonnes créées: %', (
        SELECT COUNT(*) 
        FROM information_schema.columns 
        WHERE table_schema = 'raw_data' 
        AND table_name = 'sharepoint_status_reports'
    );
    RAISE NOTICE '🔍 Index créés: %', (
        SELECT COUNT(*) 
        FROM pg_indexes 
        WHERE schemaname = 'raw_data' 
        AND tablename = 'sharepoint_status_reports'
    );
END $$;
