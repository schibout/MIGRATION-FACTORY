CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_document_tax_info_from_file_customer()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_count INTEGER;
BEGIN
    -- Enregistrer le début de l'opération
    v_start_time := NOW();
    RAISE NOTICE '[%] 🚀 Début de sp_insert_customer_document_tax_info_from_file_customer - Basé sur file_customer', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS');

    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.customer_document_tax_info;
    RAISE NOTICE '[%] 🗑️ Table customer_document_tax_info vidée', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS');

    -- Insertion directe après TRUNCATE
    INSERT INTO clean_data.customer_document_tax_info (
        CUSTOMER_ID,
        ADDRESS_ID,
        COMPANY,
        SUPPLY_COUNTRY_DB,
        DELIVERY_COUNTRY_DB,
        TAX_ID_TYPE,
        VAT_NO,
        VALIDATED_DATE,
        TAX_ID_ERROR_MESSAGE,
        TAX_OFFICE_ID
    )
    WITH fc AS (
        -- Source unifiee : fichier + clients PHL absents du fichier.
        -- customer_id et address_id sont deja calcules par la vue. TVA UE
        SELECT *
        FROM clean_data.v_customer_source
        WHERE customer_id IS NOT NULL
    )
    SELECT DISTINCT ON (fc.customer_id, fc.address_id, public.get_transcodification('COUNTRY', COALESCE(k.LAND1, fc.country, 'FR')))
        fc.customer_id as CUSTOMER_ID,
        fc.address_id as ADDRESS_ID,
        public.get_default_value('clean_data.customer_document_tax_info', 'company') as COMPANY,
        public.get_transcodification('COUNTRY', COALESCE(k.LAND1, fc.country, 'FR')) as SUPPLY_COUNTRY_DB,
        public.get_transcodification('COUNTRY', COALESCE(k.LAND1, fc.country, 'FR')) as DELIVERY_COUNTRY_DB,
        public.get_default_value('clean_data.customer_document_tax_info', 'tax_id_type') as TAX_ID_TYPE,
        -- NUMERO DE TVA. Cascade : fichier -> SAP STCEG -> PHL -> SAP STCD1.
        -- IFS exige le format majuscule.
        -- PHL (raw_data.client_adresse_phl.tva, rapproche par mnemo =
        -- search_term) arrive APRES STCEG : quand les deux existent ils sont
        -- identiques, sauf pour NEXANS COTE D'IVOIRE ou la valeur PHL est
        -- TRONQUEE ('CI-ABJ-2016-B-' contre 'CI-ABJ-2016-B-17164' dans SAP).
        -- GARDE-FOU : la colonne `tva` de PHL est peu fiable -- elle porte
        -- pour 5 clients un numero d'un tout autre pays que le client
        -- (NEXANS MAROC -> 'FR82428593230', TELMAKSAN (Turquie) ->
        -- 'IT02593800788', TUNISIE CABLE -> 'PT500049572'...). On ne la
        -- retient donc QUE si son prefixe pays correspond au pays du client.
        -- STCD1 reste en dernier recours : hors UE, SAP y loge l'identifiant
        -- fiscal local a defaut de numero de TVA intracommunautaire.
        UPPER(COALESCE(
            NULLIF(TRIM(fc.vat_number), ''),
            NULLIF(TRIM(k.STCEG), ''),
            CASE WHEN UPPER(LEFT(TRIM(phl_tva.tva), 2))
                    = UPPER(public.get_transcodification('COUNTRY', COALESCE(k.LAND1, fc.country, 'FR')))
                 THEN NULLIF(TRIM(phl_tva.tva), '') END,
            NULLIF(TRIM(k.STCD1), '')
        )) as VAT_NO,
        public.get_default_value('clean_data.customer_document_tax_info', 'validated_date')::date as VALIDATED_DATE,
        public.get_default_value('clean_data.customer_document_tax_info', 'tax_id_error_message') as TAX_ID_ERROR_MESSAGE,
        public.get_default_value('clean_data.customer_document_tax_info', 'tax_office_id') as TAX_OFFICE_ID
    FROM fc  -- TABLE MAÎTRE
    LEFT JOIN raw_data.KNA1 k
        ON fc.kunnr = k.KUNNR
        AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.T005T t_country
        ON COALESCE(k.LAND1, fc.country) = t_country.LAND1
        AND t_country.SPRAS = 'F'
    -- Numero de TVA du referentiel PHL. LATERAL + LIMIT 1 : un client PHL
    -- porte plusieurs adresses (jusqu'a 8) qui repetent toutes la meme TVA,
    -- une jointure simple dupliquerait les lignes.
    LEFT JOIN LATERAL (
        SELECT a.tva
        FROM raw_data.client_adresse_phl a
        WHERE UPPER(TRIM(a.mnemo)) = UPPER(TRIM(fc.search_term))
          AND NULLIF(TRIM(a.tva), '') IS NOT NULL
        ORDER BY TRIM(a.id_client)
        LIMIT 1
    ) phl_tva ON TRUE
    ORDER BY fc.customer_id, fc.address_id, public.get_transcodification('COUNTRY', COALESCE(k.LAND1, fc.country, 'FR'));

    -- Compter les enregistrements insérés
    GET DIAGNOSTICS v_count = ROW_COUNT;

    -- Enregistrer la fin de l'opération
    v_end_time := NOW();

    -- Logs de fin avec statistiques
    RAISE NOTICE '[%] ✅ sp_insert_customer_document_tax_info_from_file_customer terminé avec succès', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS');
    RAISE NOTICE '[%] 📊 Nombre d''enregistrements insérés: %', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'), v_count;
    RAISE NOTICE '[%] ⏱️ Durée totale: %', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'), v_end_time - v_start_time;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '[%] ❌ Erreur dans sp_insert_customer_document_tax_info_from_file_customer: %', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
        RAISE;
END;
$procedure$
