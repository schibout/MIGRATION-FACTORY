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
        public.get_default_value('clean_data.inventory_part', 'part_status') as part_status,
        
        -- PLANNER_BUYER: *
        public.get_default_value('clean_data.inventory_part', 'planner_buyer') as planner_buyer,
        
        -- ASSET_CLASS: S
        public.get_default_value('clean_data.inventory_part', 'asset_class') as asset_class,
        
        -- COUNTRY_OF_ORIGIN: MARC.HERKL
        SUBSTRING(marc.herkl, 1, 10) as country_of_origin,
        
        -- TYPE_CODE_DB: 4
        public.get_default_value('clean_data.inventory_part', 'type_code_db') as type_code_db,
        
        -- SUPPLY_CODE_DB: IO
        public.get_default_value('clean_data.inventory_part', 'supply_code_db') as supply_code_db,
        
        -- EXPECTED_LEADTIME: MARC.WEBAZ
        COALESCE(marc.webaz::numeric, 0) as expected_leadtime,
        
        -- MANUF_LEADTIME: 0
        public.get_default_value('clean_data.inventory_part', 'manuf_leadtime')::numeric as manuf_leadtime,
        
        -- PURCH_LEADTIME: 0
        public.get_default_value('clean_data.inventory_part', 'purch_leadtime')::numeric as purch_leadtime,
        
        -- LEAD_TIME_CODE_DB: P
        public.get_default_value('clean_data.inventory_part', 'lead_time_code_db') as lead_time_code_db,
        
        -- INVENTORY_VALUATION_METHOD_DB: S => ST, V => AV (selon code prix SAP)
        CASE 
            WHEN mbew.vprsv = 'S' THEN 'ST'
            WHEN mbew.vprsv = 'V' THEN 'AV'
            ELSE 'ST'
        END as inventory_valuation_method_db,
        
        -- COUNT_VARIANCE: 0
        public.get_default_value('clean_data.inventory_part', 'count_variance')::numeric as count_variance,
        
        -- CYCLE_CODE_DB: N
        public.get_default_value('clean_data.inventory_part', 'cycle_code_db') as cycle_code_db,
        
        -- CYCLE_PERIOD: 0
        public.get_default_value('clean_data.inventory_part', 'cycle_period')::numeric as cycle_period,
        
        -- QTY_CALC_ROUNDING: 0
        public.get_default_value('clean_data.inventory_part', 'qty_calc_rounding')::numeric as qty_calc_rounding,
        
        -- ZERO_COST_FLAG_DB: N
        public.get_default_value('clean_data.inventory_part', 'zero_cost_flag_db') as zero_cost_flag_db,
        
        -- OE_ALLOC_ASSIGN_FLAG_DB: N
        public.get_default_value('clean_data.inventory_part', 'oe_alloc_assign_flag_db') as oe_alloc_assign_flag_db,
        
        -- ONHAND_ANALYSIS_FLAG_DB: N
        public.get_default_value('clean_data.inventory_part', 'onhand_analysis_flag_db') as onhand_analysis_flag_db,
        
        -- SHORTAGE_FLAG_DB: Y
        public.get_default_value('clean_data.inventory_part', 'shortage_flag_db') as shortage_flag_db,
        
        -- FORECAST_CONSUMPTION_FLAG_DB: FORECAST
        public.get_default_value('clean_data.inventory_part', 'forecast_consumption_flag_db') as forecast_consumption_flag_db,
        
        -- STOCK_MANAGEMENT_DB: Y
        public.get_default_value('clean_data.inventory_part', 'stock_management_db') as stock_management_db,
        
        -- DOP_CONNECTION_DB: AUT
        public.get_default_value('clean_data.inventory_part', 'dop_connection_db') as dop_connection_db,
        
        -- NEGATIVE_ON_HAND_DB: NEG ONHAND NOT OK
        public.get_default_value('clean_data.inventory_part', 'negative_on_hand_db') as negative_on_hand_db,
        
        -- INVOICE_CONSIDERATION_DB: TRANSACTION BASED
        public.get_default_value('clean_data.inventory_part', 'invoice_consideration_db') as invoice_consideration_db,
        
        -- INVENTORY_PART_COST_LEVEL_DB: COST PER PART
        public.get_default_value('clean_data.inventory_part', 'inventory_part_cost_level_db') as inventory_part_cost_level_db,
        
        -- EXT_SERVICE_COST_METHOD_DB: EXCLUDE SERVICE COST
        public.get_default_value('clean_data.inventory_part', 'ext_service_cost_method_db') as ext_service_cost_method_db,
        
        -- AUTOMATIC_CAPABILITY_CHECK_DB: NO AUTOMATIC CAPABILITY CHECK
        public.get_default_value('clean_data.inventory_part', 'automatic_capability_check_db') as automatic_capability_check_db,
        
        -- DOP_NETTING_DB: NONET
        public.get_default_value('clean_data.inventory_part', 'dop_netting_db') as dop_netting_db,
        
        -- CO_RESERVE_ONH_ANALYS_FLAG_DB: N
        public.get_default_value('clean_data.inventory_part', 'co_reserve_onh_analys_flag_db') as co_reserve_onh_analys_flag_db,
        
        -- MANDATORY_EXPIRATION_DATE_DB: FALSE
        public.get_default_value('clean_data.inventory_part', 'mandatory_expiration_date_db') as mandatory_expiration_date_db,
        
        -- EXCL_SHIP_PACK_PROPOSAL_DB: FALSE
        public.get_default_value('clean_data.inventory_part', 'excl_ship_pack_proposal_db') as excl_ship_pack_proposal_db,

        -- RESET_CONFIG_STD_COST_DB: FALSE
        public.get_default_value('clean_data.inventory_part', 'reset_config_std_cost_db') as reset_config_std_cost_db,
        
        -- LIFECYCLE_STAGE_DB: DEVELOPMENT
        public.get_default_value('clean_data.inventory_part', 'lifecycle_stage_db') as lifecycle_stage_db,
        
        -- FREQUENCY_CLASS_DB: VERY SLOW MOVER
        public.get_default_value('clean_data.inventory_part', 'frequency_class_db') as frequency_class_db,
        
        -- AVAIL_ACTIVITY_STATUS_DB: CHANGED
        public.get_default_value('clean_data.inventory_part', 'avail_activity_status_db') as avail_activity_status_db,
        
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
