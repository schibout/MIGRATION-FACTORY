CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_info_from_sap()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_error_count INTEGER := 0;
BEGIN
    
    RAISE NOTICE 'Début insertion clients SAP - % - Filtrage par clienttosave', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS');
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.CUSTOMER_INFO;
    RAISE NOTICE 'Table customer_info vidée';
    
    -- Insertion directe après TRUNCATE
    INSERT INTO clean_data.CUSTOMER_INFO (
        CUSTOMER_ID,
        NAME,
        CREATION_DATE,
        ASSOCIATION_NO,
        PARTY,
        DEFAULT_DOMAIN,
        DEFAULT_LANGUAGE,
        DEFAULT_LANGUAGE_DB,
        COUNTRY,
        COUNTRY_DB,
        PARTY_TYPE,
        PARTY_TYPE_DB,
        CORPORATE_FORM,
        IDENTIFIER_REFERENCE,
        IDENTIFIER_REF_VALIDATION,
        IDENTIFIER_REF_VALIDATION_DB,
        PICTURE_ID,
        ONE_TIME,
        ONE_TIME_DB,
        CUSTOMER_CATEGORY,
        CUSTOMER_CATEGORY_DB,
        B2B_CUSTOMER,
        B2B_CUSTOMER_DB,
        CUSTOMER_TAX_USAGE_TYPE,
        BUSINESS_CLASSIFICATION,
        DATE_OF_REGISTRATION,
        MAIN_REPRESENTATIVE,
        cf$_legacy_customer_as400_mn,
        cf$_legacy_customer_sap_id
    )
    SELECT DISTINCT ON (ifs.customer_number)
        ifs.customer_number as CUSTOMER_ID,
        COALESCE(TRIM(k.NAME1), ifs.name_1) as NAME,
        COALESCE(
            CASE WHEN k.ERDAT IS NOT NULL AND k.ERDAT != '' AND LENGTH(TRIM(k.ERDAT)) = 8
            THEN TO_DATE(k.ERDAT, 'YYYYMMDD')
            ELSE NULL END,
            ifs.created_on
        ) as CREATION_DATE,
        COALESCE(TRIM(k.STCD1), TRIM(k.STCD2), ifs.tax_number_1) as ASSOCIATION_NO,
        ifs.customer_number as PARTY,
        public.get_default_value('clean_data.customer_info', 'default_domain', 'FALSE') as DEFAULT_DOMAIN,
        public.get_default_value('clean_data.customer_info', 'default_language', NULL) as DEFAULT_LANGUAGE,
        COALESCE(public.get_transcodification('LANGUAGE', k.SPRAS), public.get_transcodification('LANGUAGE', ifs.language)) as DEFAULT_LANGUAGE_DB,
        public.get_default_value('clean_data.customer_info', 'country', NULL) as COUNTRY,
        COALESCE(k.LAND1, ifs.country) as COUNTRY_DB,
        public.get_default_value('clean_data.customer_info', 'party_type', 'Customer', 'CUSTOMER') as PARTY_TYPE,
        public.get_default_value('clean_data.customer_info', 'party_type_db', 'CUSTOMER') as PARTY_TYPE_DB,
        public.get_default_value('clean_data.customer_info', 'corporate_form', NULL) as CORPORATE_FORM,
        COALESCE(k.STCEG, ifs.vat_number) as IDENTIFIER_REFERENCE,
        public.get_default_value('clean_data.customer_info', 'identifier_ref_validation', '', 'CUSTOMER') as IDENTIFIER_REF_VALIDATION,
        public.get_default_value('clean_data.customer_info', 'identifier_ref_validation_db', '') as IDENTIFIER_REF_VALIDATION_DB,
        public.get_default_value('clean_data.customer_info', 'picture_id', NULL)::numeric as PICTURE_ID,
        public.get_default_value('clean_data.customer_info', 'one_time', 'False', 'CUSTOMER') as ONE_TIME,
        public.get_default_value('clean_data.customer_info', 'one_time_db', 'FALSE') as ONE_TIME_DB,
        public.get_default_value('clean_data.customer_info', 'customer_category', NULL) as CUSTOMER_CATEGORY,
        public.get_default_value('clean_data.customer_info', 'customer_category_db', 'CUSTOMER') as CUSTOMER_CATEGORY_DB, 
        public.get_default_value('clean_data.customer_info', 'b2b_customer', 'FALSE', 'CUSTOMER') as B2B_CUSTOMER,
        public.get_default_value('clean_data.customer_info', 'b2b_customer_db', 'FALSE') as B2B_CUSTOMER_DB,
        public.get_default_value('clean_data.customer_info', 'customer_tax_usage_type', NULL) as CUSTOMER_TAX_USAGE_TYPE,
        public.get_default_value('clean_data.customer_info', 'business_classification', NULL) as BUSINESS_CLASSIFICATION,
        COALESCE(
            CASE WHEN k.ERDAT IS NOT NULL AND k.ERDAT != '' AND LENGTH(TRIM(k.ERDAT)) = 8
            THEN TO_DATE(k.ERDAT, 'YYYYMMDD')
            ELSE NULL END,
            ifs.created_on
        ) as DATE_OF_REGISTRATION,
        public.get_default_value('clean_data.customer_info', 'main_representative', NULL) as MAIN_REPRESENTATIVE,
        SUBSTRING(COALESCE(TRIM(k.NAME1), ifs.name_1), 1, 50) as cf$_legacy_customer_as400_mn,
        ifs.customer_number as cf$_legacy_customer_sap_id
    FROM clean_data.ifs_customer ifs  -- TABLE MAÎTRE
    LEFT JOIN raw_data.KNA1 k 
        ON ifs.customer_number = k.KUNNR
        AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.KNB1 kb 
        ON ifs.customer_number = kb.KUNNR
        AND ifs.company_code = kb.BUKRS
        AND (kb.LOEVM IS NULL OR kb.LOEVM = '')
    LEFT JOIN raw_data.T005T t_country 
        ON COALESCE(k.LAND1, ifs.country) = t_country.LAND1 
        AND t_country.SPRAS = 'F'
    LEFT JOIN raw_data.KNVV kv 
        ON ifs.customer_number = kv.KUNNR
    ORDER BY ifs.customer_number;
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    
    RAISE NOTICE 'INSERT terminé - %: % enregistrements traités', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    
EXCEPTION
    WHEN OTHERS THEN
        v_error_count := v_error_count + 1;
        RAISE EXCEPTION 'Erreur lors de l''INSERT: %', SQLERRM;
END;
$procedure$
