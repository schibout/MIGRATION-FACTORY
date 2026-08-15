-- Procédure pour insérer les codes de frais de livraison clients depuis raw_data.file_customer
-- Utilise raw_data.file_customer (CTE fc) comme table maître

CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_delivery_fee_code_from_file_customer()
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN

    v_start_time := NOW();
    RAISE NOTICE 'Début insertion delivery fee code clients - % - Basé sur file_customer', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');

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
    WITH fc AS (
        SELECT f.*,
            COALESCE(NULLIF(TRIM(f.nouveau_compte_ifs),''), NULLIF(TRIM(f.num_corrige),''), TRIM(f.kunnr)) AS customer_id,
            COALESCE(NULLIF(split_part(TRIM(f.numero_adresse), '.', 1), ''), '1') AS address_id
        FROM raw_data.file_customer f
        WHERE COALESCE(NULLIF(TRIM(f.nouveau_compte_ifs),''), NULLIF(TRIM(f.num_corrige),''), TRIM(f.kunnr)) IS NOT NULL
    )
    SELECT DISTINCT ON (fc.customer_id, fc.address_id, COALESCE(k.LAND1, fc.country, 'FR'))
        fc.customer_id as customer_id,
        fc.address_id as address_id,
        'TRIMET' as company,
        COALESCE(k.LAND1, fc.country, 'FR') as supply_country,
        COALESCE(NULLIF(TRIM(fc.code_tva_ifs), ''), 'C05') as fee_code,  -- code taxe repris du fichier file_customer (fallback C05)
        SUBSTRING(COALESCE(k.STCEG, k.STCD1, fc.tax_number_1), 1, 10) as tax_id_number,
        NULL as tax_code_selection
    FROM fc
    LEFT JOIN raw_data.KNA1 k
        ON fc.kunnr = k.KUNNR
        AND (k.LOEVM IS NULL OR k.LOEVM = '')
    ORDER BY fc.customer_id, fc.address_id, COALESCE(k.LAND1, fc.country, 'FR');

    GET DIAGNOSTICS v_processed_count = ROW_COUNT;

    v_end_time := NOW();
    RAISE NOTICE 'INSERT delivery fee code terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));

EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT delivery fee code - %: %', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$;
