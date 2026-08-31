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
        -- 1 ligne = 1 ADRESSE. Les clients rapproches a PHL reprennent TOUTES
        -- leurs adresses raw_data.client_adresse_phl (addr_id = address_id
        -- PHL) ; les clients sans rapprochement gardent l'unique adresse du
        -- fichier. Le client reste identifie par customer_id (numerotation
        -- IFS du fichier).
        SELECT *
        FROM clean_data.v_customer_address_source
        WHERE customer_id IS NOT NULL
    )
    -- Cascade appliquee a chaque colonne : PHL -> FICHIER -> SAP (ADRC/KNA1).
    -- L'ADRESSE fait autorite cote PHL (decision 2026-08-31) : le fichier ne
    -- sert plus que de repli, pour les clients non rapproches et pour les
    -- colonnes que PHL ne renseigne pas (zip_code, county, state, address3 a
    -- address6, ean_location, jurisdiction_code : vides sur les 670 lignes).
    SELECT DISTINCT ON (fc.customer_id, fc.addr_id)
        fc.customer_id as CUSTOMER_ID,
        fc.addr_id as ADDRESS_ID,
        COALESCE(NULLIF(TRIM(fc.addr_name),''), NULLIF(TRIM(fc.name_1),''), TRIM(k.NAME1)) as NAME,
        -- client_adresse_phl fournit deja l'adresse au format IFS : elle est
        -- reprise telle quelle.
        -- REGLE DE REPLI (fc.addr_id = fc.address_id) : le fichier et SAP ne
        -- decrivent QUE l'adresse principale du client. Les reprendre sur une
        -- adresse PHL secondaire produirait une adresse fausse (rue de Sens
        -- collee a l'etablissement de Bagnolet) : le repli fichier/SAP n'est
        -- donc autorise que sur l'adresse principale.
        COALESCE(NULLIF(TRIM(fc.addr_address),''),
                 CASE WHEN fc.addr_id = fc.address_id THEN
                     COALESCE(NULLIF(CONCAT_WS(' ', fc.street, fc.postal_code), ''),
                              NULLIF(CONCAT_WS(' ', TRIM(a.STREET), TRIM(a.HOUSE_NUM1)), ''))
                 END) as ADDRESS,
        COALESCE(NULLIF(TRIM(fc.addr_ean_location),''),
                 public.get_default_value('clean_data.customer_info_address', 'ean_location', NULL)) as EAN_LOCATION,
        -- Deux formats de date coexistent dans le fichier : 'YYYYMMDD' et
        -- RFC 1123 'Fri, 01 Sep 2023 00:00:00 GMT' (150 des 168 lignes). Ne
        -- tester que YYYYMMDD perdait la date du fichier au profit de SAP.
        -- 'Mon' suppose lc_time anglophone (le serveur est en en_US.UTF-8).
        -- La date reste celle du CLIENT : client_adresse_phl n'en porte pas.
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
            NULLIF(TRIM(fc.addr_address_lov),''),
            CASE WHEN fc.addr_id = fc.address_id THEN
                COALESCE(NULLIF(CONCAT_WS(', ', fc.street, fc.city, fc.postal_code), ''),
                         NULLIF(CONCAT_WS(', ', TRIM(a.STREET), TRIM(a.CITY1), TRIM(a.POST_CODE1)), ''))
            END
        ) as ADDRESS_LOV,
        -- Indicateur d'adresse par defaut : celui de PHL, adresse par adresse.
        -- Sans PHL, le fichier n'en porte pas : il est deduit de la presence
        -- du code societe.
        COALESCE(
            fc.addr_default_domain,
            CASE WHEN NULLIF(TRIM(fc.bukrs), '') IS NOT NULL THEN 'TRUE' END,
            'FALSE'
        ) as DEFAULT_DOMAIN,
        -- file_customer.country est un CODE ('FR') sur les 168 lignes, pas un
        -- libelle : il alimente COUNTRY_DB, pas COUNTRY. Le libelle vient donc
        -- de PHL (client_adresse_phl.country = 'FRANCE'), puis de SAP (T005T,
        -- SPRAS='F'), puis du client PHL.
        COALESCE(NULLIF(TRIM(fc.addr_country),''),
                 NULLIF(TRIM(t_country.LANDX),''),
                 fc.phl_cli_country) as COUNTRY,
        COALESCE(NULLIF(TRIM(fc.addr_country_db),''),
                 public.get_transcodification('COUNTRY', COALESCE(NULLIF(TRIM(fc.country),''), k.LAND1))) as COUNTRY_DB,
        COALESCE(NULLIF(TRIM(fc.addr_party_type),''),
                 public.get_default_value('clean_data.customer_info_address', 'party_type', 'Customer')) as PARTY_TYPE,
        COALESCE(NULLIF(TRIM(fc.addr_party_type_db),''),
                 public.get_default_value('clean_data.customer_info_address', 'party_type_db', 'CUSTOMER')) as PARTY_TYPE_DB,
        public.get_default_value('clean_data.customer_info_address', 'secondary_contact', NULL) as SECONDARY_CONTACT,
        public.get_default_value('clean_data.customer_info_address', 'primary_contact', NULL) as PRIMARY_CONTACT,
        COALESCE(SUBSTRING(NULLIF(TRIM(fc.addr_address1),''), 1, 35),
                 CASE WHEN fc.addr_id = fc.address_id
                      THEN COALESCE(SUBSTRING(fc.street, 1, 35), SUBSTRING(TRIM(a.STREET), 1, 35)) END) as ADDRESS1,
        COALESCE(SUBSTRING(NULLIF(TRIM(fc.addr_address2),''), 1, 35),
                 CASE WHEN fc.addr_id = fc.address_id
                      THEN SUBSTRING(NULLIF(TRIM(a.HOUSE_NUM1),''), 1, 35) END, '') as ADDRESS2,
        COALESCE(SUBSTRING(NULLIF(TRIM(fc.addr_address3),''), 1, 35),
                 CASE WHEN fc.addr_id = fc.address_id THEN TRIM(a.HOUSE_NUM2) END, '') as ADDRESS3,
        COALESCE(SUBSTRING(NULLIF(TRIM(fc.addr_address4),''), 1, 35),
                 CASE WHEN fc.addr_id = fc.address_id THEN TRIM(a.LOCATION) END, '') as ADDRESS4,
        COALESCE(SUBSTRING(NULLIF(TRIM(fc.addr_address5),''), 1, 35),
                 CASE WHEN fc.addr_id = fc.address_id THEN TRIM(a.BUILDING) END, '') as ADDRESS5,
        COALESCE(SUBSTRING(NULLIF(TRIM(fc.addr_address6),''), 1, 35),
                 CASE WHEN fc.addr_id = fc.address_id THEN TRIM(a.FLOOR) END, '') as ADDRESS6,
        COALESCE(SUBSTRING(NULLIF(TRIM(fc.addr_zip_code),''), 1, 35),
                 CASE WHEN fc.addr_id = fc.address_id
                      THEN COALESCE(SUBSTRING(fc.postal_code, 1, 35), SUBSTRING(TRIM(a.POST_CODE1), 1, 35)) END) as ZIP_CODE,
        COALESCE(SUBSTRING(NULLIF(TRIM(fc.addr_city),''), 1, 35),
                 CASE WHEN fc.addr_id = fc.address_id
                      THEN COALESCE(SUBSTRING(fc.city, 1, 35), SUBSTRING(TRIM(a.CITY1), 1, 35)) END) as CITY,
        -- STATE / COUNTY : PHL ne les porte pas. Pour une adresse francaise on
        -- reprend la regle du fichier (departement = 2 premiers chiffres du
        -- code postal) ; le champ region du fichier ne vaut que pour l'adresse
        -- principale.
        COALESCE(SUBSTRING(NULLIF(TRIM(fc.addr_state),''), 1, 35),
                 CASE WHEN fc.addr_origin = 'PHL'
                       AND fc.addr_zip_code ~ '^[0-9]{5}$'
                       AND COALESCE(fc.addr_country_db, 'FR') = 'FR'
                      THEN LEFT(fc.addr_zip_code, 2) END,
                 CASE WHEN fc.addr_id = fc.address_id
                      THEN COALESCE(SUBSTRING(fc.region, 1, 35), SUBSTRING(TRIM(a.REGION), 1, 35)) END) as STATE,
        COALESCE(SUBSTRING(NULLIF(TRIM(fc.addr_county),''), 1, 35),
                 CASE WHEN fc.addr_origin = 'PHL'
                       AND fc.addr_zip_code ~ '^[0-9]{5}$'
                       AND COALESCE(fc.addr_country_db, 'FR') = 'FR'
                      THEN LEFT(fc.addr_zip_code, 2) END,
                 CASE WHEN fc.addr_id = fc.address_id
                      THEN COALESCE(SUBSTRING(fc.region, 1, 35), SUBSTRING(TRIM(a.REGION), 1, 35)) END) as COUNTY,
        COALESCE(NULLIF(TRIM(fc.addr_jurisdiction_code),''),
                 public.get_default_value('clean_data.customer_info_address', 'jurisdiction_code', NULL)) as JURISDICTION_CODE
    FROM fc  -- SOURCE PILOTE : adresses PHL, repli fichier
    LEFT JOIN raw_data.KNA1 k
        ON fc.kunnr = k.KUNNR
        AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.ADRC a
        ON fc.numero_adresse = a.ADDRNUMBER
    LEFT JOIN raw_data.T005T t_country
        ON COALESCE(NULLIF(TRIM(fc.country),''), k.LAND1) = t_country.LAND1
        AND t_country.SPRAS = 'F'
    WHERE fc.addr_id IS NOT NULL
    ORDER BY fc.customer_id, fc.addr_id;

    GET DIAGNOSTICS v_processed_count = ROW_COUNT;

    RAISE NOTICE 'INSERT adresses terminé: % enregistrements traités', v_processed_count;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur lors de l''INSERT adresses depuis file_customer: %', SQLERRM;
END;
$procedure$
