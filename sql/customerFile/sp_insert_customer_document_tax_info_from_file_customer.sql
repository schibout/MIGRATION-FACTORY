-- Procédure pour insérer les informations fiscales document clients depuis raw_data.file_customer
-- Utilise raw_data.file_customer (CTE fc) comme table maître

CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_document_tax_info_from_file_customer()
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_count INTEGER;
BEGIN
    -- Enregistrer le début de l'opération
    v_start_time := NOW();
    RAISE NOTICE '[%] 🚀 Début de sp_insert_customer_document_tax_info_from_file_customer - Basé sur file_customer', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS');

    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.customer_document_tax_info;
    RAISE NOTICE '[%] 🗑️ Table customer_document_tax_info vidée', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS');

    -- Insertion directe après TRUNCATE
    INSERT INTO clean_data.customer_document_tax_info (
        CUSTOMER_ID,
        ADDRESS_ID,
        COMPANY,
        SUPPLY_COUNTRY,
        SUPPLY_COUNTRY_DB,
        DELIVERY_COUNTRY,
        DELIVERY_COUNTRY_DB,
        TAX_ID_TYPE,
        VAT_NO,
        VALIDATED_DATE,
        TAX_ID_ERROR_MESSAGE,
        TAX_OFFICE_ID
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
        NULL as SUPPLY_COUNTRY,
        COALESCE(k.LAND1, fc.country, 'FR') as SUPPLY_COUNTRY_DB,
        NULL as DELIVERY_COUNTRY,
        COALESCE(k.LAND1, fc.country, 'FR') as DELIVERY_COUNTRY_DB,
        NULL as TAX_ID_TYPE,
        UPPER(COALESCE(NULLIF(TRIM(fc.vat_number),''), k.STCEG, k.STCD1)) as VAT_NO,  -- IFS exige le format majuscule
        NULL as VALIDATED_DATE,
        NULL as TAX_ID_ERROR_MESSAGE,
        NULL as TAX_OFFICE_ID
    FROM fc  -- TABLE MAÎTRE
    LEFT JOIN raw_data.KNA1 k
        ON fc.kunnr = k.KUNNR
        AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.T005T t_country
        ON COALESCE(k.LAND1, fc.country) = t_country.LAND1
        AND t_country.SPRAS = 'F'
    ORDER BY fc.customer_id, fc.address_id, COALESCE(k.LAND1, fc.country, 'FR');

    -- Compter les enregistrements insérés
    GET DIAGNOSTICS v_count = ROW_COUNT;

    -- Enregistrer la fin de l'opération
    v_end_time := NOW();

    -- Logs de fin avec statistiques
    RAISE NOTICE '[%] ✅ sp_insert_customer_document_tax_info_from_file_customer terminé avec succès', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS');
    RAISE NOTICE '[%] 📊 Nombre d''enregistrements insérés: %', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'), v_count;
    RAISE NOTICE '[%] ⏱️ Durée totale: %', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'), v_end_time - v_start_time;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '[%] ❌ Erreur dans sp_insert_customer_document_tax_info_from_file_customer: %', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
        RAISE;
END;
$procedure$;
