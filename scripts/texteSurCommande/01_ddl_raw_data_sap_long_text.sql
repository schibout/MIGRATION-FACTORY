-- ============================================================================
-- raw_data.sap_long_text
-- Textes longs SAP (STXH/STXL), tout objet : MATERIAL, EINA, EINE, ...
-- Une ligne = une ligne SAPscript. La recomposition se fait en clean_data
-- (clean_data.texte_long_sap). Anciennement raw_data.sap_material_text
-- (renommee par la migration 081 du depot Migration Factory).
-- Conventions raw_data : tout en TEXT, raw_id IDENTITY, provenance, IF NOT EXISTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS raw_data.sap_long_text (
    raw_id       BIGINT GENERATED ALWAYS AS IDENTITY,
    tdobject     TEXT,   -- objet de texte SAP (STXH.TDOBJECT)
    tdname       TEXT,   -- cle de l'objet telle que stockee dans STXH (MATNR sur 18, INFNR, ...)
    tdid         TEXT,   -- type de texte (BEST, GRUN, AT, BT, ...)
    tdspras      TEXT,   -- langue SAP interne (F, E, D, ...)
    tdtitle      TEXT,   -- titre du texte (STXH)
    line_no      TEXT,   -- rang de la ligne dans le texte, 1..n
    tdformat     TEXT,   -- format SAPscript de la ligne (*, /, =, /:, /*, ...)
    tdline       TEXT,   -- LE CONTENU
    source_file  TEXT,
    loaded_at    TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sap_long_text_cle
    ON raw_data.sap_long_text (tdobject, tdid, tdspras, tdname);

COMMENT ON TABLE raw_data.sap_long_text IS
    'Textes longs SAP (STXH/STXL) lus par RFC_READ_TEXT (pyrfc). '
    'STXL.CLUSTD etant un cluster compresse de type LRAW, aucune lecture SQL directe n''est possible.';
