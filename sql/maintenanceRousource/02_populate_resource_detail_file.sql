CREATE OR REPLACE PROCEDURE clean_data.populate_resource_detail_file()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_count INTEGER := 0;
    v_updated INTEGER := 0;
    v_found_by_resource_id INTEGER := 0;
    v_found_by_description INTEGER := 0;
    v_not_found INTEGER := 0;
BEGIN
    -- Vider la table de destination
    -- CASCADE : resource_connection a une FK vers resource_detail_file ;
    -- elle est repeuplée à l'étape suivante (03_populate_resource_connection)
    TRUNCATE TABLE clean_data.resource_detail_file CASCADE;
    
    -- Insérer les données en transformant resource_id
    INSERT INTO clean_data.resource_detail_file (
        resource_seq,
        resource_id,
        description,
        resource_type,
        resource_type_db,
        used_in_maintenance,
        used_in_maintenance_db,
        used_in_manufacturing,
        used_in_manufacturing_db,
        used_in_projects,
        used_in_projects_db,
        used_in_service,
        used_in_service_db,
        use_shift_pattern,
        use_shift_pattern_db,
        resource_origin,
        resource_origin_db,
        origin_key1,
        origin_key2,
        origin_key3,
        origin_key4,
        calendar_id,
        resource_category,
        note,
        note_id,
        sched_capacity,
        sched_capacity_db,
        capacity_calc_base,
        capacity_calc_base_db,
        utilization,
        use_hr_schedule,
        use_hr_schedule_db,
        service_organization_id,
        service_delivery_unit,
        manuf_group_id,
        manuf_group_desc,
        manuf_company,
        manuf_contract,
        companies,
        sites,
        ignore_scheduling_resource,
        loaded_at,
        source_file
    )
    SELECT 
        resource_seq,
        -- Transformation de resource_id avec logique améliorée
        CASE 
            -- Pour les ressources de type PERSON, utiliser la logique de recherche
            WHEN resource_type_db = 'PERSON' THEN
                COALESCE(
                    -- Tentative 1: Recherche par resource_id (trouve via resource_id dans ifs_person)
                    raw_data.find_person_id(resource_id),
                    -- Tentative 2: Recherche par description (trouve via nom/prénom)
                    raw_data.find_person_id(description),
                    -- Fallback: Marquer pour correction manuelle
                    resource_id 
                )
            -- Pour les autres types de ressources, conserver resource_id tel quel
            ELSE
                resource_id
        END AS resource_id,
        description,
        resource_type,
        resource_type_db,
        used_in_maintenance,
        used_in_maintenance_db,
        used_in_manufacturing,
        used_in_manufacturing_db,
        used_in_projects,
        used_in_projects_db,
        used_in_service,
        used_in_service_db,
        use_shift_pattern,
        use_shift_pattern_db,
        resource_origin,
        resource_origin_db,
        origin_key1,
        origin_key2,
        origin_key3,
        origin_key4,
        calendar_id,
        resource_category,
        note,
        note_id,
        sched_capacity,
        sched_capacity_db,
        capacity_calc_base,
        capacity_calc_base_db,
        utilization,
        use_hr_schedule,
        use_hr_schedule_db,
        service_organization_id,
        service_delivery_unit,
        manuf_group_id,
        manuf_group_desc,
        manuf_company,
        manuf_contract,
        companies,
        sites,
        ignore_scheduling_resource,
        CURRENT_TIMESTAMP,
        'Populated from raw_data.resource_detail_file'
    FROM raw_data.resource_detail_file;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Procédure terminée avec succès';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Lignes insérées: %', v_count;
    
    -- Statistiques sur les transformations
    SELECT COUNT(*) INTO v_updated
    FROM clean_data.resource_detail_file c
    INNER JOIN raw_data.resource_detail_file r ON c.resource_seq = r.resource_seq
    WHERE c.resource_id != r.resource_id;
    
    RAISE NOTICE 'Lignes avec resource_id transformé: %', v_updated;
    
    -- Statistiques détaillées pour les PERSON
    SELECT COUNT(*) INTO v_found_by_resource_id
    FROM clean_data.resource_detail_file c
    INNER JOIN raw_data.resource_detail_file r ON c.resource_seq = r.resource_seq
    WHERE c.resource_type_db = 'PERSON'
      AND c.resource_id != r.resource_id
      AND c.resource_id NOT LIKE '%a Corriger'
      AND raw_data.find_person_id(r.resource_id) IS NOT NULL
      AND raw_data.find_person_id(r.resource_id) = c.resource_id;
    
    SELECT COUNT(*) INTO v_found_by_description
    FROM clean_data.resource_detail_file c
    INNER JOIN raw_data.resource_detail_file r ON c.resource_seq = r.resource_seq
    WHERE c.resource_type_db = 'PERSON'
      AND c.resource_id != r.resource_id
      AND c.resource_id NOT LIKE '%a Corriger'
      AND raw_data.find_person_id(r.resource_id) IS NULL
      AND raw_data.find_person_id(r.description) IS NOT NULL;
    
    SELECT COUNT(*) INTO v_not_found
    FROM clean_data.resource_detail_file
    WHERE resource_type_db = 'PERSON'
      AND resource_id LIKE '%a Corriger';
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Détails de transformation pour PERSON:';
    RAISE NOTICE '========================================';
    RAISE NOTICE '  - Trouvé par resource_id: %', v_found_by_resource_id;
    RAISE NOTICE '  - Trouvé par description: %', v_found_by_description;
    RAISE NOTICE '  - Non trouvé (à corriger): %', v_not_found;
    RAISE NOTICE '========================================';
    
END;
$procedure$
;
