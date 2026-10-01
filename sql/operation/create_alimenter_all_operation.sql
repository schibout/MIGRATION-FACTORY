-- Lance les 3 loaders du module Operations dans l'ordre des dependances :
-- jt_task d'abord, car jt_task_resource et maint_material_req_line filtrent via
-- EXISTS sur jt_task. Meme enchainement que etl_modules/etl_operation.py.
-- Usage : CALL clean_data.alimenter_all_operation();
CREATE OR REPLACE PROCEDURE clean_data.alimenter_all_operation()
LANGUAGE plpgsql
AS $$
DECLARE
    v_debut timestamptz;
    v_nb    bigint;
BEGIN
    v_debut := clock_timestamp();
    PERFORM clean_data.alimenter_jt_task();
    SELECT count(*) INTO v_nb FROM clean_data.jt_task;
    RAISE NOTICE 'jt_task : % lignes (%)', v_nb, clock_timestamp() - v_debut;

    v_debut := clock_timestamp();
    PERFORM clean_data.alimenter_jt_task_resource();
    SELECT count(*) INTO v_nb FROM clean_data.jt_task_resource;
    RAISE NOTICE 'jt_task_resource : % lignes (%)', v_nb, clock_timestamp() - v_debut;

    v_debut := clock_timestamp();
    PERFORM clean_data.alimenter_maint_material_req_line();
    SELECT count(*) INTO v_nb FROM clean_data.maint_material_req_line;
    RAISE NOTICE 'maint_material_req_line : % lignes (%)', v_nb, clock_timestamp() - v_debut;
END;
$$;
