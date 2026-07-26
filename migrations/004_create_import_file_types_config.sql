-- Migration: Création de la table import_file_types_config
-- Date: 2024-12-19
-- Description: Table de configuration dynamique pour les types de fichiers d'import

-- Création de la table principale
CREATE TABLE IF NOT EXISTS import_file_types_config (
    id SERIAL PRIMARY KEY,
    type_code VARCHAR(50) UNIQUE NOT NULL,  -- 'customer_info', 'customer_address', etc.
    display_name VARCHAR(100) NOT NULL,     -- "Informations Client"
    description TEXT,                       -- Description pour l'utilisateur
    category VARCHAR(50) DEFAULT 'customer', -- 'customer', 'product', 'order'
    
    -- Configuration fichier
    max_file_size_mb INTEGER DEFAULT 50,
    allowed_extensions TEXT[] DEFAULT ARRAY['csv', 'xlsx', 'xls'],
    
    -- Configuration colonnes
    required_columns JSONB NOT NULL,        -- ["client_id", "name", "email"]
    optional_columns JSONB DEFAULT '[]',    -- ["phone", "company"]
    column_mappings JSONB DEFAULT '{}',     -- {"nom": "name", "email": "email"}
    
    -- Configuration validation
    validation_rules JSONB DEFAULT '{}',    -- {"email": "email_format", "client_id": "unique"}
    
    -- Configuration traitement
    target_table VARCHAR(100),              -- "clean_data.customer_info"
    processor_class VARCHAR(100),           -- "CustomerInfoProcessor"
    
    -- Métadonnées
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER REFERENCES users(id),
    
    -- Template et aide
    template_url VARCHAR(255),              -- URL vers template CSV
    help_text TEXT,                         -- Aide contextuelle
    icon VARCHAR(50) DEFAULT 'description'  -- Icône Material-UI
);

-- Index pour performance
CREATE INDEX idx_import_file_types_category ON import_file_types_config(category);
CREATE INDEX idx_import_file_types_active ON import_file_types_config(is_active);

-- Fonction pour mise à jour automatique du timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger pour mise à jour automatique
CREATE TRIGGER update_import_file_types_config_updated_at 
    BEFORE UPDATE ON import_file_types_config 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insertion des configurations pour les 6 types clients
INSERT INTO import_file_types_config 
(type_code, display_name, description, required_columns, optional_columns, validation_rules, target_table, processor_class, icon) 
VALUES
-- Type 1: Informations client de base
('customer_info', 'Informations Client', 'Données principales du client', 
 '["client_id", "name", "email"]', '["phone", "company"]', 
 '{"email": "email_format", "client_id": "unique"}', 
 'clean_data.customer_info', 'CustomerInfoProcessor', 'person'),

-- Type 2: Adresses client  
('customer_info_address', 'Adresses Client', 'Adresses de facturation et livraison',
 '["client_id", "address_line1", "city", "postal_code"]', '["address_line2", "country"]',
 '{"postal_code": "postal_format", "client_id": "exists_in_customers"}',
 'clean_data.customer_addresses', 'CustomerAddressProcessor', 'location_on'),

-- Type 3: Types d'adresses
('customer_info_address_type', 'Types Adresses', 'Classification des adresses',
 '["client_id", "address_id", "address_type"]', '["is_default", "priority"]',
 '{"address_type": "enum:billing,shipping,both"}',
 'clean_data.customer_address_types', 'CustomerAddressTypeProcessor', 'category'),

-- Type 4: Informations fiscales
('customer_info_tax', 'Informations Fiscales', 'TVA, SIRET, codes fiscaux',
 '["client_id", "tax_number"]', '["vat_rate", "tax_exemption", "siret"]',
 '{"tax_number": "tax_format", "vat_rate": "numeric_range:0,100"}',
 'clean_data.customer_tax_info', 'CustomerTaxProcessor', 'receipt'),

-- Type 5: Fiscalité livraison  
('customer_delivery_tax_info', 'Fiscalité Livraison', 'Règles fiscales par zone',
 '["client_id", "delivery_zone", "tax_rate"]', '["tax_exemption", "special_rules"]',
 '{"tax_rate": "numeric_range:0,100"}',
 'clean_data.customer_delivery_tax', 'CustomerDeliveryTaxProcessor', 'local_shipping'),

-- Type 6: Informations commerciales
('customer_commercial_info', 'Infos Commerciales', 'Conditions et remises',
 '["client_id", "commercial_id"]', '["discount_rate", "payment_terms", "credit_limit"]',
 '{"discount_rate": "numeric_range:0,100", "credit_limit": "positive_number"}',
 'clean_data.customer_commercial', 'CustomerCommercialProcessor', 'business');

-- Commentaires pour documentation
COMMENT ON TABLE import_file_types_config IS 'Configuration dynamique des types de fichiers d''import';
COMMENT ON COLUMN import_file_types_config.type_code IS 'Code unique du type de fichier';
COMMENT ON COLUMN import_file_types_config.required_columns IS 'Colonnes obligatoires au format JSON array';
COMMENT ON COLUMN import_file_types_config.validation_rules IS 'Règles de validation au format JSON object';
COMMENT ON COLUMN import_file_types_config.processor_class IS 'Nom de la classe processeur Python à utiliser'; 