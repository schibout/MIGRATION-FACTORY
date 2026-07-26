-- ============================================================================
-- Procédure stockée
-- ============================================================================
CREATE OR REPLACE PROCEDURE clean_data.sp_insert_ifs_customer_ref()
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE '[%] 🚀 Début de sp_insert_ifs_customer_from_sap', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS');
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.ifs_customer;
    RAISE NOTICE '[%] 🗑️ Table ifs_customer vidée', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS');
    
    -- Insertion des données depuis SAP avec gestion des doublons
    INSERT INTO clean_data.ifs_customer (
        -- Identifiants
        customer_number,
        numero_adresse,
        account_group,
        vendor_number,
        -- Noms et adresse
        name_1,
        name_2,
        name_3,
        name_4,
        street,
        postal_code,
        city,
        country,
        region,
        search_term,
        -- Contact
        telephone,
        fax,
        telephone_2,
        teletex,
        telex,
        language,
        -- Infos fiscales
        tax_number_1,
        tax_number_2,
        vat_number,
        association_number,
        -- Infos générales
        industry,
        created_on,
        created_by,
        customer_classification,
        -- Blocages
        order_block,
        delivery_block,
        billing_block,
        central_block,
        deletion_flag,
        -- Infos comptables
        company_code,
        reconciliation_account,
        payment_methods,
        accounting_delete_flag,
        accounting_created_on,
        accounting_created_by,
        -- Infos ventes
        sales_organization,
        distribution_channel,
        division,
        customer_group,
        sales_district,
        pricing_procedure,
        incoterms_1,
        incoterms_2,
        sales_delivery_block,
        sales_billing_block,
        sales_order_block,
        sales_delete_flag,
        sales_created_on,
        sales_created_by
    )
    SELECT DISTINCT ON (TRIM(kna1.kunnr))
        -- ============ IDENTIFIANTS ============
        TRIM(kna1.kunnr) AS customer_number,
        kna1.adrnr AS numero_adresse,
        kna1.ktokd AS account_group,
        kna1.lifnr AS vendor_number,
        
        -- ============ NOMS ET ADRESSE ============
        TRIM(kna1.name1) AS name_1,
        TRIM(kna1.name2) AS name_2,
        TRIM(kna1.name3) AS name_3,
        TRIM(kna1.name4) AS name_4,
        TRIM(kna1.stras) AS street,
        TRIM(kna1.pstlz) AS postal_code,
        TRIM(kna1.ort01) AS city,
        kna1.land1 AS country,
        kna1.regio AS region,
        kna1.sortl AS search_term,
        
        -- ============ CONTACT ============
        kna1.telf1 AS telephone,
        kna1.telfx AS fax,
        kna1.telf2 AS telephone_2,
        kna1.teltx AS teletex,
        kna1.telx1 AS telex,
        kna1.spras AS language,
        
        -- ============ INFOS FISCALES ============
        kna1.stcd1 AS tax_number_1,
        kna1.stcd3 AS tax_number_2,
        kna1.stceg AS vat_number,
        COALESCE(kna1.stcd2, kna1.stcd1, kna1.stcd3) AS association_number,
        
        -- ============ INFOS GÉNÉRALES ============
        kna1.brsch AS industry,
        CASE 
            WHEN kna1.erdat IS NOT NULL AND kna1.erdat != '' AND LENGTH(TRIM(kna1.erdat)) = 8
            THEN TO_DATE(kna1.erdat, 'YYYYMMDD')
            ELSE NULL
        END AS created_on,
        kna1.ernam AS created_by,
        kna1.kukla AS customer_classification,
        
        -- ============ BLOCAGES ============
        kna1.aufsd AS order_block,
        kna1.lifsd AS delivery_block,
        kna1.faksd AS billing_block,
        kna1.sperr AS central_block,
        kna1.loevm AS deletion_flag,
        
        -- ============ INFOS COMPTABLES (KNB1) ============
        knb1.bukrs AS company_code,
        knb1.akont AS reconciliation_account,
        knb1.zwels AS payment_methods,
        knb1.loevm AS accounting_delete_flag,
        CASE 
            WHEN knb1.erdat IS NOT NULL AND knb1.erdat != '' AND LENGTH(TRIM(knb1.erdat)) = 8
            THEN TO_DATE(knb1.erdat, 'YYYYMMDD')
            ELSE NULL
        END AS accounting_created_on,
        knb1.ernam AS accounting_created_by,
        
        -- ============ INFOS VENTES (KNVV) ============
        knvv.vkorg AS sales_organization,
        knvv.vtweg AS distribution_channel,
        knvv.spart AS division,
        knvv.kdgrp AS customer_group,
        knvv.bzirk AS sales_district,
        knvv.kalks AS pricing_procedure,
        knvv.inco1 AS incoterms_1,
        knvv.inco2 AS incoterms_2,
        knvv.lifsd AS sales_delivery_block,
        knvv.faksd AS sales_billing_block,
        knvv.aufsd AS sales_order_block,
        knvv.loevm AS sales_delete_flag,
        CASE 
            WHEN knvv.erdat IS NOT NULL AND knvv.erdat != '' AND LENGTH(TRIM(knvv.erdat)) = 8
            THEN TO_DATE(knvv.erdat, 'YYYYMMDD')
            ELSE NULL
        END AS sales_created_on,
        knvv.ernam AS sales_created_by
    FROM raw_data.kna1 kna1
    INNER JOIN raw_data.knb1 knb1 
        ON kna1.kunnr = knb1.kunnr
        AND (knb1.loevm IS NULL OR knb1.loevm = '')  -- Clients non supprimés en comptabilité
    INNER JOIN raw_data.clienttosave c 
        ON kna1.kunnr = c.numero_client  -- FILTRE: Seulement les clients à sauvegarder
    LEFT JOIN raw_data.knvv knvv 
        ON kna1.kunnr = knvv.kunnr
    WHERE (kna1.loevm IS NULL OR kna1.loevm = '')  -- Exclure les clients marqués pour suppression
    ORDER BY TRIM(kna1.kunnr), knb1.bukrs;
    
    -- Compter les enregistrements insérés
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    
    v_end_time := NOW();
    
    -- Logs de fin avec statistiques
    RAISE NOTICE '[%] ✅ sp_insert_ifs_customer_from_sap terminé avec succès', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS');
    RAISE NOTICE '[%] 📊 Nombre d''enregistrements insérés: %', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE '[%] ⏱️ Durée totale: %', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'), v_end_time - v_start_time;
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE NOTICE '[%] ❌ Erreur dans sp_insert_ifs_customer_from_sap: %', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
        RAISE;
END;
$procedure$;

-- ============================================================================
-- Commentaires sur la table et les colonnes
-- ============================================================================
COMMENT ON TABLE clean_data.ifs_customer IS 'Table consolidée des clients SAP pour export vers IFS';
COMMENT ON COLUMN clean_data.ifs_customer.customer_number IS 'Numéro client SAP (KUNNR)';
COMMENT ON COLUMN clean_data.ifs_customer.company_code IS 'Code société (BUKRS)';
COMMENT ON COLUMN clean_data.ifs_customer.sales_organization IS 'Organisation commerciale (VKORG)';

