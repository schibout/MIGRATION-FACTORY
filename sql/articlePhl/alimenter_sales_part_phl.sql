-- Alimentation de SALES_PART pour les articles PHL (source: raw_data.phl_article)
-- INSERT en append : s'execute APRES alimenter_sales_part() et alimenter_part_catalog_phl().
-- contract = SJ. PHL = articles en stock => catalog_type INV, part_no renseigne.

CREATE OR REPLACE FUNCTION clean_data.alimenter_sales_part_phl()
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

    RAISE NOTICE 'Debut de l''alimentation SALES_PART (articles PHL) - %', v_start_time;

    INSERT INTO clean_data.sales_part (
        contract,
        catalog_no,
        catalog_desc,
        sales_unit_meas,
        catalog_group,
        sales_price_group_id,
        part_no,
        activeind_db,
        catalog_type_db,
        conv_factor,
        inverted_conv_factor,
        price_conv_factor,
        price_unit_meas,
        list_price,
        list_price_incl_tax,
        rental_list_price,
        rental_list_price_incl_tax,
        cost,
        expected_average_price,
        taxable_db,
        tax_code,
        tax_class_id,
        use_price_incl_tax_db,
        date_entered,
        price_change_date,
        close_tolerance,
        minimum_qty,
        sourcing_option_db,
        create_sm_object_option_db,
        quick_registered_part_db,
        export_to_external_app_db,
        allow_inc_pkg_rsrv_picklst,
        allow_incomp_pkg_delivery,
        pack_comp_in_shpmnt,
        sales_type_db,
        primary_catalog_db,
        delivery_type,
        non_inv_part_type_db,
        customs_stat_no,
        country_of_origin,
        statistical_code
    )
    SELECT DISTINCT ON (TRIM(phl."N. ARTICLE"))
        'SJ' as contract,
        -- catalog_no: N. ARTICLE = cle des articles PHL
        SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25) as catalog_no,
        SUBSTRING(TRIM(COALESCE(NULLIF(phl."DESCRIPTION", ''), phl."DESCRIPTION LANGUE", phl."N. ARTICLE")), 1, 200) as catalog_desc,
        -- SALES_UNIT_MEAS: U/M PHL via transcodification UOM (SAP->IFS), sinon unite brute
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(phl."U/M")), '')),
            NULLIF(TRIM(phl."U/M"), ''),
            'PCS'
        ), 1, 10) as sales_unit_meas,
        '903028' as catalog_group,
        '*' as sales_price_group_id,

        -- Article lie (PHL = article en stock)
        SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25) as part_no,

        'Y' as activeind_db,
        'INV' as catalog_type_db,

        1 as conv_factor,
        1 as inverted_conv_factor,
        1 as price_conv_factor,
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(phl."U/M")), '')),
            NULLIF(TRIM(phl."U/M"), ''),
            'PCS'
        ), 1, 10) as price_unit_meas,

        0 as list_price,
        0 as list_price_incl_tax,
        0 as rental_list_price,
        0 as rental_list_price_incl_tax,
        NULL::numeric as cost,
        NULL::numeric as expected_average_price,

        'TRUE' as taxable_db,
        'C05' as tax_code,
        NULL as tax_class_id,
        'FALSE' as use_price_incl_tax_db,

        CURRENT_TIMESTAMP as date_entered,
        NULL::timestamp as price_change_date,

        0 as close_tolerance,
        NULL::numeric as minimum_qty,

        'NOTSUPPLIED' as sourcing_option_db,

        'DONOTCREATESMOBJECT' as create_sm_object_option_db,
        'FALSE' as quick_registered_part_db,

        'FALSE' as export_to_external_app_db,
        'TRUE' as allow_inc_pkg_rsrv_picklst,
        'TRUE' as allow_incomp_pkg_delivery,
        'FALSE' as pack_comp_in_shpmnt,

        'SALES' as sales_type_db,

        'TRUE' as primary_catalog_db,

        NULL as delivery_type,
        NULL as non_inv_part_type_db,
        NULL as customs_stat_no,
        'FR' as country_of_origin,
        NULL as statistical_code

    FROM raw_data.phl_article phl
    WHERE phl."N. ARTICLE" IS NOT NULL
      AND TRIM(phl."N. ARTICLE") != ''
      -- L'article doit exister dans part_catalog (table de base)
      AND EXISTS (
          SELECT 1 FROM clean_data.part_catalog pc
          WHERE pc.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
      )
      -- Ne pas dupliquer une ligne (contract, catalog_no) deja presente
      AND NOT EXISTS (
          SELECT 1 FROM clean_data.sales_part sp
          WHERE sp.contract = 'SJ'
            AND sp.catalog_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
      )
    ORDER BY TRIM(phl."N. ARTICLE");

    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;

    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;

    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Alimentation SALES_PART (PHL) terminee avec succes';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Articles PHL inseres: %', v_count_inserted;
    RAISE NOTICE 'Duree d''execution: %', v_duration;
    RAISE NOTICE '====================================================';

EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;

        RAISE NOTICE '====================================================';
        RAISE NOTICE 'ERREUR lors de l''alimentation SALES_PART (PHL)';
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'Code d''erreur: %', SQLSTATE;
        RAISE NOTICE 'Message: %', SQLERRM;
        RAISE NOTICE 'Duree avant erreur: %', v_duration;
        RAISE NOTICE '====================================================';

        RAISE;
END;
$function$;
