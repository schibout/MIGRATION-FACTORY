CREATE OR REPLACE PROCEDURE clean_data.populate_all_pm_actions()
 LANGUAGE plpgsql
AS $procedure$
BEGIN
    CALL clean_data.populate_pm_action();
    CALL clean_data.populate_pm_action_work_step();
    CALL clean_data.populate_pm_action_resource();
    CALL clean_data.populate_pm_action_role();
    RAISE NOTICE 'populate_all_pm_actions: terminé';
END;
$procedure$
;
