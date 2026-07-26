-- Procédure pour insérer les adresses clients depuis les données SAP
-- Cette procédure extrait les données d'adresses clients SAP (KNA1, KNB1, ADRC) et les transforme
-- pour alimenter la table CUSTOMER_INFO_ADDRESS avec TRUNCATE + INSERT
-- Utilise INNER JOIN avec KNB1 pour s'assurer que seuls les clients actifs en comptabilité sont traités
-- FILTRE: Seuls les clients existants dans clean_data.customer_info sont traités

CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_address_from_sap()
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
BEGIN
    
    RAISE NOTICE 'Début insertion adresses clients SAP - Filtrage par customer_info';
    
    -- Vider la table avant insertion
    -- Supprimer toutes les lignes de la table CUSTOMER_INFO_ADDRESS ainsi que celles des tables qui en dépendent
    TRUNCATE TABLE clean_data.CUSTOMER_INFO_ADDRESS CASCADE;
    RAISE NOTICE 'Table customer_info_address vidée';
    
    -- Insertion directe après TRUNCATE
    INSERT INTO clean_data.CUSTOMER_INFO_ADDRESS (
        CUSTOMER_ID,
        ADDRESS_ID,
        NAME,
        ADDRESS,
        EAN_LOCATION,
        VALID_FROM,
        VALID_TO,
        PARTY,
        ADDRESS_LOV,
        DEFAULT_DOMAIN,
        COUNTRY,
        COUNTRY_DB,
        PARTY_TYPE,
        PARTY_TYPE_DB,
        SECONDARY_CONTACT,
        PRIMARY_CONTACT,
        ADDRESS1,
        ADDRESS2,
        ADDRESS3,
        ADDRESS4,
        ADDRESS5,
        ADDRESS6,
        ZIP_CODE,
        CITY,
        STATE,
        COUNTY,
        JURISDICTION_CODE
    )
    SELECT DISTINCT ON (ifs.customer_number, COALESCE(ifs.numero_adresse, k.ADRNR))
        ifs.customer_number as CUSTOMER_ID,
        COALESCE(ifs.numero_adresse, k.ADRNR) as ADDRESS_ID,
        COALESCE(TRIM(k.NAME1), ifs.name_1) as NAME,
        COALESCE(CONCAT_WS(' ', TRIM(a.STREET), TRIM(a.HOUSE_NUM1)), CONCAT_WS(' ', ifs.street, ifs.postal_code)) as ADDRESS,
        NULL as EAN_LOCATION,
        COALESCE(
            CASE WHEN k.ERDAT IS NOT NULL AND k.ERDAT != '' AND LENGTH(TRIM(k.ERDAT)) = 8
            THEN TO_DATE(k.ERDAT, 'YYYYMMDD')
            ELSE NULL END,
            ifs.created_on
        ) as VALID_FROM,
        NULL as VALID_TO,
        ifs.customer_number as PARTY,
        COALESCE(
            CONCAT_WS(', ', TRIM(a.STREET), TRIM(a.CITY1), TRIM(a.POST_CODE1)),
            CONCAT_WS(', ', ifs.street, ifs.city, ifs.postal_code)
        ) as ADDRESS_LOV,
        CASE 
            WHEN ifs.company_code IS NOT NULL THEN 'TRUE'
            ELSE 'FALSE'
        END as DEFAULT_DOMAIN,
        COALESCE(t_country.LANDX, ifs.country) as COUNTRY,
        COALESCE(k.LAND1, ifs.country) as COUNTRY_DB,
        'Customer' as PARTY_TYPE,
        'CUSTOMER' as PARTY_TYPE_DB,
        NULL as SECONDARY_CONTACT,
        NULL as PRIMARY_CONTACT,
        COALESCE(SUBSTRING(TRIM(a.STREET), 1, 35), SUBSTRING(ifs.street, 1, 35)) as ADDRESS1,
        COALESCE(SUBSTRING(TRIM(a.HOUSE_NUM1), 1, 35), '') as ADDRESS2,
        COALESCE(TRIM(a.HOUSE_NUM2), '') as ADDRESS3,
        COALESCE(TRIM(a.LOCATION), '') as ADDRESS4,
        COALESCE(TRIM(a.BUILDING), '') as ADDRESS5,
        COALESCE(TRIM(a.FLOOR), '') as ADDRESS6,
        COALESCE(SUBSTRING(TRIM(a.POST_CODE1), 1, 35), SUBSTRING(ifs.postal_code, 1, 35)) as ZIP_CODE,
        COALESCE(SUBSTRING(TRIM(a.CITY1), 1, 35), SUBSTRING(ifs.city, 1, 35)) as CITY,
        COALESCE(SUBSTRING(TRIM(a.REGION), 1, 35), SUBSTRING(ifs.region, 1, 35)) as STATE,
        COALESCE(SUBSTRING(TRIM(a.REGION), 1, 35), SUBSTRING(ifs.region, 1, 35)) as COUNTY,
        NULL as JURISDICTION_CODE
    FROM clean_data.ifs_customer ifs  -- TABLE MAÎTRE
    LEFT JOIN raw_data.KNA1 k 
        ON ifs.customer_number = k.KUNNR
        AND ifs.numero_adresse = k.ADRNR
        AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.ADRC a 
        ON COALESCE(ifs.numero_adresse, k.ADRNR) = a.ADDRNUMBER
    LEFT JOIN raw_data.T005T t_country 
        ON COALESCE(k.LAND1, ifs.country) = t_country.LAND1 
        AND t_country.SPRAS = 'F'
    WHERE COALESCE(ifs.numero_adresse, k.ADRNR) IS NOT NULL
    ORDER BY ifs.customer_number, COALESCE(ifs.numero_adresse, k.ADRNR);
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    
    RAISE NOTICE 'INSERT adresses terminé: % enregistrements traités', v_processed_count;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur lors de l''INSERT adresses: %', SQLERRM;
END;
$procedure$;
