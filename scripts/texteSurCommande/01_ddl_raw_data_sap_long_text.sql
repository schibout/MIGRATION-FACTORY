-- ============================================================================
-- raw_data.sap_material_text
-- Textes longs SAP rattachés aux articles (objet MATERIAL)
-- Une ligne = une ligne SAPscript. La concaténation se fait en clean_data.
-- Conventions raw_data : tout en TEXT, raw_id IDENTITY, provenance, IF NOT EXISTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS raw_data.sap_material_text (
    raw_id       BIGINT GENERATED ALWAYS AS IDENTITY,
    tdobject     TEXT,   -- toujours 'MATERIAL'
    tdname       TEXT,   -- MATNR sur 18 caractères (clé SAP)
    matnr        TEXT,   -- MATNR dégraissé des zéros de tête (clé de jointure)
    tdid         TEXT,   -- GRUN | BEST | PRUE | IVER
    tdspras      TEXT,   -- langue
    tdtitle      TEXT,   -- titre du texte (STXH)
    line_no      TEXT,   -- rang de la ligne dans le texte, 1..n
    tdformat     TEXT,   -- format SAPscript de la ligne (*, /, =, ...)
    tdline       TEXT,   -- LE CONTENU
    source_file  TEXT,
    loaded_at    TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sap_material_text_cle
    ON raw_data.sap_material_text (tdid, tdspras, tdname);

CREATE INDEX IF NOT EXISTS idx_sap_material_text_matnr
    ON raw_data.sap_material_text (matnr);

COMMENT ON TABLE raw_data.sap_material_text IS
    'Textes longs SAP objet MATERIAL, extraits par READ_TEXT (pyrfc). '
    'STXL.CLUSTD étant compressé, aucune lecture SQL directe n''est possible.';
