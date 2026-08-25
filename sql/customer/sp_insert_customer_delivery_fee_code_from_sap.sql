CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_delivery_fee_code_from_sap()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion delivery fee code clients SAP - % - Basé sur ifs_customer', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.customer_delivery_fee_code;
    RAISE NOTICE 'Table customer_delivery_fee_code vidée';
    
    -- Insertion directe après TRUNCATE
    INSERT INTO clean_data.customer_delivery_fee_code (
        customer_id,
        address_id,
        company,
        supply_country,
        fee_code,
        tax_id_number,
        tax_code_selection
    )
    SELECT DISTINCT ON (ifs.customer_number, COALESCE(ifs.numero_adresse, k.ADRNR), COALESCE(k.LAND1, ifs.country, 'FR'))
        ifs.customer_number as customer_id,
        COALESCE(ifs.numero_adresse, k.ADRNR) as address_id,
        'TRIMET' as company,
        COALESCE(k.LAND1, ifs.country, 'FR') as supply_country,
        NULL as fee_code,
        SUBSTRING(COALESCE(k.STCEG, k.STCD1, ifs.tax_number_1), 1, 10) as tax_id_number,
        NULL as tax_code_selection
    FROM clean_data.ifs_customer ifs
    LEFT JOIN raw_data.KNA1 k 
        ON ifs.customer_number = k.KUNNR
        AND ifs.numero_adresse = k.ADRNR
        AND (k.LOEVM IS NULL OR k.LOEVM = '')
    WHERE COALESCE(ifs.numero_adresse, k.ADRNR) IS NOT NULL
    ORDER BY ifs.customer_number, COALESCE(ifs.numero_adresse, k.ADRNR), COALESCE(k.LAND1, ifs.country, 'FR');
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    
    v_end_time := NOW();
    RAISE NOTICE 'INSERT delivery fee code terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT delivery fee code - %: %', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
