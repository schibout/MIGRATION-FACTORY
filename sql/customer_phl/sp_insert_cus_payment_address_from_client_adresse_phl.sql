CREATE OR REPLACE PROCEDURE clean_data.sp_insert_cus_payment_address_from_client_adresse_phl()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion adresses paiement clients PHL - %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.cus_payment_address;
    RAISE NOTICE 'Table cus_payment_address vidée';
    
    -- Insertion des données PHL
    INSERT INTO clean_data.cus_payment_address (
        company,
        identity,
        party_type,
        party_type_db,
        way_id,
        address_id,
        description,
        default_address,
        account,
        bic_code,
        blocked_for_use,
        bank_account_validated,
        bank_account_validated_db,
        bank_account_valid_date
    )
    SELECT DISTINCT ON (cp.customer_id, cap.address_id)
        'TRIMET' as company,
        cp.customer_id as identity,
        'Customer' as party_type,
        'CUSTOMER' as party_type_db,
        'SEPA' as way_id,
        cap.address_id as address_id,
        CONCAT_WS(' - ', COALESCE(cap.name, cp.name), COALESCE(cap.city, '')) as description,
        CASE
            WHEN ROW_NUMBER() OVER (
                PARTITION BY cp.customer_id
                ORDER BY
                    CASE WHEN cap.address_id IN ('01', '1') THEN 0 ELSE 1 END,
                    CASE WHEN cap.address_id = '1' THEN '01' ELSE cap.address_id END,
                    cap.address_id
            ) = 1 THEN 'TRUE'
            ELSE 'FALSE'
        END as default_address,
        NULL as account,
        NULL as bic_code,
        'FALSE' as blocked_for_use,
        NULL as bank_account_validated,
        'NOT VALIDATED' as bank_account_validated_db,
        NULL as bank_account_valid_date
    FROM raw_data.client_phl cp
    INNER JOIN raw_data.client_adresse_phl cap ON cap.customer_id = cp.customer_id
    WHERE cp.customer_id IS NOT NULL
    AND cap.address_id IS NOT NULL
    ORDER BY cp.customer_id, cap.address_id;
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();
    
    RAISE NOTICE 'INSERT adresses paiement terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT adresses paiement depuis client_adresse_phl - %: %', 
            TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
