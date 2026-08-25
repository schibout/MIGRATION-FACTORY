CREATE OR REPLACE PROCEDURE clean_data.populate_pm_action_role()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_org_contract  VARCHAR := 'SJ';
    v_org_code      VARCHAR := 'FR_MAINT';
    v_pm_revision   VARCHAR := '1';
    v_count INTEGER := 0;
BEGIN
    TRUNCATE TABLE clean_data.pm_action_role;
    INSERT INTO clean_data.pm_action_role (
        pm_no,
        pm_revision,
        row_no,
        description,
        duration,
        org_contract,
        org_code
    )
    SELECT
        s.pm_no,
        v_pm_revision,
        row_number() OVER (ORDER BY s.pm_no, s.raw_id)  AS row_no,
        left(s.designation, 200)                        AS description,
        clean_data.pe_num(s.charge)                     AS duration,
        v_org_contract,
        v_org_code
    FROM clean_data.v_pm_source s
    JOIN clean_data.pm_action p
      ON p.pm_no = s.pm_no
     AND p.pm_revision = v_pm_revision;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'pm_action_role: % lignes insérées', v_count;
END;
$procedure$
;
