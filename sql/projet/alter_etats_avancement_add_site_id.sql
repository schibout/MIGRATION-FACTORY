-- Migration: Ajouter les colonnes manquantes à la table sharepoint_etats_avancement
-- Date: 2026-03-06
-- Description: Ajoute les colonnes site_id, raw_data et autres colonnes manquantes

-- Ajouter site_id (ID du sous-site SharePoint)
ALTER TABLE raw_data.sharepoint_etats_avancement 
ADD COLUMN IF NOT EXISTS site_id TEXT;

-- Ajouter raw_data (données brutes JSON)
ALTER TABLE raw_data.sharepoint_etats_avancement 
ADD COLUMN IF NOT EXISTS raw_data JSONB;

-- Ajouter les autres colonnes manquantes
ALTER TABLE raw_data.sharepoint_etats_avancement 
ADD COLUMN IF NOT EXISTS content_type_id TEXT;

ALTER TABLE raw_data.sharepoint_etats_avancement 
ADD COLUMN IF NOT EXISTS guid UUID;

ALTER TABLE raw_data.sharepoint_etats_avancement 
ADD COLUMN IF NOT EXISTS modified TIMESTAMP;

ALTER TABLE raw_data.sharepoint_etats_avancement 
ADD COLUMN IF NOT EXISTS author_id INTEGER;

ALTER TABLE raw_data.sharepoint_etats_avancement 
ADD COLUMN IF NOT EXISTS editor_id INTEGER;

ALTER TABLE raw_data.sharepoint_etats_avancement 
ADD COLUMN IF NOT EXISTS ui_version_string TEXT;

ALTER TABLE raw_data.sharepoint_etats_avancement 
ADD COLUMN IF NOT EXISTS attachments BOOLEAN DEFAULT FALSE;

ALTER TABLE raw_data.sharepoint_etats_avancement 
ADD COLUMN IF NOT EXISTS file_system_object_type INTEGER;

ALTER TABLE raw_data.sharepoint_etats_avancement 
ADD COLUMN IF NOT EXISTS imported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Créer les index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_etats_avancement_site_id 
ON raw_data.sharepoint_etats_avancement(site_id);

CREATE INDEX IF NOT EXISTS idx_etats_avancement_status_date 
ON raw_data.sharepoint_etats_avancement(status_date);

CREATE INDEX IF NOT EXISTS idx_etats_avancement_global_status 
ON raw_data.sharepoint_etats_avancement(global_status);

CREATE INDEX IF NOT EXISTS idx_etats_avancement_raw_data 
ON raw_data.sharepoint_etats_avancement USING GIN(raw_data);

-- Ajouter les commentaires
COMMENT ON COLUMN raw_data.sharepoint_etats_avancement.site_id IS 'ID du sous-site SharePoint (ex: 863 pour le projet)';
COMMENT ON COLUMN raw_data.sharepoint_etats_avancement.raw_data IS 'Données brutes complètes en JSON pour flexibilité';
COMMENT ON COLUMN raw_data.sharepoint_etats_avancement.imported_at IS 'Date et heure d''import dans PostgreSQL';
