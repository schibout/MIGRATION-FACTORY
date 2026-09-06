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
        statistical_code,
        eng_attribute,
        note_id,
        print_control_code,
        activeind,
        catalog_type,
        discount_group,
        note_text,
        taxable,
        create_sm_object_option,
        purchase_part_no,
        replacement_part_no,
        date_of_replacement,
        cust_warranty_id,
        non_inv_part_type,
        sourcing_option,
        rule_id,
        quick_registered_part,
        export_to_external_app,
        sales_part_rebate_group,
        primary_catalog,
        use_price_incl_tax,
        sales_type,
        acquisition_origin,
        acquisition_reason_id,
        hsn_sac_code,
        saft_category,
        saft_category_db
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
        -- Valeurs par defaut : matrice site x famille SEULE
        -- (/configuration/matrice-site-famille). Aucune regle -> NULL, il n'y a
        -- plus de repli sur la constante (public.get_matrix_value, migration 071).
        public.get_matrix_value('clean_data.sales_part', 'catalog_group', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as catalog_group,
        public.get_matrix_value('clean_data.sales_part', 'sales_price_group_id', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as sales_price_group_id,
        -- Article lie (PHL = article en stock)
        SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25) as part_no,
        public.get_matrix_value('clean_data.sales_part', 'activeind_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as activeind_db,
        public.get_matrix_value('clean_data.sales_part', 'catalog_type_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as catalog_type_db,
        public.get_matrix_value('clean_data.sales_part', 'conv_factor', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as conv_factor,
        public.get_matrix_value('clean_data.sales_part', 'inverted_conv_factor', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as inverted_conv_factor,
        public.get_matrix_value('clean_data.sales_part', 'price_conv_factor', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as price_conv_factor,
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(TRIM(phl."U/M"), '')),
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(phl."U/M")), '')),
            NULLIF(TRIM(phl."U/M"), ''),
            'PCS'
        ), 1, 10) as price_unit_meas,
        public.get_matrix_value('clean_data.sales_part', 'list_price', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as list_price,
        public.get_matrix_value('clean_data.sales_part', 'list_price_incl_tax', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as list_price_incl_tax,
        public.get_matrix_value('clean_data.sales_part', 'rental_list_price', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as rental_list_price,
        public.get_matrix_value('clean_data.sales_part', 'rental_list_price_incl_tax', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as rental_list_price_incl_tax,
        public.get_matrix_value('clean_data.sales_part', 'cost', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as cost,
        public.get_matrix_value('clean_data.sales_part', 'expected_average_price', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as expected_average_price,
        public.get_matrix_value('clean_data.sales_part', 'taxable_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as taxable_db,
        public.get_matrix_value('clean_data.sales_part', 'tax_code', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as tax_code,
        public.get_matrix_value('clean_data.sales_part', 'tax_class_id', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as tax_class_id,
        public.get_matrix_value('clean_data.sales_part', 'use_price_incl_tax_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as use_price_incl_tax_db,
        CURRENT_TIMESTAMP as date_entered,
        public.get_matrix_value('clean_data.sales_part', 'price_change_date', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::timestamp as price_change_date,
        public.get_matrix_value('clean_data.sales_part', 'close_tolerance', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as close_tolerance,
        public.get_matrix_value('clean_data.sales_part', 'minimum_qty', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as minimum_qty,
        public.get_matrix_value('clean_data.sales_part', 'sourcing_option_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as sourcing_option_db,
        public.get_matrix_value('clean_data.sales_part', 'create_sm_object_option_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as create_sm_object_option_db,
        public.get_matrix_value('clean_data.sales_part', 'quick_registered_part_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as quick_registered_part_db,
        public.get_matrix_value('clean_data.sales_part', 'export_to_external_app_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as export_to_external_app_db,
        public.get_matrix_value('clean_data.sales_part', 'allow_inc_pkg_rsrv_picklst', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as allow_inc_pkg_rsrv_picklst,
        public.get_matrix_value('clean_data.sales_part', 'allow_incomp_pkg_delivery', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as allow_incomp_pkg_delivery,
        public.get_matrix_value('clean_data.sales_part', 'pack_comp_in_shpmnt', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as pack_comp_in_shpmnt,
        public.get_matrix_value('clean_data.sales_part', 'sales_type_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as sales_type_db,
        public.get_matrix_value('clean_data.sales_part', 'primary_catalog_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as primary_catalog_db,
        public.get_matrix_value('clean_data.sales_part', 'delivery_type', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as delivery_type,
        public.get_matrix_value('clean_data.sales_part', 'non_inv_part_type_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as non_inv_part_type_db,
        public.get_matrix_value('clean_data.sales_part', 'customs_stat_no', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as customs_stat_no,
        public.get_matrix_value('clean_data.sales_part', 'country_of_origin', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as country_of_origin,
        public.get_matrix_value('clean_data.sales_part', 'statistical_code', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as statistical_code,
    -- Source dedoublonnee (cf. v_phl_article_retenu.sql)
        -- Colonnes non alimentees par le fichier PHL : valeur pilotee par
        -- l'ecran /configuration/valeurs-defaut (variante ARTICLEPHL).
        public.get_matrix_value('clean_data.sales_part', 'eng_attribute', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as eng_attribute,
        NULLIF(public.get_matrix_value('clean_data.sales_part', 'note_id', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as note_id,
        public.get_matrix_value('clean_data.sales_part', 'print_control_code', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as print_control_code,
        public.get_matrix_value('clean_data.sales_part', 'activeind', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as activeind,
        public.get_matrix_value('clean_data.sales_part', 'catalog_type', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as catalog_type,
        public.get_matrix_value('clean_data.sales_part', 'discount_group', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as discount_group,
        public.get_matrix_value('clean_data.sales_part', 'note_text', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as note_text,
        public.get_matrix_value('clean_data.sales_part', 'taxable', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as taxable,
        public.get_matrix_value('clean_data.sales_part', 'create_sm_object_option', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as create_sm_object_option,
        public.get_matrix_value('clean_data.sales_part', 'purchase_part_no', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as purchase_part_no,
        public.get_matrix_value('clean_data.sales_part', 'replacement_part_no', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as replacement_part_no,
        NULLIF(public.get_matrix_value('clean_data.sales_part', 'date_of_replacement', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::timestamp as date_of_replacement,
        NULLIF(public.get_matrix_value('clean_data.sales_part', 'cust_warranty_id', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as cust_warranty_id,
        public.get_matrix_value('clean_data.sales_part', 'non_inv_part_type', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as non_inv_part_type,
        public.get_matrix_value('clean_data.sales_part', 'sourcing_option', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as sourcing_option,
        public.get_matrix_value('clean_data.sales_part', 'rule_id', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as rule_id,
        public.get_matrix_value('clean_data.sales_part', 'quick_registered_part', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as quick_registered_part,
        public.get_matrix_value('clean_data.sales_part', 'export_to_external_app', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as export_to_external_app,
        public.get_matrix_value('clean_data.sales_part', 'sales_part_rebate_group', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as sales_part_rebate_group,
        public.get_matrix_value('clean_data.sales_part', 'primary_catalog', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as primary_catalog,
        public.get_matrix_value('clean_data.sales_part', 'use_price_incl_tax', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as use_price_incl_tax,
        public.get_matrix_value('clean_data.sales_part', 'sales_type', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as sales_type,
        NULLIF(public.get_matrix_value('clean_data.sales_part', 'acquisition_origin', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as acquisition_origin,
        public.get_matrix_value('clean_data.sales_part', 'acquisition_reason_id', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as acquisition_reason_id,
        public.get_matrix_value('clean_data.sales_part', 'hsn_sac_code', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as hsn_sac_code,
        public.get_matrix_value('clean_data.sales_part', 'saft_category', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as saft_category,
        public.get_matrix_value('clean_data.sales_part', 'saft_category_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as saft_category_db
    FROM raw_data.v_phl_article_retenu phl
    WHERE phl."N. ARTICLE" IS NOT NULL
      AND phl.site = p_contract   -- cloisonnement par site (cf. v_phl_article_retenu)
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
      AND phl.site = p_contract   -- cloisonnement par site (cf. v_phl_article_retenu)
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
