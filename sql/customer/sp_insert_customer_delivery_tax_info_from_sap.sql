-- Procédure pour insérer les informations fiscales de livraison clients depuis les données SAP
-- Utilise clean_data.ifs_customer comme table maître

CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_delivery_tax_info_from_sap()
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
BEGIN
    
    RAISE NOTICE 'Début insertion delivery tax info clients SAP - Basé sur ifs_customer';
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.customer_delivery_tax_info;
    RAISE NOTICE 'Table customer_delivery_tax_info vidée';
    
    -- Insertion directe après TRUNCATE
    INSERT INTO clean_data.customer_delivery_tax_info (
        CUSTOMER_ID,
        ADDRESS_ID,
        COMPANY,
        SUPPLY_COUNTRY,
        SUPPLY_COUNTRY_DB,
        CUS_COUNTRY_CODE,
        TAX_LIABILITY,
        TAX_BOOK_ID,
        TAX_BOOK_TYPE,
        TAX_STRUCTURE_ID,
        TAX_CALC_STRUCTURE_ID
    )
    SELECT DISTINCT ON (ifs.customer_number, COALESCE(ifs.numero_adresse, k.ADRNR), COALESCE(k.LAND1, ifs.country, 'FR'))
        ifs.customer_number as CUSTOMER_ID,
        COALESCE(ifs.numero_adresse, k.ADRNR) as ADDRESS_ID,
        'TRIMET' as COMPANY,
        NULL as SUPPLY_COUNTRY,
        COALESCE(k.LAND1, ifs.country, 'FR') as SUPPLY_COUNTRY_DB,
        COALESCE(k.LAND1, ifs.country, 'FR') as CUS_COUNTRY_CODE,
        'TAX' as TAX_LIABILITY,
        NULL as TAX_BOOK_ID,
        NULL as TAX_BOOK_TYPE,
        NULL as TAX_STRUCTURE_ID,
        NULL as TAX_CALC_STRUCTURE_ID
    FROM clean_data.ifs_customer ifs  -- TABLE MAÎTRE
    LEFT JOIN raw_data.KNA1 k 
        ON ifs.customer_number = k.KUNNR
        AND ifs.numero_adresse = k.ADRNR
        AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.T005T t_country 
        ON COALESCE(k.LAND1, ifs.country) = t_country.LAND1
        AND t_country.SPRAS = 'F'
    WHERE COALESCE(ifs.numero_adresse, k.ADRNR) IS NOT NULL
    ORDER BY ifs.customer_number, COALESCE(ifs.numero_adresse, k.ADRNR), COALESCE(k.LAND1, ifs.country, 'FR');
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    
    RAISE NOTICE 'INSERT delivery tax info terminé: % enregistrements traités', v_processed_count;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur lors de l''INSERT delivery tax info: %', SQLERRM;
END;
$procedure$;
