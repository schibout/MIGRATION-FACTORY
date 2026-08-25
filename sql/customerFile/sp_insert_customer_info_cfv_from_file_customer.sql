CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_info_cfv_from_file_customer()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début alimentation CUSTOMER_INFO_CFV depuis CUSTOMER_INFO (file_customer) - %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');

    -- Vider la table avant insertion
    DELETE FROM clean_data.customer_info_cfv;
    RAISE NOTICE 'Table customer_info_cfv vidée';

    -- Insertion des données depuis CUSTOMER_INFO
    INSERT INTO clean_data.customer_info_cfv (
        customer_id,
        name,
        creation_date,
        association_no,
        party,
        default_domain,
        default_language,
        default_language_db,
        country,
        country_db,
        party_type,
        party_type_db,
        corporate_form,
        identifier_reference,
        identifier_ref_validation,
        identifier_ref_validation_db,
        picture_id,
        one_time,
        one_time_db,
        customer_category,
        customer_category_db,
        b2b_customer,
        b2b_customer_db,
        customer_tax_usage_type,
        business_classification,
        date_of_registration,
        main_representative,
        cfs_legacy_customer_as400_mn,
        cfs_legacy_customer_sap_id,
        created_at,
        updated_at
    )
    SELECT
        customer_id,
        name,
        creation_date,
        association_no,
        party,
        default_domain,
        default_language,
        default_language_db,
        country,
        country_db,
        party_type,
        party_type_db,
        corporate_form,
        identifier_reference,
        identifier_ref_validation,
        identifier_ref_validation_db,
        picture_id,
        one_time,
        one_time_db,
        customer_category,
        customer_category_db,
        b2b_customer,
        b2b_customer_db,
        customer_tax_usage_type,
        business_classification,
        date_of_registration,
        main_representative,
        cf_legacy_customer_as400_mn as cfs_legacy_customer_as400_mn,
        cf_legacy_customer_sap_id as cfs_legacy_customer_sap_id,
        NOW() as created_at,
        NOW() as updated_at
    FROM clean_data.customer_info;

    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();

    RAISE NOTICE 'INSERT customer_info_cfv terminé - %: % enregistrements traités',
        TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes',
        EXTRACT(EPOCH FROM (v_end_time - v_start_time));

EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''alimentation CUSTOMER_INFO_CFV - %: %',
            TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
