-- =====================================================
-- Script de création de la table client_adresse_phl
-- Schéma: raw_data
-- Date: 2025-12-08
-- =====================================================

CREATE SCHEMA IF NOT EXISTS raw_data;

DROP TABLE IF EXISTS raw_data.client_adresse_phl CASCADE;

CREATE TABLE raw_data.client_adresse_phl (
    id SERIAL PRIMARY KEY,
    customer_id VARCHAR(50),
    address_id VARCHAR(50),
    name VARCHAR(255),
    address TEXT,
    ean_location VARCHAR(100),
    party VARCHAR(100),
    address_lov TEXT,
    default_domain VARCHAR(50),
    country VARCHAR(100),
    country_db VARCHAR(10),
    party_type VARCHAR(100),
    party_type_db VARCHAR(50),
    secondary_contact VARCHAR(255),
    primary_contact VARCHAR(255),
    address1 VARCHAR(255),
    address2 VARCHAR(255),
    address3 VARCHAR(255),
    address4 VARCHAR(255),
    address5 VARCHAR(255),
    address6 VARCHAR(255),
    city VARCHAR(100),
    county VARCHAR(100),
    state VARCHAR(100),
    jurisdiction_code VARCHAR(50),
    comm_id VARCHAR(50),
    output_media VARCHAR(50),
    output_media_db VARCHAR(50),
    end_customer_id VARCHAR(50),
    customer_branch VARCHAR(50),
    end_cust_addr_id VARCHAR(50),
    zip_code VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Création des index
CREATE INDEX idx_client_adresse_phl_customer_id ON raw_data.client_adresse_phl(customer_id);
CREATE INDEX idx_client_adresse_phl_address_id ON raw_data.client_adresse_phl(address_id);
CREATE INDEX idx_client_adresse_phl_customer_address ON raw_data.client_adresse_phl(customer_id, address_id);
CREATE INDEX idx_client_adresse_phl_city ON raw_data.client_adresse_phl(city);
CREATE INDEX idx_client_adresse_phl_country ON raw_data.client_adresse_phl(country);
CREATE INDEX idx_client_adresse_phl_zip_code ON raw_data.client_adresse_phl(zip_code);

-- Commentaires
COMMENT ON TABLE raw_data.client_adresse_phl IS 'Table des adresses clients - 670 lignes';
COMMENT ON COLUMN raw_data.client_adresse_phl.customer_id IS 'Identifiant du client';
COMMENT ON COLUMN raw_data.client_adresse_phl.address_id IS 'Identifiant de l''adresse';
COMMENT ON COLUMN raw_data.client_adresse_phl.name IS 'Nom du client';
COMMENT ON COLUMN raw_data.client_adresse_phl.address IS 'Adresse complète';
COMMENT ON COLUMN raw_data.client_adresse_phl.city IS 'Ville';
COMMENT ON COLUMN raw_data.client_adresse_phl.zip_code IS 'Code postal';

SELECT 'Table client_adresse_phl créée avec succès!' as status;