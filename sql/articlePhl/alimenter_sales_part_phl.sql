-- L'ancienne signature sans parametre doit disparaitre, sinon PostgreSQL cree une
-- surcharge et les appels sans argument deviennent ambigus.
DROP FUNCTION IF EXISTS clean_data.alimenter_sales_part_phl();
CREATE OR REPLACE FUNCTION clean_data.alimenter_sales_part_phl(p_contract text DEFAULT 'SJ')
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_count_inserted INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL;
BEGIN
    IF p_contract NOT IN ('SJ', 'CS') THEN
        RAISE EXCEPTION 'Site invalide: % (attendu: SJ ou CS)', p_contract;
    END IF;
    v_start_time := CURRENT_TIMESTAMP;
    RAISE NOTICE 'Debut de l''alimentation SALES_PART (articles PHL, site %) - %', p_contract, v_start_time;
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
        p_contract as contract,
        -- catalog_no: N. ARTICLE = cle des articles PHL
        SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25) as catalog_no,
        SUBSTRING(TRIM(COALESCE(NULLIF(phl."DESCRIPTION", ''), phl."DESCRIPTION LANGUE", phl."N. ARTICLE")), 1, 200) as catalog_desc,
        -- SALES_UNIT_MEAS: U/M PHL via transcodification UOM (SAP->IFS), sinon unite brute
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(TRIM(phl."U/M"), '')),
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(phl."U/M")), '')),
            NULLIF(TRIM(phl."U/M"), ''),
            'PCS'
        ), 1, 10) as sales_unit_meas,
        -- Valeurs par defaut parametrables via l'ecran /configuration/valeurs-defaut
        -- (public.get_default_value, fallback = ancienne valeur codee en dur)
        public.get_default_value('clean_data.sales_part', 'catalog_group') as catalog_group,
        public.get_default_value('clean_data.sales_part', 'sales_price_group_id') as sales_price_group_id,
        -- Article lie (PHL = article en stock)
        SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25) as part_no,
        public.get_default_value('clean_data.sales_part', 'activeind_db') as activeind_db,
        public.get_default_value('clean_data.sales_part', 'catalog_type_db') as catalog_type_db,
        public.get_default_value('clean_data.sales_part', 'conv_factor')::numeric as conv_factor,
        public.get_default_value('clean_data.sales_part', 'inverted_conv_factor')::numeric as inverted_conv_factor,
        public.get_default_value('clean_data.sales_part', 'price_conv_factor')::numeric as price_conv_factor,
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(TRIM(phl."U/M"), '')),
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(phl."U/M")), '')),
            NULLIF(TRIM(phl."U/M"), ''),
            'PCS'
        ), 1, 10) as price_unit_meas,
        public.get_default_value('clean_data.sales_part', 'list_price')::numeric as list_price,
        public.get_default_value('clean_data.sales_part', 'list_price_incl_tax')::numeric as list_price_incl_tax,
        public.get_default_value('clean_data.sales_part', 'rental_list_price')::numeric as rental_list_price,
        public.get_default_value('clean_data.sales_part', 'rental_list_price_incl_tax')::numeric as rental_list_price_incl_tax,
        public.get_default_value('clean_data.sales_part', 'cost')::numeric as cost,
        public.get_default_value('clean_data.sales_part', 'expected_average_price')::numeric as expected_average_price,
        public.get_default_value('clean_data.sales_part', 'taxable_db') as taxable_db,
        public.get_default_value('clean_data.sales_part', 'tax_code') as tax_code,
        public.get_default_value('clean_data.sales_part', 'tax_class_id') as tax_class_id,
        public.get_default_value('clean_data.sales_part', 'use_price_incl_tax_db') as use_price_incl_tax_db,
        CURRENT_TIMESTAMP as date_entered,
        public.get_default_value('clean_data.sales_part', 'price_change_date')::timestamp as price_change_date,
        public.get_default_value('clean_data.sales_part', 'close_tolerance')::numeric as close_tolerance,
        public.get_default_value('clean_data.sales_part', 'minimum_qty')::numeric as minimum_qty,
        public.get_default_value('clean_data.sales_part', 'sourcing_option_db') as sourcing_option_db,
        public.get_default_value('clean_data.sales_part', 'create_sm_object_option_db') as create_sm_object_option_db,
        public.get_default_value('clean_data.sales_part', 'quick_registered_part_db') as quick_registered_part_db,
        public.get_default_value('clean_data.sales_part', 'export_to_external_app_db') as export_to_external_app_db,
        public.get_default_value('clean_data.sales_part', 'allow_inc_pkg_rsrv_picklst') as allow_inc_pkg_rsrv_picklst,
        public.get_default_value('clean_data.sales_part', 'allow_incomp_pkg_delivery') as allow_incomp_pkg_delivery,
        public.get_default_value('clean_data.sales_part', 'pack_comp_in_shpmnt') as pack_comp_in_shpmnt,
        public.get_default_value('clean_data.sales_part', 'sales_type_db') as sales_type_db,
        public.get_default_value('clean_data.sales_part', 'primary_catalog_db') as primary_catalog_db,
        public.get_default_value('clean_data.sales_part', 'delivery_type') as delivery_type,
        public.get_default_value('clean_data.sales_part', 'non_inv_part_type_db') as non_inv_part_type_db,
        public.get_default_value('clean_data.sales_part', 'customs_stat_no') as customs_stat_no,
        public.get_default_value('clean_data.sales_part', 'country_of_origin') as country_of_origin,
        public.get_default_value('clean_data.sales_part', 'statistical_code') as statistical_code
    -- Source dedoublonnee (cf. v_phl_article_retenu.sql)
    FROM raw_data.v_phl_article_retenu phl
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
          WHERE sp.contract = p_contract
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
$function$
;
