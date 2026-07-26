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

    -- Une ligne de pe_tools = une opération = un work step.
    -- pm_action_work_step_seq est la PK (seule) de la table : il doit rester
    -- globalement unique, d'où un row_number() non partitionné ; l'ordre au sein
    -- d'une pm_action est porté par order_no (compteur de gamme).
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
        s.poste_technique,
        v_connection_type,
        v_connection_type_db
    FROM clean_data.v_pm_source s;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'pm_action_work_step: % lignes insérées', v_count;
END;
$procedure$
;
