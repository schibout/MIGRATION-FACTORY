-- ============================================================================
-- Table articles_vente_sap
-- Schema: raw_data
-- Role dans le module INVENTORY: SOURCE (lecture seule)
-- ============================================================================

CREATE TABLE IF NOT EXISTS raw_data.articles_vente_sap (
    article VARCHAR(18) NOT NULL,
    designation VARCHAR(255) NOT NULL
);

-- Contraintes
ALTER TABLE raw_data.articles_vente_sap ADD CONSTRAINT articles_vente_sap_pkey PRIMARY KEY (article);

-- Index
CREATE UNIQUE INDEX articles_vente_sap_pkey ON raw_data.articles_vente_sap USING btree (article);
