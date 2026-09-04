-- L'ancienne signature sans parametre doit disparaitre, sinon PostgreSQL cree une
-- surcharge et les appels sans argument deviennent ambigus.
DROP FUNCTION IF EXISTS clean_data.alimenter_sales_part_cmp();
CREATE OR REPLACE FUNCTION clean_data.alimenter_sales_part_cmp(p_contract text DEFAULT 'SJ')
 RETURNS void
 LANGUAGE plpgsql
AS $function$
-- Table directrice : raw_data.composant_sj_cs, filtree sur site = p_contract.
--
-- Valeurs par defaut : gabarit metier valeurParDefaut/salesPart.csv, seede en
-- variante COMPOSANT (migration 061) et ajustable via /configuration/valeurs-defaut.
--
-- Colonnes laissees vides par le gabarit : elles ne sont pas dans l'INSERT
-- (delivery_type, minimum_qty, cost, expected_average_price, customs_stat_no,
-- statistical_code, tax_class_id, intrastat_conv_factor, price_change_date...).
-- NOTE_ID est un identifiant genere par IFS : non alimente. COMPANY, LANGUAGE_CODE,
-- GTIN_NO, NBS_CODE et TAX_MANUF_EQUIVALENT du gabarit n'existent pas dans
-- clean_data.sales_part.
DECLARE
    v_count_inserted INTEGER := 0;
    v_count_updated INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL;
BEGIN
    IF p_contract NOT IN ('SJ', 'CS') THEN
        RAISE EXCEPTION 'Site invalide: % (attendu: SJ ou CS)', p_contract;
    END IF;
    v_start_time := CURRENT_TIMESTAMP;
    RAISE NOTICE 'Debut de l''alimentation SALES_PART (composants, site %) - %', p_contract, v_start_time;
    INSERT INTO clean_data.sales_part (
        contract, catalog_no, catalog_desc, part_no, sales_unit_meas, price_unit_meas, date_entered,
        activeind, activeind_db, allow_inc_pkg_rsrv_picklst, allow_incomp_pkg_delivery, catalog_group,
        catalog_type, catalog_type_db, close_tolerance, conv_factor, country_of_origin,
        create_sm_object_option, create_sm_object_option_db, export_to_external_app,
        export_to_external_app_db, inverted_conv_factor, list_price, list_price_incl_tax, non_inv_part_type,
        non_inv_part_type_db, pack_comp_in_shpmnt, price_conv_factor, primary_catalog, primary_catalog_db,
        quick_registered_part, quick_registered_part_db, rental_list_price, rental_list_price_incl_tax,
        sales_price_group_id, sales_type, sales_type_db, sourcing_option, sourcing_option_db, tax_code,
        taxable, taxable_db, use_price_incl_tax, use_price_incl_tax_db
    )
    SELECT DISTINCT ON (TRIM(cmp.code_produit))
        -- site passe en parametre
        p_contract as contract,
        -- code_produit = cle des composants
        SUBSTRING(TRIM(cmp.code_produit), 1, 25) as catalog_no,
        SUBSTRING(TRIM(COALESCE(NULLIF(TRIM(cmp.libelle_produit), ''), cmp.code_produit)), 1, 200) as catalog_desc,
        -- article lie (composant = article en stock)
        SUBSTRING(TRIM(cmp.code_produit), 1, 25) as part_no,
        -- unite via transcodification UOM (KG -> kg)
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(TRIM(cmp.unite), '')),
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(cmp.unite)), '')),
            NULLIF(TRIM(cmp.unite), ''),
            'PCE'
        ), 1, 10) as sales_unit_meas,
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(TRIM(cmp.unite), '')),
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(cmp.unite)), '')),
            NULLIF(TRIM(cmp.unite), ''),
            'PCE'
        ), 1, 10) as price_unit_meas,
        CURRENT_TIMESTAMP as date_entered,
        public.get_default_value('clean_data.sales_part', 'activeind', 'COMPOSANT') as activeind,
        public.get_default_value('clean_data.sales_part', 'activeind_db', 'COMPOSANT') as activeind_db,
        public.get_default_value('clean_data.sales_part', 'allow_inc_pkg_rsrv_picklst', 'COMPOSANT') as allow_inc_pkg_rsrv_picklst,
        public.get_default_value('clean_data.sales_part', 'allow_incomp_pkg_delivery', 'COMPOSANT') as allow_incomp_pkg_delivery,
        public.get_default_value('clean_data.sales_part', 'catalog_group', 'COMPOSANT') as catalog_group,
        public.get_default_value('clean_data.sales_part', 'catalog_type', 'COMPOSANT') as catalog_type,
        public.get_default_value('clean_data.sales_part', 'catalog_type_db', 'COMPOSANT') as catalog_type_db,
        public.get_default_value('clean_data.sales_part', 'close_tolerance', 'COMPOSANT')::numeric as close_tolerance,
        public.get_default_value('clean_data.sales_part', 'conv_factor', 'COMPOSANT')::numeric as conv_factor,
        public.get_default_value('clean_data.sales_part', 'country_of_origin', 'COMPOSANT') as country_of_origin,
        public.get_default_value('clean_data.sales_part', 'create_sm_object_option', 'COMPOSANT') as create_sm_object_option,
        public.get_default_value('clean_data.sales_part', 'create_sm_object_option_db', 'COMPOSANT') as create_sm_object_option_db,
        public.get_default_value('clean_data.sales_part', 'export_to_external_app', 'COMPOSANT') as export_to_external_app,
        public.get_default_value('clean_data.sales_part', 'export_to_external_app_db', 'COMPOSANT') as export_to_external_app_db,
        public.get_default_value('clean_data.sales_part', 'inverted_conv_factor', 'COMPOSANT')::numeric as inverted_conv_factor,
        public.get_default_value('clean_data.sales_part', 'list_price', 'COMPOSANT')::numeric as list_price,
        public.get_default_value('clean_data.sales_part', 'list_price_incl_tax', 'COMPOSANT')::numeric as list_price_incl_tax,
        public.get_default_value('clean_data.sales_part', 'non_inv_part_type', 'COMPOSANT') as non_inv_part_type,
        public.get_default_value('clean_data.sales_part', 'non_inv_part_type_db', 'COMPOSANT') as non_inv_part_type_db,
        public.get_default_value('clean_data.sales_part', 'pack_comp_in_shpmnt', 'COMPOSANT') as pack_comp_in_shpmnt,
        public.get_default_value('clean_data.sales_part', 'price_conv_factor', 'COMPOSANT')::numeric as price_conv_factor,
        public.get_default_value('clean_data.sales_part', 'primary_catalog', 'COMPOSANT') as primary_catalog,
        public.get_default_value('clean_data.sales_part', 'primary_catalog_db', 'COMPOSANT') as primary_catalog_db,
        public.get_default_value('clean_data.sales_part', 'quick_registered_part', 'COMPOSANT') as quick_registered_part,
        public.get_default_value('clean_data.sales_part', 'quick_registered_part_db', 'COMPOSANT') as quick_registered_part_db,
        public.get_default_value('clean_data.sales_part', 'rental_list_price', 'COMPOSANT')::numeric as rental_list_price,
        public.get_default_value('clean_data.sales_part', 'rental_list_price_incl_tax', 'COMPOSANT')::numeric as rental_list_price_incl_tax,
        public.get_default_value('clean_data.sales_part', 'sales_price_group_id', 'COMPOSANT') as sales_price_group_id,
        public.get_default_value('clean_data.sales_part', 'sales_type', 'COMPOSANT') as sales_type,
        public.get_default_value('clean_data.sales_part', 'sales_type_db', 'COMPOSANT') as sales_type_db,
        public.get_default_value('clean_data.sales_part', 'sourcing_option', 'COMPOSANT') as sourcing_option,
        public.get_default_value('clean_data.sales_part', 'sourcing_option_db', 'COMPOSANT') as sourcing_option_db,
        public.get_default_value('clean_data.sales_part', 'tax_code', 'COMPOSANT') as tax_code,
        public.get_default_value('clean_data.sales_part', 'taxable', 'COMPOSANT') as taxable,
        public.get_default_value('clean_data.sales_part', 'taxable_db', 'COMPOSANT') as taxable_db,
        public.get_default_value('clean_data.sales_part', 'use_price_incl_tax', 'COMPOSANT') as use_price_incl_tax,
        public.get_default_value('clean_data.sales_part', 'use_price_incl_tax_db', 'COMPOSANT') as use_price_incl_tax_db
    FROM raw_data.composant_sj_cs cmp
    WHERE cmp.code_produit IS NOT NULL
      AND TRIM(cmp.code_produit) != ''
      -- Seules les lignes du site charge
      AND UPPER(TRIM(COALESCE(cmp.site, ''))) = p_contract
      -- L'article doit exister dans part_catalog (table de base)
      AND EXISTS (
          SELECT 1 FROM clean_data.part_catalog pc
          WHERE pc.part_no = SUBSTRING(TRIM(cmp.code_produit), 1, 25)
      )
      -- Ne pas dupliquer une ligne (contract, catalog_no) deja presente
      AND NOT EXISTS (
          SELECT 1 FROM clean_data.sales_part sp
          WHERE sp.contract = p_contract
            AND sp.catalog_no = SUBSTRING(TRIM(cmp.code_produit), 1, 25)
      )
    ORDER BY TRIM(cmp.code_produit);
    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;
    -- Re-execution idempotente : realignement des lignes deja presentes sur le
    -- gabarit (date_entered exclue : elle daterait de la re-execution).
    WITH src AS (
        SELECT DISTINCT ON (TRIM(cmp.code_produit))
            SUBSTRING(TRIM(cmp.code_produit), 1, 25) as catalog_no,
            SUBSTRING(TRIM(COALESCE(NULLIF(TRIM(cmp.libelle_produit), ''), cmp.code_produit)), 1, 200) as catalog_desc,
            SUBSTRING(COALESCE(
                public.get_transcodification('UOM', NULLIF(TRIM(cmp.unite), '')),
                public.get_transcodification('UOM', NULLIF(UPPER(TRIM(cmp.unite)), '')),
                NULLIF(TRIM(cmp.unite), ''),
                'PCE'
            ), 1, 10) as sales_unit_meas,
            SUBSTRING(COALESCE(
                public.get_transcodification('UOM', NULLIF(TRIM(cmp.unite), '')),
                public.get_transcodification('UOM', NULLIF(UPPER(TRIM(cmp.unite)), '')),
                NULLIF(TRIM(cmp.unite), ''),
                'PCE'
            ), 1, 10) as price_unit_meas,
            public.get_default_value('clean_data.sales_part', 'activeind', 'COMPOSANT') as activeind,
            public.get_default_value('clean_data.sales_part', 'activeind_db', 'COMPOSANT') as activeind_db,
            public.get_default_value('clean_data.sales_part', 'allow_inc_pkg_rsrv_picklst', 'COMPOSANT') as allow_inc_pkg_rsrv_picklst,
            public.get_default_value('clean_data.sales_part', 'allow_incomp_pkg_delivery', 'COMPOSANT') as allow_incomp_pkg_delivery,
            public.get_default_value('clean_data.sales_part', 'catalog_group', 'COMPOSANT') as catalog_group,
            public.get_default_value('clean_data.sales_part', 'catalog_type', 'COMPOSANT') as catalog_type,
            public.get_default_value('clean_data.sales_part', 'catalog_type_db', 'COMPOSANT') as catalog_type_db,
            public.get_default_value('clean_data.sales_part', 'close_tolerance', 'COMPOSANT')::numeric as close_tolerance,
            public.get_default_value('clean_data.sales_part', 'conv_factor', 'COMPOSANT')::numeric as conv_factor,
            public.get_default_value('clean_data.sales_part', 'country_of_origin', 'COMPOSANT') as country_of_origin,
            public.get_default_value('clean_data.sales_part', 'create_sm_object_option', 'COMPOSANT') as create_sm_object_option,
            public.get_default_value('clean_data.sales_part', 'create_sm_object_option_db', 'COMPOSANT') as create_sm_object_option_db,
            public.get_default_value('clean_data.sales_part', 'export_to_external_app', 'COMPOSANT') as export_to_external_app,
            public.get_default_value('clean_data.sales_part', 'export_to_external_app_db', 'COMPOSANT') as export_to_external_app_db,
            public.get_default_value('clean_data.sales_part', 'inverted_conv_factor', 'COMPOSANT')::numeric as inverted_conv_factor,
            public.get_default_value('clean_data.sales_part', 'list_price', 'COMPOSANT')::numeric as list_price,
            public.get_default_value('clean_data.sales_part', 'list_price_incl_tax', 'COMPOSANT')::numeric as list_price_incl_tax,
            public.get_default_value('clean_data.sales_part', 'non_inv_part_type', 'COMPOSANT') as non_inv_part_type,
            public.get_default_value('clean_data.sales_part', 'non_inv_part_type_db', 'COMPOSANT') as non_inv_part_type_db,
            public.get_default_value('clean_data.sales_part', 'pack_comp_in_shpmnt', 'COMPOSANT') as pack_comp_in_shpmnt,
            public.get_default_value('clean_data.sales_part', 'price_conv_factor', 'COMPOSANT')::numeric as price_conv_factor,
            public.get_default_value('clean_data.sales_part', 'primary_catalog', 'COMPOSANT') as primary_catalog,
            public.get_default_value('clean_data.sales_part', 'primary_catalog_db', 'COMPOSANT') as primary_catalog_db,
            public.get_default_value('clean_data.sales_part', 'quick_registered_part', 'COMPOSANT') as quick_registered_part,
            public.get_default_value('clean_data.sales_part', 'quick_registered_part_db', 'COMPOSANT') as quick_registered_part_db,
            public.get_default_value('clean_data.sales_part', 'rental_list_price', 'COMPOSANT')::numeric as rental_list_price,
            public.get_default_value('clean_data.sales_part', 'rental_list_price_incl_tax', 'COMPOSANT')::numeric as rental_list_price_incl_tax,
            public.get_default_value('clean_data.sales_part', 'sales_price_group_id', 'COMPOSANT') as sales_price_group_id,
            public.get_default_value('clean_data.sales_part', 'sales_type', 'COMPOSANT') as sales_type,
            public.get_default_value('clean_data.sales_part', 'sales_type_db', 'COMPOSANT') as sales_type_db,
            public.get_default_value('clean_data.sales_part', 'sourcing_option', 'COMPOSANT') as sourcing_option,
            public.get_default_value('clean_data.sales_part', 'sourcing_option_db', 'COMPOSANT') as sourcing_option_db,
            public.get_default_value('clean_data.sales_part', 'tax_code', 'COMPOSANT') as tax_code,
            public.get_default_value('clean_data.sales_part', 'taxable', 'COMPOSANT') as taxable,
            public.get_default_value('clean_data.sales_part', 'taxable_db', 'COMPOSANT') as taxable_db,
            public.get_default_value('clean_data.sales_part', 'use_price_incl_tax', 'COMPOSANT') as use_price_incl_tax,
            public.get_default_value('clean_data.sales_part', 'use_price_incl_tax_db', 'COMPOSANT') as use_price_incl_tax_db
        FROM raw_data.composant_sj_cs cmp
        WHERE cmp.code_produit IS NOT NULL
          AND TRIM(cmp.code_produit) != ''
          AND UPPER(TRIM(COALESCE(cmp.site, ''))) = p_contract
        ORDER BY TRIM(cmp.code_produit)
    )
    UPDATE clean_data.sales_part sp
    SET catalog_desc = src.catalog_desc,
        sales_unit_meas = src.sales_unit_meas,
        price_unit_meas = src.price_unit_meas,
        activeind = src.activeind,
        activeind_db = src.activeind_db,
        allow_inc_pkg_rsrv_picklst = src.allow_inc_pkg_rsrv_picklst,
        allow_incomp_pkg_delivery = src.allow_incomp_pkg_delivery,
        catalog_group = src.catalog_group,
        catalog_type = src.catalog_type,
        catalog_type_db = src.catalog_type_db,
        close_tolerance = src.close_tolerance,
        conv_factor = src.conv_factor,
        country_of_origin = src.country_of_origin,
        create_sm_object_option = src.create_sm_object_option,
        create_sm_object_option_db = src.create_sm_object_option_db,
        export_to_external_app = src.export_to_external_app,
        export_to_external_app_db = src.export_to_external_app_db,
        inverted_conv_factor = src.inverted_conv_factor,
        list_price = src.list_price,
        list_price_incl_tax = src.list_price_incl_tax,
        non_inv_part_type = src.non_inv_part_type,
        non_inv_part_type_db = src.non_inv_part_type_db,
        pack_comp_in_shpmnt = src.pack_comp_in_shpmnt,
        price_conv_factor = src.price_conv_factor,
        primary_catalog = src.primary_catalog,
        primary_catalog_db = src.primary_catalog_db,
        quick_registered_part = src.quick_registered_part,
        quick_registered_part_db = src.quick_registered_part_db,
        rental_list_price = src.rental_list_price,
        rental_list_price_incl_tax = src.rental_list_price_incl_tax,
        sales_price_group_id = src.sales_price_group_id,
        sales_type = src.sales_type,
        sales_type_db = src.sales_type_db,
        sourcing_option = src.sourcing_option,
        sourcing_option_db = src.sourcing_option_db,
        tax_code = src.tax_code,
        taxable = src.taxable,
        taxable_db = src.taxable_db,
        use_price_incl_tax = src.use_price_incl_tax,
        use_price_incl_tax_db = src.use_price_incl_tax_db
    FROM src
    WHERE sp.contract = p_contract
      AND sp.catalog_no = src.catalog_no
      AND (
           sp.catalog_desc, sp.sales_unit_meas, sp.price_unit_meas, sp.activeind, sp.activeind_db,
           sp.allow_inc_pkg_rsrv_picklst, sp.allow_incomp_pkg_delivery, sp.catalog_group, sp.catalog_type,
           sp.catalog_type_db, sp.close_tolerance, sp.conv_factor, sp.country_of_origin,
           sp.create_sm_object_option, sp.create_sm_object_option_db, sp.export_to_external_app,
           sp.export_to_external_app_db, sp.inverted_conv_factor, sp.list_price, sp.list_price_incl_tax,
           sp.non_inv_part_type, sp.non_inv_part_type_db, sp.pack_comp_in_shpmnt, sp.price_conv_factor,
           sp.primary_catalog, sp.primary_catalog_db, sp.quick_registered_part, sp.quick_registered_part_db,
           sp.rental_list_price, sp.rental_list_price_incl_tax, sp.sales_price_group_id, sp.sales_type,
           sp.sales_type_db, sp.sourcing_option, sp.sourcing_option_db, sp.tax_code, sp.taxable,
           sp.taxable_db, sp.use_price_incl_tax, sp.use_price_incl_tax_db
          ) IS DISTINCT FROM (
           src.catalog_desc, src.sales_unit_meas, src.price_unit_meas, src.activeind, src.activeind_db,
           src.allow_inc_pkg_rsrv_picklst, src.allow_incomp_pkg_delivery, src.catalog_group,
           src.catalog_type, src.catalog_type_db, src.close_tolerance, src.conv_factor,
           src.country_of_origin, src.create_sm_object_option, src.create_sm_object_option_db,
           src.export_to_external_app, src.export_to_external_app_db, src.inverted_conv_factor,
           src.list_price, src.list_price_incl_tax, src.non_inv_part_type, src.non_inv_part_type_db,
           src.pack_comp_in_shpmnt, src.price_conv_factor, src.primary_catalog, src.primary_catalog_db,
           src.quick_registered_part, src.quick_registered_part_db, src.rental_list_price,
           src.rental_list_price_incl_tax, src.sales_price_group_id, src.sales_type, src.sales_type_db,
           src.sourcing_option, src.sourcing_option_db, src.tax_code, src.taxable, src.taxable_db,
           src.use_price_incl_tax, src.use_price_incl_tax_db
          );
    GET DIAGNOSTICS v_count_updated = ROW_COUNT;
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Alimentation SALES_PART (composants) terminee avec succes';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Composants inseres: %', v_count_inserted;
    RAISE NOTICE 'Composants realignes sur le gabarit: %', v_count_updated;
    RAISE NOTICE 'Duree d''execution: %', v_duration;
    RAISE NOTICE '====================================================';
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'ERREUR lors de l''alimentation SALES_PART (composants)';
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'Code d''erreur: %', SQLSTATE;
        RAISE NOTICE 'Message: %', SQLERRM;
        RAISE NOTICE 'Duree avant erreur: %', v_duration;
        RAISE NOTICE '====================================================';
        RAISE;
END;
$function$
;
