-- Ajout d'un article generique SILICIUM dans PART_CATALOG (master part) et INVENTORY_PART.
-- Procedure INDEPENDANTE (execution manuelle) : ne fait PAS partie de alimenter_all_phl().
-- Reprend exactement les memes valeurs par defaut que les procedures PHL
-- (alimenter_part_catalog_phl / alimenter_inventory_part_phl).
-- Idempotente : guards NOT EXISTS, peut etre rejouee sans doublon.
--
-- Valeurs retenues :
--   part_no / description = 'SILICIUM'
--   unit_code / unit_meas = 'kg'
--   contract (inventory_part) = 'SJ'

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
        'LOT TRACKING'        as lot_tracking_code_db,
        'MANUAL'              as serial_rule_db,
        'NOT SERIAL TRACKING' as serial_tracking_code_db,
        'NOT SERIAL TRACKING' as eng_serial_tracking_code_db,
        'NOT CONFIGURED'      as configurable_db,
        'ALLOW_COND_CODE'     as condition_code_usage_db,
        'NO_SUBLOTS'          as sub_lot_rule_db,
        'MULTI_LOTS'          as lot_quantity_rule_db,
        'NOT POSITION PART'   as position_part_db,
        'FALSE'               as catch_unit_enabled_db,
        'TRACKING_OFF'        as multilevel_tracking_db,
        'MANY_LOTS_ALLOWED'   as component_lot_rule_db,
        'TRUE'                as stop_arrival_issued_serial_db,
        'FALSE'               as allow_as_not_consumed_db,
        'FALSE'               as receipt_issue_serial_track_db,
        'TRUE'                as stop_new_serial_in_rma_db
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
        'A'                              as part_status,
        '*'                              as planner_buyer,
        'S'                              as asset_class,
        NULL                             as country_of_origin,
        '3'                              as type_code_db,            -- article achete (PART TYPE = 3)
        'IO'                             as supply_code_db,
        0                                as expected_leadtime,
        0                                as manuf_leadtime,
        0                                as purch_leadtime,
        'P'                              as lead_time_code_db,        -- article achete (LEAD TIME CODE = P)
        'ST'                             as inventory_valuation_method_db,
        0                                as count_variance,
        'N'                              as cycle_code_db,
        0                                as cycle_period,
        0                                as qty_calc_rounding,
        'N'                              as zero_cost_flag_db,        -- article achete (ZERO COST FLAG = N)
        'N'                              as oe_alloc_assign_flag_db,
        'N'                              as onhand_analysis_flag_db,
        'Y'                              as shortage_flag_db,
        'FORECAST'                       as forecast_consumption_flag_db,
        'Y'                              as stock_management_db,
        'AUT'                            as dop_connection_db,
        'NEG ONHAND NOT OK'              as negative_on_hand_db,
        'TRANSACTION BASED'              as invoice_consideration_db,
        'COST PER PART'                  as inventory_part_cost_level_db,
        'EXCLUDE SERVICE COST'           as ext_service_cost_method_db,
        'NO AUTOMATIC CAPABILITY CHECK'  as automatic_capability_check_db,
        'NONET'                          as dop_netting_db,
        'N'                              as co_reserve_onh_analys_flag_db,
        'FALSE'                          as mandatory_expiration_date_db,
        'FALSE'                          as excl_ship_pack_proposal_db,
        'FALSE'                          as reset_config_std_cost_db,
        'DEVELOPMENT'                    as lifecycle_stage_db,
        'VERY SLOW MOVER'                as frequency_class_db,
        'CHANGED'                        as avail_activity_status_db,
        NULL                             as abc_class,
        NULL                             as hsn_sac_code
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
$function$;

-- Execution manuelle :
--   SELECT clean_data.ajouter_article_silicium();
