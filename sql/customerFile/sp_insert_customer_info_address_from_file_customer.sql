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
        COUNTRY_DB,
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
    -- CASCADE (revision 2026-09-01) : sur l'ADRESSE PRINCIPALE, le FICHIER
    -- fait autorite ; PHL (raw_data.client_adresse_phl) ne vient qu'ensuite,
    -- puis SAP (ADRC/KNA1), puis la valeur d'ecran :
    --     FICHIER -> PHL -> SAP -> public.get_default_value
    -- (auparavant PHL passait devant le fichier, decision du 2026-08-31).
    --
    -- Le fichier et SAP ne decrivent QUE l'adresse principale du client : la
    -- condition `fc.addr_id = fc.address_id` isole cette ligne. Sur les
    -- adresses PHL SECONDAIRES les branches fichier/SAP restent NULL et PHL
    -- demeure seule source -- y appliquer le fichier collerait la rue de Sens
    -- a l'etablissement de Bagnolet.
    --
    -- Les colonnes que le fichier ne porte pas (ean_location,
    -- jurisdiction_code, address2 a address6, party_type_db) suivent la
    -- cascade inchangee PHL -> SAP -> valeur d'ecran.
    SELECT DISTINCT ON (fc.customer_id, fc.addr_id)
        fc.customer_id as CUSTOMER_ID,
        fc.addr_id as ADDRESS_ID,
        COALESCE(
            CASE WHEN fc.addr_id = fc.address_id THEN NULLIF(TRIM(fc.name_1),'') END,
            NULLIF(TRIM(fc.addr_name),''),
            TRIM(k.NAME1)) as NAME,
        -- Adresse principale : rue + code postal du fichier. A defaut, le
        -- texte deja formate IFS de client_adresse_phl, puis ADRC.
        COALESCE(
            CASE WHEN fc.addr_id = fc.address_id
                 THEN NULLIF(TRIM(CONCAT_WS(' ', NULLIF(TRIM(fc.street),''),
                                                 NULLIF(TRIM(fc.postal_code),''))), '')
            END,
            NULLIF(TRIM(fc.addr_address),''),
            CASE WHEN fc.addr_id = fc.address_id
                 THEN NULLIF(TRIM(CONCAT_WS(' ', NULLIF(TRIM(a.STREET),''),
                                                 NULLIF(TRIM(a.HOUSE_NUM1),''))), '')
            END) as ADDRESS,
        -- Absent du fichier : PHL puis valeur d'ecran.
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
            CASE WHEN fc.addr_id = fc.address_id
                 THEN NULLIF(TRIM(CONCAT_WS(', ', NULLIF(TRIM(fc.street),''),
                                                  NULLIF(TRIM(fc.city),''),
                                                  NULLIF(TRIM(fc.postal_code),''))), '')
            END,
            NULLIF(TRIM(fc.addr_address_lov),''),
            CASE WHEN fc.addr_id = fc.address_id
                 THEN NULLIF(TRIM(CONCAT_WS(', ', NULLIF(TRIM(a.STREET),''),
                                                  NULLIF(TRIM(a.CITY1),''),
                                                  NULLIF(TRIM(a.POST_CODE1),''))), '')
            END
        ) as ADDRESS_LOV,
        -- Indicateur d'adresse par defaut. Le fichier ne le porte pas
        -- directement : il est deduit de la presence du code societe sur
        -- l'adresse principale ; les autres adresses reprennent l'indicateur
        -- de PHL, adresse par adresse.
        COALESCE(
            CASE WHEN fc.addr_id = fc.address_id
                  AND NULLIF(TRIM(fc.bukrs), '') IS NOT NULL THEN 'TRUE' END,
            fc.addr_default_domain,
            'FALSE'
        ) as DEFAULT_DOMAIN,
        COALESCE(
            CASE WHEN fc.addr_id = fc.address_id
                 THEN public.get_transcodification('COUNTRY', NULLIF(TRIM(fc.country),'')) END,
            NULLIF(TRIM(fc.addr_country_db),''),
            public.get_transcodification('COUNTRY', k.LAND1)) as COUNTRY_DB,
        -- Absent du fichier : PHL puis valeur d'ecran.
        COALESCE(NULLIF(TRIM(fc.addr_party_type_db),''),
                 public.get_default_value('clean_data.customer_info_address', 'party_type_db', 'CUSTOMER')) as PARTY_TYPE_DB,
        public.get_default_value('clean_data.customer_info_address', 'secondary_contact', NULL) as SECONDARY_CONTACT,
        public.get_default_value('clean_data.customer_info_address', 'primary_contact', NULL) as PRIMARY_CONTACT,
        COALESCE(CASE WHEN fc.addr_id = fc.address_id
                      THEN SUBSTRING(NULLIF(TRIM(fc.street),''), 1, 35) END,
                 SUBSTRING(NULLIF(TRIM(fc.addr_address1),''), 1, 35),
                 CASE WHEN fc.addr_id = fc.address_id
                      THEN SUBSTRING(NULLIF(TRIM(a.STREET),''), 1, 35) END) as ADDRESS1,
        -- address2 a address6 : le fichier ne les porte pas -> PHL puis ADRC.
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
        COALESCE(CASE WHEN fc.addr_id = fc.address_id
                      THEN SUBSTRING(NULLIF(TRIM(fc.postal_code),''), 1, 35) END,
                 SUBSTRING(NULLIF(TRIM(fc.addr_zip_code),''), 1, 35),
                 CASE WHEN fc.addr_id = fc.address_id
                      THEN SUBSTRING(NULLIF(TRIM(a.POST_CODE1),''), 1, 35) END) as ZIP_CODE,
        COALESCE(CASE WHEN fc.addr_id = fc.address_id
                      THEN SUBSTRING(NULLIF(TRIM(fc.city),''), 1, 35) END,
                 SUBSTRING(NULLIF(TRIM(fc.addr_city),''), 1, 35),
                 CASE WHEN fc.addr_id = fc.address_id
                      THEN SUBSTRING(NULLIF(TRIM(a.CITY1),''), 1, 35) END) as CITY,
        -- STATE / COUNTY : la region du fichier ne vaut que pour l'adresse
        -- principale. PHL ne les porte pas : pour une adresse francaise on
        -- reconstitue le departement (2 premiers chiffres du code postal).
        COALESCE(CASE WHEN fc.addr_id = fc.address_id
                      THEN SUBSTRING(NULLIF(TRIM(fc.region),''), 1, 35) END,
                 SUBSTRING(NULLIF(TRIM(fc.addr_state),''), 1, 35),
                 CASE WHEN fc.addr_origin = 'PHL'
                       AND fc.addr_zip_code ~ '^[0-9]{5}$'
                       AND COALESCE(fc.addr_country_db, 'FR') = 'FR'
                      THEN LEFT(fc.addr_zip_code, 2) END,
                 CASE WHEN fc.addr_id = fc.address_id
                      THEN SUBSTRING(NULLIF(TRIM(a.REGION),''), 1, 35) END) as STATE,
        COALESCE(CASE WHEN fc.addr_id = fc.address_id
                      THEN SUBSTRING(NULLIF(TRIM(fc.region),''), 1, 35) END,
                 SUBSTRING(NULLIF(TRIM(fc.addr_county),''), 1, 35),
                 CASE WHEN fc.addr_origin = 'PHL'
                       AND fc.addr_zip_code ~ '^[0-9]{5}$'
                       AND COALESCE(fc.addr_country_db, 'FR') = 'FR'
                      THEN LEFT(fc.addr_zip_code, 2) END,
                 CASE WHEN fc.addr_id = fc.address_id
                      THEN SUBSTRING(NULLIF(TRIM(a.REGION),''), 1, 35) END) as COUNTY,
        -- Absent du fichier : PHL puis valeur d'ecran.
        COALESCE(NULLIF(TRIM(fc.addr_jurisdiction_code),''),
                 public.get_default_value('clean_data.customer_info_address', 'jurisdiction_code', NULL)) as JURISDICTION_CODE
    FROM fc  -- SOURCE PILOTE des LIGNES : adresses PHL, repli fichier.
             -- Le CONTENU de l'adresse principale vient, lui, du fichier.
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
