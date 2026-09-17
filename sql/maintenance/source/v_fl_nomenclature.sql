-- =====================================================================
-- VUE MATERIALISEE : clean_data.v_fl_nomenclature
-- Nomenclature (BOM) des postes techniques SAP via TPST + STKO + STPO
-- Une ligne par composant de chaque FL ayant une BOM.
-- =====================================================================

DROP MATERIALIZED VIEW IF EXISTS clean_data.v_fl_nomenclature CASCADE;

CREATE MATERIALIZED VIEW clean_data.v_fl_nomenclature AS
SELECT
    t.tplnr,
    COALESCE(NULLIF(TRIM(s.strno), ''), t.tplnr) AS tplnr_display,
    CASE
        WHEN xf.pltxt IS NOT NULL AND TRIM(xf.pltxt) <> '' AND LOWER(TRIM(xf.pltxt)) <> 'vide'
            THEN xf.pltxt
        WHEN xe.pltxt IS NOT NULL AND TRIM(xe.pltxt) <> '' AND LOWER(TRIM(xe.pltxt)) <> 'vide'
            THEN xe.pltxt
        ELSE COALESCE(NULLIF(TRIM(s.strno), ''), t.tplnr)
    END                                                  AS fl_designation,
    t.stlnr,
    t.stlal,
    t.stlan,
    k.bmeng                                              AS base_quantity,
    k.bmein                                              AS base_unit,
    p.posnr,
    p.idnrk,
    LTRIM(p.idnrk, '0')                                  AS matnr_short,
    p.postp                                              AS item_category,
    p.menge                                              AS quantity,
    p.meins                                              AS unit,
    m.mtart                                              AS material_type,
    COALESCE(mk.maktx, NULLIF(TRIM(p.potx1), ''), NULLIF(TRIM(p.potx2), '')) AS designation,
    p.posnr::int                                         AS sort_order
FROM raw_data.tpst t
JOIN raw_data.stko k
    ON k.stlnr = t.stlnr AND k.mandt = t.mandt AND k.stlty = 'T'
JOIN raw_data.stpo p
    ON p.stlnr = t.stlnr AND p.mandt = t.mandt AND p.stlty = 'T'
LEFT JOIN raw_data.iflot i
    ON i.tplnr = t.tplnr AND i.mandt = t.mandt
LEFT JOIN raw_data.iflos s
    ON s.tplnr = t.tplnr AND s.mandt = t.mandt
LEFT JOIN raw_data.iflotx xf
    ON xf.tplnr = t.tplnr AND xf.mandt = t.mandt AND xf.spras = 'F'
LEFT JOIN raw_data.iflotx xe
    ON xe.tplnr = t.tplnr AND xe.mandt = t.mandt AND xe.spras = 'E'
LEFT JOIN raw_data.mara m
    ON m.matnr = p.idnrk AND m.mandt = t.mandt
LEFT JOIN LATERAL (
    SELECT maktx
    FROM raw_data.makt
    WHERE matnr = p.idnrk AND mandt = t.mandt
    ORDER BY (CASE WHEN spras = 'F' THEN 0
                   WHEN spras = 'E' THEN 1
                   ELSE 2 END)
    LIMIT 1
) mk ON TRUE;

CREATE INDEX idx_v_fl_nomenclature_tplnr ON clean_data.v_fl_nomenclature (tplnr);
CREATE INDEX idx_v_fl_nomenclature_idnrk ON clean_data.v_fl_nomenclature (idnrk);
CREATE INDEX idx_v_fl_nomenclature_stlnr ON clean_data.v_fl_nomenclature (stlnr);

COMMENT ON MATERIALIZED VIEW clean_data.v_fl_nomenclature IS
'BOM des postes techniques SAP (TPST + STKO + STPO + MARA/MAKT). 1 ligne par composant.';

-- =====================================================================
-- Refresh apres rechargement des tables sources :
--   REFRESH MATERIALIZED VIEW clean_data.v_fl_nomenclature;
--
-- Verifications :
--   SELECT COUNT(*) FROM clean_data.v_fl_nomenclature;
--   SELECT * FROM clean_data.v_fl_nomenclature WHERE tplnr = 'T340-E100-1005';
-- =====================================================================
