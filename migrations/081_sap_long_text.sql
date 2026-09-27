-- ============================================================================
-- 081 - raw_data.sap_material_text -> raw_data.sap_long_text
-- ----------------------------------------------------------------------------
-- La table des textes longs SAP (lus par RFC_READ_TEXT, cf.
-- scripts/texteSurCommande/) recoit desormais tout objet STXH (MATERIAL,
-- EINA, EINE, ...) et non plus les seuls articles : elle est renommee, la
-- colonne matnr (MATNR sans zeros, inutilisee : toutes les jointures passent
-- par tdname) est supprimee et l'index porte la cle complete
-- (tdobject, tdid, tdspras, tdname).
-- Idempotente : rejouable sur une base ou la table porte deja le bon nom, ou
-- n'existe pas encore (le script d'extraction la cree alors lui-meme).
-- ============================================================================
BEGIN;

DO $$
BEGIN
    IF to_regclass('raw_data.sap_material_text') IS NOT NULL
       AND to_regclass('raw_data.sap_long_text') IS NULL THEN
        ALTER TABLE raw_data.sap_material_text RENAME TO sap_long_text;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS raw_data.sap_long_text (
    raw_id       BIGINT GENERATED ALWAYS AS IDENTITY,
    tdobject     TEXT,
    tdname       TEXT,
    tdid         TEXT,
    tdspras      TEXT,
    tdtitle      TEXT,
    line_no      TEXT,
    tdformat     TEXT,
    tdline       TEXT,
    source_file  TEXT,
    loaded_at    TIMESTAMP
);

ALTER TABLE raw_data.sap_long_text DROP COLUMN IF EXISTS matnr;
DROP INDEX IF EXISTS raw_data.idx_sap_material_text_matnr;
DROP INDEX IF EXISTS raw_data.idx_sap_material_text_cle;
CREATE INDEX IF NOT EXISTS idx_sap_long_text_cle
    ON raw_data.sap_long_text (tdobject, tdid, tdspras, tdname);

COMMENT ON TABLE raw_data.sap_long_text IS
    'Textes longs SAP (STXH/STXL) lus par RFC_READ_TEXT (pyrfc), une ligne SAPscript par enregistrement. '
    'STXL.CLUSTD etant un cluster compresse de type LRAW, aucune lecture SQL directe n''est possible.';

COMMIT;
