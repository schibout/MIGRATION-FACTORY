-- ============================================================================
-- 128 - pe_tools : toutes les colonnes du modele de classeur PE Tools
-- ----------------------------------------------------------------------------
-- Les 8 classeurs « PeTool - 7.<CODE>.xlsm » (11/2026) partagent un modele de
-- 32 colonnes ; 7 n'avaient pas d'equivalent et etaient ignorees a l'import.
-- « Module d'entretien » n'existe que dans 7.MSGX. Les 24 colonnes de suivi
-- propres a 7.MFIE restent ignorees. Texte brut, comme les autres colonnes
-- du fichier. Idempotente. Redemarrer le backend apres (./deploybackend.sh).
-- ============================================================================
BEGIN;

ALTER TABLE raw_data.pe_tools
    ADD COLUMN IF NOT EXISTS poste_responsable     TEXT,
    ADD COLUMN IF NOT EXISTS test_de_donnees       TEXT,
    ADD COLUMN IF NOT EXISTS statut_doc            TEXT,
    ADD COLUMN IF NOT EXISTS module_entretien      TEXT,
    ADD COLUMN IF NOT EXISTS lien_document         TEXT,
    ADD COLUMN IF NOT EXISTS validation            TEXT,
    ADD COLUMN IF NOT EXISTS modele_gamme          TEXT,
    ADD COLUMN IF NOT EXISTS chemin_fichier_source TEXT;

COMMENT ON COLUMN raw_data.pe_tools.poste_responsable     IS 'Colonne « Poste Responsable » du fichier PE Tools. Migration 128.';
COMMENT ON COLUMN raw_data.pe_tools.test_de_donnees       IS 'Colonne « Test de données » du fichier PE Tools. Migration 128.';
COMMENT ON COLUMN raw_data.pe_tools.statut_doc            IS 'Colonne « Statut doc » du fichier PE Tools. Migration 128.';
COMMENT ON COLUMN raw_data.pe_tools.module_entretien      IS 'Colonne « Module d''entretien » du fichier PE Tools (7.MSGX). Migration 128.';
COMMENT ON COLUMN raw_data.pe_tools.lien_document         IS 'Colonne « Lien document » du fichier PE Tools. Migration 128.';
COMMENT ON COLUMN raw_data.pe_tools.validation            IS 'Colonne « Validation » du fichier PE Tools. Migration 128.';
COMMENT ON COLUMN raw_data.pe_tools.modele_gamme          IS 'Colonne « Modèle gamme » du fichier PE Tools. Migration 128.';
COMMENT ON COLUMN raw_data.pe_tools.chemin_fichier_source IS 'Colonne « Chemin fichier source » du fichier PE Tools. Migration 128.';

COMMIT;
