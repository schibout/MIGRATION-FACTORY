-- =============================================================
-- Procédure stockée : clean_data.load_equipment_object_spare
-- Cible     : clean_data.equipment_object_spare
--             (pièces de rechange rattachées à un objet d'équipement)
-- Objectif  : Alimenter la table depuis la NOMENCLATURE DES POSTES TECHNIQUES
--             (écran IH02) : tous les articles ayant un poste technique
--             comme parent.
-- Mode FULL : TRUNCATE + INSERT complet
-- Mode DELTA: suppression + réinjection d'un poste technique précis (ou tous)
-- Auteur    : généré automatiquement
--
-- Source : clean_data.v_fl_nomenclature (vue matérialisée)
--            = raw_data.tpst → stko (stlty='T') → stpo (stlty='T')
--          C'est la BOM des postes techniques affichée dans l'écran IH02
--          (route /api/.../ih02/bom/<tplnr>).
--
-- Mapping :
--   equipment_object_seq  = le CODE du POSTE TECHNIQUE (mch_code = tplnr_display),
--                           validé contre clean_data.equipment_functional
--                           (contract = 'SJ'). ⚠️ On stocke le mch_code (texte),
--                           pas la séquence interne -> la colonne cible est
--                           passée en VARCHAR (voir ALTER ci-dessous).
--   spare_id              = l'article (inventory_part) = matnr_short
--                           (idnrk sans zéros de tête).
--
-- Filtre item_category='L' : postes ARTICLE stock uniquement (vrais
--   inventory_part). Les catégories I (structure PM), Z, Y, T (texte),
--   N (non-stock), X, D (document) sont écartées.
--
-- Déduplication : un même article peut apparaître à plusieurs positions
--   (posnr) sous un même poste -> 1 seule ligne par (poste, article), les
--   quantités sont SOMMÉES.
--
-- Rejets : un poste technique absent de equipment_functional (archivé /
--   hors hiérarchie active) ne peut être rattaché -> ses articles sont rejetés.
--
-- has_spare_structure / objversion : IN_SCOPE=NO dans la spec IFS -> NULL.
-- allow_wo_mat_site = 'FALSE' ; part_ownership_db = 'COMPANY OWNED'.
-- =============================================================

CREATE OR REPLACE PROCEDURE clean_data.load_equipment_object_spare(
    p_mode        VARCHAR DEFAULT 'FULL',    -- 'FULL' | 'DELTA'
    p_tplnr       VARCHAR DEFAULT NULL       -- DELTA : recharger un poste technique précis
                                             --         (mch_code = tplnr_display) ; NULL = tous
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
    v_proc          CONSTANT VARCHAR := 'load_equipment_object_spare';

BEGIN

    -- ── Validation paramètre ─────────────────────────────────
    IF p_mode NOT IN ('FULL', 'DELTA') THEN
        RAISE EXCEPTION 'Paramètre p_mode invalide : %. Valeurs acceptées : FULL, DELTA', p_mode;
    END IF;

    -- ── Ouverture du log ─────────────────────────────────────
    INSERT INTO clean_data.etl_log (procedure_name, mode, status)
    VALUES (v_proc, p_mode, 'RUNNING')
    RETURNING id INTO v_log_id;

    RAISE NOTICE '[%] ══ Début % (mode=%, tplnr=%)',
        TO_CHAR(v_start_ts, 'HH24:MI:SS'), v_proc, p_mode,
        COALESCE(p_tplnr, 'TOUS');


    -- ═══════════════════════════════════════════════════════════
    -- MODE FULL — Rechargement complet
    -- ═══════════════════════════════════════════════════════════
    IF p_mode = 'FULL' THEN

        RAISE NOTICE '[%] Truncate de la table cible…',
            TO_CHAR(CLOCK_TIMESTAMP(), 'HH24:MI:SS');

        TRUNCATE TABLE clean_data.equipment_object_spare;

        -- ── Insertion complète ────────────────────────────────
        WITH ef_uniq AS (
            -- Postes techniques valides (actifs) ; 1 ligne par mch_code
            SELECT DISTINCT mch_code, contract
            FROM clean_data.equipment_functional
            WHERE contract = 'SJ'
        ),
        -- Composants de nomenclature de poste technique (= pièces de rechange)
        bom AS (
            SELECT
                ef.mch_code                                                          AS equipment_object_seq,  -- code poste technique
                ef.contract,
                v.matnr_short                                                        AS spare_id,
                ROUND(CAST(REGEXP_REPLACE(TRIM(v.quantity), '[^0-9.]', '', 'g') AS NUMERIC), 0) AS qty
            FROM clean_data.v_fl_nomenclature v
            JOIN ef_uniq ef ON ef.mch_code = v.tplnr_display
            WHERE v.item_category = 'L'               -- articles stock uniquement
              AND v.idnrk IS NOT NULL AND TRIM(v.idnrk) <> ''
              AND TRIM(v.quantity) <> ''
        ),
        -- 1 ligne par (poste, article) : quantités sommées
        agg AS (
            SELECT equipment_object_seq, contract, spare_id, SUM(qty) AS qty
            FROM bom
            WHERE qty IS NOT NULL AND qty > 0
            GROUP BY equipment_object_seq, contract, spare_id
        ),
        source AS (
            SELECT
                ROW_NUMBER() OVER (ORDER BY equipment_object_seq, spare_id) AS mch_spare_seq,
                contract,
                equipment_object_seq,
                contract                                                   AS spare_contract,
                spare_id,
                qty
            FROM agg
        )
        INSERT INTO clean_data.equipment_object_spare (
            mch_spare_seq,
            contract,
            equipment_object_seq,
            spare_contract,
            spare_id,
            qty,
            part_ownership_db,
            allow_wo_mat_site
        )
        SELECT
            src.mch_spare_seq,
            src.contract,
            src.equipment_object_seq,
            src.spare_contract,
            src.spare_id,
            src.qty,
            'COMPANY OWNED',
            'FALSE'                     -- booléen IFS (_db) en MAJUSCULE
        FROM source src;

        GET DIAGNOSTICS v_nb_inserted = ROW_COUNT;

        -- Couples (poste, article) sources vs insérés -> rejets
        -- (rejet principal = poste technique absent de equipment_functional)
        SELECT COUNT(*) INTO v_nb_src
        FROM (
            SELECT DISTINCT v.tplnr_display, v.matnr_short
            FROM clean_data.v_fl_nomenclature v
            WHERE v.item_category = 'L'
              AND v.idnrk IS NOT NULL AND TRIM(v.idnrk) <> ''
              AND TRIM(v.quantity) <> ''
        ) s;

        v_nb_rejected := GREATEST(v_nb_src - v_nb_inserted, 0);

        RAISE NOTICE '[%] FULL terminé — couples source: %, insérés: %, rejetés (postes non rattachés): %',
            TO_CHAR(CLOCK_TIMESTAMP(), 'HH24:MI:SS'),
            v_nb_src, v_nb_inserted, v_nb_rejected;


    -- ═══════════════════════════════════════════════════════════
    -- MODE DELTA — Rechargement ciblé (poste(s) technique(s) modifié(s))
    -- ═══════════════════════════════════════════════════════════
    ELSIF p_mode = 'DELTA' THEN

        -- Supprimer les lignes existantes concernées
        -- (equipment_object_seq contient désormais le mch_code du poste)
        DELETE FROM clean_data.equipment_object_spare eos
        WHERE (p_tplnr IS NULL)                              -- Tous
           OR eos.equipment_object_seq = p_tplnr;           -- Ou poste précis

        GET DIAGNOSTICS v_nb_deleted = ROW_COUNT;

        RAISE NOTICE '[%] Lignes supprimées avant réinjection : %',
            TO_CHAR(CLOCK_TIMESTAMP(), 'HH24:MI:SS'), v_nb_deleted;

        -- Recalcul du mch_spare_seq à partir du MAX existant
        WITH ef_uniq AS (
            SELECT DISTINCT mch_code, contract
            FROM clean_data.equipment_functional
            WHERE contract = 'SJ'
        ),
        max_seq AS (
            SELECT COALESCE(MAX(mch_spare_seq), 0) AS last_seq
            FROM clean_data.equipment_object_spare
        ),
        bom AS (
            SELECT
                ef.mch_code                                                          AS equipment_object_seq,
                ef.contract,
                v.matnr_short                                                        AS spare_id,
                ROUND(CAST(REGEXP_REPLACE(TRIM(v.quantity), '[^0-9.]', '', 'g') AS NUMERIC), 0) AS qty
            FROM clean_data.v_fl_nomenclature v
            JOIN ef_uniq ef ON ef.mch_code = v.tplnr_display
            WHERE v.item_category = 'L'
              AND v.idnrk IS NOT NULL AND TRIM(v.idnrk) <> ''
              AND TRIM(v.quantity) <> ''
              AND (p_tplnr IS NULL OR v.tplnr = p_tplnr OR v.tplnr_display = p_tplnr)
        ),
        agg AS (
            SELECT equipment_object_seq, contract, spare_id, SUM(qty) AS qty
            FROM bom
            WHERE qty IS NOT NULL AND qty > 0
            GROUP BY equipment_object_seq, contract, spare_id
        ),
        source AS (
            SELECT
                (SELECT last_seq FROM max_seq)
                + ROW_NUMBER() OVER (ORDER BY equipment_object_seq, spare_id) AS mch_spare_seq,
                contract,
                equipment_object_seq,
                contract                                                     AS spare_contract,
                spare_id,
                qty
            FROM agg
        )
        INSERT INTO clean_data.equipment_object_spare (
            mch_spare_seq,
            contract,
            equipment_object_seq,
            spare_contract,
            spare_id,
            qty,
            part_ownership_db,
            allow_wo_mat_site
        )
        SELECT
            src.mch_spare_seq,
            src.contract,
            src.equipment_object_seq,
            src.spare_contract,
            src.spare_id,
            src.qty,
            'COMPANY OWNED',
            'FALSE'                     -- booléen IFS (_db) en MAJUSCULE
        FROM source src;

        GET DIAGNOSTICS v_nb_inserted = ROW_COUNT;

        RAISE NOTICE '[%] DELTA terminé — supprimés: %, insérés: %',
            TO_CHAR(CLOCK_TIMESTAMP(), 'HH24:MI:SS'),
            v_nb_deleted, v_nb_inserted;
    END IF;


    -- ── Fermeture du log (SUCCESS/WARNING) ────────────────────
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

COMMENT ON PROCEDURE clean_data.load_equipment_object_spare IS
    'Charge la table equipment_object_spare (pièces de rechange par objet
     d''équipement) depuis la nomenclature des POSTES TECHNIQUES (écran IH02) :
     clean_data.v_fl_nomenclature (TPST → STKO stlty=T → STPO stlty=T),
     articles item_category=L uniquement.
     equipment_object_seq = CODE du poste technique (mch_code = tplnr_display),
     validé dans equipment_functional (contract=SJ). spare_id = matnr_short.
     1 ligne par (poste, article), quantités sommées.
     FULL  : Truncate + rechargement complet.
     DELTA : Suppression + réinjection pour un poste (p_tplnr = mch_code /
             tplnr_display) ou tous les postes si p_tplnr est NULL.';


-- =============================================================
-- EXEMPLES D'APPEL
-- =============================================================

-- Rechargement complet :
-- CALL clean_data.load_equipment_object_spare('FULL');

-- Rechargement delta de tous les postes :
-- CALL clean_data.load_equipment_object_spare('DELTA');

-- Rechargement delta d'un poste technique précis (mch_code / tplnr_display) :
-- CALL clean_data.load_equipment_object_spare('DELTA', 'T340-E100-1005');

-- Consulter le journal d'exécution :
-- SELECT * FROM clean_data.etl_log
-- WHERE procedure_name = 'load_equipment_object_spare'
-- ORDER BY start_ts DESC
-- LIMIT 20;

-- Rafraîchir la source avant un rechargement (si les tables SAP ont changé) :
-- REFRESH MATERIALIZED VIEW clean_data.v_fl_nomenclature;
