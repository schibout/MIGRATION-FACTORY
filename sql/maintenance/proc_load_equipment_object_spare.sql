-- =============================================================
-- Procédure stockée : clean_data.load_equipment_object_spare
-- Cible     : clean_data.equipment_object_spare
--             (pièces détachées CONNECTÉES : rattachées à un objet)
--
-- Règle métier (2026-11-16) : TOUTES les pièces détachées présentes dans la
-- structure IH02 (clean_data.maintenance_object) sous un objet exporté :
--   - objet fonctionnel = poste technique de equipment_functional ;
--   - objet série       = équipement de equipment_serial.
-- Toutes catégories de poste de nomenclature (L, I, N, X, Y, Z, vide...).
-- Règle du 2026-11-17 : on S'ARRÊTE aux articles PARENTS (directement sous
-- l'objet) ; leurs composants vont dans equipment_spare_structure.
-- MCH_PART (« Classification d'article » IFS, 2026-11-22) = position du poste
-- de nomenclature IH02 (attributes.posnr), exactement 4 caractères (ex. 0090).
-- Un article peut être à plusieurs positions sous un même objet : 1 ligne par
-- (objet, article, position) ; même position répétée -> quantités SOMMÉES.
--
-- equipment_object_seq = CODE de l'objet (mch_code), pas la séquence interne.
-- spare_id = code article (matnr sans zéros de tête).
-- Rejets : pièces sous un objet non exporté (archivé / hors hiérarchie), code
--   article de plus de 25 caractères (saisie manuelle IH02) ou
--   de quantité vide / nulle.
--
-- has_spare_structure / objversion : IN_SCOPE=NO dans la spec IFS -> NULL.
-- allow_wo_mat_site = 'FALSE' ; part_ownership_db = 'COMPANY OWNED'.
-- =============================================================

CREATE OR REPLACE VIEW clean_data.v_object_spare_export AS
-- Pièces PARENTS uniquement : postes de nomenclature directement sous l'objet.
-- Leurs composants sortent dans equipment_spare_structure (kit -> composants).
SELECT o.code AS mch_code, a.code AS spare_id, b.quantity::numeric AS qty, 1 AS lvl,
       -- MCH_PART : position sur 4 caractères (posnr SAP CHAR(4)) ; au-delà -> NULL
       CASE WHEN length(TRIM(b.attributes->>'posnr')) <= 4
            THEN lpad(TRIM(b.attributes->>'posnr'), 4, '0') END AS mch_part
FROM clean_data.maintenance_object b
JOIN clean_data.maintenance_object o
  ON o.id = b.parent_id AND o.object_type IN ('FUNC_LOC', 'EQUIPMENT') AND o.is_active
JOIN clean_data.maintenance_object a
  ON a.id = b.ref_object_id AND a.object_type = 'ARTICLE'
WHERE b.object_type = 'BOM_ITEM' AND b.is_active;

COMMENT ON VIEW clean_data.v_object_spare_export IS
'Pièces détachées connectées pour equipment_object_spare : articles PARENTS directement
 sous un poste technique ou un équipement dans IH02, toutes catégories. Les composants
 de ces articles sortent dans equipment_spare_structure.';

-- Remplacée par v_object_spare_export (plus utilisée).
DROP VIEW IF EXISTS clean_data.v_eq_nomenclature_export;

CREATE OR REPLACE PROCEDURE clean_data.load_equipment_object_spare(
    p_mode        VARCHAR DEFAULT 'FULL',    -- 'FULL' | 'DELTA'
    p_tplnr       VARCHAR DEFAULT NULL       -- DELTA : code d'un objet précis
                                             --         (mch_code) ; NULL = tous
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_nb_inserted   BIGINT  := 0;
    v_nb_updated    BIGINT  := 0;
    v_nb_deleted    BIGINT  := 0;
    v_nb_rejected   BIGINT  := 0;
    v_nb_src        BIGINT  := 0;
    v_last_seq      BIGINT  := 0;

    v_start_ts      TIMESTAMP := CLOCK_TIMESTAMP();
    v_log_id        BIGINT;
    v_err_msg       TEXT;
    v_proc          CONSTANT VARCHAR := 'load_equipment_object_spare';
BEGIN

    IF p_mode NOT IN ('FULL', 'DELTA') THEN
        RAISE EXCEPTION 'Paramètre p_mode invalide : %. Valeurs acceptées : FULL, DELTA', p_mode;
    END IF;

    INSERT INTO clean_data.etl_log (procedure_name, mode, status)
    VALUES (v_proc, p_mode, 'RUNNING')
    RETURNING id INTO v_log_id;

    RAISE NOTICE '[%] ══ Début % (mode=%, objet=%)',
        TO_CHAR(v_start_ts, 'HH24:MI:SS'), v_proc, p_mode, COALESCE(p_tplnr, 'TOUS');

    IF p_mode = 'FULL' THEN
        TRUNCATE TABLE clean_data.equipment_object_spare;
    ELSE
        DELETE FROM clean_data.equipment_object_spare eos
        WHERE p_tplnr IS NULL OR eos.equipment_object_seq = p_tplnr;
        GET DIAGNOSTICS v_nb_deleted = ROW_COUNT;
        SELECT COALESCE(MAX(mch_spare_seq), 0) INTO v_last_seq
        FROM clean_data.equipment_object_spare;
    END IF;

    WITH objets AS (
        -- Objets exportés : fonctionnels (postes techniques) et série (équipements)
        SELECT DISTINCT mch_code, contract FROM clean_data.equipment_functional WHERE contract = 'SJ'
        UNION
        SELECT DISTINCT mch_code, contract FROM clean_data.equipment_serial WHERE contract = 'SJ'
    ),
    agg AS (
        SELECT ob.mch_code AS equipment_object_seq, ob.contract, v.spare_id, v.mch_part,
               ROUND(SUM(v.qty), 0) AS qty, MIN(v.lvl) AS lvl
        FROM clean_data.v_object_spare_export v
        JOIN objets ob ON ob.mch_code = v.mch_code
        WHERE (p_tplnr IS NULL OR v.mch_code = p_tplnr)
          -- Code article IFS limité à 25 car. : les articles saisis à la main
          -- avec un libellé comme code (source MANUAL) sont rejetés, à corriger dans IH02.
          AND length(v.spare_id) <= 25
        GROUP BY ob.mch_code, ob.contract, v.spare_id, v.mch_part
    )
    INSERT INTO clean_data.equipment_object_spare (
        mch_spare_seq, contract, equipment_object_seq, spare_contract,
        spare_id, mch_part, qty, part_ownership_db, allow_wo_mat_site
    )
    SELECT
        v_last_seq + ROW_NUMBER() OVER (ORDER BY lvl, equipment_object_seq, mch_part, spare_id),  -- parents avant enfants
        contract, equipment_object_seq, contract, spare_id, mch_part, qty,
        'COMPANY OWNED',
        'FALSE'                     -- booléen IFS (_db) en MAJUSCULE
    FROM agg
    WHERE qty IS NOT NULL AND qty > 0;

    GET DIAGNOSTICS v_nb_inserted = ROW_COUNT;

    -- Triplets (objet, article, position) source vs insérés -> rejets
    SELECT COUNT(DISTINCT (mch_code, spare_id, mch_part)) INTO v_nb_src
    FROM clean_data.v_object_spare_export
    WHERE p_tplnr IS NULL OR mch_code = p_tplnr;

    v_nb_rejected := GREATEST(v_nb_src - v_nb_inserted, 0);

    RAISE NOTICE '[%] % terminé — couples source: %, insérés: %, supprimés: %, rejetés: %',
        TO_CHAR(CLOCK_TIMESTAMP(), 'HH24:MI:SS'), p_mode,
        v_nb_src, v_nb_inserted, v_nb_deleted, v_nb_rejected;

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

EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT;
    UPDATE clean_data.etl_log
    SET end_ts = CLOCK_TIMESTAMP(), status = 'ERROR', message = v_err_msg
    WHERE id = v_log_id;
    RAISE EXCEPTION '[%] ERREUR dans % : %',
        TO_CHAR(CLOCK_TIMESTAMP(), 'HH24:MI:SS'), v_proc, v_err_msg;
END;
$$;

COMMENT ON PROCEDURE clean_data.load_equipment_object_spare IS
    'Charge equipment_object_spare = pièces détachées CONNECTÉES : tout article de la
     structure IH02 sous un objet fonctionnel (equipment_functional) ou un objet série
     (equipment_serial), toutes catégories, articles PARENTS seulement
     (v_object_spare_export) ; leurs composants sont dans equipment_spare_structure.
     1 ligne par (objet, article, position) ; mch_part = position posnr sur 4 car.
     FULL  : Truncate + rechargement complet.
     DELTA : Suppression + réinjection d''un objet (p_tplnr = mch_code) ou de tous.
     Dépendances : equipment_functional et equipment_serial alimentées AVANT.';

-- CALL clean_data.load_equipment_object_spare('FULL');
-- CALL clean_data.load_equipment_object_spare('DELTA', 'T340-E100-1005');
