CREATE OR REPLACE FUNCTION clean_data.alimenter_purchase_part()
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
    RAISE NOTICE 'Début de l''alimentation des articles achat (PURCHASE_PART) - %', v_start_time;
    -- Vider la table cible avant insertion
    TRUNCATE TABLE clean_data.purchase_part RESTART IDENTITY;
    RAISE NOTICE 'Table purchase_part vidée';
    -- Insertion des articles achat depuis SAP
    INSERT INTO clean_data.purchase_part (
        -- Clés
        contract,
        part_no,
        -- Données de base
        description,
        eng_attribute,
        note_id,
        qc_code,
        stat_grp,
        -- Close
        close_code,
        close_code_db,
        close_tolerance,
        -- Dates
        date_cre,
        -- Inventory flag
        inventory_flag,
        inventory_flag_db,
        -- Notes & QC
        note_text,
        qc_date,
        -- Achat
        default_buy_unit_meas,
        over_delivery_tolerance,
        over_delivery,
        over_delivery_db,
        buyer_code,
        process_type,
        std_name_description,
        standard_pack_size,
        technical_coordinator_id,
        -- Taxable
        taxable,
        taxable_db,
        -- DOP pegged
        dop_pegged_po_update_flag,
        dop_pegged_po_update_flag_db,
        -- Acquisition
        acquisition_type,
        acquisition_type_db,
        -- Actions
        action_non_authorized,
        action_non_authorized_db,
        action_authorized,
        action_authorized_db,
        -- External resource
        external_resource,
        external_resource_db,
        -- Société et codes statistiques
        company,
        statistical_code,
        statistical_code_manuf,
        -- Qualité
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
    SELECT DISTINCT
        -- CONTRACT: 9200 = SJ, 9000 = CS
        CASE
            WHEN marc.werks = '9200' THEN 'SJ'
            WHEN marc.werks = '9000' THEN 'CS'
            ELSE 'SJ'
        END as contract,
        -- PART_NO: numero_article SAP (pas de transcodification, l'article garde son ID)
        SUBSTRING(TRIM(LTRIM(ifs.numero_article, '0')), 1, 25) as part_no,
        -- DESCRIPTION: MAKT.MAKTX (FR) sinon MARA.MATNR
        SUBSTRING(COALESCE(makt.maktx, mara.matnr), 1, 200) as description,
        -- ENG_ATTRIBUTE: vide
        NULL::text as eng_attribute,
        -- NOTE_ID: vide (numeric)
        NULL::numeric as note_id,
        -- QC_CODE: vide
        NULL::text as qc_code,
        -- STAT_GRP: vide
        NULL::text as stat_grp,
        -- CLOSE_CODE: Automatic (libellé IFS de Y)
        'Automatic' as close_code,
        -- CLOSE_CODE_DB: Y
        'Y' as close_code_db,
        -- CLOSE_TOLERANCE: 0
        0 as close_tolerance,
        -- DATE_CRE: MARA.ERSDA (date création article SAP)
        CASE
            WHEN mara.ersda IS NOT NULL AND mara.ersda <> '' THEN TO_DATE(mara.ersda, 'YYYYMMDD')
            ELSE NULL
        END as date_cre,
        -- INVENTORY_FLAG / _DB: si type IBAU/DIEN/NLAG => N (No), sinon Y (Yes)
        CASE
            WHEN mara.mtart IN ('IBAU', 'DIEN', 'NLAG') THEN 'No'
            ELSE 'Yes'
        END as inventory_flag,
        CASE
            WHEN mara.mtart IN ('IBAU', 'DIEN', 'NLAG') THEN 'N'
            ELSE 'Y'
        END as inventory_flag_db,
        -- NOTE_TEXT: vide
        NULL::text as note_text,
        -- QC_DATE: vide
        NULL::date as qc_date,
        -- DEFAULT_BUY_UNIT_MEAS: MARA.BSTME sinon MEINS via transcodification UOM (SAP->IFS), sinon unité d'entrée
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(COALESCE(NULLIF(mara.bstme, ''), mara.meins))), '')),
            UPPER(TRIM(COALESCE(NULLIF(mara.bstme, ''), mara.meins)))
        ), 1, 10) as default_buy_unit_meas,
        -- OVER_DELIVERY_TOLERANCE: 0
        0 as over_delivery_tolerance,
        -- OVER_DELIVERY / _DB: Yes / YES
        'Yes' as over_delivery,
        'YES' as over_delivery_db,
        -- BUYER_CODE: vide
        NULL::text as buyer_code,
        -- PROCESS_TYPE: STD
        'STD' as process_type,
        -- STD_NAME_DESCRIPTION: vide
        NULL::text as std_name_description,
        -- STANDARD_PACK_SIZE: 1
        1 as standard_pack_size,
        -- TECHNICAL_COORDINATOR_ID: vide
        NULL::text as technical_coordinator_id,
        -- TAXABLE / _DB: Yes / TRUE
        'Yes' as taxable,
        'TRUE' as taxable_db,
        -- DOP_PEGGED_PO_UPDATE_FLAG / _DB: Planned / PLANNED
        'Planned' as dop_pegged_po_update_flag,
        'PLANNED' as dop_pegged_po_update_flag_db,
        -- ACQUISITION_TYPE / _DB: Purchase / PURCHASE
        'Purchase' as acquisition_type,
        'PURCHASE' as acquisition_type_db,
        -- ACTION_NON_AUTHORIZED / _DB: Warning / WARNING
        'Warning' as action_non_authorized,
        'WARNING' as action_non_authorized_db,
        -- ACTION_AUTHORIZED / _DB: Warning / WARNING
        'Warning' as action_authorized,
        'WARNING' as action_authorized_db,
        -- EXTERNAL_RESOURCE / _DB: DIEN => Yes/TRUE sinon No/FALSE
        CASE WHEN mara.mtart = 'DIEN' THEN 'Yes' ELSE 'No' END as external_resource,
        CASE WHEN mara.mtart = 'DIEN' THEN 'TRUE' ELSE 'FALSE' END as external_resource_db,
        -- COMPANY: TRIMET
        'TRIMET' as company,
        -- STATISTICAL_CODE / STATISTICAL_CODE_MANUF: vide
        NULL::text as statistical_code,
        NULL::text as statistical_code_manuf,
        -- QUALITY_SYSTEM_LEVEL_ID / QSL_APPROVAL_TEMPLATE: vide
        NULL::text as quality_system_level_id,
        NULL::text as qsl_approval_template,
        -- QUALIFIED_MANUFACTURER / _DB: No / FALSE
        'No' as qualified_manufacturer,
        'FALSE' as qualified_manufacturer_db,
        -- QMR_APPROVAL_TEMPLATE: vide
        NULL::text as qmr_approval_template,
        -- QUALIFIED_SUPPLIER / _DB: No / FALSE
        'No' as qualified_supplier,
        'FALSE' as qualified_supplier_db,
        -- QSR_APPROVAL_TEMPLATE: vide
        NULL::text as qsr_approval_template,
        -- ACQUISITION_ORIGIN: vide
        NULL::numeric as acquisition_origin,
        -- ACQUISITION_REASON_ID: vide
        NULL::text as acquisition_reason_id,
        -- PACKAGE_PART_FLAG / _DB: No / FALSE
        'No' as package_part_flag,
        'FALSE' as package_part_flag_db,
        -- NBS_CODE: vide
        NULL::text as nbs_code,
        -- OBJVERSION: vide (généré par IFS)
        NULL::text as objversion,
        -- OBJID: vide (généré par IFS)
        NULL::text as objid,
        -- STD_NAME_ID: vide
        NULL::text as std_name_id
    FROM clean_data.ifs_article_maitre ifs
    INNER JOIN raw_data.mara mara
        ON mara.matnr::text = ifs.numero_article
        AND mara.mandt = '700'
    INNER JOIN raw_data.makt makt
        ON mara.matnr = makt.matnr
        AND makt.mandt = '700'
        AND makt.spras = 'F'
    INNER JOIN raw_data.marc marc
        ON mara.matnr = marc.matnr
        AND marc.mandt = '700'
    WHERE
        marc.werks IN ('9200', '9000', '2200')
        AND marc.beskz IN ('F', 'X')
        AND mara.lvorm IS NULL
        AND TRIM(mara.matnr) != ''
        -- Garantir que l'article existe dans part_catalog (table de base) avant insertion
        AND EXISTS (
            SELECT 1 FROM clean_data.part_catalog pc
            WHERE pc.part_no = SUBSTRING(TRIM(LTRIM(ifs.numero_article, '0')), 1, 25)
        )
    ORDER BY contract, part_no;
    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Alimentation PURCHASE_PART terminée avec succès';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Articles achat insérés: %', v_count_inserted;
    RAISE NOTICE 'Durée d''exécution: %', v_duration;
    RAISE NOTICE '====================================================';
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'ERREUR lors de l''alimentation PURCHASE_PART';
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'Code d''erreur: %', SQLSTATE;
        RAISE NOTICE 'Message: %', SQLERRM;
        RAISE NOTICE 'Durée avant erreur: %', v_duration;
        RAISE NOTICE '====================================================';
        RAISE;
END;
$function$
;
