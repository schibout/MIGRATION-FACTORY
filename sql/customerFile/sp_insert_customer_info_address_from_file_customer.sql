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
        -- Table pivot : raw_data.file_customer (168 clients), deja enrichie en
        -- jointure externe par raw_data.client_phl / client_adresse_phl.
        -- customer_id et address_id sont deja calcules par la vue.
        SELECT *
        FROM clean_data.v_customer_source
        WHERE customer_id IS NOT NULL
    )
    -- Cascade appliquee a chaque colonne : FICHIER -> PHL -> SAP (ADRC/KNA1).
    -- Les colonnes phl_* passaient auparavant AVANT celles du fichier : c'etait
    -- sans effet tant qu'elles n'etaient alimentees que sur la branche PHL de la
    -- vue (supprimee depuis). Maintenant qu'elles completent les clients du
    -- fichier, l'ordre est retabli : le fichier fait autorite.
    SELECT DISTINCT ON (fc.customer_id, fc.address_id)
        fc.customer_id as CUSTOMER_ID,
        fc.address_id as ADDRESS_ID,
        COALESCE(NULLIF(TRIM(fc.name_1),''), NULLIF(TRIM(fc.phl_addr_name),''), TRIM(k.NAME1)) as NAME,
        -- client_adresse_phl fournit deja l'adresse au format IFS : elle est
        -- reprise telle quelle, mais seulement si le fichier ne dit rien.
        COALESCE(NULLIF(CONCAT_WS(' ', fc.street, fc.postal_code), ''),
                 NULLIF(TRIM(fc.phl_address),''),
                 NULLIF(CONCAT_WS(' ', TRIM(a.STREET), TRIM(a.HOUSE_NUM1)), '')) as ADDRESS,
        public.get_default_value('clean_data.customer_info_address', 'ean_location', NULL) as EAN_LOCATION,
        -- Deux formats de date coexistent dans le fichier : 'YYYYMMDD' et
        -- RFC 1123 'Fri, 01 Sep 2023 00:00:00 GMT' (150 des 168 lignes). Ne
        -- tester que YYYYMMDD perdait la date du fichier au profit de SAP.
        -- 'Mon' suppose lc_time anglophone (le serveur est en en_US.UTF-8).
        COALESCE(
            CASE
                WHEN fc.created_on ~ '^[0-9]{8}$'
                    THEN TO_DATE(fc.created_on, 'YYYYMMDD')
                WHEN fc.created_on ~ '[0-9]{2} [A-Za-z]{3} [0-9]{4}'
                    THEN TO_DATE(substring(fc.created_on from '[0-9]{2} [A-Za-z]{3} [0-9]{4}'), 'DD Mon YYYY')
            END,
            fc.phl_cli_creation_date,
            CASE WHEN k.ERDAT IS NOT NULL AND k.ERDAT != '' AND LENGTH(TRIM(k.ERDAT)) = 8
            THEN TO_DATE(k.ERDAT, 'YYYYMMDD')
            ELSE NULL END
        ) as VALID_FROM,
        public.get_default_value('clean_data.customer_info_address', 'valid_to', NULL)::date as VALID_TO,
        fc.customer_id as PARTY,
        COALESCE(
            NULLIF(CONCAT_WS(', ', fc.street, fc.city, fc.postal_code), ''),
            NULLIF(TRIM(fc.phl_address_lov),''),
            NULLIF(CONCAT_WS(', ', TRIM(a.STREET), TRIM(a.CITY1), TRIM(a.POST_CODE1)), '')
        ) as ADDRESS_LOV,
        -- Le fichier ne porte pas d'indicateur de domaine par defaut : il est
        -- deduit de la presence du code societe, PHL ne servant que de repli.
        COALESCE(
            CASE WHEN NULLIF(TRIM(fc.bukrs), '') IS NOT NULL THEN 'TRUE' END,
            fc.phl_default_domain,
            'FALSE'
        ) as DEFAULT_DOMAIN,
        -- file_customer.country est un CODE ('FR') sur les 168 lignes, pas un
        -- libelle : il alimente COUNTRY_DB, pas COUNTRY. Le libelle vient donc
        -- de SAP (T005T, SPRAS='F'), puis de PHL, comme dans customer_info.
        COALESCE(NULLIF(TRIM(t_country.LANDX),''), fc.phl_cli_country) as COUNTRY,
        public.get_transcodification('COUNTRY', COALESCE(NULLIF(TRIM(fc.country),''), k.LAND1)) as COUNTRY_DB,
        public.get_default_value('clean_data.customer_info_address', 'party_type', 'Customer') as PARTY_TYPE,
        COALESCE(NULLIF(TRIM(fc.phl_party_type_db),''),
                 public.get_default_value('clean_data.customer_info_address', 'party_type_db', 'CUSTOMER')) as PARTY_TYPE_DB,
        public.get_default_value('clean_data.customer_info_address', 'secondary_contact', NULL) as SECONDARY_CONTACT,
        public.get_default_value('clean_data.customer_info_address', 'primary_contact', NULL) as PRIMARY_CONTACT,
        COALESCE(SUBSTRING(fc.street, 1, 35), SUBSTRING(TRIM(a.STREET), 1, 35)) as ADDRESS1,
        COALESCE(SUBSTRING(NULLIF(TRIM(fc.phl_address2),''), 1, 35), SUBSTRING(NULLIF(TRIM(a.HOUSE_NUM1),''), 1, 35), '') as ADDRESS2,
        COALESCE(TRIM(a.HOUSE_NUM2), '') as ADDRESS3,
        COALESCE(TRIM(a.LOCATION), '') as ADDRESS4,
        COALESCE(TRIM(a.BUILDING), '') as ADDRESS5,
        COALESCE(TRIM(a.FLOOR), '') as ADDRESS6,
        COALESCE(SUBSTRING(fc.postal_code, 1, 35), SUBSTRING(TRIM(a.POST_CODE1), 1, 35)) as ZIP_CODE,
        COALESCE(SUBSTRING(fc.city, 1, 35), SUBSTRING(TRIM(a.CITY1), 1, 35)) as CITY,
        COALESCE(SUBSTRING(fc.region, 1, 35), SUBSTRING(TRIM(a.REGION), 1, 35)) as STATE,
        COALESCE(SUBSTRING(fc.region, 1, 35), SUBSTRING(TRIM(a.REGION), 1, 35)) as COUNTY,
        public.get_default_value('clean_data.customer_info_address', 'jurisdiction_code', NULL) as JURISDICTION_CODE
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
$procedure$
