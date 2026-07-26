CREATE TABLE clean_data.supplier_address (
    -- Clés primaires (correspondant aux colonnes Excel avec flag P et K)
    supplier_id VARCHAR(20) NOT NULL,
    address_id VARCHAR(50) NOT NULL,
    -- Informations de base
    name VARCHAR(100),
    address VARCHAR(2000),
    ean_location VARCHAR(100),
    -- Dates de validité
    valid_from DATE,
    valid_to DATE,
    -- Informations partie
    party VARCHAR(20),
    default_domain VARCHAR(5),
    -- Informations pays
    country VARCHAR(4000),
    country_db VARCHAR(2),
    -- Type de partie
    party_type VARCHAR(4000),
    party_type_db VARCHAR(20),
    -- Adresse structurée (lignes 1 à 6)
    address1 VARCHAR(35),
    address2 VARCHAR(35),
    address3 VARCHAR(100),
    address4 VARCHAR(100),
    address5 VARCHAR(100),
    address6 VARCHAR(100),
    -- Informations géographiques détaillées
    zip_code VARCHAR(35),
    city VARCHAR(35),
    county VARCHAR(35),
    state VARCHAR(35),
    -- Communication
    comm_id NUMERIC(20),
    output_media VARCHAR(4000),
    output_media_db VARCHAR(20),
    -- Informations fournisseur
    supplier_branch VARCHAR(20),
    -- Champs de métadonnées (gestion application)
    created_timestamp TIMESTAMP DEFAULT NOW(),
    updated_timestamp TIMESTAMP DEFAULT NOW(),
    created_by VARCHAR(50) DEFAULT 'system',
    updated_by VARCHAR(50),
    is_deleted BOOLEAN DEFAULT FALSE,
    -- Contraintes
    PRIMARY KEY (supplier_id, address_id)
);