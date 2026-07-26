CREATE OR REPLACE FUNCTION clean_data.alimenter_inventory_part()
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
    v_count_inserted INTEGER := 0;
    v_count_errors INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    RAISE NOTICE 'Début de l''alimentation des articles en stock (INVENTORY_PART) - %', v_start_time;
    
    -- Vider la table cible avant insertion
    TRUNCATE TABLE clean_data.inventory_part RESTART IDENTITY;
    RAISE NOTICE 'Table inventory_part vidée';
    
    -- Insertion des articles depuis ifs_article_maitre avec règles de gestion Trimet
    INSERT INTO clean_data.inventory_part (
        -- Clés
        contract,
        part_no,
        
        -- Données de base
        description,
        unit_meas,
        part_status,
        planner_buyer,
        asset_class,
        country_of_origin,
        
        -- Type et approvisionnement (_db uniquement, autres vides)
        type_code_db,
        supply_code_db,
        
        -- Délais
        expected_leadtime,
        manuf_leadtime,
        purch_leadtime,
        lead_time_code_db,
        
        -- Valorisation et gestion
        inventory_valuation_method_db,
        count_variance,
        cycle_code_db,
        cycle_period,
        qty_calc_rounding,
        
        -- Flags _db (valeurs non-vides selon règles)
        zero_cost_flag_db,
        oe_alloc_assign_flag_db,
        onhand_analysis_flag_db,
        shortage_flag_db,
        forecast_consumption_flag_db,
        stock_management_db,
        dop_connection_db,
        negative_on_hand_db,
        invoice_consideration_db,
        inventory_part_cost_level_db,
        ext_service_cost_method_db,
        automatic_capability_check_db,
        dop_netting_db,
        co_reserve_onh_analys_flag_db,
        mandatory_expiration_date_db,
        excl_ship_pack_proposal_db,
        reset_config_std_cost_db,
        
        -- Lifecycle et classification
        lifecycle_stage_db,
        frequency_class_db,
        avail_activity_status_db,
        
        -- Classification depuis SAP
        abc_class,
        hsn_sac_code
    )
    SELECT DISTINCT
        -- CONTRACT: 9200 = SJ (Saint Jean), 9000 = CS (Castel)
        CASE 
            WHEN marc.werks = '9200' THEN 'SJ'
            WHEN marc.werks = '9000' THEN 'CS'
            ELSE 'SJ'
        END as contract,
        
        -- PART_NO: numero_article SAP (pas de transcodification, l'article garde son ID)
        SUBSTRING(TRIM(LTRIM(ifs.numero_article, '0')), 1, 25) as part_no,
        
        -- DESCRIPTION: depuis SAP
        SUBSTRING(COALESCE(makt.maktx, mara.matnr), 1, 200) as description,
          -- UNIT_MEAS: MARA.MEINS via transcodification UOM (SAP->IFS), sinon unité d'entrée
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(mara.meins)), '')),
            UPPER(TRIM(mara.meins))
        ), 1, 10) as unit_meas,
        -- PART_STATUS: A
        'A' as part_status,
        
        -- PLANNER_BUYER: *
        '*' as planner_buyer,
        
        -- ASSET_CLASS: S
        'S' as asset_class,
        
        -- COUNTRY_OF_ORIGIN: MARC.HERKL
        SUBSTRING(marc.herkl, 1, 10) as country_of_origin,
        
        -- TYPE_CODE_DB: 4
        '4' as type_code_db,
        
        -- SUPPLY_CODE_DB: IO
        'IO' as supply_code_db,
        
        -- EXPECTED_LEADTIME: MARC.WEBAZ
        COALESCE(marc.webaz::numeric, 0) as expected_leadtime,
        
        -- MANUF_LEADTIME: 0
        0 as manuf_leadtime,
        
        -- PURCH_LEADTIME: 0
        0 as purch_leadtime,
        
        -- LEAD_TIME_CODE_DB: P
        'P' as lead_time_code_db,
        
        -- INVENTORY_VALUATION_METHOD_DB: S => ST, V => AV (selon code prix SAP)
        CASE 
            WHEN mbew.vprsv = 'S' THEN 'ST'
            WHEN mbew.vprsv = 'V' THEN 'AV'
            ELSE 'ST'
        END as inventory_valuation_method_db,
        
        -- COUNT_VARIANCE: 0
        0 as count_variance,
        
        -- CYCLE_CODE_DB: N
        'N' as cycle_code_db,
        
        -- CYCLE_PERIOD: 0
        0 as cycle_period,
        
        -- QTY_CALC_ROUNDING: 0
        0 as qty_calc_rounding,
        
        -- ZERO_COST_FLAG_DB: N
        'N' as zero_cost_flag_db,
        
        -- OE_ALLOC_ASSIGN_FLAG_DB: N
        'N' as oe_alloc_assign_flag_db,
        
        -- ONHAND_ANALYSIS_FLAG_DB: N
        'N' as onhand_analysis_flag_db,
        
        -- SHORTAGE_FLAG_DB: Y
        'Y' as shortage_flag_db,
        
        -- FORECAST_CONSUMPTION_FLAG_DB: FORECAST
        'FORECAST' as forecast_consumption_flag_db,
        
        -- STOCK_MANAGEMENT_DB: Y
        'Y' as stock_management_db,
        
        -- DOP_CONNECTION_DB: AUT
        'AUT' as dop_connection_db,
        
        -- NEGATIVE_ON_HAND_DB: NEG ONHAND NOT OK
        'NEG ONHAND NOT OK' as negative_on_hand_db,
        
        -- INVOICE_CONSIDERATION_DB: TRANSACTION BASED
        'TRANSACTION BASED' as invoice_consideration_db,
        
        -- INVENTORY_PART_COST_LEVEL_DB: COST PER PART
        'COST PER PART' as inventory_part_cost_level_db,
        
        -- EXT_SERVICE_COST_METHOD_DB: EXCLUDE SERVICE COST
        'EXCLUDE SERVICE COST' as ext_service_cost_method_db,
        
        -- AUTOMATIC_CAPABILITY_CHECK_DB: NO AUTOMATIC CAPABILITY CHECK
        'NO AUTOMATIC CAPABILITY CHECK' as automatic_capability_check_db,
        
        -- DOP_NETTING_DB: NONET
        'NONET' as dop_netting_db,
        
        -- CO_RESERVE_ONH_ANALYS_FLAG_DB: N
        'N' as co_reserve_onh_analys_flag_db,
        
        -- MANDATORY_EXPIRATION_DATE_DB: FALSE
        'FALSE' as mandatory_expiration_date_db,
        
        -- EXCL_SHIP_PACK_PROPOSAL_DB: FALSE
        'FALSE' as excl_ship_pack_proposal_db,

        -- RESET_CONFIG_STD_COST_DB: FALSE
        'FALSE' as reset_config_std_cost_db,
        
        -- LIFECYCLE_STAGE_DB: DEVELOPMENT
        'DEVELOPMENT' as lifecycle_stage_db,
        
        -- FREQUENCY_CLASS_DB: VERY SLOW MOVER
        'VERY SLOW MOVER' as frequency_class_db,
        
        -- AVAIL_ACTIVITY_STATUS_DB: CHANGED
        'CHANGED' as avail_activity_status_db,
        
        -- ABC_CLASS: MARC.MAABC
        SUBSTRING(marc.maabc, 1, 1) as abc_class,
        
        -- HSN_SAC_CODE: MARC.MOWNR
        SUBSTRING(marc.mownr, 1, 20) as hsn_sac_code
        
    FROM clean_data.ifs_article_maitre ifs
    INNER JOIN raw_data.mara mara 
        ON mara.matnr::text = ifs.numero_article
        AND mara.mandt = '700'
    INNER JOIN raw_data.makt makt 
        ON mara.matnr = makt.matnr 
        AND makt.mandt = '700'
        AND makt.spras = 'F'
    INNER JOIN raw_data.marc marc 
        ON mara.matnr = marc.matnr
        AND marc.mandt = '700'
    LEFT JOIN raw_data.mbew mbew 
        ON mara.matnr = mbew.matnr 
        AND marc.werks = mbew.bwkey
        AND mbew.mandt = '700'
    
    WHERE
        marc.werks IN ('9200', '9000')
        AND mara.lvorm IS NULL
        AND TRIM(mara.matnr) != ''
        -- Garantir que l'article existe dans part_catalog (table de base) avant insertion
        AND EXISTS (
            SELECT 1 FROM clean_data.part_catalog pc
            WHERE pc.part_no = SUBSTRING(TRIM(LTRIM(ifs.numero_article, '0')), 1, 25)
        )

    ORDER BY part_no;
    
    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;
    
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;
    
    -- Log des résultats
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Alimentation INVENTORY_PART terminée avec succès';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Articles insérés: %', v_count_inserted;
    RAISE NOTICE 'Durée d''exécution: %', v_duration;
    RAISE NOTICE 'Début: %, Fin: %', v_start_time, v_end_time;
    RAISE NOTICE '====================================================';
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;
        
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'ERREUR lors de l''alimentation INVENTORY_PART';
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'Code d''erreur: %', SQLSTATE;
        RAISE NOTICE 'Message: %', SQLERRM;
        RAISE NOTICE 'Durée avant erreur: %', v_duration;
        RAISE NOTICE '====================================================';
        
        RAISE;
END;
$function$;

COMMENT ON FUNCTION clean_data.alimenter_inventory_part() IS 
'Alimente la table INVENTORY_PART depuis ifs_article_maitre et tables SAP.
Règles de gestion Trimet:
- CONTRACT: 9200=SJ (Saint Jean), 9000=CS (Castel)
- PART_NO: numero_article SAP (pas de transcodification, l''article garde son ID)
- INVENTORY_VALUATION_METHOD_DB: S=>ST, V=>AV (MBEW.VPRSV)
- NEGATIVE_ON_HAND_DB: NEG ONHAND OK pour articles SAP
- ABC_CLASS: MARC.MAABC
- HSN_SAC_CODE: MARC.MOWNR
- EXPECTED_LEADTIME: MARC.WEBAZ
- COUNTRY_OF_ORIGIN: MARC.HERKL';
