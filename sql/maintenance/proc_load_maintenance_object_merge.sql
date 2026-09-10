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
-- PERIMETRE (p_root_tplnr, defaut 'T') : seuls la racine demandee et ses
--   descendants (chaine tplma) sont importes, et les postes techniques SAP
--   hors perimetre deja presents sont SUPPRIMES (purge stricte : meme
--   modifies via l'UI). C'est le seul moyen de garantir "uniquement T et ses
--   enfants" a l'ecran, un residu d'extraction precedente etant absent du
--   staging et donc conserve indefiniment par la regle sap_missing ci-dessous.
--   Exception a la purge : les creations utilisateur (source='MANUAL').
--   raw_data n'est jamais modifie (filtre a la lecture).
--
-- Disparitions cote SAP : une ligne non protegee absente de SAP n'est
-- reellement supprimee que si elle n'a AUCUN enfant (sinon le CASCADE
-- detruirait potentiellement du travail utilisateur). Les autres sont
-- marquees attributes->>'sap_missing' = 'true' et comptees en rejets.
--
-- Meme decoupage en 5 passes que le mode FULL, via une table de staging
-- (pg_temp.mo_stg) qui porte les liens par CLE SAP et non par id.
-- =============================================================

-- L'ancienne signature sans argument doit disparaitre : sinon CALL
-- load_maintenance_object_merge() serait ambigu entre les deux surcharges.
DROP PROCEDURE IF EXISTS clean_data.load_maintenance_object_merge();

CREATE OR REPLACE PROCEDURE clean_data.load_maintenance_object_merge(
    p_root_tplnr TEXT DEFAULT 'T'
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_proc        CONSTANT VARCHAR := 'load_maintenance_object_merge';
    v_nb_scope    BIGINT := 0;   -- postes techniques dans le perimetre retenu
    v_nb_iflot    BIGINT := 0;   -- postes techniques presents dans raw_data.iflot
    v_nb_purge    BIGINT := 0;   -- postes SAP supprimes car hors perimetre
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
    -- PERIMETRE : la racine demandee + ses descendants (tplma), calcule en
    -- LECTURE SEULE sur raw_data. UNION (et non UNION ALL) : dedoublonne,
    -- ce qui garantit l'arret meme si les donnees SAP ont un cycle tplma.
    -- =============================================================
    DROP TABLE IF EXISTS pg_temp.fl_scope;
    CREATE TEMP TABLE fl_scope (tplnr TEXT PRIMARY KEY);

    -- Ancres de la recursion : la racine demandee, PLUS les postes qui portent
    -- son prefixe mais dont le tplma est vide (T200-X060-60, T300-X050).
    -- Identique au mode FULL.
    WITH RECURSIVE scope AS (
        SELECT i.tplnr FROM raw_data.iflot i
        WHERE i.tplnr = p_root_tplnr
           OR (NULLIF(TRIM(i.tplma), '') IS NULL
               AND i.tplnr <> p_root_tplnr
               AND i.tplnr LIKE p_root_tplnr || '%')
        UNION
        SELECT c.tplnr FROM raw_data.iflot c JOIN scope s ON c.tplma = s.tplnr
    )
    INSERT INTO fl_scope (tplnr) SELECT tplnr FROM scope;

    SELECT COUNT(*) INTO v_nb_scope FROM fl_scope;

    -- Racine introuvable : on echoue AVANT la purge de perimetre, qui sinon
    -- supprimerait tous les postes techniques SAP.
    IF v_nb_scope = 0 THEN
        RAISE EXCEPTION 'Racine "%" introuvable dans raw_data.iflot : fusion annulee', p_root_tplnr;
    END IF;

    ANALYZE fl_scope;

    SELECT COUNT(*) INTO v_nb_iflot FROM raw_data.iflot;

    RAISE NOTICE '[%] Perimetre "%": % postes techniques retenus sur % (% ecartes)',
        TO_CHAR(CLOCK_TIMESTAMP(),'HH24:MI:SS'), p_root_tplnr,
        v_nb_scope, v_nb_iflot, v_nb_iflot - v_nb_scope;

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
    -- ------------------------------------------------------------------
    -- Code affiche du poste technique : strno (etiquette externe SAP), avec
    -- REPLI sur le tplnr en cas de collision entre freres.
    -- 25 codes sont portes par plusieurs postes (dont les postes en
    -- numerotation interne ?01000000000000000xx, qui reprennent le strno d'un
    -- poste externe). La comparaison est GLOBALE et non entre freres : en
    -- passe 1 tous les FUNC_LOC sont inseres avec parent_id NULL, et l'index
    -- uq_mo_code_sibling est NULLS NOT DISTINCT -> a cet instant deux NULL
    -- sont egaux, donc le code doit etre unique sur toute la table. Un
    -- partitionnement par tplma ne suffit pas. Trois de ces paires sont des postes
    -- REELLEMENT distincts (ex. T212-B005 : « EQUIPEMENT COLLECTIF MOYEN
    -- D'ACCES », porteur de 3 equipements, contre « EVACUATION EAUX
    -- PLUVIALES ») : dedupliquer en perdrait un. Le poste en numerotation
    -- externe garde donc le strno, les autres prennent leur tplnr.
    -- sap_key n'est jamais affecte : les rattachements restent intacts.
    -- ------------------------------------------------------------------
    WITH fl_code AS (
        SELECT x.tplnr, x.mandt,
               CASE WHEN ROW_NUMBER() OVER (
                        PARTITION BY x.mandt, x.candidat
                        ORDER BY (CASE WHEN x.tplnr LIKE '?%' THEN 1 ELSE 0 END), x.tplnr
                    ) = 1
                    THEN x.candidat
                    ELSE x.tplnr
               END AS code
        FROM (
            SELECT DISTINCT ON (i.tplnr, i.mandt)
                   i.tplnr, i.mandt, i.tplma,
                   COALESCE(NULLIF(TRIM(s.strno), ''), i.tplnr) AS candidat
            FROM raw_data.iflot i
            LEFT JOIN raw_data.iflos s ON s.tplnr = i.tplnr AND s.mandt = i.mandt
            ORDER BY i.tplnr, i.mandt
        ) x
    )
    SELECT
        'FUNC_LOC',
        i.tplnr,
        fc.code,
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
        -- Repli pour les postes a tplma vide entres par les ancres du perimetre
        -- (T200-X060-60 -> T200-X060) : uniquement si ce parent est bien dans
        -- le perimetre, sinon le poste reste racine. attributes.tplma_sap garde
        -- la valeur SAP brute (vide) : on ne falsifie pas la donnee source.
        COALESCE(
            NULLIF(TRIM(i.tplma), ''),
            CASE WHEN i.tplnr <> p_root_tplnr AND i.tplnr LIKE '%-%'
                 THEN (SELECT sc2.tplnr FROM fl_scope sc2
                       WHERE sc2.tplnr = regexp_replace(i.tplnr, '-[^-]+$', ''))
            END
        ),
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
    JOIN fl_scope sc ON sc.tplnr = i.tplnr          -- perimetre : racine + descendants
    JOIN fl_code  fc ON fc.tplnr = i.tplnr AND fc.mandt = i.mandt
    LEFT JOIN raw_data.iflos  s  ON s.tplnr  = i.tplnr AND s.mandt = i.mandt
    LEFT JOIN raw_data.iflotx xf ON xf.tplnr = i.tplnr AND xf.mandt = i.mandt AND xf.spras = 'F'
    LEFT JOIN raw_data.iflotx xe ON xe.tplnr = i.tplnr AND xe.mandt = i.mandt AND xe.spras = 'E'
    LEFT JOIN LATERAL (
        SELECT pltxt FROM raw_data.iflotx
        WHERE tplnr = i.tplnr AND mandt = i.mandt
          AND pltxt IS NOT NULL AND TRIM(pltxt) <> '' AND LOWER(TRIM(pltxt)) <> 'vide'
        LIMIT 1
    ) xa ON TRUE
    -- Poste de charge (ppsid) : lu dans ILOA, une vraie table, via iflot.iloan.
    -- raw_data.iflo est une VUE SAP, comme itob : non extractible de facon
    -- fiable, elle finirait vide ou perimee et ferait disparaitre le poste de
    -- charge des postes techniques. Chemin verifie strictement equivalent :
    -- 0 ecart de ppsid sur les 23 356 postes, 10 985 renseignes de part et
    -- d'autre. L'alias reste `fl` : les usages en aval ne changent pas.
    LEFT JOIN raw_data.iloa fl
        ON fl.iloan = i.iloan AND fl.mandt = i.mandt
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
    FROM (
        -- ------------------------------------------------------------------
        -- Equipements reconstitues DIRECTEMENT depuis les tables SAP extraites.
        -- raw_data.itob est une vue d'agregation SAP, donc non extractible :
        -- l'extraction avait laisse en place une table vide du meme nom, cette
        -- passe n'inserait plus rien et, faute de tplnr_sap, la passe 3b
        -- laissait 7 653 equipements sur 7 654 detaches de l'arbre IH02.
        --   equi = master equipement
        --   eqkt = designation (FR prioritaire, sinon premiere langue trouvee)
        --   equz = enregistrement courant (datbi = '99991231') -> iwerk/ingrp/iloan
        --   iloa = localisation via equz.iloan -> tplnr (le rattachement !)
        -- hequi (equipement superieur) n'existe dans AUCUNE table extraite :
        -- la hierarchie equipement -> equipement n'est pas reconstituable, seul
        -- le rattachement au poste technique l'est.
        -- ------------------------------------------------------------------
        SELECT
            e.mandt, e.equnr,
            COALESCE(kt_fr.eqktx, kt_any.eqktx) AS eqktx,
            e.eqart, e.eqtyp, e.herst, e.herld, e.typbz, e.sernr, e.invnr,
            e.groes, e.brgew, e.gewei, e.ansdt, e.answt, e.waers, e.elief,
            e.matnr, e.baujj, e.baumm, e.gwlen, e.gwldt, e.inbdt, e.erdat,
            e.ernam, e.aedat, e.aenam, e.lvorm, e.begru, e.warpl,
            ez2.iwerk, ez2.ingrp,
            il.tplnr, il.kostl, il.swerk, il.stort, il.beber, il.bukrs, il.gsber,
            NULL::varchar AS hequi
        FROM raw_data.equi e
        LEFT JOIN raw_data.eqkt kt_fr
               ON kt_fr.mandt = e.mandt AND kt_fr.equnr = e.equnr AND kt_fr.spras = 'F'
        LEFT JOIN LATERAL (
            SELECT eqktx FROM raw_data.eqkt
            WHERE mandt = e.mandt AND equnr = e.equnr
            ORDER BY (CASE WHEN spras = 'F' THEN 0 WHEN spras = 'E' THEN 1 ELSE 2 END)
            LIMIT 1
        ) kt_any ON TRUE
        LEFT JOIN raw_data.equz ez2
               ON ez2.mandt = e.mandt AND ez2.equnr = e.equnr AND ez2.datbi = '99991231'
        LEFT JOIN raw_data.iloa il
               ON il.mandt = ez2.mandt AND il.iloan = ez2.iloan
    ) t
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
        -- a) composants de nomenclature
        SELECT DISTINCT p.idnrk AS matnr, p.mandt
        FROM raw_data.stpo p
        WHERE p.stlty IN ('T', 'M')
          AND p.idnrk IS NOT NULL AND TRIM(p.idnrk) <> ''
        UNION
        -- b) TETE de nomenclature designee comme TYPE DE CONSTRUCTION (IBAU)
        --    d'un poste technique (cf. mode FULL, passe 4). Volontairement
        --    limite a submt : ouvrir a toutes les tetes de mast ajouterait
        --    10 627 articles inatteignables dans l'arbre.
        SELECT DISTINCT TRIM(f.submt), f.mandt
        FROM raw_data.iflo f
        WHERE NULLIF(TRIM(f.submt), '') IS NOT NULL
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

    -- -------------------------------------------------------------
    -- PASSE 4c : nomenclature d'un poste technique via son TYPE DE
    --   CONSTRUCTION (IBAU) : iflo.submt -> mara -> mast -> stpo (stlty='M').
    --   Rattachement A PLAT sous le poste, conforme a l'affichage SAP.
    --   Voir le commentaire detaille de la passe 5c du mode FULL
    --   (proc_load_maintenance_object.sql) : source iflo car iflot.submt est
    --   vide, tpst prime sur submt, prefixe 'S:' obligatoire pour ne pas
    --   entrer en collision avec les lignes 'M:' de la passe 4b.
    -- -------------------------------------------------------------
    SELECT COUNT(*) INTO v_tmp FROM raw_data.iflo;

    IF v_tmp = 0 THEN
        RAISE WARNING '[%] Passe 4c ignoree : raw_data.iflo est vide, le type de construction (submt) est introuvable -> les postes techniques sans tpst resteront sans nomenclature',
            TO_CHAR(CLOCK_TIMESTAMP(),'HH24:MI:SS');
    ELSE
        INSERT INTO mo_stg (
            object_type, sap_key, parent_type, parent_sap_key, ref_sap_key,
            sort_order, code, designation, category, quantity, unit, attributes
        )
        SELECT
            'BOM_ITEM',
            -- Le tplnr fait PARTIE DE LA CLE : un meme IBAU est partage par
            -- plusieurs postes techniques (cf. mode FULL, passe 5c).
            'S:' || sm.tplnr || ':' || sm.stlnr || ':'
                 || COALESCE(NULLIF(TRIM(sm.stlal), ''), '01')
                 || ':' || p.posnr || ':' || COALESCE(p.stlkn, ''),
            'FUNC_LOC',
            sm.tplnr,
            p.idnrk,
            NULLIF(regexp_replace(p.posnr, '[^0-9]', '', 'g'), '')::int,
            LTRIM(p.idnrk, '0'),
            art.designation,
            p.postp,
            NULLIF(regexp_replace(TRIM(p.menge), '[^0-9.]', '', 'g'), '')::numeric,
            p.meins,
            jsonb_strip_nulls(jsonb_build_object(
                'stlty', 'M', 'origin', 'SUBMT', 'submt', sm.submt,
                'stlnr', sm.stlnr, 'stlal', sm.stlal, 'stlan', sm.stlan,
                'posnr', p.posnr, 'stlkn', p.stlkn, 'postp', p.postp,
                'potx1', NULLIF(TRIM(p.potx1), ''), 'potx2', NULLIF(TRIM(p.potx2), ''),
                'base_quantity', k.bmeng, 'base_unit', k.bmein,
                'mandt', p.mandt
            ))
        FROM (
            SELECT DISTINCT ON (fs.tplnr)
                   fs.tplnr, fs.submt, m.stlnr, m.stlal, m.stlan, m.mandt
            FROM (
                SELECT DISTINCT ON (f.tplnr)
                       f.tplnr, f.mandt, NULLIF(TRIM(f.submt), '') AS submt
                FROM raw_data.iflo f
                JOIN fl_scope sc ON sc.tplnr = f.tplnr
                WHERE NULLIF(TRIM(f.submt), '') IS NOT NULL
                  AND NOT EXISTS (SELECT 1 FROM raw_data.tpst t
                                  WHERE t.tplnr = f.tplnr AND t.mandt = f.mandt)
                ORDER BY f.tplnr,
                         (CASE WHEN f.spras = 'F' THEN 0 WHEN f.spras = 'E' THEN 1 ELSE 2 END)
            ) fs
            JOIN raw_data.mast m ON m.matnr = fs.submt AND m.mandt = fs.mandt
            ORDER BY fs.tplnr,
                     (CASE WHEN m.werks = '9200' THEN 0 ELSE 1 END), m.stlal, m.stlnr
        ) sm
        JOIN raw_data.stpo p ON p.stlnr = sm.stlnr AND p.mandt = sm.mandt AND p.stlty = 'M'
        -- quantite de base de la nomenclature, comme la passe 4a le fait pour tpst
        LEFT JOIN raw_data.stko k
            ON k.stlnr = sm.stlnr AND k.mandt = sm.mandt AND k.stlty = 'M'
           AND k.stlal = sm.stlal
        JOIN mo_stg art ON art.object_type = 'ARTICLE' AND art.sap_key = p.idnrk
        WHERE EXISTS (SELECT 1 FROM mo_stg fl
                      WHERE fl.object_type = 'FUNC_LOC' AND fl.sap_key = sm.tplnr)
        ON CONFLICT (object_type, sap_key) DO NOTHING;
    END IF;

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
    -- PURGE DE PERIMETRE : ne conserver que la racine et ses descendants.
    --
    -- Necessaire EN PLUS du filtre a la lecture : un residu d'extraction
    -- precedente (autre indicateur de structure, ex. racine 'S') est absent
    -- du staging, donc jamais rafraichi — et la regle "disparu de SAP mais a
    -- des enfants" ci-dessous le conserverait indefiniment en le marquant
    -- seulement sap_missing. Sans cette purge, l'ecran cumule les structures.
    --
    -- Purge STRICTE (choix explicite) : un poste SAP hors perimetre est
    -- supprime MEME si l'utilisateur l'a modifie — c'est la seule facon de
    -- garantir "uniquement la racine et ses enfants" a l'ecran. La regle de
    -- protection updated_by ne s'applique donc pas ici ; le snapshot
    -- automatique pris avant chaque rechargement reste le filet de securite.
    -- Les creations utilisateur (source='MANUAL') sont conservees.
    -- Seuls les FUNC_LOC sont supprimes : leurs nomenclatures et equipements
    -- rattaches suivent via ON DELETE CASCADE. Les ARTICLE (hors arbre) et
    -- les EQUIPMENT sans poste porteur ne sont pas concernes.
    -- =============================================================
    IF NOT EXISTS (
        SELECT 1 FROM clean_data.maintenance_object
        WHERE object_type = 'FUNC_LOC' AND sap_key = p_root_tplnr
    ) THEN
        RAISE EXCEPTION
            'Racine "%" absente de clean_data apres fusion : purge de perimetre annulee',
            p_root_tplnr;
    END IF;

    WITH RECURSIVE keep AS (
        SELECT id FROM clean_data.maintenance_object
        WHERE object_type = 'FUNC_LOC' AND sap_key = p_root_tplnr
        UNION
        SELECT c.id
        FROM clean_data.maintenance_object c
        JOIN keep k ON c.parent_id = k.id
    )
    DELETE FROM clean_data.maintenance_object d
    WHERE d.object_type = 'FUNC_LOC'
      AND d.source = 'SAP'
      AND NOT EXISTS (SELECT 1 FROM keep WHERE keep.id = d.id);

    GET DIAGNOSTICS v_nb_purge = ROW_COUNT;

    IF v_nb_purge > 0 THEN
        RAISE NOTICE '[%] Purge hors perimetre "%": % postes techniques supprimes '
                     '(descendants emportes par CASCADE)',
            TO_CHAR(CLOCK_TIMESTAMP(),'HH24:MI:SS'), p_root_tplnr, v_nb_purge;
    END IF;

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
    DROP TABLE IF EXISTS pg_temp.fl_scope;

    -- =============================================================
    -- Cloture du log
    -- =============================================================
    UPDATE clean_data.etl_log
    SET end_ts      = CLOCK_TIMESTAMP(),
        status      = CASE WHEN v_nb_missing > 0 THEN 'WARNING' ELSE 'SUCCESS' END,
        nb_inserted = v_nb_ins,
        nb_updated  = v_nb_upd,
        nb_deleted  = v_nb_del + v_nb_purge,
        nb_rejected = v_nb_missing,
        message     = FORMAT(
            'Duree: %s s | perimetre: %s (%s postes) | ajoutes: %s | rafraichis: %s | '
            'supprimes: %s | purges hors perimetre: %s | '
            'disparus SAP conserves (ont des enfants): %s | '
            'lignes protegees (travail utilisateur): %s',
            EXTRACT(EPOCH FROM (CLOCK_TIMESTAMP() - v_start_ts))::INTEGER,
            p_root_tplnr, v_nb_scope,
            v_nb_ins, v_nb_upd, v_nb_del, v_nb_purge, v_nb_missing, v_nb_prot)
    WHERE id = v_log_id;

    RAISE NOTICE '[%] == Fin % — ajoutes:% rafraichis:% supprimes:% purges:% '
                 'disparus-conserves:% proteges:% (duree %s s)',
        TO_CHAR(CLOCK_TIMESTAMP(),'HH24:MI:SS'), v_proc,
        v_nb_ins, v_nb_upd, v_nb_del, v_nb_purge, v_nb_missing, v_nb_prot,
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

COMMENT ON PROCEDURE clean_data.load_maintenance_object_merge(TEXT) IS
'Rechargement NON destructif de clean_data.maintenance_object depuis raw_data.
 Preserve integralement les lignes touchees par l''utilisateur (source=MANUAL
 ou updated_by IS NOT NULL) : ni mises a jour, ni deplacees, ni supprimees.
 Rafraichit les autres lignes SAP et ajoute les nouveautes, en conservant les
 id internes (donc les rattachements manuels). SEULE exception a la protection :
 la purge de perimetre, qui supprime les postes techniques SAP hors de
 p_root_tplnr (defaut ''T'') et de ses descendants, meme modifies. Pendant non
 destructif de clean_data.load_maintenance_object(). Appel :
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
