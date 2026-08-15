-- Procédure pour insérer les adresses clients depuis le fichier file_customer
-- Cette procédure extrait les données d'adresses clients du fichier (raw_data.file_customer)
-- enrichies par les tables SAP (KNA1, ADRC) et les transforme
-- pour alimenter la table CUSTOMER_INFO_ADDRESS avec TRUNCATE + INSERT
-- La source pilote est le fichier file_customer ; les valeurs du fichier sont prioritaires

CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_info_address_from_file_customer()
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
BEGIN

    RAISE NOTICE 'Début insertion adresses clients depuis file_customer';

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
    WITH fc AS (
        SELECT f.*,
            COALESCE(NULLIF(TRIM(f.nouveau_compte_ifs),''), NULLIF(TRIM(f.num_corrige),''), TRIM(f.kunnr)) AS customer_id,
            COALESCE(NULLIF(split_part(TRIM(f.numero_adresse), '.', 1), ''), '1') AS address_id
        FROM raw_data.file_customer f
        WHERE COALESCE(NULLIF(TRIM(f.nouveau_compte_ifs),''), NULLIF(TRIM(f.num_corrige),''), TRIM(f.kunnr)) IS NOT NULL
    )
    SELECT DISTINCT ON (fc.customer_id, fc.address_id)
        fc.customer_id as CUSTOMER_ID,
        fc.address_id as ADDRESS_ID,
        COALESCE(NULLIF(TRIM(fc.name_1),''), TRIM(k.NAME1)) as NAME,
        COALESCE(CONCAT_WS(' ', fc.street, fc.postal_code), CONCAT_WS(' ', TRIM(a.STREET), TRIM(a.HOUSE_NUM1))) as ADDRESS,
        NULL as EAN_LOCATION,
        COALESCE(
            CASE WHEN fc.created_on ~ '^[0-9]{8}$' THEN TO_DATE(fc.created_on, 'YYYYMMDD') ELSE NULL END,
            CASE WHEN k.ERDAT IS NOT NULL AND k.ERDAT != '' AND LENGTH(TRIM(k.ERDAT)) = 8
            THEN TO_DATE(k.ERDAT, 'YYYYMMDD')
            ELSE NULL END
        ) as VALID_FROM,
        NULL as VALID_TO,
        fc.customer_id as PARTY,
        COALESCE(
            CONCAT_WS(', ', fc.street, fc.city, fc.postal_code),
            CONCAT_WS(', ', TRIM(a.STREET), TRIM(a.CITY1), TRIM(a.POST_CODE1))
        ) as ADDRESS_LOV,
        CASE
            WHEN fc.bukrs IS NOT NULL THEN 'TRUE'
            ELSE 'FALSE'
        END as DEFAULT_DOMAIN,
        COALESCE(NULLIF(TRIM(fc.country),''), t_country.LANDX) as COUNTRY,
        COALESCE(NULLIF(TRIM(fc.country),''), k.LAND1) as COUNTRY_DB,
        'Customer' as PARTY_TYPE,
        'CUSTOMER' as PARTY_TYPE_DB,
        NULL as SECONDARY_CONTACT,
        NULL as PRIMARY_CONTACT,
        COALESCE(SUBSTRING(fc.street, 1, 35), SUBSTRING(TRIM(a.STREET), 1, 35)) as ADDRESS1,
        COALESCE(SUBSTRING(TRIM(a.HOUSE_NUM1), 1, 35), '') as ADDRESS2,
        COALESCE(TRIM(a.HOUSE_NUM2), '') as ADDRESS3,
        COALESCE(TRIM(a.LOCATION), '') as ADDRESS4,
        COALESCE(TRIM(a.BUILDING), '') as ADDRESS5,
        COALESCE(TRIM(a.FLOOR), '') as ADDRESS6,
        COALESCE(SUBSTRING(fc.postal_code, 1, 35), SUBSTRING(TRIM(a.POST_CODE1), 1, 35)) as ZIP_CODE,
        COALESCE(SUBSTRING(fc.city, 1, 35), SUBSTRING(TRIM(a.CITY1), 1, 35)) as CITY,
        COALESCE(SUBSTRING(fc.region, 1, 35), SUBSTRING(TRIM(a.REGION), 1, 35)) as STATE,
        COALESCE(SUBSTRING(fc.region, 1, 35), SUBSTRING(TRIM(a.REGION), 1, 35)) as COUNTY,
        NULL as JURISDICTION_CODE
    FROM fc  -- SOURCE PILOTE : fichier file_customer
    LEFT JOIN raw_data.KNA1 k
        ON fc.kunnr = k.KUNNR
        AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.ADRC a
        ON fc.numero_adresse = a.ADDRNUMBER
    LEFT JOIN raw_data.T005T t_country
        ON COALESCE(NULLIF(TRIM(fc.country),''), k.LAND1) = t_country.LAND1
        AND t_country.SPRAS = 'F'
    WHERE fc.address_id IS NOT NULL
    ORDER BY fc.customer_id, fc.address_id;

    GET DIAGNOSTICS v_processed_count = ROW_COUNT;

    RAISE NOTICE 'INSERT adresses terminé: % enregistrements traités', v_processed_count;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur lors de l''INSERT adresses depuis file_customer: %', SQLERRM;
END;
$procedure$;
