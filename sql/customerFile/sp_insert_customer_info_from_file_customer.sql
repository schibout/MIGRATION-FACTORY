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
        cf_legacy_customer_as400_mn,
        cf_legacy_customer_sap_id
    )
    WITH fc AS (
        -- Table pivot : raw_data.file_customer (168 clients), deja enrichie en
        -- jointure externe par raw_data.client_phl / client_adresse_phl.
        -- customer_id et address_id sont deja calcules par la vue.
        SELECT *
        FROM clean_data.v_customer_source
        WHERE customer_id IS NOT NULL
    )
    -- Cascade appliquee a chaque colonne : FICHIER -> PHL -> SAP -> valeur par
    -- defaut d'ecran (public.get_default_value). Le fichier fait autorite, PHL
    -- (raw_data.client_phl, rapproche par la vue sur kunnr = numero_sap puis,
    -- a defaut, sur le nom normalise) comble ce que le fichier ne porte pas,
    -- SAP (KNA1) sert de dernier recours metier, et la valeur d'ecran
    -- n'intervient que si aucune source n'a repondu.
    -- Seule exception, documentee sur place : COUNTRY, ou SAP passe avant PHL.
    SELECT DISTINCT ON (fc.customer_id)
        fc.customer_id as CUSTOMER_ID,
        COALESCE(NULLIF(TRIM(fc.name_1),''), fc.phl_cli_name, TRIM(k.NAME1)) as NAME,
        COALESCE(
            -- Date du fichier. Deux formats coexistent : 'YYYYMMDD' (branche PHL
            -- de la vue) et RFC 1123 'Fri, 01 Sep 2023 00:00:00 GMT' (le fichier
            -- reel, 150 des 168 lignes ; l'ancien code ne testait que YYYYMMDD et
            -- perdait donc systematiquement la date du referentiel au profit de SAP).
            -- 'Mon' suppose lc_time anglophone (le serveur est en en_US.UTF-8).
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
        ) as CREATION_DATE,
        COALESCE(NULLIF(TRIM(fc.tax_number_1),''), fc.phl_cli_association_no, TRIM(k.STCD1), TRIM(k.STCD2)) as ASSOCIATION_NO,
        fc.customer_id as PARTY,
        COALESCE(fc.phl_client_default_domain,
                 public.get_default_value('clean_data.customer_info', 'default_domain', 'FALSE')) as DEFAULT_DOMAIN,
        -- Libelle de langue : aucune source ne le porte (le fichier n'a que le
        -- code SAP, client_phl.default_language est vide sur les 152 lignes et
        -- SAP n'expose pas T002T ici) -> seule la valeur d'ecran repond.
        COALESCE(fc.phl_cli_default_language,
                 public.get_default_value('clean_data.customer_info', 'default_language', NULL)) as DEFAULT_LANGUAGE,
        -- Le code langue du fichier est un code SAP ('F', 'E') -> transcodification.
        -- client_phl porte deja le code IFS ('fr', 'en') -> repris tel quel.
        COALESCE(
            public.get_transcodification('LANGUAGE', NULLIF(TRIM(fc.language), '')),
            fc.phl_cli_default_language_db,
            public.get_transcodification('LANGUAGE', k.SPRAS)
        ) as DEFAULT_LANGUAGE_DB,
        -- Libelle de pays : le fichier ne porte que le code ('FR'). SAP passe ici
        -- AVANT PHL, par exception a la cascade habituelle : T005T (SPRAS='F')
        -- repond pour les 168 clients avec un libelle homogene ('France'), alors
        -- que client_phl.country est en majuscules et tronque a 50 caracteres
        -- ('ROYAUME-UNI DE GRANDE-BRETAGNE ET D''IRLANDE DU NOR'). Melanger les
        -- deux donnerait un libelle different d'un client a l'autre.
        COALESCE(NULLIF(TRIM(t_country.LANDX), ''),
                 fc.phl_cli_country,
                 public.get_default_value('clean_data.customer_info', 'country', NULL)) as COUNTRY,
        -- Certains codes pays SAP (ex: 'SZ') n'existent pas dans IFS → NULL pour éviter ORA-20111 IsoCountry.NOTEXIST
        NULLIF(
            COALESCE(
                public.get_transcodification('COUNTRY', NULLIF(TRIM(fc.country), '')),
                fc.phl_cli_country_db,
                public.get_transcodification('COUNTRY', k.LAND1)
            ), 'SZ') as COUNTRY_DB,
        COALESCE(fc.phl_cli_party_type,
                 public.get_default_value('clean_data.customer_info', 'party_type', 'Customer', 'CUSTOMERFILE')) as PARTY_TYPE,
        COALESCE(fc.phl_cli_party_type_db,
                 public.get_default_value('clean_data.customer_info', 'party_type_db', 'CUSTOMER')) as PARTY_TYPE_DB,
        COALESCE(fc.phl_cli_corporate_form,
                 public.get_default_value('clean_data.customer_info', 'corporate_form', NULL)) as CORPORATE_FORM,
        COALESCE(NULLIF(TRIM(fc.vat_number),''), fc.phl_cli_identifier_reference, k.STCEG) as IDENTIFIER_REFERENCE,
        COALESCE(fc.phl_cli_identifier_ref_validation,
                 public.get_default_value('clean_data.customer_info', 'identifier_ref_validation', '', 'CUSTOMERFILE')) as IDENTIFIER_REF_VALIDATION,
        COALESCE(fc.phl_identifier_ref_validation_db,
                 public.get_default_value('clean_data.customer_info', 'identifier_ref_validation_db', '')) as IDENTIFIER_REF_VALIDATION_DB,
        COALESCE(fc.phl_cli_picture_id,
                 public.get_default_value('clean_data.customer_info', 'picture_id', NULL))::numeric as PICTURE_ID,
        COALESCE(fc.phl_cli_one_time,
                 public.get_default_value('clean_data.customer_info', 'one_time', 'False', 'CUSTOMERFILE')) as ONE_TIME,
        COALESCE(fc.phl_one_time_db,
                 public.get_default_value('clean_data.customer_info', 'one_time_db', 'FALSE')) as ONE_TIME_DB,
        COALESCE(fc.phl_cli_customer_category,
                 public.get_default_value('clean_data.customer_info', 'customer_category', NULL)) as CUSTOMER_CATEGORY,
        COALESCE(fc.phl_customer_category_db,
                 public.get_default_value('clean_data.customer_info', 'customer_category_db', 'CUSTOMER')) as CUSTOMER_CATEGORY_DB,
        COALESCE(fc.phl_cli_b2b_customer,
                 public.get_default_value('clean_data.customer_info', 'b2b_customer', 'FALSE', 'CUSTOMERFILE')) as B2B_CUSTOMER,
        COALESCE(fc.phl_b2b_customer_db,
                 public.get_default_value('clean_data.customer_info', 'b2b_customer_db', 'FALSE')) as B2B_CUSTOMER_DB,
        COALESCE(fc.phl_cli_customer_tax_usage_type,
                 public.get_default_value('clean_data.customer_info', 'customer_tax_usage_type', NULL)) as CUSTOMER_TAX_USAGE_TYPE,
        COALESCE(fc.phl_cli_business_classification,
                 public.get_default_value('clean_data.customer_info', 'business_classification', NULL)) as BUSINESS_CLASSIFICATION,
        COALESCE(
            -- Date du fichier. Deux formats coexistent : 'YYYYMMDD' (branche PHL
            -- de la vue) et RFC 1123 'Fri, 01 Sep 2023 00:00:00 GMT' (le fichier
            -- reel, 150 des 168 lignes ; l'ancien code ne testait que YYYYMMDD et
            -- perdait donc systematiquement la date du referentiel au profit de SAP).
            -- 'Mon' suppose lc_time anglophone (le serveur est en en_US.UTF-8).
            CASE
                WHEN fc.created_on ~ '^[0-9]{8}$'
                    THEN TO_DATE(fc.created_on, 'YYYYMMDD')
                WHEN fc.created_on ~ '[0-9]{2} [A-Za-z]{3} [0-9]{4}'
                    THEN TO_DATE(substring(fc.created_on from '[0-9]{2} [A-Za-z]{3} [0-9]{4}'), 'DD Mon YYYY')
            END,
            fc.phl_cli_date_of_registration,
            CASE WHEN k.ERDAT IS NOT NULL AND k.ERDAT != '' AND LENGTH(TRIM(k.ERDAT)) = 8
            THEN TO_DATE(k.ERDAT, 'YYYYMMDD')
            ELSE NULL END
        ) as DATE_OF_REGISTRATION,
        public.get_default_value('clean_data.customer_info', 'main_representative', NULL) as MAIN_REPRESENTATIVE,
        -- CUSTOMER_ID est le numero de compte IFS du fichier et n'est plus
        -- renumerote : sp_renumber_all_customer_ids_file a ete retiree du
        -- pipeline (backend/etl_modules/etl_file_customer.py).
        -- Identifiants legacy : conserves tels quels.
        -- as400 = code client PHL resolu par clean_data.get_legacy_as400_id
        --         (recherche par n° SAP, repli par nom). PAS de repli sur
        --         l'identifiant du fichier : sans correspondance PHL, on laisse
        --         vide plutot que d'y stocker un identifiant qui n'est pas un code AS400.
        -- sap   = identifiant SAP du fichier (kunnr, NULL si le client n'existe pas dans SAP)
        clean_data.get_legacy_as400_id(fc.kunnr, fc.name_1) as cf_legacy_customer_as400_mn,
        fc.kunnr as cf_legacy_customer_sap_id
    -- TABLE PIVOT : le fichier. SAP n'est jamais qu'une jointure EXTERNE : il
    -- complete les colonnes absentes du fichier, il ne cree aucun client.
    -- KNB1 et KNVV etaient joints sans etre lus (et KNVV, multi-lignes par
    -- client, dupliquait les lignes avant le DISTINCT ON) -> supprimes.
    FROM fc
    LEFT JOIN raw_data.KNA1 k
        ON fc.kunnr = k.KUNNR
        AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.T005T t_country
        ON COALESCE(NULLIF(TRIM(fc.country),''), k.LAND1) = t_country.LAND1
        AND t_country.SPRAS = 'F'
    ORDER BY fc.customer_id;

    GET DIAGNOSTICS v_processed_count = ROW_COUNT;

    RAISE NOTICE 'INSERT terminé - %: % enregistrements traités', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;

EXCEPTION
    WHEN OTHERS THEN
        v_error_count := v_error_count + 1;
        RAISE EXCEPTION 'Erreur lors de l''INSERT: %', SQLERRM;
END;
$procedure$
