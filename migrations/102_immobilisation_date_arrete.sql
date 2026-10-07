-- =====================================================
-- Migration 102 : immobilisations arretees a la derniere cloture mensuelle
-- clean_data.alimenter_immobilisation() reprend desormais les mouvements et la
-- dotation de l'exercice (ANLC-ANSWL, *AFAG, *AFAV, *AFAL) au lieu des seules
-- valeurs d'ouverture ; date_arrete = fin du mois de la derniere periode
-- d'amortissement comptabilisee (ANLP). Colonne ajoutee EN FIN de table : la
-- fonction insere sans liste de colonnes.
-- A jouer AVANT sql/immobilisation/compile.sh. Idempotent.
-- =====================================================
ALTER TABLE clean_data.immobilisation ADD COLUMN IF NOT EXISTS date_arrete date;

COMMENT ON COLUMN clean_data.immobilisation.date_arrete IS
    'Date d''arrete des montants : fin du mois de la derniere periode d''amortissement comptabilisee (max ANLP-PERAF, zone 02, exercice de valorisation)';
COMMENT ON COLUMN clean_data.immobilisation.valeur_acq_fin_exercice IS 'ANLC-KANSW + ANSWL : valeur d''acquisition a la date d''arrete';
COMMENT ON COLUMN clean_data.immobilisation.amort_cumules IS '|cumul ouverture K*AFA + dotation *AFAG + part des sorties *AFAV/*AFAL + reintegrations ZUS*| a la date d''arrete (positif)';
COMMENT ON COLUMN clean_data.immobilisation.vnc IS 'valeur_acq_fin_exercice - amort_cumules, a la date d''arrete';
COMMENT ON COLUMN clean_data.immobilisation.dotation_annuelle IS '|NAFAG+SAFAG+AAFAG+MAFAG| : dotation de l''exercice comptabilisee a la date d''arrete';
