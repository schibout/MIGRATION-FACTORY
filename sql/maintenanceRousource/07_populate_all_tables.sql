CREATE OR REPLACE PROCEDURE clean_data.populate_all_tables()
 LANGUAGE plpgsql
AS $procedure$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'DÉBUT ALIMENTATION CLEAN_DATA';
    RAISE NOTICE '========================================';
    
    RAISE NOTICE 'Alimentation de ifs_person...';
    CALL clean_data.populate_ifs_person();
    
    RAISE NOTICE 'Alimentation de resource_detail_file...';
    CALL clean_data.populate_resource_detail_file();
    
    RAISE NOTICE 'Alimentation de resource_connection...';
    CALL clean_data.populate_resource_connection();
    
    RAISE NOTICE 'Alimentation de resource_availability...';
    CALL clean_data.populate_resource_availability();
    
    RAISE NOTICE 'Alimentation de resource_parent...';
    CALL clean_data.populate_resource_parent();
    
    RAISE NOTICE 'Alimentation de maint_person_resource...';
    CALL clean_data.populate_maint_person_resource();
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'ALIMENTATION TERMINÉE AVEC SUCCÈS';
    RAISE NOTICE '========================================';
END;
$procedure$
;
