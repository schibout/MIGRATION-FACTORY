-- ============================================================================
-- Table article_definitif
-- Schema: raw_data
-- Role dans le module INVENTORY: SOURCE (lecture seule)
-- ============================================================================

CREATE TABLE IF NOT EXISTS raw_data.article_definitif (
    groupe_comptable INTEGER,
    compte INTEGER,
    designation_compte VARCHAR(255),
    compte_conso INTEGER,
    libelle_compte_conso VARCHAR(255),
    article VARCHAR(50),
    designation_article VARCHAR(255),
    groupe_produit_1 VARCHAR(100),
    groupe_articles_supply_chain VARCHAR(50),
    libelle_gpe_article_supply VARCHAR(255),
    famille_de_produit VARCHAR(100),
    famille VARCHAR(100)
);
