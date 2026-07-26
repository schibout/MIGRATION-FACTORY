-- Procédure pour insérer les exemptions fiscales de livraison clients depuis les données SAP
-- Utilise clean_data.ifs_customer comme table maître

CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_del_tax_exempt_from_sap()
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion del tax exempt clients SAP - % - Basé sur ifs_customer', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.CUSTOMER_DEL_TAX_EXEMPT;
    RAISE NOTICE 'Table customer_del_tax_exempt vidée';
    
    -- Insertion directe après TRUNCATE
    INSERT INTO clean_data.CUSTOMER_DEL_TAX_EXEMPT (
        CUSTOMER_ID,
        ADDRESS_ID,
        COMPANY,
        SUPPLY_COUNTRY,
        TAX_EXEMPTION_CERT_NO,
        CERTIFICATION_JURISDICTION,
        CERTIFICATION_DATE,
        EXPIRATION_DATE,
        EXEMPT_CERTIFICATE_TYPE,
        EXEMPT_CERTIFICATE_TYPE_DB,
        CERTIFICATE_AMOUNT
    )
    SELECT DISTINCT ON (ifs.customer_number, COALESCE(ifs.numero_adresse, k.ADRNR), COALESCE(k.LAND1, ifs.country, 'FR'), COALESCE(k.STCEG, k.STCD1, ifs.tax_number_1, 'NO_CERT'))
        ifs.customer_number as CUSTOMER_ID,
        COALESCE(ifs.numero_adresse, k.ADRNR) as ADDRESS_ID,
        'TRIMET' as COMPANY,
        COALESCE(k.LAND1, ifs.country, 'FR') as SUPPLY_COUNTRY,
        SUBSTRING(COALESCE(k.STCEG, k.STCD1, ifs.tax_number_1, 'NO_CERT'), 1, 20) as TAX_EXEMPTION_CERT_NO,
        SUBSTRING(COALESCE(k.LAND1, ifs.country, 'FR'), 1, 100) as CERTIFICATION_JURISDICTION,
        COALESCE(
            CASE WHEN k.ERDAT IS NOT NULL AND k.ERDAT != '' AND LENGTH(TRIM(k.ERDAT)) = 8
            THEN TO_TIMESTAMP(k.ERDAT, 'YYYYMMDD')
            ELSE NULL END,
            ifs.created_on
        ) as CERTIFICATION_DATE,
        COALESCE(
            CASE WHEN k.ERDAT IS NOT NULL AND k.ERDAT != '' AND LENGTH(TRIM(k.ERDAT)) = 8
            THEN TO_TIMESTAMP(k.ERDAT, 'YYYYMMDD') + INTERVAL '1 year'
            ELSE NULL END,
            ifs.created_on + INTERVAL '1 year'
        ) as EXPIRATION_DATE,
        '' as EXEMPT_CERTIFICATE_TYPE,
        'BLANKET CERTIFICATE' as EXEMPT_CERTIFICATE_TYPE_DB,
        0 as CERTIFICATE_AMOUNT
    FROM clean_data.ifs_customer ifs  -- TABLE MAÎTRE
    LEFT JOIN raw_data.KNA1 k 
        ON ifs.customer_number = k.KUNNR
        AND ifs.numero_adresse = k.ADRNR
        AND (k.LOEVM IS NULL OR k.LOEVM = '')
    WHERE COALESCE(ifs.numero_adresse, k.ADRNR) IS NOT NULL
    ORDER BY ifs.customer_number, COALESCE(ifs.numero_adresse, k.ADRNR), COALESCE(k.LAND1, ifs.country, 'FR'), COALESCE(k.STCEG, k.STCD1, ifs.tax_number_1, 'NO_CERT');
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    
    v_end_time := NOW();
    RAISE NOTICE 'INSERT del tax exempt terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT del tax exempt - %: %', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$;
