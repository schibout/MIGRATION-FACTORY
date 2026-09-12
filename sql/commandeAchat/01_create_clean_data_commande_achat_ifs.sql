-- ============================================================================
-- clean_data.commande_achat_ifs : commandes d'achat SAP ouvertes, format de
-- reprise IFS (une ligne par poste de commande EKPO avec reliquat a livrer).
-- ============================================================================
-- Table de SNAPSHOT : rechargee integralement (TRUNCATE + INSERT) a chaque
-- appel de clean_data.alimenter_commande_achat_ifs(). Pas d'historique.
--
-- DROP + CREATE : la table est un snapshot sans donnee a preserver, et la
-- version creee a la main le 11/09/2026 (CTAS en-tete seule) portait des noms
-- de colonnes en MAJUSCULES entre guillemets ("Site", "SOCIETE_SAP"...) que le
-- service d'export ne sait pas lire (il normalise les noms en minuscules :
-- toutes les colonnes seraient sorties a NULL). Noms en minuscules comme
-- toutes les tables clean_data. Par rapport a la CTAS :
--   - fournisseur_ifs / fournisseur_facturation_ifs en varchar(20), type
--     renvoye par public.get_vendor_no_ifs() (etaient integer) ;
--   - ajout de num_ligne_sap (ebelp) : sans elle une commande a plusieurs
--     postes n'a aucun identifiant de ligne dans le fichier.
-- ============================================================================

DROP TABLE IF EXISTS clean_data.commande_achat_ifs;

CREATE TABLE clean_data.commande_achat_ifs (
    site                        varchar(10),  -- SJ / CS, deduit de la division (werks 9200 / 9000)
    societe_sap                 varchar(4),   -- ekko.bukrs
    num_commande_sap            varchar(10),  -- ekko.ebeln
    num_ligne_sap               varchar(5),   -- ekpo.ebelp (NULL en repli en-tete)
    fournisseur_sap             varchar(10),  -- ekko.lifnr
    fournisseur_ifs             varchar(20),  -- get_vendor_no_ifs(lifnr), NULL si absent du fichier
    nom_fournisseur             varchar(35),  -- lfa1.name1
    fournisseur_facturation_sap varchar(10),  -- ekpa RS/PI, sinon lifnr
    fournisseur_facturation_ifs varchar(20),
    type_ligne_ifs              text,         -- PART / NOPART
    article_sap                 text,         -- ekpo.matnr
    designation                 text,         -- ekpo.txz01
    qte_commandee               numeric,
    qte_restant_livrer          numeric,
    qte_restant_facturer        numeric,
    unite_achat                 text,         -- transco UOM, '*' si non transcodee
    prix_net_unitaire           numeric,
    montant_restant_livrer      numeric,
    montant_restant_facturer    numeric,
    devise                      varchar(5),
    taux_change                 varchar(12),
    date_creation               text,         -- DD/MM/YYYY
    date_livraison_planifiee    text,
    date_reception_souhaitee    text,
    date_livraison_promise      text,
    acheteur_sap                varchar(3),   -- ekko.ekgrp brut (pas de transcodification)
    condition_paiement          varchar(4),
    condition_livraison         text,         -- inco1 + inco2
    mode_expedition             text,
    adresse_livraison           text,
    code_postal_livraison       text,
    ville_livraison             text,
    pays_livraison              text,
    pre_imputation_projet       text          -- PROJET= / CENTRE_COUT= / ORDRE= / COMPTE=
);

CREATE INDEX idx_commande_achat_ifs_ebeln
    ON clean_data.commande_achat_ifs (num_commande_sap, num_ligne_sap);

COMMENT ON TABLE clean_data.commande_achat_ifs IS
    'Commandes d''achat SAP ouvertes (reliquat a livrer > 0) au format de reprise IFS. Snapshot recharge par clean_data.alimenter_commande_achat_ifs() (module ETL etl_commande_achat.py).';
