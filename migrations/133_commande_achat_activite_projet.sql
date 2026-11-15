-- Commandes d'achat : activite d'imputation projet sur les lignes, regle de la reprise
-- des couts projet : abreviation <ID projet IFS>.20.REP (CAPEX) / .30.REP (OPEX),
-- sous-projet 20 / 30, n° d'activite REP. Colonnes hors modele IFS, exclues des CSV
-- de reprise. ACTIVITY_SEQ existe deja. Rejouable.
ALTER TABLE clean_data.purchase_order_line_part
    ADD COLUMN IF NOT EXISTS abreviation_activite text,
    ADD COLUMN IF NOT EXISTS sub_project_id varchar(10),
    ADD COLUMN IF NOT EXISTS activity_no varchar(10);
ALTER TABLE clean_data.purchase_order_line_nopart
    ADD COLUMN IF NOT EXISTS abreviation_activite text,
    ADD COLUMN IF NOT EXISTS sub_project_id varchar(10),
    ADD COLUMN IF NOT EXISTS activity_no varchar(10);
