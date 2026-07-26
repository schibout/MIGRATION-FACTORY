-- =====================================================================
-- VUE raw_data.itob
-- Agregation des tables sources SAP equi + eqkt + equz + iloa
-- Une ligne par equipement (equnr)
--   - equi : master equipement
--   - eqkt : description (FR prioritaire, sinon premiere langue dispo)
--   - equz : record courant (datbi = '99991231') pour iwerk/ingrp/gewrk/iloan
--   - iloa : localisation via equz.iloan -> tplnr/kostl/swerk/stort/beber/bukrs/gsber
--
-- Colonnes hequi et warpl mises a NULL (absentes des tables sources).
-- =====================================================================

DROP VIEW IF EXISTS raw_data.itob CASCADE;

CREATE OR REPLACE VIEW raw_data.itob AS
SELECT
    e.mandt,
    e.equnr,
    -- Description : FR si dispo, sinon premiere langue trouvee
    COALESCE(kt_fr.eqktx, kt_any.eqktx) AS eqktx,

    -- Champs equi (master)
    e.eqart,
    e.eqtyp,
    e.herst,
    e.herld,
    e.typbz,
    e.sernr,
    e.invnr,
    e.groes,
    e.brgew,
    e.gewei,
    e.ansdt,
    e.answt,
    e.waers,
    e.elief,
    e.matnr,
    e.baujj,
    e.baumm,
    e.gwlen,
    e.gwldt,
    e.inbdt,
    e.erdat,
    e.ernam,
    e.aedat,
    e.aenam,
    e.lvorm,
    e.begru,
    e.objnr,

    -- Champs equz (record courant)
    ez.iwerk,
    ez.ingrp,
    ez.gewrk,
    ez.iloan,

    -- Champs iloa (via equz.iloan)
    il.tplnr,
    il.kostl,
    il.swerk,
    il.stort,
    il.beber,
    il.bukrs,
    il.gsber,

    -- Colonnes absentes des tables sources : forcees a NULL
    NULL::varchar AS hequi,
    NULL::varchar AS warpl
FROM raw_data.equi e
LEFT JOIN raw_data.eqkt kt_fr
    ON kt_fr.mandt = e.mandt
   AND kt_fr.equnr = e.equnr
   AND kt_fr.spras = 'F'
LEFT JOIN LATERAL (
    SELECT eqktx
    FROM raw_data.eqkt
    WHERE mandt = e.mandt
      AND equnr = e.equnr
    ORDER BY (CASE WHEN spras = 'F' THEN 0
                   WHEN spras = 'E' THEN 1
                   ELSE 2 END)
    LIMIT 1
) kt_any ON TRUE
LEFT JOIN raw_data.equz ez
    ON ez.mandt = e.mandt
   AND ez.equnr = e.equnr
   AND ez.datbi = '99991231'
LEFT JOIN raw_data.iloa il
    ON il.mandt = ez.mandt
   AND il.iloan = ez.iloan;

COMMENT ON VIEW raw_data.itob IS
'Vue agregee equipements SAP (equi+eqkt+equz+iloa). hequi/warpl = NULL (non disponibles).';

-- Verification rapide
-- SELECT COUNT(*) FROM raw_data.itob;
-- SELECT * FROM raw_data.itob LIMIT 5;
