-- Table supplier_info_address
-- Structure conforme aux spécifications IFS pour les adresses de fournisseurs

CREATE TABLE IF NOT EXISTS clean_data.supplier_info_address (
    -- Clés primaires
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
    
    -- Contraintes
    PRIMARY KEY (supplier_id, address_id)
);

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_supplier_info_address_supplier_id 
    ON clean_data.supplier_info_address(supplier_id);

CREATE INDEX IF NOT EXISTS idx_supplier_info_address_country_db 
    ON clean_data.supplier_info_address(country_db);

CREATE INDEX IF NOT EXISTS idx_supplier_info_address_party_type_db 
    ON clean_data.supplier_info_address(party_type_db);

-- Commentaires sur la table et les colonnes
COMMENT ON TABLE clean_data.supplier_info_address IS 'Adresses des fournisseurs selon les spécifications IFS';
COMMENT ON COLUMN clean_data.supplier_info_address.supplier_id IS 'ID du fournisseur (clé primaire)';
COMMENT ON COLUMN clean_data.supplier_info_address.address_id IS 'ID de l''adresse (clé primaire)';
COMMENT ON COLUMN clean_data.supplier_info_address.name IS 'Nom de la société';
COMMENT ON COLUMN clean_data.supplier_info_address.address IS 'Adresse complète formatée';
COMMENT ON COLUMN clean_data.supplier_info_address.ean_location IS 'Code EAN ou secteur industriel';
COMMENT ON COLUMN clean_data.supplier_info_address.valid_from IS 'Date de début de validité';
COMMENT ON COLUMN clean_data.supplier_info_address.valid_to IS 'Date de fin de validité';
COMMENT ON COLUMN clean_data.supplier_info_address.party IS 'Partie liée';
COMMENT ON COLUMN clean_data.supplier_info_address.default_domain IS 'Domaine par défaut';
COMMENT ON COLUMN clean_data.supplier_info_address.country IS 'Pays (format long)';
COMMENT ON COLUMN clean_data.supplier_info_address.country_db IS 'Code pays (2 caractères)';
COMMENT ON COLUMN clean_data.supplier_info_address.party_type IS 'Type de partie (format long)';
COMMENT ON COLUMN clean_data.supplier_info_address.party_type_db IS 'Type de partie (code DB)';
COMMENT ON COLUMN clean_data.supplier_info_address.address1 IS 'Ligne d''adresse 1';
COMMENT ON COLUMN clean_data.supplier_info_address.address2 IS 'Ligne d''adresse 2';
COMMENT ON COLUMN clean_data.supplier_info_address.address3 IS 'Ligne d''adresse 3';
COMMENT ON COLUMN clean_data.supplier_info_address.address4 IS 'Ligne d''adresse 4';
COMMENT ON COLUMN clean_data.supplier_info_address.address5 IS 'Ligne d''adresse 5';
COMMENT ON COLUMN clean_data.supplier_info_address.address6 IS 'Ligne d''adresse 6';
COMMENT ON COLUMN clean_data.supplier_info_address.zip_code IS 'Code postal';
COMMENT ON COLUMN clean_data.supplier_info_address.city IS 'Ville';
COMMENT ON COLUMN clean_data.supplier_info_address.county IS 'Département';
COMMENT ON COLUMN clean_data.supplier_info_address.state IS 'État/Région';
COMMENT ON COLUMN clean_data.supplier_info_address.comm_id IS 'ID de communication';
COMMENT ON COLUMN clean_data.supplier_info_address.output_media IS 'Média de sortie (format long)';
COMMENT ON COLUMN clean_data.supplier_info_address.output_media_db IS 'Média de sortie (code DB)';
COMMENT ON COLUMN clean_data.supplier_info_address.supplier_branch IS 'Branche fournisseur';
