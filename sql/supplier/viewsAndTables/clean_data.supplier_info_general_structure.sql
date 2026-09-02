-- ============================================================================
-- Table supplier_info_general
-- Schema: clean_data
-- Role dans le module INVENTORY: SOURCE (lecture seule)
-- ============================================================================

CREATE TABLE IF NOT EXISTS clean_data.supplier_info_general (
    supplier_id VARCHAR(20),
    name VARCHAR(100),
    country VARCHAR(4000),
    creation_date DATE,
    created_by VARCHAR(50),
    updated_by VARCHAR(50),
    created_timestamp TIMESTAMP,
    updated_timestamp TIMESTAMP,
    is_deleted BOOLEAN,
    country_db VARCHAR(2),
    association_no VARCHAR(50),
    party VARCHAR(20),
    default_domain VARCHAR(5),
    default_language VARCHAR(100),
    default_language_db VARCHAR(2),
    party_type VARCHAR(100),
    party_type_db VARCHAR(20),
    suppliers_own_id VARCHAR(20),
    corporate_form VARCHAR(8),
    identifier_reference VARCHAR(100),
    identifier_ref_validation VARCHAR(100),
    identifier_ref_validation_db VARCHAR(20),
    picture_id NUMERIC(20,0),
    one_time VARCHAR(5),
    one_time_db VARCHAR(20),
    supplier_category VARCHAR(100),
    supplier_category_db VARCHAR(20),
    b2b_supplier VARCHAR(5),
    b2b_supplier_db VARCHAR(20),
    business_classification VARCHAR(10),
    supplier_legacy_sap_id VARCHAR(100)
);

-- Index
CREATE INDEX idx_supplier_info_general_country_db ON clean_data.supplier_info_general USING btree (country_db);
CREATE INDEX idx_supplier_info_general_name ON clean_data.supplier_info_general USING btree (name);
