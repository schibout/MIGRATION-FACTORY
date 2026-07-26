CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_info_address_from_client_adresse_phl()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion adresses clients depuis client_adresse_phl - %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.customer_info_address CASCADE;
    RAISE NOTICE 'Table customer_info_address vidée';
    
    -- Insertion des données depuis client_adresse_phl
    INSERT INTO clean_data.customer_info_address (
        customer_id,
        address_id,
        name,
        address,
        ean_location,
        valid_from,
        valid_to,
        party,
        address_lov,
        default_domain,
        country,
        country_db,
        party_type,
        party_type_db,
        secondary_contact,
        primary_contact,
        address1,
        address2,
        address3,
        address4,
        address5,
        address6,
        zip_code,
        city,
        state,
        county,
        jurisdiction_code
    )
    SELECT DISTINCT ON (cap.customer_id, cap.address_id)
        cap.customer_id as customer_id,
        cap.address_id as address_id,
        cap.name as name,
        cap.address as address,
        cap.ean_location as ean_location,
        NULL as valid_from,
        NULL as valid_to,
        cap.party as party,
        cap.address_lov as address_lov,
        NULL as default_domain,
        cap.country as country,
        cap.country_db as country_db,
        cap.party_type as party_type,
        cap.party_type_db as party_type_db,
        cap.secondary_contact as secondary_contact,
        cap.primary_contact as primary_contact,
        cap.address1 as address1,
        cap.address2 as address2,
        cap.address3 as address3,
        cap.address4 as address4,
        cap.address5 as address5,
        cap.address6 as address6,
        cap.zip_code as zip_code,
        cap.city as city,
        cap.state as state,
        cap.county as county,
        cap.jurisdiction_code as jurisdiction_code
    FROM raw_data.client_adresse_phl cap
    WHERE cap.customer_id IS NOT NULL
    AND cap.address_id IS NOT NULL
    ORDER BY cap.customer_id, cap.address_id, cap.id;
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();
    
    RAISE NOTICE 'INSERT adresses terminé - %: % enregistrements insérés', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT adresses depuis client_adresse_phl - %: %', 
            TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
