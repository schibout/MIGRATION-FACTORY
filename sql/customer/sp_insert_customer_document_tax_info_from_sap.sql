CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_document_tax_info_from_sap()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_count INTEGER;
BEGIN
    -- Enregistrer le début de l'opération
    v_start_time := NOW();
    RAISE NOTICE '[%] 🚀 Début de sp_insert_customer_document_tax_info_from_sap - Basé sur ifs_customer', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS');
    
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
    SELECT DISTINCT ON (ifs.customer_number, COALESCE(ifs.numero_adresse, k.ADRNR), COALESCE(k.LAND1, ifs.country, 'FR'))
        ifs.customer_number as CUSTOMER_ID,
        COALESCE(ifs.numero_adresse, k.ADRNR) as ADDRESS_ID,
        public.get_default_value('clean_data.customer_document_tax_info', 'company', 'TRIMET') as COMPANY,
        public.get_default_value('clean_data.customer_document_tax_info', 'supply_country', NULL) as SUPPLY_COUNTRY,
        COALESCE(k.LAND1, ifs.country, 'FR') as SUPPLY_COUNTRY_DB,
        public.get_default_value('clean_data.customer_document_tax_info', 'delivery_country', NULL) as DELIVERY_COUNTRY,
        COALESCE(k.LAND1, ifs.country, 'FR') as DELIVERY_COUNTRY_DB,
        public.get_default_value('clean_data.customer_document_tax_info', 'tax_id_type', NULL) as TAX_ID_TYPE,
        public.get_default_value('clean_data.customer_document_tax_info', 'vat_no', NULL) as VAT_NO,
        public.get_default_value('clean_data.customer_document_tax_info', 'validated_date', NULL)::date as VALIDATED_DATE,
        public.get_default_value('clean_data.customer_document_tax_info', 'tax_id_error_message', NULL) as TAX_ID_ERROR_MESSAGE,
        public.get_default_value('clean_data.customer_document_tax_info', 'tax_office_id', NULL) as TAX_OFFICE_ID
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
    
    -- Compter les enregistrements insérés
    GET DIAGNOSTICS v_count = ROW_COUNT;
    
    -- Enregistrer la fin de l'opération
    v_end_time := NOW();
    
    -- Logs de fin avec statistiques
    RAISE NOTICE '[%] ✅ sp_insert_customer_document_tax_info_from_sap terminé avec succès', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS');
    RAISE NOTICE '[%] 📊 Nombre d''enregistrements insérés: %', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'), v_count;
    RAISE NOTICE '[%] ⏱️ Durée totale: %', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'), v_end_time - v_start_time;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '[%] ❌ Erreur dans sp_insert_customer_document_tax_info_from_sap: %', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
        RAISE;
END;
$procedure$
