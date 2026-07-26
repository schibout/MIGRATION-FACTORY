CREATE OR REPLACE PROCEDURE clean_data.sp_insert_cust_ord_customer_address_from_client_adresse_phl()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion infos adresse commande clients PHL - %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.cust_ord_customer_address;
    RAISE NOTICE 'Table cust_ord_customer_address vidée';
    
    -- Insertion des données PHL
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
    SELECT DISTINCT ON (cp.customer_id, cap.address_id)
        cp.customer_id as customer_no,
        cap.address_id as addr_no,
        'EXW' as delivery_terms,
        NULL as district_code,
        cap.state as region_code,
        '01' as ship_via_code,
        NULL as contact,
        NULL as route_id,
        NULL as delivery_time,
        NULL as intrastat_exempt,
        'FALSE' as intrastat_exempt_db,
        NULL as shipment_uncon_struct,
        'FALSE' as shipment_uncon_struct_db,
        NULL as del_terms_location,
        NULL as cust_calendar_id,
        NULL as shipment_type
    FROM raw_data.client_phl cp
    INNER JOIN raw_data.client_adresse_phl cap ON cap.customer_id = cp.customer_id
    WHERE cp.customer_id IS NOT NULL
    AND cap.address_id IS NOT NULL
    ORDER BY cp.customer_id, cap.address_id;
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();
    
    RAISE NOTICE 'INSERT infos adresse commande terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT infos adresse commande depuis client_adresse_phl - %: %', 
            TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
