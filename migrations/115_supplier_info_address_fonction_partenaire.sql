-- Migration 115 : adresses partenaires des fournisseurs (2026-10-09)
--
-- supplier_info_address ne portait que l'adresse propre du fournisseur
-- (lfa1.adrnr). Elle recoit desormais aussi les adresses de ses partenaires
-- SAP (raw_data.wyt3 -> lfa1 du partenaire -> adrc) :
--   RS auteur de la facture -> types INVOICE + PAY
--   BA adresse de commande  -> INVOICE
--   VA adresse contrat      -> VISIT
--   SP transporteur         -> DELIVERY
-- fonction_partenaire = code PARVW SAP ; NULL = adresse propre du fournisseur
-- (adresse principale, seule a porter les 4 types et def_address = TRUE).
-- Colonne hors export IFS (column_list explicite dans etl_export_queries).

ALTER TABLE clean_data.supplier_info_address
    ADD COLUMN IF NOT EXISTS fonction_partenaire varchar(2);

COMMENT ON COLUMN clean_data.supplier_info_address.fonction_partenaire IS
    'Fonction partenaire SAP (wyt3.parvw : RS, BA, VA, SP) ; NULL = adresse propre du fournisseur';
