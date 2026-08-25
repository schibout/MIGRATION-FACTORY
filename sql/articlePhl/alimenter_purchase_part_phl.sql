CREATE OR REPLACE FUNCTION clean_data.alimenter_purchase_part_phl()
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
    RAISE NOTICE 'Debut de l''alimentation PURCHASE_PART (articles PHL) - %', v_start_time;
    INSERT INTO clean_data.purchase_part (
        contract,
        part_no,
        description,
        eng_attribute,
        note_id,
        qc_code,
        stat_grp,
        close_code,
        close_code_db,
        close_tolerance,
        date_cre,
        inventory_flag,
        inventory_flag_db,
        note_text,
        qc_date,
        default_buy_unit_meas,
        over_delivery_tolerance,
        over_delivery,
        over_delivery_db,
        buyer_code,
        process_type,
        std_name_description,
        standard_pack_size,
        technical_coordinator_id,
        taxable,
        taxable_db,
        dop_pegged_po_update_flag,
        dop_pegged_po_update_flag_db,
        acquisition_type,
        acquisition_type_db,
        action_non_authorized,
        action_non_authorized_db,
        action_authorized,
        action_authorized_db,
        external_resource,
        external_resource_db,
        company,
        statistical_code,
        statistical_code_manuf,
        quality_system_level_id,
        qsl_approval_template,
        qualified_manufacturer,
        qualified_manufacturer_db,
        qmr_approval_template,
        qualified_supplier,
        qualified_supplier_db,
        qsr_approval_template,
        acquisition_origin,
        acquisition_reason_id,
        package_part_flag,
        package_part_flag_db,
        nbs_code,
        objversion,
        objid,
        std_name_id
    )
    SELECT DISTINCT ON (TRIM(phl."N. ARTICLE"))
        'SJ' as contract,
        -- part_no: N. ARTICLE = cle des articles PHL
        SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25) as part_no,
        SUBSTRING(TRIM(COALESCE(NULLIF(phl."DESCRIPTION", ''), phl."DESCRIPTION LANGUE", phl."N. ARTICLE")), 1, 200) as description,
        NULL::text as eng_attribute,
        NULL::numeric as note_id,
        NULL::text as qc_code,
        NULL::text as stat_grp,
        'Automatic' as close_code,
        'Y' as close_code_db,
        0 as close_tolerance,
        NULL::date as date_cre,
        -- PHL = article en stock => inventory_flag Yes/Y
        'Yes' as inventory_flag,
        'Y' as inventory_flag_db,
        NULL::text as note_text,
        NULL::date as qc_date,
        -- DEFAULT_BUY_UNIT_MEAS: U/M PHL via transcodification UOM (SAP->IFS)
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(TRIM(phl."U/M"), '')),
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(phl."U/M")), '')),
            NULLIF(TRIM(phl."U/M"), ''),
            'PCE'
        ), 1, 10) as default_buy_unit_meas,
        0 as over_delivery_tolerance,
        'Yes' as over_delivery,
        'YES' as over_delivery_db,
        NULL::text as buyer_code,
        'STD' as process_type,
        NULL::text as std_name_description,
        1 as standard_pack_size,
        NULL::text as technical_coordinator_id,
        'Yes' as taxable,
        'TRUE' as taxable_db,
        'Planned' as dop_pegged_po_update_flag,
        'PLANNED' as dop_pegged_po_update_flag_db,
        'Purchase' as acquisition_type,
        'PURCHASE' as acquisition_type_db,
        'Warning' as action_non_authorized,
        'WARNING' as action_non_authorized_db,
        'Warning' as action_authorized,
        'WARNING' as action_authorized_db,
        'No' as external_resource,
        'FALSE' as external_resource_db,
        'TRIMET' as company,
        NULL::text as statistical_code,
        NULL::text as statistical_code_manuf,
        NULL::text as quality_system_level_id,
        NULL::text as qsl_approval_template,
        'No' as qualified_manufacturer,
        'FALSE' as qualified_manufacturer_db,
        NULL::text as qmr_approval_template,
        'No' as qualified_supplier,
        'FALSE' as qualified_supplier_db,
        NULL::text as qsr_approval_template,
        NULL::numeric as acquisition_origin,
        NULL::text as acquisition_reason_id,
        'No' as package_part_flag,
        'FALSE' as package_part_flag_db,
        NULL::text as nbs_code,
        NULL::text as objversion,
        NULL::text as objid,
        NULL::text as std_name_id
    -- Source dedoublonnee (cf. v_phl_article_retenu.sql)
    FROM raw_data.v_phl_article_retenu phl
    WHERE phl."N. ARTICLE" IS NOT NULL
      AND TRIM(phl."N. ARTICLE") != ''
      -- Exclure les articles de production : produits finis (STATUT=F) et intermediaires (STATUT=I)
      -- (purchase_part = articles ACHETES, pas fabriques en interne)
      AND UPPER(LEFT(TRIM(phl."STATUT"), 1)) NOT IN ('F', 'I')
      -- L'article doit exister dans part_catalog (table de base)
      AND EXISTS (
          SELECT 1 FROM clean_data.part_catalog pc
          WHERE pc.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
      )
      -- Ne pas dupliquer une ligne (contract, part_no) deja presente
      AND NOT EXISTS (
          SELECT 1 FROM clean_data.purchase_part pp
          WHERE pp.contract = 'SJ'
            AND pp.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
      )
    ORDER BY TRIM(phl."N. ARTICLE");
    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Alimentation PURCHASE_PART (PHL) terminee avec succes';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Articles PHL inseres: %', v_count_inserted;
    RAISE NOTICE 'Duree d''execution: %', v_duration;
    RAISE NOTICE '====================================================';
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'ERREUR lors de l''alimentation PURCHASE_PART (PHL)';
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'Code d''erreur: %', SQLSTATE;
        RAISE NOTICE 'Message: %', SQLERRM;
        RAISE NOTICE 'Duree avant erreur: %', v_duration;
        RAISE NOTICE '====================================================';
        RAISE;
END;
$function$
;
