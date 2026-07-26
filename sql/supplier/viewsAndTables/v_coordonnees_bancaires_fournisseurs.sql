-- Coordonnées bancaires fournisseurs (LFBK + LFA1 + BNKA)
-- Piloté par LFBK pour ne pas perdre les lignes bancaires si LFA1/BNKA est partiel.
-- À exécuter sur la base PostgreSQL (schéma clean_data).
--
-- PostgreSQL refuse CREATE OR REPLACE VIEW si on retire ou réordonne des colonnes (42P16).
-- Drop explicite avant recréation.

DROP VIEW IF EXISTS clean_data.v_coordonnees_bancaires_fournisseurs CASCADE;

-- k.* : toutes les colonnes SAP LFBK ; champs LFA1 / BNKA en complément (noms sans collision avec k).
CREATE VIEW clean_data.v_coordonnees_bancaires_fournisseurs AS
SELECT
    k.*,
    COALESCE(a.name1, ''::character varying) AS "Nom 1 fournisseur",
    COALESCE(a.name2, ''::character varying) AS "Nom 2 fournisseur",
    COALESCE(a.loevm, ''::character varying) AS "Fournisseur supprimé (centr.)",
    COALESCE(b.banka, ''::character varying) AS "Nom banque",
    COALESCE(b.swift, ''::character varying) AS "SWIFT/BIC",
    COALESCE(b.stras, ''::character varying) AS "Rue banque",
    COALESCE(b.ort01, ''::character varying) AS "Localité banque",
    COALESCE(b.provz, ''::character varying) AS "Région banque"
FROM raw_data.lfbk k
LEFT JOIN raw_data.lfa1 a
    ON a.mandt::text = k.mandt::text AND a.lifnr::text = k.lifnr::text
LEFT JOIN raw_data.bnka b
    ON b.banks::text = k.banks::text AND b.bankl::text = k.bankl::text;
