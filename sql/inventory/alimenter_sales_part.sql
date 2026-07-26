CREATE OR REPLACE FUNCTION clean_data.alimenter_sales_part()
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
    
    RAISE NOTICE 'Début de l''alimentation des articles de vente (SALES_PART) - %', v_start_time;
    
    -- Vider la table cible avant insertion (si elle existe)
    BEGIN
        TRUNCATE TABLE clean_data.sales_part RESTART IDENTITY;
        RAISE NOTICE 'Table sales_part vidée';
    EXCEPTION
        WHEN undefined_table THEN
            RAISE NOTICE 'Table sales_part n''existe pas encore';
    END;
    
    -- Insertion des articles de vente depuis SAP
    INSERT INTO clean_data.sales_part (
        -- Clés primaires
        contract,
        catalog_no,
        
        -- Données de base (obligatoires)
        catalog_desc,
        sales_unit_meas,
        catalog_group,
        sales_price_group_id,
        
        -- Article lié
        part_no,
        
        -- Flags et statuts (_DB uniquement)
        activeind_db,
        catalog_type_db,
        
        -- Facteurs de conversion
        conv_factor,
        inverted_conv_factor,
        price_conv_factor,
        price_unit_meas,
        
        -- Prix
        list_price,
        list_price_incl_tax,
        rental_list_price,
        rental_list_price_incl_tax,
        cost,
        expected_average_price,
        
        -- Taxes (_DB uniquement)
        taxable_db,
        tax_code,
        tax_class_id,
        use_price_incl_tax_db,
        
        -- Dates
        date_entered,
        price_change_date,
        
        -- Tolérances et quantités
        close_tolerance,
        minimum_qty,
        
        -- Options d'approvisionnement (_DB uniquement)
        sourcing_option_db,
        
        -- Options de création (_DB uniquement)
        create_sm_object_option_db,
        quick_registered_part_db,
        
        -- Exports et options avancées (_DB uniquement)
        export_to_external_app_db,
        allow_inc_pkg_rsrv_picklst,
        allow_incomp_pkg_delivery,
        pack_comp_in_shpmnt,
        
        -- Type de vente (_DB uniquement)
        sales_type_db,
        
        -- Article principal (_DB uniquement)
        primary_catalog_db,
        
        -- Infos diverses
        delivery_type,
        non_inv_part_type_db,
        customs_stat_no,
        country_of_origin,
        statistical_code
    )
    SELECT DISTINCT
        -- Clés primaires
        CASE
            WHEN marc.werks = '9200' THEN 'SJ'
            WHEN marc.werks = '9100' THEN 'CS'
            ELSE 'SJ'
        END as contract,
        SUBSTRING(LTRIM(mara.matnr, '0'), 1, 25) as catalog_no,
        
        -- Données de base
        SUBSTRING(COALESCE(makt.maktx, mara.matnr), 1, 200) as catalog_desc,
        -- SALES_UNIT_MEAS: MVKE.VRKME sinon MARA.MEINS via transcodification UOM (SAP->IFS), sinon unité d'entrée
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(COALESCE(NULLIF(mvke.vrkme, ''), mara.meins))), '')),
            UPPER(TRIM(COALESCE(NULLIF(mvke.vrkme, ''), mara.meins)))
        ), 1, 10) as sales_unit_meas,
        '903028' as catalog_group,
        '*' as sales_price_group_id,
        
        -- Article lié (pour Inventory part)
        CASE 
            WHEN mara.mtart IN ('FERT', 'HALB', 'ROH') 
            THEN SUBSTRING(LTRIM(mara.matnr, '0'), 1, 25)
            ELSE NULL
        END as part_no,
        
        -- Flags et statuts (_DB uniquement) : tous les articles actifs
        'Y' as activeind_db,
        CASE 
            WHEN mara.mtart IN ('FERT', 'HALB', 'ROH') THEN 'INV'
            ELSE 'NON'
        END as catalog_type_db,
        
        -- Facteurs de conversion
        1 as conv_factor,
        1 as inverted_conv_factor,
        1 as price_conv_factor,
        -- PRICE_UNIT_MEAS: MVKE.VRKME sinon MARA.MEINS via transcodification UOM (SAP->IFS), sinon unité d'entrée
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(COALESCE(NULLIF(mvke.vrkme, ''), mara.meins))), '')),
            UPPER(TRIM(COALESCE(NULLIF(mvke.vrkme, ''), mara.meins)))
        ), 1, 10) as price_unit_meas,
        
        -- Prix (par défaut à 0)
        0 as list_price,
        0 as list_price_incl_tax,
        0 as rental_list_price,
        0 as rental_list_price_incl_tax,
        NULL::numeric as cost,
        NULL::numeric as expected_average_price,
        
        -- Taxes (_DB uniquement)
        'TRUE' as taxable_db,
        'C05' as tax_code,
        NULL as tax_class_id,
        'FALSE' as use_price_incl_tax_db,
        
        -- Dates
        CASE 
            WHEN mara.ersda IS NOT NULL AND mara.ersda ~ '^\d{8}$' 
            THEN TO_TIMESTAMP(mara.ersda, 'YYYYMMDD')
            ELSE CURRENT_TIMESTAMP
        END as date_entered,
        NULL::timestamp as price_change_date,
        
        -- Tolérances et quantités
        0 as close_tolerance,
        NULL::numeric as minimum_qty,
        
        -- Options d'approvisionnement (_DB uniquement)
        'NOTSUPPLIED' as sourcing_option_db,
        
        -- Options de création (_DB uniquement)
        'DONOTCREATESMOBJECT' as create_sm_object_option_db,
        'FALSE' as quick_registered_part_db,
        
        -- Exports et options avancées (_DB uniquement)
        'FALSE' as export_to_external_app_db,
        'TRUE' as allow_inc_pkg_rsrv_picklst,
        'TRUE' as allow_incomp_pkg_delivery,
        'FALSE' as pack_comp_in_shpmnt,
        
        -- Type de vente (_DB uniquement)
        'SALES' as sales_type_db,
        
        -- Article principal (_DB uniquement)
        'TRUE' as primary_catalog_db,
        
        -- Infos diverses
        NULL as delivery_type,
        CASE 
            WHEN mara.mtart NOT IN ('FERT', 'HALB', 'ROH') THEN 'GOODS'
            ELSE NULL
        END as non_inv_part_type_db,
        mara.extwg as customs_stat_no,
        'FR' as country_of_origin,
        NULL as statistical_code
        
    FROM raw_data.mara mara
    INNER JOIN raw_data.articles_vente_sap avs
        ON LPAD(avs.article, 18, '0') = mara.matnr
    INNER JOIN raw_data.makt makt
        ON mara.matnr = makt.matnr
        AND makt.spras = 'F'
    LEFT JOIN raw_data.mvke mvke
        ON mvke.matnr = mara.matnr
        AND mvke.mandt = '700'
        AND mvke.vkorg = '0001'
        AND mvke.vtweg = '01'
    LEFT JOIN raw_data.marc marc
        ON mara.matnr = marc.matnr
        AND marc.werks IN ('9200', '9100')

    WHERE
        mara.lvorm IS NULL
        AND TRIM(mara.matnr) != ''
        AND mara.mtart IN ('FERT', 'HALB', 'DIEN', 'NLAG', 'HIBE', 'ERSA')
        -- Garantir que l'article (catalog_no) existe dans part_catalog (table de base) avant insertion
        AND EXISTS (
            SELECT 1 FROM clean_data.part_catalog pc
            WHERE pc.part_no = SUBSTRING(LTRIM(mara.matnr, '0'), 1, 25)
        )

    ORDER BY catalog_no;
    
    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;
    
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;
    
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Alimentation SALES_PART terminée avec succès';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Articles de vente insérés: %', v_count_inserted;
    RAISE NOTICE 'Durée d''exécution: %', v_duration;
    RAISE NOTICE 'Début: %, Fin: %', v_start_time, v_end_time;
    RAISE NOTICE '====================================================';
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;
        
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'ERREUR lors de l''alimentation SALES_PART';
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'Code d''erreur: %', SQLSTATE;
        RAISE NOTICE 'Message: %', SQLERRM;
        RAISE NOTICE 'Durée avant erreur: %', v_duration;
        RAISE NOTICE '====================================================';
        
        RAISE;
END;
$function$;

COMMENT ON FUNCTION clean_data.alimenter_sales_part() IS 
'Alimente SALES_PART depuis SAP (MVKE, MARA, MAKT, MARC).
IMPORTANT: Seules les colonnes _DB sont renseignées, les colonnes sans _DB sont auto-calculées par IFS.
Exemples: activeind_db=Y (activeind calculé auto), catalog_type_db=INV (catalog_type calculé auto)';