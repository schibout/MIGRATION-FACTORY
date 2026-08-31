CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_info_from_client_phl()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion clients depuis client_phl - %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.customer_info;
    RAISE NOTICE 'Table customer_info vidée';
    
    -- Insertion des données depuis client_phl
    INSERT INTO clean_data.customer_info (
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
        cf$_legacy_customer_as400_mn,
        cf$_legacy_customer_sap_id
    )
    SELECT DISTINCT ON (cp.customer_id)
        cp.customer_id as customer_id,
        cp.name as name,
        cp.creation_date as creation_date,
        cp.association_no as association_no,
        cp.numero_sap as party,
        cp.default_domain as default_domain,
        cp.default_language as default_language,
        cp.default_language_db as default_language_db,
        public.get_default_value('clean_data.customer_info', 'country', NULL) as country,
        cp.country_db as country_db,
        public.get_default_value('clean_data.customer_info', 'party_type', NULL, 'CUSTOMER_PHL') as party_type,
        cp.party_type_db as party_type_db,
        cp.corporate_form as corporate_form,
        cp.identifier_reference as identifier_reference,
        public.get_default_value('clean_data.customer_info', 'identifier_ref_validation', NULL, 'CUSTOMER_PHL') as identifier_ref_validation,
        cp.identifier_ref_validation_db as identifier_ref_validation_db,
        public.get_default_value('clean_data.customer_info', 'picture_id', NULL)::numeric as picture_id,
        public.get_default_value('clean_data.customer_info', 'one_time', NULL, 'CUSTOMER_PHL') as one_time,
        cp.one_time_db as one_time_db,
        public.get_default_value('clean_data.customer_info', 'customer_category', NULL) as customer_category,
        cp.customer_category_db as customer_category_db,
        public.get_default_value('clean_data.customer_info', 'b2b_customer', NULL, 'CUSTOMER_PHL') as b2b_customer,
        cp.b2b_customer_db as b2b_customer_db,
        cp.customer_tax_usage_type as customer_tax_usage_type,
        cp.business_classification as business_classification,
        cp.date_of_registration as date_of_registration,
        public.get_default_value('clean_data.customer_info', 'main_representative', NULL) as main_representative,
        cp.customer_id as cf$_legacy_customer_as400_mn,
        cp.numero_sap as cf$_legacy_customer_sap_id
    FROM raw_data.client_phl cp
    WHERE cp.customer_id IS NOT NULL
    ORDER BY cp.customer_id, cp.id;
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();
    
    RAISE NOTICE 'INSERT terminé - %: % enregistrements insérés', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT depuis client_phl - %: %', 
            TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
