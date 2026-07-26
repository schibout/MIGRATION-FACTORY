-- Procédure pour insérer les informations clients depuis raw_data.file_customer
-- Transposition de sp_insert_customer_info_from_sap : la table maître ifs_customer
-- est remplacée par une CTE sur raw_data.file_customer (liste explicite des clients).
-- Le fichier est la source faisant autorité (données corrigées) -> les COALESCE
-- préfèrent le fichier puis retombent sur les tables SAP.
-- Alimente clean_data.CUSTOMER_INFO avec TRUNCATE + INSERT.

CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_info_from_file_customer()
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_error_count INTEGER := 0;
BEGIN

    RAISE NOTICE 'Début insertion clients file_customer - %', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS');

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
    WITH fc AS (
        SELECT f.*,
            COALESCE(NULLIF(TRIM(f.nouveau_compte_ifs),''), NULLIF(TRIM(f.num_corrige),''), TRIM(f.kunnr)) AS customer_id,
            COALESCE(NULLIF(split_part(TRIM(f.numero_adresse), '.', 1), ''), '1') AS address_id
        FROM raw_data.file_customer f
        WHERE COALESCE(NULLIF(TRIM(f.nouveau_compte_ifs),''), NULLIF(TRIM(f.num_corrige),''), TRIM(f.kunnr)) IS NOT NULL
    )
    SELECT DISTINCT ON (fc.customer_id)
        fc.customer_id as CUSTOMER_ID,
        COALESCE(NULLIF(TRIM(fc.name_1),''), TRIM(k.NAME1)) as NAME,
        COALESCE(
            CASE WHEN fc.created_on ~ '^[0-9]{8}$' THEN TO_DATE(fc.created_on, 'YYYYMMDD') ELSE NULL END,
            CASE WHEN k.ERDAT IS NOT NULL AND k.ERDAT != '' AND LENGTH(TRIM(k.ERDAT)) = 8
            THEN TO_DATE(k.ERDAT, 'YYYYMMDD')
            ELSE NULL END
        ) as CREATION_DATE,
        COALESCE(NULLIF(TRIM(fc.tax_number_1),''), TRIM(k.STCD1), TRIM(k.STCD2)) as ASSOCIATION_NO,
        fc.customer_id as PARTY,
        'FALSE' as DEFAULT_DOMAIN,
        NULL as DEFAULT_LANGUAGE,
        public.get_transcodification('LANGUAGE', COALESCE(fc.language, k.SPRAS)) as DEFAULT_LANGUAGE_DB,
        NULL as COUNTRY,
        -- Certains codes pays SAP (ex: 'SZ') n'existent pas dans IFS → NULL pour éviter ORA-20111 IsoCountry.NOTEXIST
        CASE WHEN COALESCE(NULLIF(TRIM(fc.country),''), k.LAND1) IN ('SZ') THEN NULL
             ELSE COALESCE(NULLIF(TRIM(fc.country),''), k.LAND1)
        END as COUNTRY_DB,
        'Customer' as PARTY_TYPE,
        'CUSTOMER' as PARTY_TYPE_DB,
        NULL as CORPORATE_FORM,
        COALESCE(NULLIF(TRIM(fc.vat_number),''), k.STCEG) as IDENTIFIER_REFERENCE,
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
            CASE WHEN fc.created_on ~ '^[0-9]{8}$' THEN TO_DATE(fc.created_on, 'YYYYMMDD') ELSE NULL END,
            CASE WHEN k.ERDAT IS NOT NULL AND k.ERDAT != '' AND LENGTH(TRIM(k.ERDAT)) = 8
            THEN TO_DATE(k.ERDAT, 'YYYYMMDD')
            ELSE NULL END
        ) as DATE_OF_REGISTRATION,
        NULL as MAIN_REPRESENTATIVE,
        SUBSTRING(COALESCE(NULLIF(TRIM(fc.name_1),''), TRIM(k.NAME1)), 1, 50) as cf$_legacy_customer_as400_mn,
        fc.kunnr as cf$_legacy_customer_sap_id
    FROM fc  -- TABLE MAÎTRE (file_customer)
    LEFT JOIN raw_data.KNA1 k
        ON fc.kunnr = k.KUNNR
        AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.KNB1 kb
        ON fc.kunnr = kb.KUNNR
        AND fc.bukrs = kb.BUKRS
        AND (kb.LOEVM IS NULL OR kb.LOEVM = '')
    LEFT JOIN raw_data.T005T t_country
        ON COALESCE(NULLIF(TRIM(fc.country),''), k.LAND1) = t_country.LAND1
        AND t_country.SPRAS = 'F'
    LEFT JOIN raw_data.KNVV kv
        ON fc.kunnr = kv.KUNNR
    ORDER BY fc.customer_id;

    GET DIAGNOSTICS v_processed_count = ROW_COUNT;

    RAISE NOTICE 'INSERT terminé - %: % enregistrements traités', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;

EXCEPTION
    WHEN OTHERS THEN
        v_error_count := v_error_count + 1;
        RAISE EXCEPTION 'Erreur lors de l''INSERT: %', SQLERRM;
END;
$procedure$;
