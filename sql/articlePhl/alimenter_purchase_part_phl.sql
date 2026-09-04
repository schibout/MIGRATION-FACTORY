-- L'ancienne signature sans parametre doit disparaitre, sinon PostgreSQL cree une
-- surcharge et les appels sans argument deviennent ambigus.
DROP FUNCTION IF EXISTS clean_data.alimenter_purchase_part_phl();
CREATE OR REPLACE FUNCTION clean_data.alimenter_purchase_part_phl(p_contract text DEFAULT 'SJ')
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
    RAISE NOTICE 'Debut de l''alimentation PURCHASE_PART (articles PHL, site %) - %', p_contract, v_start_time;
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
        p_contract as contract,
        -- part_no: N. ARTICLE = cle des articles PHL
        SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25) as part_no,
        SUBSTRING(TRIM(COALESCE(NULLIF(phl."DESCRIPTION", ''), phl."DESCRIPTION LANGUE", phl."N. ARTICLE")), 1, 200) as description,
        -- Valeurs par defaut parametrables :
        --   1. matrice site x famille  -> /configuration/matrice-site-famille
        --   2. constante par colonne   -> /configuration/valeurs-defaut
        --   3. NULL si rien n'est parametre
        -- (public.get_default_value_ctx, migration 066)
        public.get_default_value_ctx('clean_data.purchase_part', 'eng_attribute', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as eng_attribute,
        public.get_default_value_ctx('clean_data.purchase_part', 'note_id', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as note_id,
        public.get_default_value_ctx('clean_data.purchase_part', 'qc_code', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as qc_code,
        public.get_default_value_ctx('clean_data.purchase_part', 'stat_grp', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as stat_grp,
        public.get_default_value_ctx('clean_data.purchase_part', 'close_code', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as close_code,
        public.get_default_value_ctx('clean_data.purchase_part', 'close_code_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as close_code_db,
        public.get_default_value_ctx('clean_data.purchase_part', 'close_tolerance', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as close_tolerance,
        public.get_default_value_ctx('clean_data.purchase_part', 'date_cre', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::date as date_cre,
        -- PHL = article en stock => inventory_flag Yes/Y
        public.get_default_value_ctx('clean_data.purchase_part', 'inventory_flag', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as inventory_flag,
        public.get_default_value_ctx('clean_data.purchase_part', 'inventory_flag_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as inventory_flag_db,
        public.get_default_value_ctx('clean_data.purchase_part', 'note_text', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as note_text,
        public.get_default_value_ctx('clean_data.purchase_part', 'qc_date', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::date as qc_date,
        -- DEFAULT_BUY_UNIT_MEAS: U/M PHL via transcodification UOM (SAP->IFS)
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(TRIM(phl."U/M"), '')),
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(phl."U/M")), '')),
            NULLIF(TRIM(phl."U/M"), ''),
            'PCE'
        ), 1, 10) as default_buy_unit_meas,
        public.get_default_value_ctx('clean_data.purchase_part', 'over_delivery_tolerance', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as over_delivery_tolerance,
        public.get_default_value_ctx('clean_data.purchase_part', 'over_delivery', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as over_delivery,
        public.get_default_value_ctx('clean_data.purchase_part', 'over_delivery_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as over_delivery_db,
        public.get_default_value_ctx('clean_data.purchase_part', 'buyer_code', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as buyer_code,
        public.get_default_value_ctx('clean_data.purchase_part', 'process_type', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as process_type,
        public.get_default_value_ctx('clean_data.purchase_part', 'std_name_description', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as std_name_description,
        public.get_default_value_ctx('clean_data.purchase_part', 'standard_pack_size', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as standard_pack_size,
        public.get_default_value_ctx('clean_data.purchase_part', 'technical_coordinator_id', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as technical_coordinator_id,
        public.get_default_value_ctx('clean_data.purchase_part', 'taxable', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as taxable,
        public.get_default_value_ctx('clean_data.purchase_part', 'taxable_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as taxable_db,
        public.get_default_value_ctx('clean_data.purchase_part', 'dop_pegged_po_update_flag', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as dop_pegged_po_update_flag,
        public.get_default_value_ctx('clean_data.purchase_part', 'dop_pegged_po_update_flag_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as dop_pegged_po_update_flag_db,
        public.get_default_value_ctx('clean_data.purchase_part', 'acquisition_type', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as acquisition_type,
        public.get_default_value_ctx('clean_data.purchase_part', 'acquisition_type_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as acquisition_type_db,
        public.get_default_value_ctx('clean_data.purchase_part', 'action_non_authorized', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as action_non_authorized,
        public.get_default_value_ctx('clean_data.purchase_part', 'action_non_authorized_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as action_non_authorized_db,
        public.get_default_value_ctx('clean_data.purchase_part', 'action_authorized', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as action_authorized,
        public.get_default_value_ctx('clean_data.purchase_part', 'action_authorized_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as action_authorized_db,
        public.get_default_value_ctx('clean_data.purchase_part', 'external_resource', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as external_resource,
        public.get_default_value_ctx('clean_data.purchase_part', 'external_resource_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as external_resource_db,
        public.get_default_value_ctx('clean_data.purchase_part', 'company', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as company,
        public.get_default_value_ctx('clean_data.purchase_part', 'statistical_code', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as statistical_code,
        public.get_default_value_ctx('clean_data.purchase_part', 'statistical_code_manuf', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as statistical_code_manuf,
        public.get_default_value_ctx('clean_data.purchase_part', 'quality_system_level_id', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as quality_system_level_id,
        public.get_default_value_ctx('clean_data.purchase_part', 'qsl_approval_template', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as qsl_approval_template,
        public.get_default_value_ctx('clean_data.purchase_part', 'qualified_manufacturer', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as qualified_manufacturer,
        public.get_default_value_ctx('clean_data.purchase_part', 'qualified_manufacturer_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as qualified_manufacturer_db,
        public.get_default_value_ctx('clean_data.purchase_part', 'qmr_approval_template', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as qmr_approval_template,
        public.get_default_value_ctx('clean_data.purchase_part', 'qualified_supplier', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as qualified_supplier,
        public.get_default_value_ctx('clean_data.purchase_part', 'qualified_supplier_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as qualified_supplier_db,
        public.get_default_value_ctx('clean_data.purchase_part', 'qsr_approval_template', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as qsr_approval_template,
        public.get_default_value_ctx('clean_data.purchase_part', 'acquisition_origin', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as acquisition_origin,
        public.get_default_value_ctx('clean_data.purchase_part', 'acquisition_reason_id', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as acquisition_reason_id,
        public.get_default_value_ctx('clean_data.purchase_part', 'package_part_flag', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as package_part_flag,
        public.get_default_value_ctx('clean_data.purchase_part', 'package_part_flag_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as package_part_flag_db,
        public.get_default_value_ctx('clean_data.purchase_part', 'nbs_code', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as nbs_code,
        public.get_default_value_ctx('clean_data.purchase_part', 'objversion', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as objversion,
        public.get_default_value_ctx('clean_data.purchase_part', 'objid', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as objid,
        public.get_default_value_ctx('clean_data.purchase_part', 'std_name_id', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as std_name_id
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
          WHERE pp.contract = p_contract
            AND pp.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
      )
      -- Routage de creation site x famille (/configuration/matrice-site-famille).
      -- Aucune ligne de matrice pour ce couple -> creation autorisee (COALESCE TRUE),
      -- donc comportement inchange tant que la matrice n'est pas renseignee.
      AND COALESCE(public.get_part_type_matrix('clean_data.purchase_part', p_contract,
                                               NULLIF(TRIM(phl."FAMILLE"), '')), TRUE)
    ORDER BY TRIM(phl."N. ARTICLE");
    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;

    -- Symetrique du garde ci-dessus : une famille passee a "ne pas creer" doit
    -- voir ses lignes disparaitre au prochain chargement. La table n'est jamais
    -- videe (insertion en APPEND), sans cette purge le flag serait sans effet
    -- sur les articles deja charges. Perimetre strict : articles PHL du site.
    DELETE FROM clean_data.purchase_part pp
    USING raw_data.v_phl_article_retenu phl
    WHERE pp.contract = p_contract
      AND pp.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
      AND public.get_part_type_matrix('clean_data.purchase_part', p_contract,
                                      NULLIF(TRIM(phl."FAMILLE"), '')) IS FALSE;
    GET DIAGNOSTICS v_count_routage_supprime = ROW_COUNT;
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Alimentation PURCHASE_PART (PHL) terminee avec succes';
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
