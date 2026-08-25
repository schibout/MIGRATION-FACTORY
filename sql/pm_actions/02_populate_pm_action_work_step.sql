CREATE OR REPLACE PROCEDURE clean_data.populate_pm_action_work_step()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_org_contract        VARCHAR := 'SJ';
    v_pm_revision         VARCHAR := '1';
    v_connection_type     VARCHAR := 'Functional Object';
    v_connection_type_db  VARCHAR := 'FUNCTIONAL';
    v_count INTEGER := 0;
BEGIN
    TRUNCATE TABLE clean_data.pm_action_work_step;
    INSERT INTO clean_data.pm_action_work_step (
        pm_no,
        pm_revision,
        pm_action_work_step_seq,
        description,
        order_no,
        mch_code_contract,
        mch_code,
        connection_type,
        connection_type_db
    )
    SELECT
        s.pm_no,
        v_pm_revision,
        row_number() OVER (ORDER BY s.pm_no, s.raw_id)                     AS pm_action_work_step_seq,
        left(COALESCE(NULLIF(btrim(s.designation), ''), 'N/A'), 500)       AS description,
        clean_data.pe_num(s.compteur_de_gamme)                             AS order_no,
        v_org_contract,
        p.mch_code,
        v_connection_type,
        v_connection_type_db
    FROM clean_data.v_pm_source s
    JOIN clean_data.pm_action p
      ON p.pm_no = s.pm_no
     AND p.pm_revision = v_pm_revision;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'pm_action_work_step: % lignes insérées', v_count;
END;
$procedure$
;
