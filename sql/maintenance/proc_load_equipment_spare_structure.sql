-- =============================================================
-- Procédure stockée : clean_data.load_equipment_spare_structure
-- Objectif  : Alimenter la structure kit -> composants depuis raw_data
--             (MAST / STKO / STPO, nomenclature matière stlty='M').
-- Mode FULL : TRUNCATE + INSERT complet
-- Mode DELTA: suppression + réinjection d'un sous-arbre (ou tous)
-- Auteur    : généré automatiquement
--
-- PÉRIMÈTRE (restreint aux postes techniques) :
--   On n'insère QUE les articles dont le parent est un article lui-même
--   rattaché à un poste technique. Autrement dit :
--     poste technique → article B → article C ( … récursif)
--   Les RACINES B sont les articles rattachés à un poste technique =
--   clean_data.equipment_object_spare.spare_id (catégorie L, postes actifs).
--   On explose ensuite la nomenclature matière de B de façon RÉCURSIVE
--   (un composant qui est lui-même un kit est éclaté à son tour).
--
-- Pas de filtre mtart : tout article ayant une nomenclature matière compte
--   comme kit (ERSA, HIBE, HALB, …).
--
-- Hiérarchie : le spare_seq est ordonné par niveau -> les PARENTS sont
--   insérés AVANT les composants.
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. PROCÉDURE PRINCIPALE
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE clean_data.load_equipment_spare_structure(
    p_mode        VARCHAR DEFAULT 'FULL',    -- 'FULL' | 'DELTA'
    p_spare_id    VARCHAR DEFAULT NULL       -- DELTA : recharger un sous-arbre précis
                                             --         (racine B = spare_id) ; NULL = tous
)
LANGUAGE plpgsql
AS $$
DECLARE
    -- Compteurs
    v_nb_inserted   BIGINT  := 0;
    v_nb_updated    BIGINT  := 0;
    v_nb_deleted    BIGINT  := 0;
    v_nb_rejected   BIGINT  := 0;
    v_nb_src        BIGINT  := 0;

    -- Exécution
    v_start_ts      TIMESTAMP := CLOCK_TIMESTAMP();
    v_log_id        BIGINT;
    v_err_msg       TEXT;
    v_proc          CONSTANT VARCHAR := 'load_equipment_spare_structure';

BEGIN

    -- ── Validation paramètre ─────────────────────────────────
    IF p_mode NOT IN ('FULL', 'DELTA') THEN
        RAISE EXCEPTION 'Paramètre p_mode invalide : %. Valeurs acceptées : FULL, DELTA', p_mode;
    END IF;

    -- ── Ouverture du log ─────────────────────────────────────
    INSERT INTO clean_data.etl_log (procedure_name, mode, status)
    VALUES (v_proc, p_mode, 'RUNNING')
    RETURNING id INTO v_log_id;

    RAISE NOTICE '[%] ══ Début % (mode=%, spare_id=%)',
        TO_CHAR(v_start_ts, 'HH24:MI:SS'), v_proc, p_mode,
        COALESCE(p_spare_id, 'TOUS');


    -- ═══════════════════════════════════════════════════════════
    -- MODE FULL — Rechargement complet
    -- ═══════════════════════════════════════════════════════════
    IF p_mode = 'FULL' THEN

        RAISE NOTICE '[%] Truncate de la table cible…',
            TO_CHAR(CLOCK_TIMESTAMP(), 'HH24:MI:SS');

        TRUNCATE TABLE clean_data.equipment_spare_structure;

        -- ── Insertion complète ────────────────────────────────
        WITH RECURSIVE werks_mapping (sap_werks, ifs_contract) AS (
            VALUES
                ('9200', 'SJ'),   -- ⚠️ Adapter selon votre configuration
                ('2200', 'CS')    -- ⚠️ Adapter selon votre configuration
        ),
        -- Racines B : articles rattachés à un poste technique
        roots AS (
            SELECT DISTINCT spare_id::text AS matnr
            FROM clean_data.equipment_object_spare
        ),
        -- Toutes les arêtes de nomenclature matière (kit -> composant), tous mtart
        edges AS (
            SELECT
                TRIM(mst.werks)                                AS werks,
                TRIM(LEADING '0' FROM TRIM(mst.matnr))::text   AS parent_id,
                TRIM(LEADING '0' FROM TRIM(spo.idnrk))::text   AS child_id,
                NULLIF(TRIM(spo.pswrk), '')                    AS child_werks,
                ROUND(CAST(REGEXP_REPLACE(TRIM(spo.menge), '[^0-9.]', '', 'g') AS NUMERIC), 0) AS qty
            FROM raw_data.mast mst
            JOIN raw_data.stko sko ON sko.stlnr = mst.stlnr AND sko.stlty = 'M'
            JOIN raw_data.stpo spo ON spo.stlnr = sko.stlnr AND spo.stlty = sko.stlty
            WHERE spo.postp  = 'L'
              AND TRIM(spo.menge) <> ''
              AND TRIM(spo.idnrk) <> ''
        ),
        -- Descente récursive depuis les racines B (parents avant composants)
        hier AS (
            SELECT r.matnr AS matnr, 1 AS lvl, ARRAY[r.matnr] AS path
            FROM roots r
            UNION ALL
            SELECT e.child_id, h.lvl + 1, h.path || e.child_id
            FROM hier h
            JOIN edges e ON e.parent_id = h.matnr
            WHERE e.child_id <> ALL (h.path)   -- anti-cycle
              AND h.lvl < 50                    -- garde-fou de profondeur
        ),
        kit_level AS (
            SELECT matnr, MIN(lvl) AS lvl FROM hier GROUP BY matnr
        ),
        source AS (
            SELECT
                ROW_NUMBER() OVER (
                    ORDER BY kl.lvl, e.werks, e.parent_id, e.child_id
                )                                                   AS spare_seq,
                COALESCE(wm.ifs_contract, e.werks)                  AS spare_contract,
                e.parent_id                                         AS spare_id,
                e.child_id                                          AS component_spare_id,
                COALESCE(
                    wm2.ifs_contract,
                    e.child_werks,
                    COALESCE(wm.ifs_contract, e.werks)
                )                                                   AS component_spare_contract,
                e.qty                                               AS qty
            FROM edges e
            -- INNER JOIN : on ne garde que les arêtes dont le PARENT est
            -- atteignable depuis une racine B (rattachée à un poste technique)
            JOIN kit_level     kl  ON  kl.matnr      = e.parent_id
            LEFT JOIN werks_mapping wm  ON  wm.sap_werks  = e.werks
            LEFT JOIN werks_mapping wm2 ON  wm2.sap_werks = e.child_werks
        )
        INSERT INTO clean_data.equipment_spare_structure (
            spare_seq,
            spare_contract,
            spare_id,
            component_spare_id,
            component_spare_contract,
            qty,
            part_ownership_db,
            created_at,
            updated_at
        )
        SELECT
            src.spare_seq,
            src.spare_contract,
            src.spare_id,
            src.component_spare_id,
            src.component_spare_contract,
            src.qty,
            'COMPANY OWNED',
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
        FROM source src
        WHERE src.qty IS NOT NULL       -- Exclure les quantités non convertibles
          AND src.qty > 0;             -- Exclure les quantités nulles ou négatives

        GET DIAGNOSTICS v_nb_inserted = ROW_COUNT;
        v_nb_src := v_nb_inserted;   -- pas de rejet métier ici (on insère tout l'arbre)

        RAISE NOTICE '[%] FULL terminé — insérés: %',
            TO_CHAR(CLOCK_TIMESTAMP(), 'HH24:MI:SS'), v_nb_inserted;


    -- ═══════════════════════════════════════════════════════════
    -- MODE DELTA — Rechargement ciblé (sous-arbre d'une racine B)
    -- ═══════════════════════════════════════════════════════════
    ELSIF p_mode = 'DELTA' THEN

        -- Supprimer le sous-arbre existant concerné
        IF p_spare_id IS NULL THEN
            DELETE FROM clean_data.equipment_spare_structure;
        ELSE
            WITH RECURSIVE edges AS (
                SELECT
                    TRIM(LEADING '0' FROM TRIM(mst.matnr))::text AS parent_id,
                    TRIM(LEADING '0' FROM TRIM(spo.idnrk))::text AS child_id
                FROM raw_data.mast mst
                JOIN raw_data.stko sko ON sko.stlnr = mst.stlnr AND sko.stlty = 'M'
                JOIN raw_data.stpo spo ON spo.stlnr = sko.stlnr AND spo.stlty = sko.stlty
                WHERE spo.postp = 'L' AND TRIM(spo.idnrk) <> ''
            ),
            subtree AS (
                SELECT p_spare_id::text AS matnr, ARRAY[p_spare_id::text] AS path
                UNION ALL
                SELECT e.child_id, s.path || e.child_id
                FROM subtree s
                JOIN edges e ON e.parent_id = s.matnr
                WHERE e.child_id <> ALL (s.path)
                  AND array_length(s.path, 1) < 50
            )
            DELETE FROM clean_data.equipment_spare_structure
            WHERE spare_id IN (SELECT matnr FROM subtree);
        END IF;

        GET DIAGNOSTICS v_nb_deleted = ROW_COUNT;

        RAISE NOTICE '[%] Lignes supprimées avant réinjection : %',
            TO_CHAR(CLOCK_TIMESTAMP(), 'HH24:MI:SS'), v_nb_deleted;

        -- Réinjection (racines filtrées par p_spare_id), seq à partir du MAX
        WITH RECURSIVE werks_mapping (sap_werks, ifs_contract) AS (
            VALUES
                ('9200', 'SJ'),   -- ⚠️ Adapter selon votre configuration
                ('2200', 'CS')    -- ⚠️ Adapter selon votre configuration
        ),
        max_seq AS (
            SELECT COALESCE(MAX(spare_seq), 0) AS last_seq
            FROM clean_data.equipment_spare_structure
        ),
        roots AS (
            SELECT DISTINCT spare_id::text AS matnr
            FROM clean_data.equipment_object_spare
            WHERE (p_spare_id IS NULL OR spare_id = p_spare_id)
        ),
        edges AS (
            SELECT
                TRIM(mst.werks)                                AS werks,
                TRIM(LEADING '0' FROM TRIM(mst.matnr))::text   AS parent_id,
                TRIM(LEADING '0' FROM TRIM(spo.idnrk))::text   AS child_id,
                NULLIF(TRIM(spo.pswrk), '')                    AS child_werks,
                ROUND(CAST(REGEXP_REPLACE(TRIM(spo.menge), '[^0-9.]', '', 'g') AS NUMERIC), 0) AS qty
            FROM raw_data.mast mst
            JOIN raw_data.stko sko ON sko.stlnr = mst.stlnr AND sko.stlty = 'M'
            JOIN raw_data.stpo spo ON spo.stlnr = sko.stlnr AND spo.stlty = sko.stlty
            WHERE spo.postp  = 'L'
              AND TRIM(spo.menge) <> ''
              AND TRIM(spo.idnrk) <> ''
        ),
        hier AS (
            SELECT r.matnr AS matnr, 1 AS lvl, ARRAY[r.matnr] AS path
            FROM roots r
            UNION ALL
            SELECT e.child_id, h.lvl + 1, h.path || e.child_id
            FROM hier h
            JOIN edges e ON e.parent_id = h.matnr
            WHERE e.child_id <> ALL (h.path)
              AND h.lvl < 50
        ),
        kit_level AS (
            SELECT matnr, MIN(lvl) AS lvl FROM hier GROUP BY matnr
        ),
        source AS (
            SELECT
                (SELECT last_seq FROM max_seq)
                + ROW_NUMBER() OVER (
                    ORDER BY kl.lvl, e.werks, e.parent_id, e.child_id
                )                                                   AS spare_seq,
                COALESCE(wm.ifs_contract, e.werks)                  AS spare_contract,
                e.parent_id                                         AS spare_id,
                e.child_id                                          AS component_spare_id,
                COALESCE(
                    wm2.ifs_contract,
                    e.child_werks,
                    COALESCE(wm.ifs_contract, e.werks)
                )                                                   AS component_spare_contract,
                e.qty                                               AS qty
            FROM edges e
            JOIN kit_level     kl  ON  kl.matnr      = e.parent_id
            LEFT JOIN werks_mapping wm  ON  wm.sap_werks  = e.werks
            LEFT JOIN werks_mapping wm2 ON  wm2.sap_werks = e.child_werks
        )
        INSERT INTO clean_data.equipment_spare_structure (
            spare_seq,
            spare_contract,
            spare_id,
            component_spare_id,
            component_spare_contract,
            qty,
            part_ownership_db,
            created_at,
            updated_at
        )
        SELECT
            src.spare_seq,
            src.spare_contract,
            src.spare_id,
            src.component_spare_id,
            src.component_spare_contract,
            src.qty,
            'COMPANY OWNED',
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
        FROM source src
        WHERE src.qty IS NOT NULL AND src.qty > 0;

        GET DIAGNOSTICS v_nb_inserted = ROW_COUNT;

        RAISE NOTICE '[%] DELTA terminé — supprimés: %, insérés: %',
            TO_CHAR(CLOCK_TIMESTAMP(), 'HH24:MI:SS'),
            v_nb_deleted, v_nb_inserted;
    END IF;


    -- ── Fermeture du log (SUCCESS) ────────────────────────────
    UPDATE clean_data.etl_log
    SET end_ts      = CLOCK_TIMESTAMP(),
        status      = CASE WHEN v_nb_rejected > 0 THEN 'WARNING' ELSE 'SUCCESS' END,
        nb_inserted = v_nb_inserted,
        nb_updated  = v_nb_updated,
        nb_deleted  = v_nb_deleted,
        nb_rejected = v_nb_rejected,
        message     = FORMAT(
            'Durée : %s s | src: %s | insérés: %s | supprimés: %s | rejetés: %s',
            EXTRACT(EPOCH FROM (CLOCK_TIMESTAMP() - v_start_ts))::INTEGER,
            v_nb_src, v_nb_inserted, v_nb_deleted, v_nb_rejected
        )
    WHERE id = v_log_id;

    RAISE NOTICE '[%] ══ Fin % — statut: % — durée: %s s',
        TO_CHAR(CLOCK_TIMESTAMP(), 'HH24:MI:SS'), v_proc,
        CASE WHEN v_nb_rejected > 0 THEN 'WARNING' ELSE 'SUCCESS' END,
        EXTRACT(EPOCH FROM (CLOCK_TIMESTAMP() - v_start_ts))::INTEGER;


-- ── Gestion des erreurs ───────────────────────────────────────
EXCEPTION WHEN OTHERS THEN

    GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT;

    UPDATE clean_data.etl_log
    SET end_ts  = CLOCK_TIMESTAMP(),
        status  = 'ERROR',
        message = v_err_msg
    WHERE id = v_log_id;

    RAISE EXCEPTION '[%] ERREUR dans % : %',
        TO_CHAR(CLOCK_TIMESTAMP(), 'HH24:MI:SS'), v_proc, v_err_msg;

END;
$$;

COMMENT ON PROCEDURE clean_data.load_equipment_spare_structure IS
    'Charge la structure kit -> composants (equipment_spare_structure) depuis
     la nomenclature matière SAP (MAST/STKO/STPO stlty=M), tout mtart.
     PÉRIMÈTRE : uniquement les articles dont le parent est un article rattaché
     à un poste technique. Racines B = equipment_object_spare.spare_id ;
     explosion RÉCURSIVE de leur nomenclature (parents avant composants).
     FULL  : Truncate + rechargement complet.
     DELTA : Suppression + réinjection du sous-arbre d''une racine (p_spare_id)
             ou de tout si p_spare_id est NULL.
     Dépendance : equipment_object_spare doit être alimentée AVANT.';


-- =============================================================
-- EXEMPLES D'APPEL
-- =============================================================

-- Rechargement complet :
-- CALL clean_data.load_equipment_spare_structure('FULL');

-- Rechargement delta de tout :
-- CALL clean_data.load_equipment_spare_structure('DELTA');

-- Rechargement delta d'un sous-arbre précis (racine B) :
-- CALL clean_data.load_equipment_spare_structure('DELTA', '609515');

-- Consulter le journal d'exécution :
-- SELECT * FROM clean_data.etl_log
-- WHERE procedure_name = 'load_equipment_spare_structure'
-- ORDER BY start_ts DESC
-- LIMIT 20;
