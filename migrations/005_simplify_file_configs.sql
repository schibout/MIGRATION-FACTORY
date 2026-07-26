-- ===============================================
-- Migration 005: Simplification de la configuration des imports
-- Date: 2025-01-18
-- Description: Simplification pour import brut des données
-- ===============================================

-- 1. Création du schéma raw_data s'il n'existe pas
CREATE SCHEMA IF NOT EXISTS raw_data;

-- 2. Création de la table pour les données brutes des clients
CREATE TABLE IF NOT EXISTS raw_data.customer_info (
    id SERIAL PRIMARY KEY,
    mnemonique VARCHAR(50),
    customer_id VARCHAR(50),
    name VARCHAR(200),
    date_creation DATE,
    customer_asso VARCHAR(100),
    customer_party VARCHAR(50),
    customer_domaine VARCHAR(20),
    customer_langue VARCHAR(20),
    customer_id_langue VARCHAR(10),
    customer_pays VARCHAR(100),
    customer_id_pays VARCHAR(10),
    customer_id_party VARCHAR(50),
    customer_corporate VARCHAR(100),
    customer_id_ref VARCHAR(100),
    customer_ref_valid VARCHAR(50),
    customer_ref_id_valid VARCHAR(50),
    customer_picture VARCHAR(200),
    customer_one_time VARCHAR(20),
    customer_one_time_db VARCHAR(20),
    customer_categorie VARCHAR(50),
    customer_id_categorie VARCHAR(50),
    customer_btob VARCHAR(20),
    customer_btob_id VARCHAR(20),
    customer_taxe_type VARCHAR(100),
    customer_business VARCHAR(200),
    customer_date_reg DATE,
    -- Colonnes techniques pour traçabilité
    import_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    import_file_name VARCHAR(255),
    import_batch_id VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Ajout des index pour performance
CREATE INDEX IF NOT EXISTS idx_customer_info_customer_id ON raw_data.customer_info(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_info_import_batch ON raw_data.customer_info(import_batch_id);
CREATE INDEX IF NOT EXISTS idx_customer_info_import_date ON raw_data.customer_info(import_date);

-- 4. Modification de la table file_type_configs pour la simplifier
-- Sauvegarde des données existantes si nécessaire
CREATE TABLE IF NOT EXISTS file_type_configs_backup AS 
SELECT * FROM file_type_configs;

-- Suppression des colonnes complexes et ajout des nouvelles colonnes simples
ALTER TABLE file_type_configs 
DROP COLUMN IF EXISTS required_columns,
DROP COLUMN IF EXISTS optional_columns,
DROP COLUMN IF EXISTS column_mappings,
DROP COLUMN IF EXISTS validation_rules,
DROP COLUMN IF EXISTS transformation_rules;

-- Ajout des nouvelles colonnes pour configuration simple
ALTER TABLE file_type_configs 
ADD COLUMN IF NOT EXISTS separator CHAR(1) DEFAULT ';',
ADD COLUMN IF NOT EXISTS encoding VARCHAR(20) DEFAULT 'utf-8',
ADD COLUMN IF NOT EXISTS has_header BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS skip_rows INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS processor_class VARCHAR(100) DEFAULT 'RawDataProcessor';

-- 5. Mise à jour de la configuration pour customer_info
INSERT INTO file_type_configs (
    file_type, 
    display_name, 
    description, 
    target_table, 
    target_schema,
    separator,
    encoding,
    has_header,
    skip_rows,
    processor_class,
    is_active
) VALUES (
    'customer_info', 
    'Customer Info (Raw Data)', 
    'Import brut des données clients vers raw_data.customer_info', 
    'customer_info',
    'raw_data',
    ';', 
    'utf-8', 
    true,
    0,
    'RawDataProcessor',
    true
) ON CONFLICT (file_type) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    target_table = EXCLUDED.target_table,
    target_schema = EXCLUDED.target_schema,
    separator = EXCLUDED.separator,
    encoding = EXCLUDED.encoding,
    has_header = EXCLUDED.has_header,
    skip_rows = EXCLUDED.skip_rows,
    processor_class = EXCLUDED.processor_class,
    updated_at = CURRENT_TIMESTAMP;

-- 6. Création de commentaires pour documentation
COMMENT ON TABLE raw_data.customer_info IS 'Table de stockage brut des données clients importées depuis les fichiers CSV';
COMMENT ON COLUMN raw_data.customer_info.import_batch_id IS 'Identifiant du lot d''import pour traçabilité';
COMMENT ON COLUMN raw_data.customer_info.import_file_name IS 'Nom du fichier source de l''import';

-- 7. Permissions (ajuster selon vos besoins)
-- GRANT SELECT, INSERT, UPDATE ON raw_data.customer_info TO import_user;
-- GRANT USAGE ON SCHEMA raw_data TO import_user;

COMMIT; 