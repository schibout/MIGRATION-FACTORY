-- ============================================================================
-- clean_data.ifs_fournisseurs
-- ----------------------------------------------------------------------------
-- Table pivot du module fournisseurs : une ligne par fournisseur retenu pour la
-- migration vers IFS. Elle est TRUNCATE puis reconstruite integralement par
-- clean_data.alimenter_ifs_fournisseurs() (sql/supplier/01_...), a partir de :
--   * raw_data.selection_fournisseurs_stg -> source pilote (fichier metier)
--   * raw_data.lfa1 / lfb1 / lfm1         -> enrichissement SAP (LEFT JOIN)
-- Tous les scripts 02->15 du module lisent cette table.
--
-- Structure alignee sur la base reelle au 2026-09-02 (41 colonnes).
-- Les colonnes KPI historiques (derniere_date_commande, devise_principale,
-- ca_2020..ca_2025, nb_commandes_2020..2025) ont ete supprimees : le bloc qui
-- les alimentait est commente dans 01_alimenter_ifs_fournisseurs.sql.
--
-- ATTENTION : ce fichier CREE la table, il ne la remplace pas. Pour la
-- reconstruire, il faut la DROP au prealable -- ce qui perd les donnees ; la
-- table d'affectation des identifiants IFS (clean_data.ifs_fournisseur_id_map)
-- n'est en revanche jamais a purger, elle fige les numeros deja attribues.
-- ============================================================================

CREATE TABLE IF NOT EXISTS clean_data.ifs_fournisseurs (
    -- --- Cle : numero de compte SAP (LIFNR), complete a 10 caracteres --------
    numero_compte_fournisseur   VARCHAR         NOT NULL,

    -- --- Identite et adresse (fichier de selection > SAP) --------------------
    nom_1                       VARCHAR,
    rue                         VARCHAR,
    localite                    VARCHAR,
    code_postal                 VARCHAR,
    cle_pays                    VARCHAR,
    siret                       VARCHAR,
    tva                         VARCHAR,

    -- --- Donnees achats / comptabilite (SAP : lfb1, lfm1) --------------------
    societe                     TEXT,
    organisation_achats         VARCHAR,
    conditions_paiement_compta  TEXT,
    conditions_paiement_achats  VARCHAR,
    incoterms_1                 VARCHAR,
    incoterms_2                 VARCHAR,
    telephone_1                 VARCHAR,
    telephone_2                 VARCHAR,

    -- --- Horodatage -----------------------------------------------------------
    date_creation               TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    date_maj                    TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    date_creation_sap           DATE,

    -- --- Constantes IFS (parametrables via public.get_default_value) ---------
    destinataire_paiement       VARCHAR(60),
    company                     VARCHAR(10)     DEFAULT 'TRIMET',
    language_sap                VARCHAR,
    party_type                  VARCHAR         DEFAULT 'Supplier',
    party_type_db               VARCHAR         DEFAULT 'SUPPLIER',
    address_id                  VARCHAR(50),
    code_tva_ifs                VARCHAR(20),

    -- --- Colonnes reprises du fichier de selection ---------------------------
    numero_compte_ifs           VARCHAR(20),
    code_tva_sap                VARCHAR(20),
    france_etranger             VARCHAR(20),
    numero_siren                VARCHAR(20),
    complement_adresse          VARCHAR(255),
    condition_paiement_sap      VARCHAR(50),
    telephone_3                 VARCHAR(50),
    critere_recherche           VARCHAR(255),
    langue                      VARCHAR(10),
    email                       VARCHAR(255),
    iban_paiement               VARCHAR(50),
    swift_bic                   VARCHAR(20),
    nom_banque                  VARCHAR(100),
    mode_paiement               VARCHAR(50),

    -- --- Tracabilite ---------------------------------------------------------
    source                      VARCHAR(20),

    CONSTRAINT pk_ifs_fournisseurs PRIMARY KEY (numero_compte_fournisseur)
);

-- ----------------------------------------------------------------------------
-- Commentaires
-- ----------------------------------------------------------------------------
COMMENT ON TABLE clean_data.ifs_fournisseurs IS
    'Table pivot des fournisseurs a migrer vers IFS, reconstruite a chaque execution par clean_data.alimenter_ifs_fournisseurs()';

COMMENT ON COLUMN clean_data.ifs_fournisseurs.numero_compte_fournisseur IS
    'Numero de compte SAP (LIFNR) complete a 10 caracteres, cle de jointure vers raw_data.lfa1';
COMMENT ON COLUMN clean_data.ifs_fournisseurs.numero_compte_ifs IS
    'Identifiant IFS arbitre par le metier, repris tel quel du fichier de selection (600001+)';
COMMENT ON COLUMN clean_data.ifs_fournisseurs.company IS
    'Code société (TRIMET par défaut)';
COMMENT ON COLUMN clean_data.ifs_fournisseurs.source IS
    'Origine de la ligne : FICHIER (selection_fournisseurs_stg) ou SAP_NOUVEAU (cree dans SAP apres la selection)';
