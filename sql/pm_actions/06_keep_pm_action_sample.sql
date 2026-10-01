-- Echantillon de test : ne garde que p_nb actions preventives tirees au hasard
-- (10 par defaut) et supprime les lignes filles des autres pm_no
-- (work_step, resource, role). A lancer APRES populate_all_pm_actions ;
-- un rechargement du module retablit le jeu complet.
-- p_pm_no_debut (optionnel) : renumerote les pm_no gardes a partir de cette
-- valeur, +1 a chaque ligne (ordre des anciens pm_no), dans pm_action et ses
-- 3 tables filles. NULL = pm_no inchanges.
-- Usage : CALL clean_data.sp_keep_pm_action_sample();            -- 10 lignes
--         CALL clean_data.sp_keep_pm_action_sample(25);
--         CALL clean_data.sp_keep_pm_action_sample(10, 1000);    -- pm_no 1000..1009
DROP PROCEDURE IF EXISTS clean_data.sp_keep_pm_action_sample(INTEGER);
CREATE OR REPLACE PROCEDURE clean_data.sp_keep_pm_action_sample(
    p_nb          INTEGER DEFAULT 10,
    p_pm_no_debut NUMERIC DEFAULT NULL
)
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_supprimes INTEGER;
BEGIN
    IF p_nb IS NULL OR p_nb < 1 THEN
        RAISE EXCEPTION 'sp_keep_pm_action_sample : p_nb doit etre >= 1 (recu %)', p_nb;
    END IF;

    CREATE TEMP TABLE tmp_pm_garde ON COMMIT DROP AS
        SELECT pm_no, pm_revision
        FROM clean_data.pm_action
        ORDER BY random()
        LIMIT p_nb;

    DELETE FROM clean_data.pm_action_role r
    WHERE NOT EXISTS (SELECT 1 FROM tmp_pm_garde g WHERE g.pm_no = r.pm_no AND g.pm_revision = r.pm_revision);
    DELETE FROM clean_data.pm_action_resource r
    WHERE NOT EXISTS (SELECT 1 FROM tmp_pm_garde g WHERE g.pm_no = r.pm_no AND g.pm_revision = r.pm_revision);
    DELETE FROM clean_data.pm_action_work_step w
    WHERE NOT EXISTS (SELECT 1 FROM tmp_pm_garde g WHERE g.pm_no = w.pm_no AND g.pm_revision = w.pm_revision);
    DELETE FROM clean_data.pm_action p
    WHERE NOT EXISTS (SELECT 1 FROM tmp_pm_garde g WHERE g.pm_no = p.pm_no AND g.pm_revision = p.pm_revision);
    GET DIAGNOSTICS v_supprimes = ROW_COUNT;

    IF p_pm_no_debut IS NOT NULL THEN
        CREATE TEMP TABLE tmp_pm_renum ON COMMIT DROP AS
            SELECT pm_no AS ancien,
                   p_pm_no_debut + row_number() OVER (ORDER BY pm_no) - 1 AS nouveau
            FROM (SELECT DISTINCT pm_no FROM tmp_pm_garde) x;

        UPDATE clean_data.pm_action_role r      SET pm_no = m.nouveau FROM tmp_pm_renum m WHERE r.pm_no = m.ancien;
        UPDATE clean_data.pm_action_resource r  SET pm_no = m.nouveau FROM tmp_pm_renum m WHERE r.pm_no = m.ancien;
        UPDATE clean_data.pm_action_work_step w SET pm_no = m.nouveau FROM tmp_pm_renum m WHERE w.pm_no = m.ancien;
        -- Cle primaire (pm_no, pm_revision) : passage par des valeurs negatives
        -- pour qu'un nouveau numero ne heurte pas un ancien encore present
        UPDATE clean_data.pm_action p SET pm_no = -m.nouveau FROM tmp_pm_renum m WHERE p.pm_no = m.ancien;
        UPDATE clean_data.pm_action    SET pm_no = -pm_no WHERE pm_no < 0;

        DROP TABLE tmp_pm_renum;
    END IF;

    DROP TABLE tmp_pm_garde;
    RAISE NOTICE 'sp_keep_pm_action_sample : % pm_action gardees, % supprimees',
        (SELECT count(*) FROM clean_data.pm_action), v_supprimes;
END;
$procedure$
;
