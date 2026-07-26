-- =====================================================
-- PHL RAW DATA SCHEMA
-- =====================================================

CREATE SCHEMA IF NOT EXISTS raw_data;

-- =====================================================
-- 1. CLIENT PHL
-- =====================================================

CREATE TABLE IF NOT EXISTS raw_data.client_phl (
    customer_id                    VARCHAR(50),
    sap_number                     VARCHAR(20),
    name                           VARCHAR(255),
    creation_date                  DATE,
    association_no                 VARCHAR(50),
    party                          VARCHAR(50),
    default_domain                 VARCHAR(10),
    default_language               VARCHAR(10),
    default_language_db            VARCHAR(10),
    country                        VARCHAR(100),
    country_db                     VARCHAR(5),
    date_of_registration           DATE
);

-- =====================================================
-- 2. TAX CLIENT
-- =====================================================

CREATE TABLE IF NOT EXISTS raw_data.tax_client (
    customer_id        VARCHAR(50),
    address_id         VARCHAR(20),
    company            VARCHAR(50),
    supply_country     VARCHAR(5),
    fee_code           VARCHAR(10),
    tax_id_number      VARCHAR(50),
    tax_code_selection VARCHAR(50)
);

-- =====================================================
-- 3. TAX EXEMPT
-- =====================================================

CREATE TABLE IF NOT EXISTS raw_data.tax_exempt (
    customer_id            VARCHAR(50),
    address_id             VARCHAR(20),
    company                VARCHAR(50),
    supply_country         VARCHAR(100),
    supply_country_db      VARCHAR(5),
    tax_liability          VARCHAR(20),
    tax_book_id            VARCHAR(50),
    tax_book_type          VARCHAR(50),
    tax_structure_id       VARCHAR(50),
    cus_country_code       VARCHAR(5),
    tax_calc_structure_id  VARCHAR(50)
);

-- =====================================================
-- 4. CLIENT ADDRESS
-- =====================================================

CREATE TABLE IF NOT EXISTS raw_data.client_address (
    mnemo         VARCHAR(50),
    id_client     VARCHAR(20),
    nom           VARCHAR(255),
    adresse       VARCHAR(255),
    adresse_suite VARCHAR(255),
    code_postal   VARCHAR(20),
    ville         VARCHAR(150),
    pays          VARCHAR(100),
    id_ville      VARCHAR(10),
    siren         VARCHAR(20),
    siret         VARCHAR(20),
    tva           VARCHAR(30)
);