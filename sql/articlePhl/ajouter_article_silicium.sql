CREATE OR REPLACE FUNCTION clean_data.ajouter_article_silicium()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_part_no    text := 'SILICIUM';
    v_description text := 'SILICIUM';
    v_unit       text := 'kg';
    v_contract   text := 'SJ';
    v_cat_inserted INTEGER := 0;
    v_inv_inserted INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time   TIMESTAMP;
    v_duration   INTERVAL;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;

    RAISE NOTICE 'Debut de l''ajout de l''article generique SILICIUM - %', v_start_time;

    -- ============================================================
    -- 1) PART_CATALOG (master part) - table de base
    -- ============================================================
    INSERT INTO clean_data.part_catalog (
        part_no,
        description,
        unit_code,
        lot_tracking_code_db,
        serial_rule_db,
        serial_tracking_code_db,
        eng_serial_tracking_code_db,
        configurable_db,
        condition_code_usage_db,
        sub_lot_rule_db,
        lot_quantity_rule_db,
        position_part_db,
        catch_unit_enabled_db,
        multilevel_tracking_db,
        component_lot_rule_db,
        stop_arrival_issued_serial_db,
        allow_as_not_consumed_db,
        receipt_issue_serial_track_db,
        stop_new_serial_in_rma_db
    )
    SELECT
        v_part_no,
        v_description,
        v_unit,
        -- Memes valeurs _db que les articles PHL (type I et F)
        public.get_default_value('clean_data.part_catalog', 'lot_tracking_code_db', 'LOT TRACKING')        as lot_tracking_code_db,
        public.get_default_value('clean_data.part_catalog', 'serial_rule_db', 'MANUAL')              as serial_rule_db,
        public.get_default_value('clean_data.part_catalog', 'serial_tracking_code_db', 'NOT SERIAL TRACKING') as serial_tracking_code_db,
        public.get_default_value('clean_data.part_catalog', 'eng_serial_tracking_code_db', 'NOT SERIAL TRACKING') as eng_serial_tracking_code_db,
        public.get_default_value('clean_data.part_catalog', 'configurable_db', 'NOT CONFIGURED')      as configurable_db,
        public.get_default_value('clean_data.part_catalog', 'condition_code_usage_db', 'NOT_ALLOW_COND_CODE')     as condition_code_usage_db,
        public.get_default_value('clean_data.part_catalog', 'sub_lot_rule_db', 'NO_SUBLOTS')          as sub_lot_rule_db,
        public.get_default_value('clean_data.part_catalog', 'lot_quantity_rule_db', 'MULTI_LOTS')          as lot_quantity_rule_db,
        public.get_default_value('clean_data.part_catalog', 'position_part_db', 'NOT POSITION PART')   as position_part_db,
        public.get_default_value('clean_data.part_catalog', 'catch_unit_enabled_db', 'FALSE')               as catch_unit_enabled_db,
        public.get_default_value('clean_data.part_catalog', 'multilevel_tracking_db', 'TRACKING_OFF')        as multilevel_tracking_db,
        public.get_default_value('clean_data.part_catalog', 'component_lot_rule_db', 'MANY_LOTS_ALLOWED', 'ARTICLEPHL')   as component_lot_rule_db,
        public.get_default_value('clean_data.part_catalog', 'stop_arrival_issued_serial_db', 'TRUE')                as stop_arrival_issued_serial_db,
        public.get_default_value('clean_data.part_catalog', 'allow_as_not_consumed_db', 'FALSE')               as allow_as_not_consumed_db,
        public.get_default_value('clean_data.part_catalog', 'receipt_issue_serial_track_db', 'FALSE')               as receipt_issue_serial_track_db,
        public.get_default_value('clean_data.part_catalog', 'stop_new_serial_in_rma_db', 'TRUE')                as stop_new_serial_in_rma_db
    WHERE NOT EXISTS (
        SELECT 1 FROM clean_data.part_catalog pc
        WHERE pc.part_no = v_part_no
    );

    GET DIAGNOSTICS v_cat_inserted = ROW_COUNT;

    -- ============================================================
    -- 2) INVENTORY_PART (contract = SJ)
    --    Necessite l'existence dans part_catalog (cree juste au-dessus)
    -- ============================================================
    INSERT INTO clean_data.inventory_part (
        contract,
        part_no,
        description,
        unit_meas,
        part_status,
        planner_buyer,
        asset_class,
        country_of_origin,
        type_code_db,
        supply_code_db,
        expected_leadtime,
        manuf_leadtime,
        purch_leadtime,
        lead_time_code_db,
        inventory_valuation_method_db,
        count_variance,
        cycle_code_db,
        cycle_period,
        qty_calc_rounding,
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
        lifecycle_stage_db,
        frequency_class_db,
        avail_activity_status_db,
        abc_class,
        hsn_sac_code
    )
    SELECT
        v_contract,
        v_part_no,
        v_description,
        v_unit,
        public.get_default_value('clean_data.inventory_part', 'part_status', 'A')                              as part_status,
        public.get_default_value('clean_data.inventory_part', 'planner_buyer', '*')                              as planner_buyer,
        public.get_default_value('clean_data.inventory_part', 'asset_class', 'S')                              as asset_class,
        public.get_default_value('clean_data.inventory_part', 'country_of_origin', NULL)                             as country_of_origin,
        public.get_default_value('clean_data.inventory_part', 'type_code_db', '3', 'SILICIUM') as type_code_db,  -- article achete (PART TYPE = 3)
        public.get_default_value('clean_data.inventory_part', 'supply_code_db', 'IO')                             as supply_code_db,
        public.get_default_value('clean_data.inventory_part', 'expected_leadtime', '0')::numeric                                as expected_leadtime,
        public.get_default_value('clean_data.inventory_part', 'manuf_leadtime', '0')::numeric                                as manuf_leadtime,
        public.get_default_value('clean_data.inventory_part', 'purch_leadtime', '0')::numeric                                as purch_leadtime,
        public.get_default_value('clean_data.inventory_part', 'lead_time_code_db', 'P', 'SILICIUM') as lead_time_code_db,  -- article achete (LEAD TIME CODE = P)
        public.get_default_value('clean_data.inventory_part', 'inventory_valuation_method_db', 'ST')                             as inventory_valuation_method_db,
        public.get_default_value('clean_data.inventory_part', 'count_variance', '0')::numeric                                as count_variance,
        public.get_default_value('clean_data.inventory_part', 'cycle_code_db', 'N')                              as cycle_code_db,
        public.get_default_value('clean_data.inventory_part', 'cycle_period', '0')::numeric                                as cycle_period,
        public.get_default_value('clean_data.inventory_part', 'qty_calc_rounding', '0')::numeric                                as qty_calc_rounding,
        public.get_default_value('clean_data.inventory_part', 'zero_cost_flag_db', 'N', 'SILICIUM') as zero_cost_flag_db,  -- article achete (ZERO COST FLAG = N)
        public.get_default_value('clean_data.inventory_part', 'oe_alloc_assign_flag_db', 'N')                              as oe_alloc_assign_flag_db,
        public.get_default_value('clean_data.inventory_part', 'onhand_analysis_flag_db', 'N')                              as onhand_analysis_flag_db,
        public.get_default_value('clean_data.inventory_part', 'shortage_flag_db', 'Y')                              as shortage_flag_db,
        public.get_default_value('clean_data.inventory_part', 'forecast_consumption_flag_db', 'FORECAST')                       as forecast_consumption_flag_db,
        public.get_default_value('clean_data.inventory_part', 'stock_management_db', 'Y')                              as stock_management_db,
        public.get_default_value('clean_data.inventory_part', 'dop_connection_db', 'AUT')                            as dop_connection_db,
        public.get_default_value('clean_data.inventory_part', 'negative_on_hand_db', 'NEG ONHAND NOT OK')              as negative_on_hand_db,
        public.get_default_value('clean_data.inventory_part', 'invoice_consideration_db', 'TRANSACTION BASED')              as invoice_consideration_db,
        public.get_default_value('clean_data.inventory_part', 'inventory_part_cost_level_db', 'COST PER PART')                  as inventory_part_cost_level_db,
        public.get_default_value('clean_data.inventory_part', 'ext_service_cost_method_db', 'EXCLUDE SERVICE COST')           as ext_service_cost_method_db,
        public.get_default_value('clean_data.inventory_part', 'automatic_capability_check_db', 'NO AUTOMATIC CAPABILITY CHECK')  as automatic_capability_check_db,
        public.get_default_value('clean_data.inventory_part', 'dop_netting_db', 'NONET')                          as dop_netting_db,
        public.get_default_value('clean_data.inventory_part', 'co_reserve_onh_analys_flag_db', 'N')                              as co_reserve_onh_analys_flag_db,
        public.get_default_value('clean_data.inventory_part', 'mandatory_expiration_date_db', 'FALSE')                          as mandatory_expiration_date_db,
        public.get_default_value('clean_data.inventory_part', 'excl_ship_pack_proposal_db', 'FALSE')                          as excl_ship_pack_proposal_db,
        public.get_default_value('clean_data.inventory_part', 'reset_config_std_cost_db', 'FALSE')                          as reset_config_std_cost_db,
        public.get_default_value('clean_data.inventory_part', 'lifecycle_stage_db', 'DEVELOPMENT')                    as lifecycle_stage_db,
        public.get_default_value('clean_data.inventory_part', 'frequency_class_db', 'VERY SLOW MOVER')                as frequency_class_db,
        public.get_default_value('clean_data.inventory_part', 'avail_activity_status_db', 'CHANGED')                        as avail_activity_status_db,
        public.get_default_value('clean_data.inventory_part', 'abc_class', NULL)                             as abc_class,
        public.get_default_value('clean_data.inventory_part', 'hsn_sac_code', NULL)                             as hsn_sac_code
    WHERE NOT EXISTS (
        SELECT 1 FROM clean_data.inventory_part ip
        WHERE ip.contract = v_contract
          AND ip.part_no  = v_part_no
    );

    GET DIAGNOSTICS v_inv_inserted = ROW_COUNT;

    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;

    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Ajout article SILICIUM termine avec succes';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'PART_CATALOG    inseres: % (0 = deja present)', v_cat_inserted;
    RAISE NOTICE 'INVENTORY_PART  inseres: % (0 = deja present)', v_inv_inserted;
    RAISE NOTICE 'Duree d''execution: %', v_duration;
    RAISE NOTICE '====================================================';

EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;

        RAISE NOTICE '====================================================';
        RAISE NOTICE 'ERREUR lors de l''ajout de l''article SILICIUM';
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'Code d''erreur: %', SQLSTATE;
        RAISE NOTICE 'Message: %', SQLERRM;
        RAISE NOTICE 'Duree avant erreur: %', v_duration;
        RAISE NOTICE '====================================================';

        RAISE;
END;
$function$
;
