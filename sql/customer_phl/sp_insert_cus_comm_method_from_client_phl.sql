CREATE OR REPLACE PROCEDURE clean_data.sp_insert_cus_comm_method_from_client_phl()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion méthodes communication clients PHL - %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.cus_comm_method;
    RAISE NOTICE 'Table cus_comm_method vidée';
    
    -- Note: Les données PHL n'ont pas de champs téléphone/fax directement
    -- On insère un enregistrement par client/adresse sans valeur de communication
    INSERT INTO clean_data.cus_comm_method (
        party_type,
        party_type_db,
        identity,
        comm_id,
        value,
        method_id,
        description,
        valid_from,
        valid_to,
        method_default,
        address_default,
        name,
        method_id_db,
        address_id
    )
    SELECT DISTINCT ON (cp.customer_id, cap.address_id)
        NULL AS party_type,
        'CUSTOMER' AS party_type_db,
        cp.customer_id AS identity,
        NULL::NUMERIC AS comm_id,
        NULL AS value,
        NULL AS method_id,
        NULL AS description,
        NULL::DATE AS valid_from,
        NULL::DATE AS valid_to,
        'FALSE' AS method_default,
        'FALSE' AS address_default,
        COALESCE(cap.name, cp.name) AS name,
        'PHONE' AS method_id_db,
        cap.address_id AS address_id
    FROM raw_data.client_phl cp
    INNER JOIN raw_data.client_adresse_phl cap ON cap.customer_id = cp.customer_id
    WHERE cp.customer_id IS NOT NULL
    AND cap.address_id IS NOT NULL
    ORDER BY cp.customer_id, cap.address_id;
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();
    
    RAISE NOTICE 'INSERT méthodes communication terminé - %: % enregistrements insérés', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT méthodes communication depuis client_adresse_phl - %: %', 
            TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
