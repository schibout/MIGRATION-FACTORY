-- =====================================================================
-- PROCEDURE : raw_data.sp_keep_only_t_hierarchy
-- Supprime tous les postes techniques sauf 'T' et ses descendants.
-- Tables impactees : iflot, iflotx, iflo, iflos
--
-- /!\ OBSOLETE — NE PLUS UTILISER.
--   Cette procedure SUPPRIME dans raw_data, ce que la regle du projet
--   interdit (les tables SAP sont en lecture seule) : la donnee ecartee est
--   perdue jusqu'a la prochaine extraction complete.
--   Le filtrage se fait desormais A L'IMPORT, sans toucher raw_data, via le
--   parametre p_root_tplnr (defaut 'T') de :
--     - clean_data.load_maintenance_object(p_root_tplnr)        (mode reset)
--     - clean_data.load_maintenance_object_merge(p_root_tplnr)  (mode fusion)
--   Conservee uniquement pour l'historique.
-- =====================================================================

DROP PROCEDURE IF EXISTS raw_data.sp_keep_only_t_hierarchy(text);

CREATE OR REPLACE PROCEDURE raw_data.sp_keep_only_t_hierarchy(
    p_root_tplnr text DEFAULT 'T'
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_before    bigint;
    v_total_after     bigint;
    v_to_keep         bigint;
    v_deleted_iflot   bigint;
    v_deleted_iflotx  bigint;
    v_deleted_iflo    bigint;
    v_deleted_iflos   bigint;
BEGIN
    SELECT COUNT(*) INTO v_total_before FROM raw_data.iflot;

    DROP TABLE IF EXISTS tmp_keep_tplnr;
    CREATE TEMP TABLE tmp_keep_tplnr (tplnr varchar PRIMARY KEY);

    WITH RECURSIVE descendants AS (
        SELECT tplnr
        FROM raw_data.iflot
        WHERE tplnr = p_root_tplnr
        UNION ALL
        SELECT c.tplnr
        FROM raw_data.iflot c
        JOIN descendants d ON c.tplma = d.tplnr
    )
    INSERT INTO tmp_keep_tplnr (tplnr)
    SELECT DISTINCT tplnr FROM descendants;

    SELECT COUNT(*) INTO v_to_keep FROM tmp_keep_tplnr;

    IF v_to_keep = 0 THEN
        RAISE EXCEPTION 'Racine "%" introuvable dans raw_data.iflot', p_root_tplnr;
    END IF;

    DELETE FROM raw_data.iflotx
    WHERE tplnr NOT IN (SELECT tplnr FROM tmp_keep_tplnr);
    GET DIAGNOSTICS v_deleted_iflotx = ROW_COUNT;

    DELETE FROM raw_data.iflo
    WHERE tplnr NOT IN (SELECT tplnr FROM tmp_keep_tplnr);
    GET DIAGNOSTICS v_deleted_iflo = ROW_COUNT;

    DELETE FROM raw_data.iflos
    WHERE tplnr NOT IN (SELECT tplnr FROM tmp_keep_tplnr);
    GET DIAGNOSTICS v_deleted_iflos = ROW_COUNT;

    DELETE FROM raw_data.iflot
    WHERE tplnr NOT IN (SELECT tplnr FROM tmp_keep_tplnr);
    GET DIAGNOSTICS v_deleted_iflot = ROW_COUNT;

    SELECT COUNT(*) INTO v_total_after FROM raw_data.iflot;

    DROP TABLE IF EXISTS tmp_keep_tplnr;

    RAISE NOTICE '=== Nettoyage hierarchie IH02 ===';
    RAISE NOTICE 'Racine conservee       : %', p_root_tplnr;
    RAISE NOTICE 'Total IFLOT avant      : %', v_total_before;
    RAISE NOTICE 'Conserves (T+enfants)  : %', v_to_keep;
    RAISE NOTICE 'Total IFLOT apres      : %', v_total_after;
    RAISE NOTICE 'Supprimes IFLOT        : %', v_deleted_iflot;
    RAISE NOTICE 'Supprimes IFLOTX       : %', v_deleted_iflotx;
    RAISE NOTICE 'Supprimes IFLO         : %', v_deleted_iflo;
    RAISE NOTICE 'Supprimes IFLOS        : %', v_deleted_iflos;
END;
$$;

COMMENT ON PROCEDURE raw_data.sp_keep_only_t_hierarchy(text) IS
'Conserve uniquement la racine indiquee (defaut: T) et ses descendants dans iflot/iflotx/iflo/iflos.';

-- =====================================================================
-- Execution :
--   CALL raw_data.sp_keep_only_t_hierarchy();        -- garde 'T'
--   CALL raw_data.sp_keep_only_t_hierarchy('T');     -- explicite
--
-- Verifications :
--   SELECT COUNT(*) FROM raw_data.iflot;
--   SELECT tplnr FROM raw_data.iflot WHERE tplma IS NULL OR TRIM(tplma)='';
-- =====================================================================
