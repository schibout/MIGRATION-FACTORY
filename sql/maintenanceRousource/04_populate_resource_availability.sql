CREATE OR REPLACE PROCEDURE clean_data.populate_resource_availability()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_count INTEGER := 0;
BEGIN
    TRUNCATE TABLE clean_data.resource_availability;
    
    INSERT INTO clean_data.resource_availability (
        resource_availability_seq,
        resource_parent_seq,
        resource_seq,
        company,
        site,
        start_date,
        end_date,
        available_percentage,
        efficiency,
        loaded_at,
        source_file
    )
    SELECT 
        resource_availability_seq,
        resource_parent_seq,
        resource_seq,
        company,
        site,
        start_date,
        end_date,
        available_percentage,
        efficiency,
        CURRENT_TIMESTAMP,
        'Populated from raw_data.resource_availability'
    FROM raw_data.resource_availability;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'resource_availability: % lignes insérées', v_count;
END;
$procedure$
;
