CREATE OR REPLACE FUNCTION clean_data.alimenter_purchase_part_supplier()
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
    v_count_inserted INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    RAISE NOTICE 'Début de l''alimentation des fournisseurs article achat (PURCHASE_PART_SUPPLIER) - %', v_start_time;
    
    -- Vider la table cible avant insertion
    TRUNCATE TABLE clean_data.purchase_part_supplier RESTART IDENTITY;
    RAISE NOTICE 'Table purchase_part_supplier vidée';
    
    -- Insertion des relations article-fournisseur depuis SAP (EINA/EINE)
    INSERT INTO clean_data.purchase_part_supplier (
        -- Clés
        contract,
        part_no,
        vendor_no,
        
        -- Données de base
        buy_unit_meas,
        currency_code,
        status_code,
        
        -- Flags et paramètres par défaut
        primary_vendor_db,
        leadtime_auto_db,
        receive_case_db,
        external_service_allowed_db,
        part_ownership_db,
        dist_order_receipt_type_db,
        multisite_planned_part_db,
        quick_registered_part_db,
        purchase_payment_type_db,
        acquisition_type_db,
        rental_primary_vendor_db,
        use_price_incl_tax_db,
        qualified_supplier_db,
        ext_svc_primary_vendor_db,
        issue_packaging_material_db
    )
    SELECT DISTINCT
        -- CONTRACT: 9200 = SJ, 9000 = CS
        CASE 
            WHEN eine.ekorg = '9200' THEN 'SJ'
            WHEN eine.ekorg = '9000' THEN 'CS'
            ELSE 'SJ'
        END as contract,
        
        -- PART_NO: numero_article SAP (pas de transcodification, l'article garde son ID)
        SUBSTRING(TRIM(LTRIM(ifs.numero_article, '0')), 1, 25) as part_no,
        
        -- VENDOR_NO: NOUVEAU numéro IFS du fournisseur (renuméroté 600xxx),
        -- mappé depuis le LIFNR SAP via supplier_info_general.supplier_legacy_sap_id.
        -- Indispensable : la table supplier est renumérotée, le LIFNR SAP brut ne correspond plus.
        SUBSTRING(sig.supplier_id, 1, 20) as vendor_no,
        
        -- BUY_UNIT_MEAS: EINA.MEINS via transcodification UOM (SAP->IFS), sinon unité d'entrée
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(eina.meins)), '')),
            UPPER(TRIM(eina.meins))
        ), 1, 10) as buy_unit_meas,
        
        -- CURRENCY_CODE: EINE.WAERS
        SUBSTRING(COALESCE(NULLIF(eine.waers, ''), 'EUR'), 1, 3) as currency_code,
        
        -- STATUS_CODE: 2
        '2' as status_code,
        
        -- PRIMARY_VENDOR_DB: Y par défaut (fournisseur principal)
        'Y' as primary_vendor_db,
        
        -- LEADTIME_AUTO_DB: N (délai manuel)
        'N' as leadtime_auto_db,
        
        -- RECEIVE_CASE_DB: INVDIR (réception directe en stock)
        'INVDIR' as receive_case_db,
        
        -- EXTERNAL_SERVICE_ALLOWED_DB: FALSE
        'FALSE' as external_service_allowed_db,
        
        -- PART_OWNERSHIP_DB: COMPANY OWNED
        'COMPANY OWNED' as part_ownership_db,
        
        -- DIST_ORDER_RECEIPT_TYPE_DB: NO AUTOMATIC RECPT
        'NO AUTOMATIC RECPT' as dist_order_receipt_type_db,
        
        -- MULTISITE_PLANNED_PART_DB: NOT_MULTISITE_PLAN
        'NOT_MULTISITE_PLAN' as multisite_planned_part_db,
        
        -- QUICK_REGISTERED_PART_DB: FALSE
        'FALSE' as quick_registered_part_db,
        
        -- PURCHASE_PAYMENT_TYPE_DB: NORMAL
        'NORMAL' as purchase_payment_type_db,
        
        -- ACQUISITION_TYPE_DB: PURCHASE
        'PURCHASE' as acquisition_type_db,
        
        -- RENTAL_PRIMARY_VENDOR_DB: N
        'N' as rental_primary_vendor_db,
        
        -- USE_PRICE_INCL_TAX_DB: FALSE
        'FALSE' as use_price_incl_tax_db,
        
        -- QUALIFIED_SUPPLIER_DB: FALSE
        'FALSE' as qualified_supplier_db,
        
        -- EXT_SVC_PRIMARY_VENDOR_DB: FALSE
        'FALSE' as ext_svc_primary_vendor_db,
        
        -- ISSUE_PACKAGING_MATERIAL_DB: FALSE
        'FALSE' as issue_packaging_material_db
        
    FROM raw_data.eina eina
    INNER JOIN raw_data.eine eine 
        ON eina.infnr = eine.infnr
        AND eine.mandt = '700'
    INNER JOIN clean_data.ifs_article_maitre ifs
        ON eina.matnr::text = ifs.numero_article
    -- Mapping LIFNR SAP -> nouveau supplier_id IFS (600xxx).
    -- INNER JOIN volontaire : un lien vers un fournisseur absent des tables IFS
    -- définitives serait rejeté au chargement, on n'insère donc que les liens valides.
    INNER JOIN clean_data.supplier_info_general sig
        ON LTRIM(sig.supplier_legacy_sap_id, '0') = LTRIM(eina.lifnr, '0')
        AND sig.is_deleted = FALSE

    WHERE
        -- Filtrer sur les organisations d'achat Trimet
        eine.ekorg IN ('9200', '9000')
        -- Exclure les enregistrements supprimés
        AND (eina.loekz IS NULL OR eina.loekz = '')
        AND (eine.loekz IS NULL OR eine.loekz = '')
        -- Article et fournisseur non vides
        AND TRIM(eina.matnr) != ''
        AND TRIM(eina.lifnr) != ''
        
    ORDER BY contract, part_no, vendor_no;
    
    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;
    
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;
    
    -- Log des résultats
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Alimentation PURCHASE_PART_SUPPLIER terminée';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Relations article-fournisseur insérées: %', v_count_inserted;
    RAISE NOTICE 'Durée d''exécution: %', v_duration;
    RAISE NOTICE '====================================================';
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;
        
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'ERREUR lors de l''alimentation PURCHASE_PART_SUPPLIER';
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'Code d''erreur: %', SQLSTATE;
        RAISE NOTICE 'Message: %', SQLERRM;
        RAISE NOTICE 'Durée avant erreur: %', v_duration;
        RAISE NOTICE '====================================================';
        
        RAISE;
END;
$function$;

COMMENT ON FUNCTION clean_data.alimenter_purchase_part_supplier() IS 
'Alimente la table PURCHASE_PART_SUPPLIER depuis les fiches info achat SAP (EINA/EINE).
Sources SAP:
- EINA: Fiche info achat - données générales (matnr, lifnr, meins)
- EINE: Fiche info achat - données organisation (ekorg, waers)
Règles:
- CONTRACT: 9200=SJ, 9000=CS
- VENDOR_NO: nouveau supplier_id IFS (600xxx) mappe depuis EINA.LIFNR via
  supplier_info_general.supplier_legacy_sap_id (les fournisseurs sont renumerotes 600000+)
- BUY_UNIT_MEAS: EINA.MEINS
- CURRENCY_CODE: EINE.WAERS
- STATUS_CODE: 2
- Une ligne par couple article/fournisseur';
