CREATE OR REPLACE PROCEDURE clean_data.populate_resource_connection()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_count INTEGER := 0;
    v_transformed INTEGER := 0;
BEGIN
    -- Vider la table de destination
    TRUNCATE TABLE clean_data.resource_connection;
    
    -- Insérer les données avec toutes les colonnes
    INSERT INTO clean_data.resource_connection (
        resource_connection_seq,
        res_id,
        parent_resource_id,
        resource_seq,
        primary_parent_resource_seq,
        connection_type,
        connection_type_db,
        company,
        site,
        employee_id,
        calendar_id,
        org_code,
        quantity,
        sched_capacity,
        sched_capacity_db,
        capacity_calc_base,
        capacity_calc_base_db,
        primary_scheduling,
        primary_scheduling_db,
        objversion,
        objid,
        resource_id,
        resource_type,
        resource_type_db,
        loaded_at,
        source_file
    )
    SELECT 
        resource_connection_seq,
        res_id,
        parent_resource_id,
        resource_seq,
        primary_parent_resource_seq,
        connection_type,
        connection_type_db,
        company,
        site,
        employee_id,
        calendar_id,
        org_code,
        quantity,
        sched_capacity,
        sched_capacity_db,
        capacity_calc_base,
        capacity_calc_base_db,
        primary_scheduling,
        primary_scheduling_db,
        objversion,
        objid,
        -- Transformation de resource_id pour les PERSON uniquement
        CASE 
            WHEN resource_type_db = 'PERSON' THEN
                COALESCE(
                    raw_data.find_person_id(resource_id),
                    raw_data.find_person_id(res_id),
                    resource_id
                )
            ELSE
                resource_id
        END AS resource_id,
        resource_type,
        resource_type_db,
        CURRENT_TIMESTAMP,
        'Populated from raw_data.resource_connection'
    FROM raw_data.resource_connection;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Procédure terminée avec succès';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Lignes insérées: %', v_count;
    
    -- Statistiques sur les transformations
    SELECT COUNT(*) INTO v_transformed
    FROM clean_data.resource_connection c
    INNER JOIN raw_data.resource_connection r 
        ON c.resource_connection_seq = r.resource_connection_seq
    WHERE c.resource_id != r.resource_id
      AND c.resource_type_db = 'PERSON';
    
    RAISE NOTICE 'Lignes avec resource_id transformé (PERSON): %', v_transformed;
    RAISE NOTICE '========================================';
    
END;
$procedure$
;
