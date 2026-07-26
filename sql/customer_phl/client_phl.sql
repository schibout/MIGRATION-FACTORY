-- =====================================================
-- Script de création de la table client_phl
-- Schéma: raw_data
-- Généré automatiquement à partir du fichier clientPhl.csv
-- Date: 2025-12-08
-- =====================================================

-- Création du schéma s'il n'existe pas
CREATE SCHEMA IF NOT EXISTS raw_data;

-- Suppression de la table si elle existe
DROP TABLE IF EXISTS raw_data.client_phl CASCADE;

-- Création de la table principale
CREATE TABLE raw_data.client_phl (
    id SERIAL PRIMARY KEY,
    customer_id VARCHAR(50),
    numero_sap VARCHAR(50),
    name VARCHAR(255),
    creation_date DATE,
    association_no VARCHAR(100),
    party VARCHAR(100),
    default_domain VARCHAR(100),
    default_language VARCHAR(50),
    default_language_db VARCHAR(50),
    country VARCHAR(100),
    country_db VARCHAR(50),
    party_type VARCHAR(100),
    party_type_db VARCHAR(50),
    corporate_form VARCHAR(100),
    identifier_reference VARCHAR(100),
    identifier_ref_validation VARCHAR(100),
    identifier_ref_validation_db VARCHAR(50),
    picture_id VARCHAR(100),
    one_time VARCHAR(50),
    one_time_db VARCHAR(50),
    customer_category VARCHAR(100),
    customer_category_db VARCHAR(50),
    b2b_customer VARCHAR(50),
    b2b_customer_db VARCHAR(50),
    customer_tax_usage_type VARCHAR(100),
    business_classification VARCHAR(100),
    date_of_registration DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Création des index pour améliorer les performances
CREATE INDEX idx_client_phl_customer_id ON raw_data.client_phl(customer_id);
CREATE INDEX idx_client_phl_numero_sap ON raw_data.client_phl(numero_sap);
CREATE INDEX idx_client_phl_name ON raw_data.client_phl(name);
CREATE INDEX idx_client_phl_creation_date ON raw_data.client_phl(creation_date);
CREATE INDEX idx_client_phl_country ON raw_data.client_phl(country);

-- Ajout de commentaires sur la table et colonnes principales
COMMENT ON TABLE raw_data.client_phl IS 'Table des clients importée depuis clientPhl.csv - Contient les informations des clients avec leurs identifiants SAP';
COMMENT ON COLUMN raw_data.client_phl.id IS 'Clé primaire auto-incrémentée';
COMMENT ON COLUMN raw_data.client_phl.customer_id IS 'Identifiant unique du client';
COMMENT ON COLUMN raw_data.client_phl.numero_sap IS 'Numéro SAP du client (format S0000000)';
COMMENT ON COLUMN raw_data.client_phl.name IS 'Nom complet du client';
COMMENT ON COLUMN raw_data.client_phl.creation_date IS 'Date de création du client';
COMMENT ON COLUMN raw_data.client_phl.created_at IS 'Date et heure de création de l''enregistrement';
COMMENT ON COLUMN raw_data.client_phl.updated_at IS 'Date et heure de dernière modification';

-- Affichage de confirmation
SELECT 'Table raw_data.client_phl créée avec succès!' AS status;