-- Echantillon de test : ne garde que les p_nb operations les plus recentes de
-- clean_data.jt_task (10 par defaut, tri reported_date DESC puis task_seq DESC)
-- et supprime les jt_task_resource et maint_material_req_line des operations
-- retirees (rattachement par task_seq). A lancer APRES alimenter_all_operation ;
-- un rechargement du module retablit le jeu complet.
-- p_task_seq_debut (optionnel) : renumerote les task_seq gardes a partir de
-- cette valeur, +1 par operation (ordre des anciens task_seq), dans jt_task et
-- jt_task_resource et maint_material_req_line. NULL = inchanges. order_no n'est jamais modifie.
-- Usage : CALL clean_data.sp_keep_jt_task_recent();          -- 10 lignes
--         CALL clean_data.sp_keep_jt_task_recent(25);
--         CALL clean_data.sp_keep_jt_task_recent(10, 1000);  -- task_seq 1000..1009
DROP PROCEDURE IF EXISTS clean_data.sp_keep_jt_task_recent(INTEGER);
DROP PROCEDURE IF EXISTS clean_data.sp_keep_jt_task_recent(INTEGER, NUMERIC);
CREATE OR REPLACE PROCEDURE clean_data.sp_keep_jt_task_recent(
    p_nb             INTEGER DEFAULT 10,
    p_task_seq_debut NUMERIC DEFAULT NULL
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
    DELETE FROM clean_data.maint_material_req_line m
    WHERE NOT EXISTS (SELECT 1 FROM tmp_jt_garde g WHERE g.task_seq = m.task_seq);
    DELETE FROM clean_data.jt_task t
    WHERE NOT EXISTS (SELECT 1 FROM tmp_jt_garde g WHERE g.task_seq = t.task_seq);
    GET DIAGNOSTICS v_supprimes = ROW_COUNT;

    IF p_task_seq_debut IS NOT NULL THEN
        CREATE TEMP TABLE tmp_jt_renum ON COMMIT DROP AS
            SELECT task_seq AS ancien,
                   p_task_seq_debut + row_number() OVER (ORDER BY task_seq) - 1 AS nouveau
            FROM tmp_jt_garde;

        UPDATE clean_data.jt_task_resource r SET task_seq = m.nouveau FROM tmp_jt_renum m WHERE r.task_seq = m.ancien;
        UPDATE clean_data.maint_material_req_line l SET task_seq = m.nouveau FROM tmp_jt_renum m WHERE l.task_seq = m.ancien;
        UPDATE clean_data.jt_task t          SET task_seq = m.nouveau FROM tmp_jt_renum m WHERE t.task_seq = m.ancien;

        DROP TABLE tmp_jt_renum;
    END IF;

    DROP TABLE tmp_jt_garde;
    RAISE NOTICE 'sp_keep_jt_task_recent : % jt_task gardees, % supprimees',
        (SELECT count(*) FROM clean_data.jt_task), v_supprimes;
END;
$procedure$
;
