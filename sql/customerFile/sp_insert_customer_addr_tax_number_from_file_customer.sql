-- Procédure pour insérer les numéros de taxe d'adresse clients depuis raw_data.file_customer
-- Utilise raw_data.file_customer (CTE fc) comme table maître

CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_addr_tax_number_from_file_customer()
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN

    v_start_time := NOW();
    RAISE NOTICE 'Début insertion addr tax number clients - % - Basé sur file_customer', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');

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
    WITH fc AS (
        SELECT f.*,
            COALESCE(NULLIF(TRIM(f.nouveau_compte_ifs),''), NULLIF(TRIM(f.num_corrige),''), TRIM(f.kunnr)) AS customer_id,
            COALESCE(NULLIF(split_part(TRIM(f.numero_adresse), '.', 1), ''), '1') AS address_id
        FROM raw_data.file_customer f
        WHERE COALESCE(NULLIF(TRIM(f.nouveau_compte_ifs),''), NULLIF(TRIM(f.num_corrige),''), TRIM(f.kunnr)) IS NOT NULL
    )
    SELECT DISTINCT ON (fc.customer_id, fc.address_id, COALESCE(k.LAND1, fc.country, 'FR'))
        fc.customer_id as CUSTOMER_ID,
        fc.address_id as ADDRESS_ID,
        'TRIMET' as COMPANY,
        COALESCE(k.LAND1, fc.country, 'FR') as SUPPLY_COUNTRY,
        COALESCE(k.LAND1, fc.country, 'FR') as DELIVERY_COUNTRY,
        '' as TAX_ID_TYPE,
        SUBSTRING(COALESCE(NULLIF(TRIM(fc.vat_number),''), NULLIF(TRIM(fc.tax_number_1),''), k.STCEG, k.STCD1, 'NO_TAX_ID'), 1, 50) as TAX_ID_NUMBER,
        'True' as DEFAULT_TAX_ID_NUMBER,
        'TRUE' as DEFAULT_TAX_ID_NUMBER_DB
    FROM fc  -- TABLE MAÎTRE
    LEFT JOIN raw_data.KNA1 k
        ON fc.kunnr = k.KUNNR
        AND (k.LOEVM IS NULL OR k.LOEVM = '')
    ORDER BY fc.customer_id, fc.address_id, COALESCE(k.LAND1, fc.country, 'FR');

    GET DIAGNOSTICS v_processed_count = ROW_COUNT;

    v_end_time := NOW();
    RAISE NOTICE 'INSERT addr tax number terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));

EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT addr tax number - %: %', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$;
