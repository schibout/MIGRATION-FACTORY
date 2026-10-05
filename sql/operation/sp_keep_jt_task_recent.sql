-- Echantillon de test : ne garde que les p_nb operations les plus recentes de
-- clean_data.jt_task (10 par defaut, tri reported_date DESC puis task_seq DESC)
-- et supprime les jt_task_resource des operations retirees.
-- A lancer APRES alimenter_all_operation ; un rechargement du module retablit
-- le jeu complet. maint_material_req_line n'est pas touchee (perimetre propre).
-- p_order_no_debut (optionnel) : renumerote les order_no gardes a partir de
-- cette valeur, +1 par order_no distinct (ordre des anciens order_no ; les
-- operations d'un meme ordre gardent le meme numero). NULL = inchanges.
-- Usage : CALL clean_data.sp_keep_jt_task_recent();          -- 10 lignes
--         CALL clean_data.sp_keep_jt_task_recent(25);
--         CALL clean_data.sp_keep_jt_task_recent(10, 1000);  -- order_no 1000, 1001...
DROP PROCEDURE IF EXISTS clean_data.sp_keep_jt_task_recent(INTEGER);
CREATE OR REPLACE PROCEDURE clean_data.sp_keep_jt_task_recent(
    p_nb             INTEGER DEFAULT 10,
    p_order_no_debut NUMERIC DEFAULT NULL
)
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_supprimes INTEGER;
BEGIN
    IF p_nb IS NULL OR p_nb < 1 THEN
        RAISE EXCEPTION 'sp_keep_jt_task_recent : p_nb doit etre >= 1 (recu %)', p_nb;
    END IF;

    CREATE TEMP TABLE tmp_jt_garde ON COMMIT DROP AS
        SELECT task_seq
        FROM clean_data.jt_task
        ORDER BY reported_date DESC NULLS LAST, task_seq DESC
        LIMIT p_nb;

    DELETE FROM clean_data.jt_task_resource r
    WHERE NOT EXISTS (SELECT 1 FROM tmp_jt_garde g WHERE g.task_seq = r.task_seq);
    DELETE FROM clean_data.jt_task t
    WHERE NOT EXISTS (SELECT 1 FROM tmp_jt_garde g WHERE g.task_seq = t.task_seq);
    GET DIAGNOSTICS v_supprimes = ROW_COUNT;

    IF p_order_no_debut IS NOT NULL THEN
        UPDATE clean_data.jt_task t
        SET order_no = m.nouveau
        FROM (
            SELECT order_no AS ancien,
                   p_order_no_debut + row_number() OVER (ORDER BY order_no) - 1 AS nouveau
            FROM (SELECT DISTINCT order_no FROM clean_data.jt_task WHERE order_no IS NOT NULL) x
        ) m
        WHERE t.order_no = m.ancien;
    END IF;

    DROP TABLE tmp_jt_garde;
    RAISE NOTICE 'sp_keep_jt_task_recent : % jt_task gardees, % supprimees',
        (SELECT count(*) FROM clean_data.jt_task), v_supprimes;
END;
$procedure$
;
