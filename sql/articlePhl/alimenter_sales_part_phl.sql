-- L'ancienne signature sans parametre doit disparaitre, sinon PostgreSQL cree une
-- surcharge et les appels sans argument deviennent ambigus.
DROP FUNCTION IF EXISTS clean_data.alimenter_sales_part_phl();
CREATE OR REPLACE FUNCTION clean_data.alimenter_sales_part_phl(p_contract text DEFAULT 'SJ')
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_count_inserted INTEGER := 0;
    v_count_routage_supprime INTEGER := 0;
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
        -- Valeurs par defaut parametrables :
        --   1. matrice site x famille  -> /configuration/matrice-site-famille
        --   2. constante par colonne   -> /configuration/valeurs-defaut
        --   3. NULL si rien n'est parametre
        -- (public.get_default_value_ctx, migration 066)
        public.get_default_value_ctx('clean_data.sales_part', 'catalog_group', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as catalog_group,
        public.get_default_value_ctx('clean_data.sales_part', 'sales_price_group_id', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as sales_price_group_id,
        -- Article lie (PHL = article en stock)
        SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25) as part_no,
        public.get_default_value_ctx('clean_data.sales_part', 'activeind_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as activeind_db,
        public.get_default_value_ctx('clean_data.sales_part', 'catalog_type_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as catalog_type_db,
        public.get_default_value_ctx('clean_data.sales_part', 'conv_factor', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as conv_factor,
        public.get_default_value_ctx('clean_data.sales_part', 'inverted_conv_factor', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as inverted_conv_factor,
        public.get_default_value_ctx('clean_data.sales_part', 'price_conv_factor', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as price_conv_factor,
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(TRIM(phl."U/M"), '')),
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(phl."U/M")), '')),
            NULLIF(TRIM(phl."U/M"), ''),
            'PCS'
        ), 1, 10) as price_unit_meas,
        public.get_default_value_ctx('clean_data.sales_part', 'list_price', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as list_price,
        public.get_default_value_ctx('clean_data.sales_part', 'list_price_incl_tax', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as list_price_incl_tax,
        public.get_default_value_ctx('clean_data.sales_part', 'rental_list_price', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as rental_list_price,
        public.get_default_value_ctx('clean_data.sales_part', 'rental_list_price_incl_tax', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as rental_list_price_incl_tax,
        public.get_default_value_ctx('clean_data.sales_part', 'cost', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as cost,
        public.get_default_value_ctx('clean_data.sales_part', 'expected_average_price', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as expected_average_price,
        public.get_default_value_ctx('clean_data.sales_part', 'taxable_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as taxable_db,
        public.get_default_value_ctx('clean_data.sales_part', 'tax_code', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as tax_code,
        public.get_default_value_ctx('clean_data.sales_part', 'tax_class_id', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as tax_class_id,
        public.get_default_value_ctx('clean_data.sales_part', 'use_price_incl_tax_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as use_price_incl_tax_db,
        CURRENT_TIMESTAMP as date_entered,
        public.get_default_value_ctx('clean_data.sales_part', 'price_change_date', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::timestamp as price_change_date,
        public.get_default_value_ctx('clean_data.sales_part', 'close_tolerance', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as close_tolerance,
        public.get_default_value_ctx('clean_data.sales_part', 'minimum_qty', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as minimum_qty,
        public.get_default_value_ctx('clean_data.sales_part', 'sourcing_option_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as sourcing_option_db,
        public.get_default_value_ctx('clean_data.sales_part', 'create_sm_object_option_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as create_sm_object_option_db,
        public.get_default_value_ctx('clean_data.sales_part', 'quick_registered_part_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as quick_registered_part_db,
        public.get_default_value_ctx('clean_data.sales_part', 'export_to_external_app_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as export_to_external_app_db,
        public.get_default_value_ctx('clean_data.sales_part', 'allow_inc_pkg_rsrv_picklst', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as allow_inc_pkg_rsrv_picklst,
        public.get_default_value_ctx('clean_data.sales_part', 'allow_incomp_pkg_delivery', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as allow_incomp_pkg_delivery,
        public.get_default_value_ctx('clean_data.sales_part', 'pack_comp_in_shpmnt', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as pack_comp_in_shpmnt,
        public.get_default_value_ctx('clean_data.sales_part', 'sales_type_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as sales_type_db,
        public.get_default_value_ctx('clean_data.sales_part', 'primary_catalog_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as primary_catalog_db,
        public.get_default_value_ctx('clean_data.sales_part', 'delivery_type', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as delivery_type,
        public.get_default_value_ctx('clean_data.sales_part', 'non_inv_part_type_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as non_inv_part_type_db,
        public.get_default_value_ctx('clean_data.sales_part', 'customs_stat_no', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as customs_stat_no,
        public.get_default_value_ctx('clean_data.sales_part', 'country_of_origin', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as country_of_origin,
        public.get_default_value_ctx('clean_data.sales_part', 'statistical_code', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as statistical_code
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
      -- Routage de creation site x famille (/configuration/matrice-site-famille).
      -- Aucune ligne de matrice pour ce couple -> creation autorisee (COALESCE TRUE),
      -- donc comportement inchange tant que la matrice n'est pas renseignee.
      AND COALESCE(public.get_part_type_matrix('clean_data.sales_part', p_contract,
                                               NULLIF(TRIM(phl."FAMILLE"), '')), TRUE)
    ORDER BY TRIM(phl."N. ARTICLE");
    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;

    -- Symetrique du garde ci-dessus : une famille passee a "ne pas creer" doit
    -- voir ses lignes disparaitre au prochain chargement. La table n'est jamais
    -- videe (insertion en APPEND), sans cette purge le flag serait sans effet
    -- sur les articles deja charges. Perimetre strict : articles PHL du site.
    DELETE FROM clean_data.sales_part sp
    USING raw_data.v_phl_article_retenu phl
    WHERE sp.contract = p_contract
      AND sp.catalog_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
      AND public.get_part_type_matrix('clean_data.sales_part', p_contract,
                                      NULLIF(TRIM(phl."FAMILLE"), '')) IS FALSE;
    GET DIAGNOSTICS v_count_routage_supprime = ROW_COUNT;
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Alimentation SALES_PART (PHL) terminee avec succes';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Articles PHL inseres: %', v_count_inserted;
    RAISE NOTICE 'Lignes supprimees par le routage site x famille: %', v_count_routage_supprime;
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
