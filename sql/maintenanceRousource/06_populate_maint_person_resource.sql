CREATE OR REPLACE PROCEDURE clean_data.populate_maint_person_resource()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_count INTEGER := 0;
BEGIN
    TRUNCATE TABLE clean_data.maint_person_resource;
    
    INSERT INTO clean_data.maint_person_resource (
        maint_resource_seq,
        resource_connection_seq,
        company,
        contract,
        connection_type,
        connection_type_db,
        org_code,
        secondment_company,
        secondment_employee,
        vendor_no,
        remark,
        filter_id,
        disable_operation_costs,
        mob_user,
        mob_user_db,
        mob_user_type,
        mob_user_type_db,
        default_time_type,
        default_travel_time_type,
        disable_transfer_mobile,
        disable_transfer_mobile_db,
        primary_resource,
        primary_resource_db,
        avail_for_scheduling,
        avail_for_scheduling_db,
        travel_resource_group_seq,
        primary_contract,
        primary_contract_db,
        crew_time_invoicing,
        crew_time_invoicing_db,
        loaded_at,
        source_file
    )
    SELECT 
        maint_resource_seq,
        resource_connection_seq,
        company,
        contract,
        connection_type,
        connection_type_db,
        org_code,
        secondment_company,
        secondment_employee,
        vendor_no,
        remark,
        filter_id,
        disable_operation_costs,
        mob_user,
        mob_user_db,
        mob_user_type,
        mob_user_type_db,
        default_time_type,
        default_travel_time_type,
        disable_transfer_mobile,
        disable_transfer_mobile_db,
        primary_resource,
        primary_resource_db,
        avail_for_scheduling,
        avail_for_scheduling_db,
        travel_resource_group_seq,
        primary_contract,
        primary_contract_db,
        crew_time_invoicing,
        crew_time_invoicing_db,
        CURRENT_TIMESTAMP,
        'Populated from raw_data.maint_person_resource'
    FROM raw_data.maint_person_resource;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'maint_person_resource: % lignes insérées', v_count;
END;
$procedure$
;
