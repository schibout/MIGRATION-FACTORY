CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_addr_tax_number_from_sap()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion addr tax number clients SAP - % - Basé sur ifs_customer', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.CUSTOMER_ADDR_TAX_NUMBER;
    RAISE NOTICE 'Table customer_addr_tax_number vidée';
    
    -- Insertion directe après TRUNCATE
    INSERT INTO clean_data.CUSTOMER_ADDR_TAX_NUMBER (
        CUSTOMER_ID,
        ADDRESS_ID,
        COMPANY,
        SUPPLY_COUNTRY,
        DELIVERY_COUNTRY,
        TAX_ID_TYPE,
        TAX_ID_NUMBER,
        DEFAULT_TAX_ID_NUMBER,
        DEFAULT_TAX_ID_NUMBER_DB
    )
    SELECT DISTINCT ON (ifs.customer_number, COALESCE(ifs.numero_adresse, k.ADRNR), COALESCE(k.LAND1, ifs.country, 'FR'))
        ifs.customer_number as CUSTOMER_ID,
        COALESCE(ifs.numero_adresse, k.ADRNR) as ADDRESS_ID,
        'TRIMET' as COMPANY,
        COALESCE(k.LAND1, ifs.country, 'FR') as SUPPLY_COUNTRY,
        COALESCE(k.LAND1, ifs.country, 'FR') as DELIVERY_COUNTRY,
        '' as TAX_ID_TYPE,
        SUBSTRING(COALESCE(k.STCEG, k.STCD1, ifs.tax_number_1, 'NO_TAX_ID'), 1, 50) as TAX_ID_NUMBER,
        'True' as DEFAULT_TAX_ID_NUMBER,
        'TRUE' as DEFAULT_TAX_ID_NUMBER_DB
    FROM clean_data.ifs_customer ifs  -- TABLE MAÎTRE
    LEFT JOIN raw_data.KNA1 k 
        ON ifs.customer_number = k.KUNNR
        AND ifs.numero_adresse = k.ADRNR
        AND (k.LOEVM IS NULL OR k.LOEVM = '')
    WHERE COALESCE(ifs.numero_adresse, k.ADRNR) IS NOT NULL
    ORDER BY ifs.customer_number, COALESCE(ifs.numero_adresse, k.ADRNR), COALESCE(k.LAND1, ifs.country, 'FR');
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    
    v_end_time := NOW();
    RAISE NOTICE 'INSERT addr tax number terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT addr tax number - %: %', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
