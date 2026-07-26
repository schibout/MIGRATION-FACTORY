CREATE OR REPLACE PROCEDURE clean_data.populate_resource_parent()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_count INTEGER := 0;
BEGIN
    TRUNCATE TABLE clean_data.resource_parent;
    
    INSERT INTO clean_data.resource_parent (
        resource_parent_seq,
        resource_seq,
        scheduling_proficiency,
        loaded_at,
        source_file
    )
    SELECT 
        resource_parent_seq,
        resource_seq,
        scheduling_proficiency,
        CURRENT_TIMESTAMP,
        'Populated from raw_data.resource_parent'
    FROM raw_data.resource_parent;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'resource_parent: % lignes insérées', v_count;
END;
$procedure$
;
