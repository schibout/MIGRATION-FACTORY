-- =============================================================
-- Procedure : clean_data.load_maintenance_object
-- Cible     : clean_data.maintenance_object (table unique ecran IH02)
-- Source    : tables SAP raw_data (lecture seule)
--
-- Mode FULL (defaut) : rechargement complet.
--   Supprime uniquement les lignes source='SAP' (preserve les lignes
--   'MANUAL' creees via l'UI), puis reconstruit toute l'arborescence SAP.
--   Les parents sont resolus par sap_key (stable) -> re-executable a volonte
--   AVANT la bascule. Apres la bascule, la table devient la source de verite
--   (ne plus recharger, ou fusionner via updated_by IS NULL).
--
-- 5 passes ordonnees (les FK parent imposent l'ordre) :
--   1. FUNC_LOC          (postes techniques, sans parent)
--   2. resolution parent FUNC_LOC (tplma -> id)
--   3. EQUIPMENT + resolution parent (FL porteur, sinon equipement hequi)
--   4. ARTICLE           (articles references par une BOM T ou M)
--   5. BOM_ITEM          (a: BOM de FL stlty=T ; b: BOM matiere stlty=M)
--
-- NB parite ecran : on charge TOUS les postes/equipements (l'ecran IH02 ne
--   filtre pas les objets archives). is_active reste TRUE au chargement ; le
--   soft delete ne se fait que via l'UI (DELETE -> is_active=false).
-- =============================================================

CREATE OR REPLACE PROCEDURE clean_data.load_maintenance_object()
LANGUAGE plpgsql
AS $$
DECLARE
    v_proc        CONSTANT VARCHAR := 'load_maintenance_object';
    v_start_ts    TIMESTAMP := CLOCK_TIMESTAMP();
    v_log_id      BIGINT;
    v_err_msg     TEXT;

    v_nb_fl       BIGINT := 0;
    v_nb_eq       BIGINT := 0;
    v_nb_art      BIGINT := 0;
    v_nb_bom      BIGINT := 0;
    v_fl_orphan   BIGINT := 0;   -- FL dont le parent (tplma) n'a pas ete resolu
    v_bom_orphan  BIGINT := 0;   -- BOM sans article reference resolu (log)
BEGIN
    INSERT INTO clean_data.etl_log (procedure_name, mode, status)
    VALUES (v_proc, 'FULL', 'RUNNING')
    RETURNING id INTO v_log_id;

    RAISE NOTICE '[%] == Debut % (FULL)',
        TO_CHAR(v_start_ts, 'HH24:MI:SS'), v_proc;

    -- Purge des seules lignes issues de SAP (preserve source='MANUAL')
    DELETE FROM clean_data.maintenance_object WHERE source = 'SAP';

    -- ============================================================
    -- PASSE 1 : FUNC_LOC (postes techniques) sans parent
    --   iflot + iflos (strno/tplkz) + iflotx (F>E>any # 'vide')
    --   + iflo/crhd/crtx (poste de travail) si iflo present
    -- ============================================================
    INSERT INTO clean_data.maintenance_object (
        object_type, sap_key, code, designation,
        type_code, category, work_center, work_center_txt,
        plant, planner_group, attributes, source
    )
    SELECT
        'FUNC_LOC',
        i.tplnr,
        COALESCE(NULLIF(TRIM(s.strno), ''), i.tplnr),
        CASE
            WHEN xf.pltxt IS NOT NULL AND TRIM(xf.pltxt) <> '' AND LOWER(TRIM(xf.pltxt)) <> 'vide'
                THEN xf.pltxt
            WHEN xe.pltxt IS NOT NULL AND TRIM(xe.pltxt) <> '' AND LOWER(TRIM(xe.pltxt)) <> 'vide'
                THEN xe.pltxt
            WHEN xa.pltxt IS NOT NULL AND TRIM(xa.pltxt) <> '' AND LOWER(TRIM(xa.pltxt)) <> 'vide'
                THEN xa.pltxt
            ELSE COALESCE(NULLIF(TRIM(s.strno), ''), i.tplnr)
        END,
        i.fltyp,
        s.tplkz,
        cr.arbpl,
        ctx.ktext,
        i.iwerk,
        i.ingrp,
        jsonb_strip_nulls(jsonb_build_object(
            'tplma_sap', NULLIF(TRIM(i.tplma), ''),
            'strno',     NULLIF(TRIM(s.strno), ''),
            'tplkz',     s.tplkz,
            'fltyp',     i.fltyp,
            'mandt',     i.mandt
        )),
        'SAP'
    FROM raw_data.iflot i
    LEFT JOIN raw_data.iflos  s  ON s.tplnr  = i.tplnr AND s.mandt = i.mandt
    LEFT JOIN raw_data.iflotx xf ON xf.tplnr = i.tplnr AND xf.mandt = i.mandt AND xf.spras = 'F'
    LEFT JOIN raw_data.iflotx xe ON xe.tplnr = i.tplnr AND xe.mandt = i.mandt AND xe.spras = 'E'
    LEFT JOIN LATERAL (
        SELECT pltxt FROM raw_data.iflotx
        WHERE tplnr = i.tplnr AND mandt = i.mandt
          AND pltxt IS NOT NULL AND TRIM(pltxt) <> '' AND LOWER(TRIM(pltxt)) <> 'vide'
        LIMIT 1
    ) xa ON TRUE
    LEFT JOIN raw_data.iflo fl
        ON fl.tplnr = i.tplnr AND fl.mandt = i.mandt AND fl.spras = 'F'
    LEFT JOIN raw_data.crhd cr  ON cr.objid = fl.ppsid AND fl.ppsid <> '00000000'
    LEFT JOIN raw_data.crtx ctx ON ctx.objid = cr.objid AND ctx.spras = 'F'
    ON CONFLICT (object_type, sap_key) DO NOTHING;

    GET DIAGNOSTICS v_nb_fl = ROW_COUNT;
    RAISE NOTICE '[%] Passe 1 FUNC_LOC : %', TO_CHAR(CLOCK_TIMESTAMP(),'HH24:MI:SS'), v_nb_fl;

    -- ============================================================
    -- PASSE 2 : resolution du parent des FUNC_LOC (tplma -> id)
    -- ============================================================
    UPDATE clean_data.maintenance_object c
    SET parent_id = p.id
    FROM clean_data.maintenance_object p
    WHERE c.object_type = 'FUNC_LOC'
      AND c.source = 'SAP'
      AND NULLIF(TRIM(c.attributes->>'tplma_sap'), '') IS NOT NULL
      AND p.object_type = 'FUNC_LOC'
      AND p.sap_key = c.attributes->>'tplma_sap';

    SELECT COUNT(*) INTO v_fl_orphan
    FROM clean_data.maintenance_object c
    WHERE c.object_type = 'FUNC_LOC' AND c.source = 'SAP'
      AND c.parent_id IS NULL
      AND NULLIF(TRIM(c.attributes->>'tplma_sap'), '') IS NOT NULL;

    RAISE NOTICE '[%] Passe 2 parents FL resolus (orphelins tplma non resolus : %)',
        TO_CHAR(CLOCK_TIMESTAMP(),'HH24:MI:SS'), v_fl_orphan;

    -- ============================================================
    -- PASSE 3a : EQUIPMENT (itob) sans parent
    --   parent resolu en 3b (FL via tplnr, sinon equipement via hequi)
    -- ============================================================
    INSERT INTO clean_data.maintenance_object (
        object_type, sap_key, code, designation,
        type_code, category, work_center, work_center_txt,
        cost_center, plant, planner_group, attributes, source
    )
    SELECT
        'EQUIPMENT',
        t.equnr,
        LTRIM(t.equnr, '0'),
        COALESCE(t.eqktx, 'Equipement ' || LTRIM(t.equnr, '0')),
        t.eqart,
        t.eqtyp,
        cr.arbpl,
        ctx.ktext,
        t.kostl,
        t.iwerk,
        t.ingrp,
        jsonb_strip_nulls(jsonb_build_object(
            'equnr_long', t.equnr,
            'tplnr_sap',  NULLIF(TRIM(t.tplnr), ''),
            'hequi',      NULLIF(TRIM(NULLIF(t.hequi, '000000000000000000')), ''),
            'herst', t.herst, 'herld', t.herld, 'typbz', t.typbz,
            'sernr', t.sernr, 'invnr', t.invnr, 'groes', t.groes,
            'brgew', t.brgew, 'gewei', t.gewei, 'answt', t.answt,
            'waers', t.waers, 'ansdt', t.ansdt, 'baujj', t.baujj,
            'baumm', t.baumm, 'inbdt', t.inbdt, 'erdat', t.erdat,
            'ernam', t.ernam, 'aedat', t.aedat, 'aenam', t.aenam,
            'lvorm', t.lvorm, 'gwlen', t.gwlen, 'gwldt', t.gwldt,
            'elief', t.elief, 'matnr', NULLIF(TRIM(t.matnr), ''),
            'begru', t.begru, 'bukrs', t.bukrs, 'gsber', t.gsber,
            'swerk', t.swerk, 'stort', t.stort, 'beber', t.beber,
            'warpl', t.warpl, 'gewrk', ez.gewrk, 'mandt', t.mandt
        )),
        'SAP'
    FROM raw_data.itob t
    LEFT JOIN raw_data.equz ez  ON ez.equnr = t.equnr AND ez.datbi = '99991231'
    LEFT JOIN raw_data.crhd cr  ON cr.objid = ez.gewrk
    LEFT JOIN raw_data.crtx ctx ON ctx.objid = cr.objid AND ctx.spras = 'F'
    ON CONFLICT (object_type, sap_key) DO NOTHING;

    GET DIAGNOSTICS v_nb_eq = ROW_COUNT;

    -- PASSE 3b : parent EQUIPMENT = equipement superieur (hequi) si present...
    UPDATE clean_data.maintenance_object c
    SET parent_id = p.id
    FROM clean_data.maintenance_object p
    WHERE c.object_type = 'EQUIPMENT' AND c.source = 'SAP'
      AND NULLIF(TRIM(c.attributes->>'hequi'), '') IS NOT NULL
      AND p.object_type = 'EQUIPMENT'
      AND p.sap_key = c.attributes->>'hequi';

    -- ...sinon poste technique porteur (tplnr)
    UPDATE clean_data.maintenance_object c
    SET parent_id = p.id
    FROM clean_data.maintenance_object p
    WHERE c.object_type = 'EQUIPMENT' AND c.source = 'SAP'
      AND c.parent_id IS NULL
      AND NULLIF(TRIM(c.attributes->>'tplnr_sap'), '') IS NOT NULL
      AND p.object_type = 'FUNC_LOC'
      AND p.sap_key = c.attributes->>'tplnr_sap';

    RAISE NOTICE '[%] Passe 3 EQUIPMENT : %', TO_CHAR(CLOCK_TIMESTAMP(),'HH24:MI:SS'), v_nb_eq;

    -- ============================================================
    -- PASSE 4 : ARTICLE (articles references par une BOM T ou M)
    --   mara + makt (F>E>any)
    -- ============================================================
    INSERT INTO clean_data.maintenance_object (
        object_type, sap_key, code, designation, type_code, attributes, source
    )
    SELECT
        'ARTICLE',
        m.matnr,
        LTRIM(m.matnr, '0'),
        mk.maktx,
        m.mtart,
        jsonb_strip_nulls(jsonb_build_object(
            'matnr_long', m.matnr,
            'mtart', m.mtart, 'meins_base', m.meins,
            'mbrsh', m.mbrsh, 'matkl', m.matkl, 'mandt', m.mandt
        )),
        'SAP'
    FROM (
        SELECT DISTINCT p.idnrk AS matnr, p.mandt
        FROM raw_data.stpo p
        WHERE p.stlty IN ('T', 'M')
          AND p.idnrk IS NOT NULL AND TRIM(p.idnrk) <> ''
    ) src
    JOIN raw_data.mara m ON m.matnr = src.matnr AND m.mandt = src.mandt
    LEFT JOIN LATERAL (
        SELECT maktx FROM raw_data.makt
        WHERE matnr = m.matnr AND mandt = m.mandt
        ORDER BY (CASE WHEN spras = 'F' THEN 0 WHEN spras = 'E' THEN 1 ELSE 2 END)
        LIMIT 1
    ) mk ON TRUE
    ON CONFLICT (object_type, sap_key) DO NOTHING;

    GET DIAGNOSTICS v_nb_art = ROW_COUNT;
    RAISE NOTICE '[%] Passe 4 ARTICLE : %', TO_CHAR(CLOCK_TIMESTAMP(),'HH24:MI:SS'), v_nb_art;

    -- ============================================================
    -- PASSE 5a : BOM_ITEM des postes techniques (stlty='T')
    --   tpst -> stko -> stpo ; parent = FL(tplnr), ref = ARTICLE(idnrk)
    -- ============================================================
    INSERT INTO clean_data.maintenance_object (
        object_type, sap_key, parent_id, ref_object_id, sort_order,
        code, designation, category, quantity, unit, attributes, source
    )
    SELECT
        'BOM_ITEM',
        'T:' || t.stlnr || ':' || COALESCE(NULLIF(TRIM(t.stlal), ''), '01') || ':' || p.posnr,
        fl.id,
        art.id,
        NULLIF(regexp_replace(p.posnr, '[^0-9]', '', 'g'), '')::int,
        art.code,
        art.designation,
        p.postp,
        NULLIF(regexp_replace(TRIM(p.menge), '[^0-9.]', '', 'g'), '')::numeric,
        p.meins,
        jsonb_strip_nulls(jsonb_build_object(
            'stlty', 'T', 'stlnr', t.stlnr, 'stlal', t.stlal, 'stlan', t.stlan,
            'posnr', p.posnr, 'stlkn', p.stlkn, 'postp', p.postp,
            'potx1', NULLIF(TRIM(p.potx1), ''), 'potx2', NULLIF(TRIM(p.potx2), ''),
            'base_quantity', k.bmeng, 'base_unit', k.bmein, 'mandt', p.mandt
        )),
        'SAP'
    FROM raw_data.tpst t
    JOIN raw_data.stko k ON k.stlnr = t.stlnr AND k.mandt = t.mandt AND k.stlty = 'T'
    JOIN raw_data.stpo p ON p.stlnr = t.stlnr AND p.mandt = t.mandt AND p.stlty = 'T'
    JOIN clean_data.maintenance_object fl
        ON fl.object_type = 'FUNC_LOC' AND fl.sap_key = t.tplnr
    LEFT JOIN clean_data.maintenance_object art
        ON art.object_type = 'ARTICLE' AND art.sap_key = p.idnrk
    WHERE p.idnrk IS NOT NULL AND TRIM(p.idnrk) <> ''
      AND art.id IS NOT NULL
    ON CONFLICT (object_type, sap_key) DO NOTHING;

    GET DIAGNOSTICS v_nb_bom = ROW_COUNT;

    -- ============================================================
    -- PASSE 5b : BOM matiere des articles (stlty='M')
    --   mast (BOM preferee werks='9200') -> stpo ;
    --   parent = ARTICLE(matnr du mast), ref = ARTICLE(idnrk)
    -- ============================================================
    WITH best_mast AS (
        SELECT DISTINCT ON (m.matnr)
               m.matnr, m.stlnr, m.stlal, m.mandt
        FROM raw_data.mast m
        WHERE EXISTS (SELECT 1 FROM clean_data.maintenance_object a
                      WHERE a.object_type = 'ARTICLE' AND a.sap_key = m.matnr)
        ORDER BY m.matnr, (CASE WHEN m.werks = '9200' THEN 0 ELSE 1 END), m.stlal, m.stlnr
    )
    INSERT INTO clean_data.maintenance_object (
        object_type, sap_key, parent_id, ref_object_id, sort_order,
        code, designation, category, quantity, unit, attributes, source
    )
    SELECT
        'BOM_ITEM',
        'M:' || bm.stlnr || ':' || COALESCE(NULLIF(TRIM(bm.stlal), ''), '01')
             || ':' || p.posnr || ':' || COALESCE(p.stlkn, ''),
        parent.id,
        art.id,
        NULLIF(regexp_replace(p.posnr, '[^0-9]', '', 'g'), '')::int,
        art.code,
        art.designation,
        p.postp,
        NULLIF(regexp_replace(TRIM(p.menge), '[^0-9.]', '', 'g'), '')::numeric,
        p.meins,
        jsonb_strip_nulls(jsonb_build_object(
            'stlty', 'M', 'stlnr', bm.stlnr, 'stlal', bm.stlal,
            'posnr', p.posnr, 'stlkn', p.stlkn, 'postp', p.postp,
            'potx1', NULLIF(TRIM(p.potx1), ''), 'potx2', NULLIF(TRIM(p.potx2), ''),
            'mandt', p.mandt
        )),
        'SAP'
    FROM best_mast bm
    JOIN raw_data.stpo p ON p.stlnr = bm.stlnr AND p.mandt = bm.mandt AND p.stlty = 'M'
    JOIN clean_data.maintenance_object parent
        ON parent.object_type = 'ARTICLE' AND parent.sap_key = bm.matnr
    LEFT JOIN clean_data.maintenance_object art
        ON art.object_type = 'ARTICLE' AND art.sap_key = p.idnrk
    WHERE p.idnrk IS NOT NULL AND TRIM(p.idnrk) <> ''
      AND art.id IS NOT NULL
    ON CONFLICT (object_type, sap_key) DO NOTHING;

    GET DIAGNOSTICS v_bom_orphan = ROW_COUNT;  -- reutilise comme compteur passe 5b
    v_nb_bom := v_nb_bom + v_bom_orphan;

    RAISE NOTICE '[%] Passe 5 BOM_ITEM (T+M) : %',
        TO_CHAR(CLOCK_TIMESTAMP(),'HH24:MI:SS'), v_nb_bom;

    -- ============================================================
    -- Cloture du log
    -- ============================================================
    UPDATE clean_data.etl_log
    SET end_ts      = CLOCK_TIMESTAMP(),
        status      = CASE WHEN v_fl_orphan > 0 THEN 'WARNING' ELSE 'SUCCESS' END,
        nb_inserted = v_nb_fl + v_nb_eq + v_nb_art + v_nb_bom,
        nb_rejected = v_fl_orphan,
        message     = FORMAT(
            'Duree: %s s | FL: %s | EQ: %s | ART: %s | BOM: %s | FL orphelins: %s',
            EXTRACT(EPOCH FROM (CLOCK_TIMESTAMP() - v_start_ts))::INTEGER,
            v_nb_fl, v_nb_eq, v_nb_art, v_nb_bom, v_fl_orphan)
    WHERE id = v_log_id;

    RAISE NOTICE '[%] == Fin % — FL:% EQ:% ART:% BOM:% (duree %s s)',
        TO_CHAR(CLOCK_TIMESTAMP(),'HH24:MI:SS'), v_proc,
        v_nb_fl, v_nb_eq, v_nb_art, v_nb_bom,
        EXTRACT(EPOCH FROM (CLOCK_TIMESTAMP() - v_start_ts))::INTEGER;

EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT;
    UPDATE clean_data.etl_log
    SET end_ts = CLOCK_TIMESTAMP(), status = 'ERROR', message = v_err_msg
    WHERE id = v_log_id;
    RAISE EXCEPTION '[%] ERREUR dans % : %',
        TO_CHAR(CLOCK_TIMESTAMP(),'HH24:MI:SS'), v_proc, v_err_msg;
END;
$$;

COMMENT ON PROCEDURE clean_data.load_maintenance_object IS
'Charge clean_data.maintenance_object depuis raw_data (iflot/iflos/iflotx/iflo,
 itob/equz/crhd/crtx, mara/makt, tpst/stko/stpo, mast/stpo). 5 passes :
 FUNC_LOC, parents FL, EQUIPMENT+parents, ARTICLE, BOM_ITEM (T puis M).
 Supprime uniquement source=SAP (preserve MANUAL). Idempotent (parents
 resolus par sap_key). Appel : CALL clean_data.load_maintenance_object();';

-- =============================================================
-- EXEMPLES
--   CALL clean_data.load_maintenance_object();
--   SELECT object_type, COUNT(*) FROM clean_data.maintenance_object GROUP BY 1;
--   SELECT * FROM clean_data.etl_log
--     WHERE procedure_name='load_maintenance_object' ORDER BY start_ts DESC LIMIT 5;
-- =============================================================
