CREATE OR REPLACE PROCEDURE clean_data.sp_insert_cust_ord_customer_address_from_sap()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion infos adresse commande clients SAP - % - Basé sur ifs_customer', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    
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
        intrastat_exempt,
        intrastat_exempt_db,
        shipment_uncon_struct,
        shipment_uncon_struct_db,
        del_terms_location,
        cust_calendar_id,
        shipment_type
    )
    SELECT DISTINCT ON (ifs.customer_number, COALESCE(ifs.numero_adresse, k.ADRNR))
        ifs.customer_number as customer_no,
        COALESCE(ifs.numero_adresse, k.ADRNR) as addr_no,
        COALESCE(knvv.INCO1, ifs.incoterms_1, 'EXW') as delivery_terms,
        COALESCE(knvv.BZIRK, ifs.sales_district) as district_code,
        COALESCE(k.REGIO, ifs.region) as region_code,
        COALESCE(knvv.VSBED, '01') as ship_via_code,
        NULL as contact,
        NULL as route_id,
        NULL as delivery_time,
        NULL as intrastat_exempt,
        'FALSE' as intrastat_exempt_db,
        NULL as shipment_uncon_struct,
        'FALSE' as shipment_uncon_struct_db,
        COALESCE(knvv.INCO2, ifs.incoterms_2) as del_terms_location,
        NULL as cust_calendar_id,
        NULL as shipment_type
    FROM clean_data.ifs_customer ifs
    LEFT JOIN raw_data.KNA1 k 
        ON ifs.customer_number = k.KUNNR
        AND ifs.numero_adresse = k.ADRNR
        AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.KNVV knvv 
        ON ifs.customer_number = knvv.KUNNR
        AND ifs.sales_organization = knvv.VKORG
    WHERE COALESCE(ifs.numero_adresse, k.ADRNR) IS NOT NULL
    ORDER BY ifs.customer_number, COALESCE(ifs.numero_adresse, k.ADRNR);
    
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
