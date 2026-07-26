CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_del_tax_exempt_from_client_adresse_phl()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion del tax exempt clients PHL - %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.CUSTOMER_DEL_TAX_EXEMPT;
    RAISE NOTICE 'Table customer_del_tax_exempt vidée';
    
    -- Insertion directe après TRUNCATE
    INSERT INTO clean_data.CUSTOMER_DEL_TAX_EXEMPT (
        CUSTOMER_ID,
        ADDRESS_ID,
        COMPANY,
        SUPPLY_COUNTRY,
        TAX_EXEMPTION_CERT_NO,
        CERTIFICATION_JURISDICTION,
        CERTIFICATION_DATE,
        EXPIRATION_DATE,
        EXEMPT_CERTIFICATE_TYPE,
        EXEMPT_CERTIFICATE_TYPE_DB,
        CERTIFICATE_AMOUNT
    )
    SELECT DISTINCT ON (cp.customer_id, cap.address_id, COALESCE(ic.code_pays, cap.country_db, 'FR'), COALESCE(ic.numero_tva_1, ic.numero_tva_2, 'NO_CERT'))
        cp.customer_id as CUSTOMER_ID,
        cap.address_id as ADDRESS_ID,
        'TRIMET' as COMPANY,
        COALESCE(ic.code_pays, cap.country_db, 'FR') as SUPPLY_COUNTRY,
        SUBSTRING(COALESCE(ic.numero_tva_ue, ic.numero_tva_1, ic.numero_tva_2, 'NO_CERT'), 1, 20) as TAX_EXEMPTION_CERT_NO,
        SUBSTRING(COALESCE(ic.code_pays, cap.country_db, 'FR'), 1, 100) as CERTIFICATION_JURISDICTION,
        cp.creation_date as CERTIFICATION_DATE,
        COALESCE(cp.creation_date + INTERVAL '1 year', CURRENT_DATE + INTERVAL '1 year') as EXPIRATION_DATE,
        '' as EXEMPT_CERTIFICATE_TYPE,
        'BLANKET CERTIFICATE' as EXEMPT_CERTIFICATE_TYPE_DB,
        0 as CERTIFICATE_AMOUNT
    FROM clean_data.ifs_clients ic
    INNER JOIN raw_data.client_phl cp ON cp.numero_sap = ic.numero_client
    LEFT JOIN raw_data.client_adresse_phl cap ON cap.customer_id = cp.customer_id
    WHERE cp.customer_id IS NOT NULL
    AND cap.address_id IS NOT NULL
    ORDER BY cp.customer_id, cap.address_id, COALESCE(ic.code_pays, cap.country_db, 'FR'), COALESCE(ic.numero_tva_1, ic.numero_tva_2, 'NO_CERT');
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();
    
    RAISE NOTICE 'INSERT del tax exempt terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT del tax exempt depuis client_adresse_phl - %: %', 
            TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
