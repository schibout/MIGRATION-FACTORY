-- ============================================================================
-- clean_data.historique_cout_projet : historique des couts par projet SAP
-- (reconstitution de l'etat ZCOA sur raw_data.rpsco, cf.
-- docs/zcoa_credits_investissement_raw_data.sql, requete 3).
-- Une ligne par projet / element d'OTP / annee / periode. Table de SNAPSHOT :
-- TRUNCATE + INSERT par clean_data.alimenter_historique_cout_projet().
-- Societe STJN, ledger RPSCO 0003, version 000, montants en EUR (devise societe).
-- ============================================================================
CREATE TABLE IF NOT EXISTS clean_data.historique_cout_projet (
    projet          varchar(24) NOT NULL,  -- proj.pspid
    projet_libelle  text,                  -- proj.post1
    responsable     text,                  -- proj.verna
    element_otp     varchar(24) NOT NULL,  -- prps.posid
    otp_libelle     text,                  -- prps.post1
    annee           integer     NOT NULL,  -- rpsco.gjahr
    periode         integer     NOT NULL,  -- 0..16 (0 = budget annuel, 13-16 periodes speciales)
    reel            numeric(17,2) NOT NULL DEFAULT 0,  -- WRTTP 04 hors VORGA KOAO
    plan            numeric(17,2) NOT NULL DEFAULT 0,  -- WRTTP 01
    budget_annuel   numeric(17,2) NOT NULL DEFAULT 0,  -- WRTTP 41 (annee <> 0000)
    engag_cde       numeric(17,2) NOT NULL DEFAULT 0,  -- WRTTP 22 commandes non receptionnees
    engag_da        numeric(17,2) NOT NULL DEFAULT 0,  -- WRTTP 21 demandes d'achat
    charge_at       timestamp   NOT NULL DEFAULT current_timestamp,
    PRIMARY KEY (projet, element_otp, annee, periode)
);

-- N° projet SharePoint (= project_id IFS) de l'element d'OTP, meme regle que
-- clean_data.commande_achat_ifs.numero_projet (ajout du 2026-10-26).
ALTER TABLE clean_data.historique_cout_projet ADD COLUMN IF NOT EXISTS numero_projet text;
