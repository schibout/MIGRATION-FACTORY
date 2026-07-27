-- =============================================================
-- Procedure : clean_data.load_maintenance_object_merge
-- Cible     : clean_data.maintenance_object
-- Source    : tables SAP raw_data (lecture seule)
--
-- Mode MERGE : rechargement NON destructif, pendant d'un mode FULL
-- (clean_data.load_maintenance_object) qui, lui, supprime tout source='SAP'.
--
-- REGLE DE PROTECTION (strategie documentee README_MIGRATION_IH02 §3.2) :
--   une ligne est PROTEGEE des que l'utilisateur y a touche, c'est-a-dire
--       source = 'MANUAL'  (creee via l'UI)
--    OU updated_by IS NOT NULL  (modifiee via l'UI : renommage, deplacement,
--       bulk-update, soft delete...)
--   Une ligne protegee n'est ni mise a jour, ni deplacee, ni supprimee.
--   Les autres lignes (source='SAP' AND updated_by IS NULL) sont rafraichies
--   depuis SAP a l'identique du mode FULL.
--
-- Les id internes sont CONSERVES (pas de DELETE/reinsert massif) : les
-- parent_id / ref_object_id poses par l'utilisateur restent valides, et les
-- lignes MANUAL rattachees a un noeud SAP ne sont pas emportees par le
-- ON DELETE CASCADE (ce que le mode FULL ne garantit pas).
--
-- Disparitions cote SAP : une ligne non protegee absente de SAP n'est
-- reellement supprimee que si elle n'a AUCUN enfant (sinon le CASCADE
-- detruirait potentiellement du travail utilisateur). Les autres sont
-- marquees attributes->>'sap_missing' = 'true' et comptees en rejets.
--
-- Meme decoupage en 5 passes que le mode FULL, via une table de staging
-- (pg_temp.mo_stg) qui porte les liens par CLE SAP et non par id.
-- =============================================================

CREATE OR REPLACE PROCEDURE clean_data.load_maintenance_object_merge()
LANGUAGE plpgsql
AS $$
DECLARE
    v_proc        CONSTANT VARCHAR := 'load_maintenance_object_merge';
    v_start_ts    TIMESTAMP := CLOCK_TIMESTAMP();
    v_log_id      BIGINT;
    v_err_msg     TEXT;

    v_nb_ins      BIGINT := 0;   -- lignes ajoutees (nouveautes SAP)
    v_nb_upd      BIGINT := 0;   -- lignes rafraichies depuis SAP
    v_nb_del      BIGINT := 0;   -- lignes supprimees (disparues de SAP, sans enfant)
    v_nb_missing  BIGINT := 0;   -- disparues de SAP mais conservees (ont des enfants)
    v_nb_prot     BIGINT := 0;   -- lignes protegees (travail utilisateur preserve)
    v_tmp         BIGINT := 0;
BEGIN
    INSERT INTO clean_data.etl_log (procedure_name, mode, status)
    VALUES (v_proc, 'MERGE', 'RUNNING')
    RETURNING id INTO v_log_id;

    RAISE NOTICE '[%] == Debut % (MERGE)',
        TO_CHAR(v_start_ts, 'HH24:MI:SS'), v_proc;

    SELECT COUNT(*) INTO v_nb_prot
    FROM clean_data.maintenance_object
    WHERE source = 'MANUAL' OR updated_by IS NOT NULL;

    RAISE NOTICE '[%] Lignes protegees (travail utilisateur) : %',
        TO_CHAR(CLOCK_TIMESTAMP(),'HH24:MI:SS'), v_nb_prot;

    -- =============================================================
    -- STAGING : reconstruction de l'image SAP courante, liens par cle SAP
    -- =============================================================
    DROP TABLE IF EXISTS pg_temp.mo_stg;
    CREATE TEMP TABLE mo_stg (
        object_type     TEXT NOT NULL,
        sap_key         TEXT NOT NULL,
        code            TEXT,
        designation     TEXT,
        parent_type     TEXT,
        parent_sap_key  TEXT,
        ref_sap_key     TEXT,
        sort_order      INTEGER,
        type_code       TEXT,
        category        TEXT,
        work_center     TEXT,
        work_center_txt TEXT,
        cost_center     TEXT,
        plant           TEXT,
        planner_group   TEXT,
        quantity        NUMERIC(15, 3),
        unit            TEXT,
        attributes      JSONB NOT NULL DEFAULT '{}'::jsonb
    );

    -- Cree AVANT les insertions : absorbe les doublons SAP via ON CONFLICT,
    -- exactement comme la contrainte uq_mo_type_key le fait en mode FULL.
    CREATE UNIQUE INDEX idx_mo_stg_key ON mo_stg (object_type, sap_key);

    -- -------------------------------------------------------------
    -- PASSE 1 : FUNC_LOC (identique au mode FULL, parent par tplma)
    -- -------------------------------------------------------------
    INSERT INTO mo_stg (
        object_type, sap_key, code, designation, parent_type, parent_sap_key,
        type_code, category, work_center, work_center_txt,
        plant, planner_group, attributes
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
        'FUNC_LOC',
        NULLIF(TRIM(i.tplma), ''),
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
        ))
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

    -- -------------------------------------------------------------
    -- PASSE 2 : EQUIPMENT (parent = hequi si present, sinon tplnr)
    -- -------------------------------------------------------------
    INSERT INTO mo_stg (
        object_type, sap_key, code, designation, parent_type, parent_sap_key,
        type_code, category, work_center, work_center_txt,
        cost_center, plant, planner_group, attributes
    )
    SELECT
        'EQUIPMENT',
        t.equnr,
        LTRIM(t.equnr, '0'),
        COALESCE(t.eqktx, 'Equipement ' || LTRIM(t.equnr, '0')),
        CASE
            WHEN NULLIF(TRIM(NULLIF(t.hequi, '000000000000000000')), '') IS NOT NULL
                THEN 'EQUIPMENT'
            WHEN NULLIF(TRIM(t.tplnr), '') IS NOT NULL THEN 'FUNC_LOC'
        END,
        COALESCE(
            NULLIF(TRIM(NULLIF(t.hequi, '000000000000000000')), ''),
            NULLIF(TRIM(t.tplnr), '')
        ),
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
        ))
    FROM raw_data.itob t
    LEFT JOIN raw_data.equz ez  ON ez.equnr = t.equnr AND ez.datbi = '99991231'
    LEFT JOIN raw_data.crhd cr  ON cr.objid = ez.gewrk
    LEFT JOIN raw_data.crtx ctx ON ctx.objid = cr.objid AND ctx.spras = 'F'
    ON CONFLICT (object_type, sap_key) DO NOTHING;

    -- -------------------------------------------------------------
    -- PASSE 3 : ARTICLE (references par une BOM T ou M)
    -- -------------------------------------------------------------
    INSERT INTO mo_stg (
        object_type, sap_key, code, designation, type_code, attributes
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
        ))
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

    -- -------------------------------------------------------------
    -- PASSE 4a : BOM_ITEM des postes techniques (stlty='T')
    -- -------------------------------------------------------------
    INSERT INTO mo_stg (
        object_type, sap_key, parent_type, parent_sap_key, ref_sap_key,
        sort_order, code, designation, category, quantity, unit, attributes
    )
    SELECT
        'BOM_ITEM',
        'T:' || t.stlnr || ':' || COALESCE(NULLIF(TRIM(t.stlal), ''), '01') || ':' || p.posnr,
        'FUNC_LOC',
        t.tplnr,
        p.idnrk,
        NULLIF(regexp_replace(p.posnr, '[^0-9]', '', 'g'), '')::int,
        LTRIM(p.idnrk, '0'),
        art.designation,
        p.postp,
        NULLIF(regexp_replace(TRIM(p.menge), '[^0-9.]', '', 'g'), '')::numeric,
        p.meins,
        jsonb_strip_nulls(jsonb_build_object(
            'stlty', 'T', 'stlnr', t.stlnr, 'stlal', t.stlal, 'stlan', t.stlan,
            'posnr', p.posnr, 'stlkn', p.stlkn, 'postp', p.postp,
            'potx1', NULLIF(TRIM(p.potx1), ''), 'potx2', NULLIF(TRIM(p.potx2), ''),
            'base_quantity', k.bmeng, 'base_unit', k.bmein, 'mandt', p.mandt
        ))
    FROM raw_data.tpst t
    JOIN raw_data.stko k ON k.stlnr = t.stlnr AND k.mandt = t.mandt AND k.stlty = 'T'
    JOIN raw_data.stpo p ON p.stlnr = t.stlnr AND p.mandt = t.mandt AND p.stlty = 'T'
    JOIN mo_stg art ON art.object_type = 'ARTICLE' AND art.sap_key = p.idnrk
    WHERE EXISTS (SELECT 1 FROM mo_stg fl
                  WHERE fl.object_type = 'FUNC_LOC' AND fl.sap_key = t.tplnr)
    ON CONFLICT (object_type, sap_key) DO NOTHING;

    -- -------------------------------------------------------------
    -- PASSE 4b : BOM matiere des articles (stlty='M')
    -- -------------------------------------------------------------
    INSERT INTO mo_stg (
        object_type, sap_key, parent_type, parent_sap_key, ref_sap_key,
        sort_order, code, designation, category, quantity, unit, attributes
    )
    SELECT
        'BOM_ITEM',
        'M:' || bm.stlnr || ':' || COALESCE(NULLIF(TRIM(bm.stlal), ''), '01')
             || ':' || p.posnr || ':' || COALESCE(p.stlkn, ''),
        'ARTICLE',
        bm.matnr,
        p.idnrk,
        NULLIF(regexp_replace(p.posnr, '[^0-9]', '', 'g'), '')::int,
        LTRIM(p.idnrk, '0'),
        art.designation,
        p.postp,
        NULLIF(regexp_replace(TRIM(p.menge), '[^0-9.]', '', 'g'), '')::numeric,
        p.meins,
        jsonb_strip_nulls(jsonb_build_object(
            'stlty', 'M', 'stlnr', bm.stlnr, 'stlal', bm.stlal,
            'posnr', p.posnr, 'stlkn', p.stlkn, 'postp', p.postp,
            'potx1', NULLIF(TRIM(p.potx1), ''), 'potx2', NULLIF(TRIM(p.potx2), ''),
            'mandt', p.mandt
        ))
    FROM (
        SELECT DISTINCT ON (m.matnr) m.matnr, m.stlnr, m.stlal, m.mandt
        FROM raw_data.mast m
        WHERE EXISTS (SELECT 1 FROM mo_stg a
                      WHERE a.object_type = 'ARTICLE' AND a.sap_key = m.matnr)
        ORDER BY m.matnr, (CASE WHEN m.werks = '9200' THEN 0 ELSE 1 END), m.stlal, m.stlnr
    ) bm
    JOIN raw_data.stpo p ON p.stlnr = bm.stlnr AND p.mandt = bm.mandt AND p.stlty = 'M'
    JOIN mo_stg art ON art.object_type = 'ARTICLE' AND art.sap_key = p.idnrk
    ON CONFLICT (object_type, sap_key) DO NOTHING;

    ANALYZE mo_stg;

    SELECT COUNT(*) INTO v_tmp FROM mo_stg;
    RAISE NOTICE '[%] Staging construit : % lignes SAP',
        TO_CHAR(CLOCK_TIMESTAMP(),'HH24:MI:SS'), v_tmp;

    -- =============================================================
    -- FUSION — dans l'ordre des dependances FK :
    --   FUNC_LOC -> EQUIPMENT -> ARTICLE -> BOM_ITEM
    -- Les lignes protegees ne sont jamais touchees.
    -- =============================================================

    -- -------------------------------------------------------------
    -- 1. FUNC_LOC : ajout des nouveautes, rafraichissement des non modifiees
    -- -------------------------------------------------------------
    INSERT INTO clean_data.maintenance_object (
        object_type, sap_key, code, designation, type_code, category,
        work_center, work_center_txt, plant, planner_group, attributes, source
    )
    SELECT s.object_type, s.sap_key, s.code, s.designation, s.type_code, s.category,
           s.work_center, s.work_center_txt, s.plant, s.planner_group, s.attributes, 'SAP'
    FROM mo_stg s
    WHERE s.object_type = 'FUNC_LOC'
    ON CONFLICT (object_type, sap_key) DO NOTHING;

    GET DIAGNOSTICS v_tmp = ROW_COUNT;  v_nb_ins := v_nb_ins + v_tmp;

    UPDATE clean_data.maintenance_object m
    SET code            = s.code,
        designation     = s.designation,
        type_code       = s.type_code,
        category        = s.category,
        work_center     = s.work_center,
        work_center_txt = s.work_center_txt,
        plant           = s.plant,
        planner_group   = s.planner_group,
        -- on conserve les cles techniques ajoutees par l'app (ex. sap_missing)
        attributes      = (m.attributes || s.attributes) - 'sap_missing'::text
    FROM mo_stg s
    WHERE m.object_type = 'FUNC_LOC'
      AND s.object_type = 'FUNC_LOC'
      AND m.sap_key = s.sap_key
      AND m.source = 'SAP'
      AND m.updated_by IS NULL;

    GET DIAGNOSTICS v_tmp = ROW_COUNT;  v_nb_upd := v_nb_upd + v_tmp;

    -- Parents FUNC_LOC (uniquement pour les lignes non protegees)
    UPDATE clean_data.maintenance_object m
    SET parent_id = p.id
    FROM mo_stg s
    JOIN clean_data.maintenance_object p
        ON p.object_type = 'FUNC_LOC' AND p.sap_key = s.parent_sap_key
    WHERE m.object_type = 'FUNC_LOC'
      AND s.object_type = 'FUNC_LOC'
      AND m.sap_key = s.sap_key
      AND s.parent_sap_key IS NOT NULL
      AND m.source = 'SAP'
      AND m.updated_by IS NULL
      AND m.parent_id IS DISTINCT FROM p.id;

    -- -------------------------------------------------------------
    -- 2. EQUIPMENT
    -- -------------------------------------------------------------
    INSERT INTO clean_data.maintenance_object (
        object_type, sap_key, code, designation, type_code, category,
        work_center, work_center_txt, cost_center, plant, planner_group,
        attributes, source
    )
    SELECT s.object_type, s.sap_key, s.code, s.designation, s.type_code, s.category,
           s.work_center, s.work_center_txt, s.cost_center, s.plant, s.planner_group,
           s.attributes, 'SAP'
    FROM mo_stg s
    WHERE s.object_type = 'EQUIPMENT'
    ON CONFLICT (object_type, sap_key) DO NOTHING;

    GET DIAGNOSTICS v_tmp = ROW_COUNT;  v_nb_ins := v_nb_ins + v_tmp;

    UPDATE clean_data.maintenance_object m
    SET code            = s.code,
        designation     = s.designation,
        type_code       = s.type_code,
        category        = s.category,
        work_center     = s.work_center,
        work_center_txt = s.work_center_txt,
        cost_center     = s.cost_center,
        plant           = s.plant,
        planner_group   = s.planner_group,
        attributes      = (m.attributes || s.attributes) - 'sap_missing'::text
    FROM mo_stg s
    WHERE m.object_type = 'EQUIPMENT'
      AND s.object_type = 'EQUIPMENT'
      AND m.sap_key = s.sap_key
      AND m.source = 'SAP'
      AND m.updated_by IS NULL;

    GET DIAGNOSTICS v_tmp = ROW_COUNT;  v_nb_upd := v_nb_upd + v_tmp;

    UPDATE clean_data.maintenance_object m
    SET parent_id = p.id
    FROM mo_stg s
    JOIN clean_data.maintenance_object p
        ON p.object_type = s.parent_type AND p.sap_key = s.parent_sap_key
    WHERE m.object_type = 'EQUIPMENT'
      AND s.object_type = 'EQUIPMENT'
      AND m.sap_key = s.sap_key
      AND s.parent_sap_key IS NOT NULL
      AND m.source = 'SAP'
      AND m.updated_by IS NULL
      AND m.parent_id IS DISTINCT FROM p.id;

    -- -------------------------------------------------------------
    -- 3. ARTICLE
    -- -------------------------------------------------------------
    INSERT INTO clean_data.maintenance_object (
        object_type, sap_key, code, designation, type_code, attributes, source
    )
    SELECT s.object_type, s.sap_key, s.code, s.designation, s.type_code,
           s.attributes, 'SAP'
    FROM mo_stg s
    WHERE s.object_type = 'ARTICLE'
    ON CONFLICT (object_type, sap_key) DO NOTHING;

    GET DIAGNOSTICS v_tmp = ROW_COUNT;  v_nb_ins := v_nb_ins + v_tmp;

    UPDATE clean_data.maintenance_object m
    SET code        = s.code,
        designation = s.designation,
        type_code   = s.type_code,
        attributes  = (m.attributes || s.attributes) - 'sap_missing'::text
    FROM mo_stg s
    WHERE m.object_type = 'ARTICLE'
      AND s.object_type = 'ARTICLE'
      AND m.sap_key = s.sap_key
      AND m.source = 'SAP'
      AND m.updated_by IS NULL;

    GET DIAGNOSTICS v_tmp = ROW_COUNT;  v_nb_upd := v_nb_upd + v_tmp;

    -- -------------------------------------------------------------
    -- 4. BOM_ITEM (parent_id et ref_object_id resolus des l'insertion :
    --    contrainte ck_mo_bom les exige tous deux NOT NULL)
    -- -------------------------------------------------------------
    INSERT INTO clean_data.maintenance_object (
        object_type, sap_key, parent_id, ref_object_id, sort_order,
        code, designation, category, quantity, unit, attributes, source
    )
    SELECT s.object_type, s.sap_key, par.id, art.id, s.sort_order,
           COALESCE(art.code, s.code), COALESCE(art.designation, s.designation),
           s.category, s.quantity, s.unit, s.attributes, 'SAP'
    FROM mo_stg s
    JOIN clean_data.maintenance_object par
        ON par.object_type = s.parent_type AND par.sap_key = s.parent_sap_key
    JOIN clean_data.maintenance_object art
        ON art.object_type = 'ARTICLE' AND art.sap_key = s.ref_sap_key
    WHERE s.object_type = 'BOM_ITEM'
    ON CONFLICT (object_type, sap_key) DO NOTHING;

    GET DIAGNOSTICS v_tmp = ROW_COUNT;  v_nb_ins := v_nb_ins + v_tmp;

    UPDATE clean_data.maintenance_object m
    SET sort_order = s.sort_order,
        category   = s.category,
        quantity   = s.quantity,
        unit       = s.unit,
        attributes = (m.attributes || s.attributes) - 'sap_missing'::text
    FROM mo_stg s
    WHERE m.object_type = 'BOM_ITEM'
      AND s.object_type = 'BOM_ITEM'
      AND m.sap_key = s.sap_key
      AND m.source = 'SAP'
      AND m.updated_by IS NULL;

    GET DIAGNOSTICS v_tmp = ROW_COUNT;  v_nb_upd := v_nb_upd + v_tmp;

    -- =============================================================
    -- DISPARITIONS COTE SAP (lignes non protegees absentes du staging)
    --   - sans enfant           -> suppression reelle
    --   - avec enfants          -> conservees + marquees 'sap_missing'
    --     (un DELETE cascaderait sur des lignes potentiellement protegees)
    -- =============================================================
    WITH gone AS (
        SELECT m.id
        FROM clean_data.maintenance_object m
        WHERE m.source = 'SAP'
          AND m.updated_by IS NULL
          AND NOT EXISTS (
              SELECT 1 FROM mo_stg s
              WHERE s.object_type = m.object_type AND s.sap_key = m.sap_key
          )
          AND NOT EXISTS (
              SELECT 1 FROM clean_data.maintenance_object c
              WHERE c.parent_id = m.id OR c.ref_object_id = m.id
          )
    )
    DELETE FROM clean_data.maintenance_object d
    USING gone WHERE d.id = gone.id;

    GET DIAGNOSTICS v_nb_del = ROW_COUNT;

    UPDATE clean_data.maintenance_object m
    SET attributes = m.attributes || jsonb_build_object('sap_missing', true)
    WHERE m.source = 'SAP'
      AND m.updated_by IS NULL
      AND NOT (m.attributes ? 'sap_missing')
      AND NOT EXISTS (
          SELECT 1 FROM mo_stg s
          WHERE s.object_type = m.object_type AND s.sap_key = m.sap_key
      );

    GET DIAGNOSTICS v_nb_missing = ROW_COUNT;

    DROP TABLE IF EXISTS pg_temp.mo_stg;

    -- =============================================================
    -- Cloture du log
    -- =============================================================
    UPDATE clean_data.etl_log
    SET end_ts      = CLOCK_TIMESTAMP(),
        status      = CASE WHEN v_nb_missing > 0 THEN 'WARNING' ELSE 'SUCCESS' END,
        nb_inserted = v_nb_ins,
        nb_updated  = v_nb_upd,
        nb_deleted  = v_nb_del,
        nb_rejected = v_nb_missing,
        message     = FORMAT(
            'Duree: %s s | ajoutes: %s | rafraichis: %s | supprimes: %s | '
            'disparus SAP conserves (ont des enfants): %s | '
            'lignes protegees (travail utilisateur): %s',
            EXTRACT(EPOCH FROM (CLOCK_TIMESTAMP() - v_start_ts))::INTEGER,
            v_nb_ins, v_nb_upd, v_nb_del, v_nb_missing, v_nb_prot)
    WHERE id = v_log_id;

    RAISE NOTICE '[%] == Fin % — ajoutes:% rafraichis:% supprimes:% '
                 'disparus-conserves:% proteges:% (duree %s s)',
        TO_CHAR(CLOCK_TIMESTAMP(),'HH24:MI:SS'), v_proc,
        v_nb_ins, v_nb_upd, v_nb_del, v_nb_missing, v_nb_prot,
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

COMMENT ON PROCEDURE clean_data.load_maintenance_object_merge IS
'Rechargement NON destructif de clean_data.maintenance_object depuis raw_data.
 Preserve integralement les lignes touchees par l''utilisateur (source=MANUAL
 ou updated_by IS NOT NULL) : ni mises a jour, ni deplacees, ni supprimees.
 Rafraichit les autres lignes SAP et ajoute les nouveautes, en conservant les
 id internes (donc les rattachements manuels). Pendant non destructif de
 clean_data.load_maintenance_object(). Appel :
 CALL clean_data.load_maintenance_object_merge();';

-- =============================================================
-- EXEMPLES
--   CALL clean_data.load_maintenance_object_merge();
--   SELECT * FROM clean_data.etl_log
--     WHERE procedure_name='load_maintenance_object_merge'
--     ORDER BY start_ts DESC LIMIT 5;
--   -- Lignes protegees (travail utilisateur) :
--   SELECT COUNT(*) FROM clean_data.maintenance_object
--     WHERE source='MANUAL' OR updated_by IS NOT NULL;
--   -- Objets disparus de SAP mais conserves :
--   SELECT object_type, sap_key, code FROM clean_data.maintenance_object
--     WHERE attributes ? 'sap_missing';
-- =============================================================
