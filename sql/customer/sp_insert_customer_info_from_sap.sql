-- Procédure pour insérer les informations clients depuis les données SAP
-- Cette procédure extrait les données clients SAP (KNA1, KNB1) et les transforme
-- pour alimenter la table CUSTOMER_INFO avec TRUNCATE + INSERT
-- Utilise INNER JOIN avec KNB1 pour s'assurer que seuls les clients actifs en comptabilité sont traités
-- FILTRE: Seuls les clients présents dans raw_data.clienttosave sont traités
-- Mise à jour pour inclure les nouvelles colonnes : CUSTOMER_TAX_USAGE_TYPE, BUSINESS_CLASSIFICATION, 
-- DATE_OF_REGISTRATION, MAIN_REPRESENTATIVE

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
        cf_legacy_customer_as400_mn,
        cf_legacy_customer_sap_id
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
        'FALSE' as DEFAULT_DOMAIN,
        NULL as DEFAULT_LANGUAGE,
        COALESCE(public.get_transcodification('LANGUAGE', k.SPRAS), public.get_transcodification('LANGUAGE', ifs.language)) as DEFAULT_LANGUAGE_DB,
        NULL as COUNTRY,
        -- Certains codes pays SAP (ex: 'SZ') n'existent pas dans IFS → NULL pour éviter ORA-20111 IsoCountry.NOTEXIST
        CASE WHEN COALESCE(k.LAND1, ifs.country) IN ('SZ') THEN NULL
             ELSE COALESCE(k.LAND1, ifs.country)
        END as COUNTRY_DB,
        'Customer' as PARTY_TYPE,
        'CUSTOMER' as PARTY_TYPE_DB,
        NULL as CORPORATE_FORM,
        COALESCE(k.STCEG, ifs.vat_number) as IDENTIFIER_REFERENCE,
        '' as IDENTIFIER_REF_VALIDATION,
        '' as IDENTIFIER_REF_VALIDATION_DB,
        NULL as PICTURE_ID,
        'False' as ONE_TIME,
        'FALSE' as ONE_TIME_DB,
        null as CUSTOMER_CATEGORY,
        'CUSTOMER' as CUSTOMER_CATEGORY_DB, 
        'FALSE' as B2B_CUSTOMER,
        'FALSE' as B2B_CUSTOMER_DB,
        NULL as CUSTOMER_TAX_USAGE_TYPE,
        NULL as BUSINESS_CLASSIFICATION,
        COALESCE(
            CASE WHEN k.ERDAT IS NOT NULL AND k.ERDAT != '' AND LENGTH(TRIM(k.ERDAT)) = 8
            THEN TO_DATE(k.ERDAT, 'YYYYMMDD')
            ELSE NULL END,
            ifs.created_on
        ) as DATE_OF_REGISTRATION,
        NULL as MAIN_REPRESENTATIVE,
        SUBSTRING(COALESCE(TRIM(k.NAME1), ifs.name_1), 1, 50) as cf_legacy_customer_as400_mn,
        ifs.customer_number as cf_legacy_customer_sap_id
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
$procedure$;
