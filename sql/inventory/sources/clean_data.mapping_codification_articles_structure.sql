-- ============================================================================
-- Table mapping_codification_articles
-- Schema: clean_data
-- Role dans le module INVENTORY: SOURCE (lecture seule)
-- ============================================================================

CREATE TABLE IF NOT EXISTS clean_data.mapping_codification_articles (
    id INTEGER NOT NULL,
    matnr VARCHAR(18) NOT NULL,
    designation_sap VARCHAR(255),
    type_article VARCHAR(10),
    groupe_article VARCHAR(10),
    categorie VARCHAR(20),
    sous_categorie VARCHAR(30),
    composant VARCHAR(20),
    teneur VARCHAR(20),
    forme VARCHAR(30),
    famille_alliage VARCHAR(20),
    dimensions VARCHAR(50),
    propriete VARCHAR(100),
    codification_ifs VARCHAR(50),
    codification_manuelle BOOLEAN,
    date_creation TIMESTAMP,
    date_modification TIMESTAMP,
    modifie_par VARCHAR(50),
    commentaire TEXT
);

-- Contraintes
ALTER TABLE clean_data.mapping_codification_articles ADD CONSTRAINT mapping_codification_articles_matnr_key UNIQUE (matnr);
ALTER TABLE clean_data.mapping_codification_articles ADD CONSTRAINT mapping_codification_articles_pkey PRIMARY KEY (id);

-- Index
CREATE INDEX idx_mapping_codif_categorie ON clean_data.mapping_codification_articles USING btree (categorie);
CREATE INDEX idx_mapping_codif_ifs ON clean_data.mapping_codification_articles USING btree (codification_ifs);
CREATE INDEX idx_mapping_codif_type ON clean_data.mapping_codification_articles USING btree (type_article);
CREATE UNIQUE INDEX mapping_codification_articles_matnr_key ON clean_data.mapping_codification_articles USING btree (matnr);
CREATE UNIQUE INDEX mapping_codification_articles_pkey ON clean_data.mapping_codification_articles USING btree (id);
