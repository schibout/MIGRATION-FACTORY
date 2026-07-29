-- Alimentation de INVENTORY_PART pour les articles PHL (source: raw_data.phl_article)
-- INSERT en append : s'execute APRES alimenter_inventory_part() et alimenter_part_catalog_phl().
-- contract = SJ (les PHL n'ont pas d'usine SAP). Defauts identiques a la version SAP.

CREATE OR REPLACE FUNCTION clean_data.alimenter_inventory_part_phl()
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

    RAISE NOTICE 'Debut de l''alimentation INVENTORY_PART (articles PHL) - %', v_start_time;

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
    SELECT DISTINCT ON (TRIM(phl."N. ARTICLE"))
        -- CONTRACT: SJ (Saint-Jean) pour tous les PHL
        'SJ' as contract,

        -- PART_NO: N. ARTICLE = cle des articles PHL
        SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25) as part_no,

        SUBSTRING(TRIM(COALESCE(NULLIF(phl."DESCRIPTION", ''), phl."DESCRIPTION LANGUE", phl."N. ARTICLE")), 1, 200) as description,
        -- UNIT_MEAS: U/M via transcodification UOM (SAP->IFS), sinon unite d'entree
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(phl."U/M")), '')),
            NULLIF(TRIM(phl."U/M"), ''),
            'PCE'
        ), 1, 10) as unit_meas,
        'A' as part_status,
        '*' as planner_buyer,
        'S' as asset_class,
        NULL as country_of_origin,
        '1' as type_code_db,
        'IO' as supply_code_db,
        0 as expected_leadtime,
        0 as manuf_leadtime,
        0 as purch_leadtime,
        'Y' as lead_time_code_db,
        'ST' as inventory_valuation_method_db,
        0 as count_variance,
        'N' as cycle_code_db,
        0 as cycle_period,
        0 as qty_calc_rounding,
        'Y' as zero_cost_flag_db,
        'N' as oe_alloc_assign_flag_db,
        'N' as onhand_analysis_flag_db,
        'Y' as shortage_flag_db,
        'FORECAST' as forecast_consumption_flag_db,
        'Y' as stock_management_db,
        'AUT' as dop_connection_db,
        'NEG ONHAND NOT OK' as negative_on_hand_db,
        'TRANSACTION BASED' as invoice_consideration_db,
        'COST PER PART' as inventory_part_cost_level_db,
        'EXCLUDE SERVICE COST' as ext_service_cost_method_db,
        'NO AUTOMATIC CAPABILITY CHECK' as automatic_capability_check_db,
        'NONET' as dop_netting_db,
        'N' as co_reserve_onh_analys_flag_db,
        'FALSE' as mandatory_expiration_date_db,
        'FALSE' as excl_ship_pack_proposal_db,
        'FALSE' as reset_config_std_cost_db,
        'DEVELOPMENT' as lifecycle_stage_db,
        'VERY SLOW MOVER' as frequency_class_db,
        'CHANGED' as avail_activity_status_db,
        NULL as abc_class,
        NULL as hsn_sac_code

    -- Source dedoublonnee (cf. v_phl_article_retenu.sql)
    FROM raw_data.v_phl_article_retenu phl
    WHERE phl."N. ARTICLE" IS NOT NULL
      AND TRIM(phl."N. ARTICLE") != ''
      -- Ne garder que les produits finis (STATUT=F) et intermediaires (STATUT=I)
      AND UPPER(LEFT(TRIM(phl."STATUT"), 1)) IN ('F', 'I')
      -- L'article doit exister dans part_catalog (table de base)
      AND EXISTS (
          SELECT 1 FROM clean_data.part_catalog pc
          WHERE pc.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
      )
      -- Ne pas dupliquer une ligne (contract, part_no) deja presente
      AND NOT EXISTS (
          SELECT 1 FROM clean_data.inventory_part ip
          WHERE ip.contract = 'SJ'
            AND ip.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
      )
    ORDER BY TRIM(phl."N. ARTICLE");

    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;

    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;

    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Alimentation INVENTORY_PART (PHL) terminee avec succes';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Articles PHL inseres: %', v_count_inserted;
    RAISE NOTICE 'Duree d''execution: %', v_duration;
    RAISE NOTICE '====================================================';

EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;

        RAISE NOTICE '====================================================';
        RAISE NOTICE 'ERREUR lors de l''alimentation INVENTORY_PART (PHL)';
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'Code d''erreur: %', SQLSTATE;
        RAISE NOTICE 'Message: %', SQLERRM;
        RAISE NOTICE 'Duree avant erreur: %', v_duration;
        RAISE NOTICE '====================================================';

        RAISE;
END;
$function$;
