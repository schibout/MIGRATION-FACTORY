-- ============================================================================
-- clean_data.immobilisation : immobilisations SAP (tout ANLA) x zones
-- d'amortissement, avec la determination comptable FI-AA.
-- ============================================================================
-- Structure = celle de raw_data.v_immo_comptes (demande explicite du
-- 2026-10-06 : « a l'image de la vue »), memes noms et memes types.
-- Table de SNAPSHOT : rechargee integralement (TRUNCATE + INSERT) par
-- clean_data.alimenter_immobilisation(). Pas d'historique, rien a preserver :
-- le DROP est sans risque.
-- ============================================================================

DROP TABLE IF EXISTS clean_data.immobilisation;

CREATE TABLE clean_data.immobilisation (
    mandt                   varchar(20)  NOT NULL,
    bukrs                   varchar(20)  NOT NULL,  -- societe SAP
    anln1                   varchar(20)  NOT NULL,  -- numero d'immobilisation
    anln2                   varchar(20)  NOT NULL,  -- sous-numero
    designation             varchar(50),            -- anla.txt50
    classe_immo             varchar(20),            -- anla.anlkl
    ktogr_immo              varchar(20),            -- groupe de comptes de la fiche (anla.ktogr)
    ktogr_classe            varchar(20),            -- groupe de comptes de la classe (anka.ktogr)
    ecart_ktogr             boolean,                -- fiche et classe divergent
    ktogr_libelle           varchar(50),            -- t095t.ktgrtx
    plan_comptable          varchar(255),           -- t001.ktopl
    afabe                   varchar(20)  NOT NULL,  -- zone d'amortissement
    afabe_libelle           varchar(50),            -- t093t.afbtxt
    indic_comptabilisation  varchar(20),            -- t093.buhbkt
    cpt_valeur_acquisition  text,                   -- t095.ktansw
    cpt_contrepartie_acq    text,                   -- t095.ktansg
    cpt_produit_cession     text,                   -- t095.kterlw
    cpt_vnc_cession         text,                   -- t095.ktvbab
    cpt_vnc_mise_au_rebut   text,                   -- t095.ktrest
    cpt_amort_cumules       text,                   -- t095b.ktnafb
    cpt_dotation_amort      text,                   -- t095b.ktnafg
    cpt_amort_deroga_bilan  text,                   -- t095b.ktsafb
    cpt_amort_deroga_charge text,                   -- t095b.ktsafg
    cpt_amort_except_bilan  text,                   -- t095b.ktaafb
    cpt_amort_except_charge text,                   -- t095b.ktaafg
    PRIMARY KEY (mandt, bukrs, anln1, anln2, afabe)
);

COMMENT ON TABLE clean_data.immobilisation IS
    'Immobilisations SAP (tout ANLA) x zones d''amortissement + determination comptable FI-AA. Snapshot de raw_data.v_immo_comptes, recharge par clean_data.alimenter_immobilisation().';
