CREATE OR REPLACE PROCEDURE clean_data.sp_insert_cust_ord_customer_address_from_file_customer()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN

    v_start_time := NOW();
    RAISE NOTICE 'Début insertion infos adresse commande clients file_customer - %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');

    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.cust_ord_customer_address;
    RAISE NOTICE 'Table cust_ord_customer_address vidée';

    -- Insertion directe après TRUNCATE
    INSERT INTO clean_data.cust_ord_customer_address (
        customer_no,
        addr_no,
        delivery_terms,
        district_code,
        region_code,
        ship_via_code,
        contact,
        route_id,
        delivery_time,
        intrastat_exempt_db,
        shipment_uncon_struct_db,
        del_terms_location,
        cust_calendar_id,
        shipment_type
    )
    WITH fc AS (
        -- 1 ligne = 1 ADRESSE, meme source que customer_info_address : chaque
        -- adresse chargee recoit ses parametres de commande, sinon une adresse
        -- de livraison PHL n'aurait ni incoterm ni mode d'expedition.
        SELECT *
        FROM clean_data.v_customer_address_source
        WHERE customer_id IS NOT NULL
    )
    SELECT DISTINCT ON (fc.customer_id, fc.addr_id)
        fc.customer_id as customer_no,
        fc.addr_id as addr_no,
        COALESCE(knvv.INCO1, NULLIF(TRIM(fc.incoterms_1),''), 'EXW') as delivery_terms,
        COALESCE(knvv.BZIRK, fc.sales_district) as district_code,
        -- Departement de L'ADRESSE : deduit du code postal PHL (regle du
        -- fichier), le champ region du fichier ne valant que pour l'adresse
        -- principale.
        COALESCE(
            CASE WHEN fc.addr_origin = 'PHL'
                  AND fc.addr_zip_code ~ '^[0-9]{5}$'
                  AND COALESCE(fc.addr_country_db, 'FR') = 'FR'
                 THEN LEFT(fc.addr_zip_code, 2) END,
            CASE WHEN fc.addr_id = fc.address_id
                 THEN COALESCE(NULLIF(TRIM(fc.region),''), k.REGIO) END
        ) as region_code,
        COALESCE(knvv.VSBED, '01') as ship_via_code,
        public.get_default_value('clean_data.cust_ord_customer_address', 'contact') as contact,
        public.get_default_value('clean_data.cust_ord_customer_address', 'route_id') as route_id,
        public.get_default_value('clean_data.cust_ord_customer_address', 'delivery_time')::date as delivery_time,
        public.get_default_value('clean_data.cust_ord_customer_address', 'intrastat_exempt_db', 'CUSTOMERFILE') as intrastat_exempt_db,
        public.get_default_value('clean_data.cust_ord_customer_address', 'shipment_uncon_struct_db') as shipment_uncon_struct_db,
        COALESCE(knvv.INCO2, NULLIF(TRIM(fc.incoterms_2),'')) as del_terms_location,
        public.get_default_value('clean_data.cust_ord_customer_address', 'cust_calendar_id') as cust_calendar_id,
        public.get_default_value('clean_data.cust_ord_customer_address', 'shipment_type') as shipment_type
    FROM fc
    LEFT JOIN raw_data.KNA1 k
        ON fc.kunnr = k.KUNNR
        AND fc.numero_adresse = k.ADRNR
        AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.KNVV knvv
        ON fc.kunnr = knvv.KUNNR
        AND fc.vkorg = knvv.VKORG
    ORDER BY fc.customer_id, fc.addr_id;

    GET DIAGNOSTICS v_processed_count = ROW_COUNT;

    v_end_time := NOW();
    RAISE NOTICE 'INSERT infos adresse commande terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));

EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT infos adresse commande - %: %', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
