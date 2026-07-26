-- ============================================================================
-- Table de sélection des fournisseurs à exporter
-- Liste définitive des fournisseurs retenus pour la migration
-- ============================================================================

CREATE TABLE IF NOT EXISTS raw_data.selection_fournisseurs (
    numero_compte_sap VARCHAR(10) NOT NULL,
    numero_compte_ifs INTEGER,
    code_tva_sap VARCHAR(20),
    code_tva_ifs VARCHAR(20),
    numero_tva_intra VARCHAR(50),
    france_etranger VARCHAR(20),
    numero_siret VARCHAR(50),
    numero_siren BIGINT,
    denomination_sociale VARCHAR(255),
    numero_voie VARCHAR(20),
    indice_numero_voie VARCHAR(20),
    type_voie VARCHAR(50),
    libelle_voie VARCHAR(255),
    libelle_concatene VARCHAR(255),
    complement_adresse VARCHAR(255),
    localite VARCHAR(100),
    code_postal VARCHAR(20),
    code_pays VARCHAR(10),
    condition_paiement_sap VARCHAR(50),
    condition_paiement_ifs VARCHAR(50),
    telephone_1 VARCHAR(50),
    telephone_2 VARCHAR(50),
    telephone_3 VARCHAR(50),
    critere_recherche VARCHAR(255),
    langue VARCHAR(10),
    email VARCHAR(255),
    iban_paiement VARCHAR(50),
    swift_bic VARCHAR(20),
    nom_banque VARCHAR(100),
    mode_paiement VARCHAR(50),
    date_import TIMESTAMP,
    date_modification TIMESTAMP,
    utilisateur_modification VARCHAR(100),
    statut_validation VARCHAR(20)
);

-- Index sur numero_compte_sap pour améliorer les performances des jointures
CREATE INDEX IF NOT EXISTS idx_selection_fournisseurs_numero_compte_sap ON raw_data.selection_fournisseurs(numero_compte_sap);

COMMENT ON TABLE raw_data.selection_fournisseurs IS 'Liste définitive des fournisseurs sélectionnés pour la migration vers IFS';
