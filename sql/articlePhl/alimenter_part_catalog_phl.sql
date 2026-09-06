-- L'ancienne signature sans parametre doit disparaitre, sinon PostgreSQL cree une
-- surcharge et les appels sans argument deviennent ambigus.
DROP FUNCTION IF EXISTS clean_data.alimenter_part_catalog_phl();
CREATE OR REPLACE FUNCTION clean_data.alimenter_part_catalog_phl(p_contract text DEFAULT 'SJ')
 RETURNS void
 LANGUAGE plpgsql
AS $function$
-- part_catalog n'a pas de site : l'article est insere une seule fois quel que soit
-- le site charge (garde NOT EXISTS). p_contract influe toutefois sur le suivi par
-- lot : sur Castel TOUS les articles sont suivis par lot, alors que sur Saint-Jean
-- les rebuts (FORME contient REBUT) ne le sont pas.
DECLARE
    v_count_inserted INTEGER := 0;
    v_count_rebut_updated INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL;
BEGIN
    IF p_contract NOT IN ('SJ', 'CS') THEN
        RAISE EXCEPTION 'Site invalide: % (attendu: SJ ou CS)', p_contract;
    END IF;
    v_start_time := CURRENT_TIMESTAMP;
    RAISE NOTICE 'Debut de l''alimentation PART_CATALOG (articles PHL) - %', v_start_time;
    INSERT INTO clean_data.part_catalog (
        part_no,
        description,
        unit_code,
        lot_tracking_code_db,
        serial_rule_db,
        serial_tracking_code_db,
        eng_serial_tracking_code_db,
        configurable_db,
        condition_code_usage_db,
        sub_lot_rule_db,
        lot_quantity_rule_db,
        position_part_db,
        catch_unit_enabled_db,
        multilevel_tracking_db,
        component_lot_rule_db,
        stop_arrival_issued_serial_db,
        allow_as_not_consumed_db,
        receipt_issue_serial_track_db,
        stop_new_serial_in_rma_db,
        std_name_id,
        language_description,
        info_text,
        lot_tracking_code,
        serial_rule,
        serial_tracking_code,
        eng_serial_tracking_code,
        configurable,
        condition_code_usage,
        sub_lot_rule,
        position_part,
        catch_unit_enabled,
        multilevel_tracking,
        component_lot_rule,
        stop_arrival_issued_serial,
        allow_as_not_consumed,
        receipt_issue_serial_track,
        stop_new_serial_in_rma,
        product_type_classif,
        part_main_group,
        cust_warranty_id,
        sup_warranty_id,
        input_unit_meas_group_id,
        weight_net,
        uom_for_weight_net,
        volume_net,
        uom_for_volume_net,
        freight_factor,
        technical_drawing_no,
        product_type_classif_db,
        cest_code,
        fci_code
    )
    SELECT DISTINCT ON (TRIM(phl."N. ARTICLE"))
        -- part_no: N. ARTICLE = cle des articles PHL
        SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25) as part_no,
        SUBSTRING(TRIM(COALESCE(NULLIF(phl."DESCRIPTION", ''), phl."DESCRIPTION LANGUE", phl."N. ARTICLE")), 1, 200) as description,
        -- unit_code: U/M via transcodification UOM (SAP->IFS), sinon unite d'entree
        -- (meme logique que clean_data.alimenter_part_catalog())
        CASE
            WHEN LOWER(TRIM(COALESCE(phl."U/M", ''))) = 't' THEN 'kg'
            ELSE SUBSTRING(COALESCE(
                public.get_transcodification('UOM', NULLIF(TRIM(phl."U/M"), ''), 'PHL', 'IFS'),
                public.get_transcodification('UOM', NULLIF(UPPER(TRIM(phl."U/M")), ''), 'PHL', 'IFS'),
                public.get_transcodification('UOM', NULLIF(TRIM(phl."U/M"), '')),
                public.get_transcodification('UOM', NULLIF(UPPER(TRIM(phl."U/M")), '')),
                NULLIF(TRIM(phl."U/M"), ''),
                'PCE'
            ), 1, 30)
        END as unit_code,
        -- Valeurs _db pour les articles PHL (type I et F)
        -- Suivi par lot : sur le site Castel TOUS les articles sont suivis par lot
        -- (regle metier), y compris les rebuts. Sur Saint-Jean, les articles de type
        -- rebut (FORME contient REBUT) ne le sont pas.
        -- Valeurs par defaut : matrice site x famille SEULE
        -- (/configuration/matrice-site-famille, public.get_matrix_value)
        CASE
            WHEN p_contract = 'CS'
                THEN public.get_matrix_value('clean_data.part_catalog', 'lot_tracking_code_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))
            WHEN UPPER(COALESCE(phl."FORME", '')) LIKE '%REBUT%' THEN 'NOT LOT TRACKING'
            ELSE public.get_matrix_value('clean_data.part_catalog', 'lot_tracking_code_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))
        END as lot_tracking_code_db,
        public.get_matrix_value('clean_data.part_catalog', 'serial_rule_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as serial_rule_db,
        public.get_matrix_value('clean_data.part_catalog', 'serial_tracking_code_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as serial_tracking_code_db,
        public.get_matrix_value('clean_data.part_catalog', 'eng_serial_tracking_code_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as eng_serial_tracking_code_db,
        public.get_matrix_value('clean_data.part_catalog', 'configurable_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as configurable_db,
        public.get_matrix_value('clean_data.part_catalog', 'condition_code_usage_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as condition_code_usage_db,
        public.get_matrix_value('clean_data.part_catalog', 'sub_lot_rule_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as sub_lot_rule_db,
        public.get_matrix_value('clean_data.part_catalog', 'lot_quantity_rule_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as lot_quantity_rule_db,
        public.get_matrix_value('clean_data.part_catalog', 'position_part_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as position_part_db,
        public.get_matrix_value('clean_data.part_catalog', 'catch_unit_enabled_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as catch_unit_enabled_db,
        public.get_matrix_value('clean_data.part_catalog', 'multilevel_tracking_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as multilevel_tracking_db,
        public.get_matrix_value('clean_data.part_catalog', 'component_lot_rule_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as component_lot_rule_db,
        public.get_matrix_value('clean_data.part_catalog', 'stop_arrival_issued_serial_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as stop_arrival_issued_serial_db,
        public.get_matrix_value('clean_data.part_catalog', 'allow_as_not_consumed_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as allow_as_not_consumed_db,
        public.get_matrix_value('clean_data.part_catalog', 'receipt_issue_serial_track_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as receipt_issue_serial_track_db,
        public.get_matrix_value('clean_data.part_catalog', 'stop_new_serial_in_rma_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as stop_new_serial_in_rma_db,
    -- Source dedoublonnee (cf. v_phl_article_retenu.sql)
        -- Colonnes non alimentees par le fichier PHL : valeur pilotee par
        -- l'ecran /configuration/valeurs-defaut (variante ARTICLEPHL).
        NULLIF(public.get_matrix_value('clean_data.part_catalog', 'std_name_id', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as std_name_id,
        public.get_matrix_value('clean_data.part_catalog', 'language_description', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as language_description,
        public.get_matrix_value('clean_data.part_catalog', 'info_text', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as info_text,
        public.get_matrix_value('clean_data.part_catalog', 'lot_tracking_code', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as lot_tracking_code,
        public.get_matrix_value('clean_data.part_catalog', 'serial_rule', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as serial_rule,
        public.get_matrix_value('clean_data.part_catalog', 'serial_tracking_code', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as serial_tracking_code,
        public.get_matrix_value('clean_data.part_catalog', 'eng_serial_tracking_code', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as eng_serial_tracking_code,
        public.get_matrix_value('clean_data.part_catalog', 'configurable', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as configurable,
        public.get_matrix_value('clean_data.part_catalog', 'condition_code_usage', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as condition_code_usage,
        public.get_matrix_value('clean_data.part_catalog', 'sub_lot_rule', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as sub_lot_rule,
        public.get_matrix_value('clean_data.part_catalog', 'position_part', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as position_part,
        public.get_matrix_value('clean_data.part_catalog', 'catch_unit_enabled', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as catch_unit_enabled,
        public.get_matrix_value('clean_data.part_catalog', 'multilevel_tracking', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as multilevel_tracking,
        public.get_matrix_value('clean_data.part_catalog', 'component_lot_rule', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as component_lot_rule,
        public.get_matrix_value('clean_data.part_catalog', 'stop_arrival_issued_serial', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as stop_arrival_issued_serial,
        public.get_matrix_value('clean_data.part_catalog', 'allow_as_not_consumed', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as allow_as_not_consumed,
        public.get_matrix_value('clean_data.part_catalog', 'receipt_issue_serial_track', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as receipt_issue_serial_track,
        public.get_matrix_value('clean_data.part_catalog', 'stop_new_serial_in_rma', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as stop_new_serial_in_rma,
        public.get_matrix_value('clean_data.part_catalog', 'product_type_classif', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as product_type_classif,
        public.get_matrix_value('clean_data.part_catalog', 'part_main_group', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as part_main_group,
        NULLIF(public.get_matrix_value('clean_data.part_catalog', 'cust_warranty_id', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as cust_warranty_id,
        NULLIF(public.get_matrix_value('clean_data.part_catalog', 'sup_warranty_id', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as sup_warranty_id,
        public.get_matrix_value('clean_data.part_catalog', 'input_unit_meas_group_id', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as input_unit_meas_group_id,
        NULLIF(public.get_matrix_value('clean_data.part_catalog', 'weight_net', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as weight_net,
        public.get_matrix_value('clean_data.part_catalog', 'uom_for_weight_net', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as uom_for_weight_net,
        NULLIF(public.get_matrix_value('clean_data.part_catalog', 'volume_net', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as volume_net,
        public.get_matrix_value('clean_data.part_catalog', 'uom_for_volume_net', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as uom_for_volume_net,
        NULLIF(public.get_matrix_value('clean_data.part_catalog', 'freight_factor', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as freight_factor,
        public.get_matrix_value('clean_data.part_catalog', 'technical_drawing_no', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as technical_drawing_no,
        public.get_matrix_value('clean_data.part_catalog', 'product_type_classif_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as product_type_classif_db,
        public.get_matrix_value('clean_data.part_catalog', 'cest_code', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as cest_code,
        public.get_matrix_value('clean_data.part_catalog', 'fci_code', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as fci_code
    FROM raw_data.v_phl_article_retenu phl
    WHERE phl."N. ARTICLE" IS NOT NULL
      AND phl.site = p_contract   -- cloisonnement par site (cf. v_phl_article_retenu)
      AND TRIM(phl."N. ARTICLE") != ''
      -- Ne garder que les produits finis (STATUT=F) et intermediaires (STATUT=I)
      AND UPPER(LEFT(TRIM(phl."STATUT"), 1)) IN ('F', 'I')
      -- Ne pas dupliquer un part_no deja present (articles SAP ou re-execution)
      AND NOT EXISTS (
          SELECT 1 FROM clean_data.part_catalog pc
          WHERE pc.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
      )
    ORDER BY TRIM(phl."N. ARTICLE");
    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;
    -- Realigner le suivi par lot des articles deja presents lors d'une re-execution
    -- idempotente de la procedure (l'INSERT ci-dessus ignore les part_no existants).
    -- Meme regle qu'a l'insertion : tout suivi par lot sur Castel, rebuts exclus
    -- sur Saint-Jean.
    UPDATE clean_data.part_catalog pc
    SET lot_tracking_code_db = CASE
            WHEN p_contract = 'CS'
                THEN public.get_matrix_value('clean_data.part_catalog', 'lot_tracking_code_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))
            WHEN UPPER(COALESCE(phl."FORME", '')) LIKE '%REBUT%' THEN 'NOT LOT TRACKING'
            ELSE public.get_matrix_value('clean_data.part_catalog', 'lot_tracking_code_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))
        END
    FROM raw_data.v_phl_article_retenu phl
    WHERE pc.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
      AND phl.site = p_contract   -- cloisonnement par site (cf. v_phl_article_retenu)
      AND phl."N. ARTICLE" IS NOT NULL
      AND TRIM(phl."N. ARTICLE") != ''
      AND UPPER(LEFT(TRIM(phl."STATUT"), 1)) IN ('F', 'I')
      AND pc.lot_tracking_code_db IS DISTINCT FROM CASE
            WHEN p_contract = 'CS'
                THEN public.get_matrix_value('clean_data.part_catalog', 'lot_tracking_code_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))
            WHEN UPPER(COALESCE(phl."FORME", '')) LIKE '%REBUT%' THEN 'NOT LOT TRACKING'
            ELSE public.get_matrix_value('clean_data.part_catalog', 'lot_tracking_code_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))
        END;
    GET DIAGNOSTICS v_count_rebut_updated = ROW_COUNT;
    -- Corriger aussi l'unite PHL deja presente : U/M = t doit devenir kg dans IFS.
    UPDATE clean_data.part_catalog pc
    SET unit_code = CASE
            WHEN LOWER(TRIM(COALESCE(phl."U/M", ''))) = 't' THEN 'kg'
            ELSE SUBSTRING(COALESCE(
                public.get_transcodification('UOM', NULLIF(TRIM(phl."U/M"), ''), 'PHL', 'IFS'),
                public.get_transcodification('UOM', NULLIF(UPPER(TRIM(phl."U/M")), ''), 'PHL', 'IFS'),
                public.get_transcodification('UOM', NULLIF(TRIM(phl."U/M"), '')),
                public.get_transcodification('UOM', NULLIF(UPPER(TRIM(phl."U/M")), '')),
                NULLIF(TRIM(phl."U/M"), ''),
                'PCE'
            ), 1, 30)
        END
    FROM raw_data.v_phl_article_retenu phl
    WHERE pc.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
      AND phl.site = p_contract   -- cloisonnement par site (cf. v_phl_article_retenu)
      AND phl."N. ARTICLE" IS NOT NULL
      AND TRIM(phl."N. ARTICLE") != ''
      AND UPPER(LEFT(TRIM(phl."STATUT"), 1)) IN ('F', 'I')
      AND pc.unit_code IS DISTINCT FROM CASE
            WHEN LOWER(TRIM(COALESCE(phl."U/M", ''))) = 't' THEN 'kg'
            ELSE SUBSTRING(COALESCE(
                public.get_transcodification('UOM', NULLIF(TRIM(phl."U/M"), ''), 'PHL', 'IFS'),
                public.get_transcodification('UOM', NULLIF(UPPER(TRIM(phl."U/M")), ''), 'PHL', 'IFS'),
                public.get_transcodification('UOM', NULLIF(TRIM(phl."U/M"), '')),
                public.get_transcodification('UOM', NULLIF(UPPER(TRIM(phl."U/M")), '')),
                NULLIF(TRIM(phl."U/M"), ''),
                'PCE'
            ), 1, 30)
        END;
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;
    RAISE NOTICE 'Alimentation PART_CATALOG (PHL) terminee avec succes';
    RAISE NOTICE 'Articles PHL inseres: %', v_count_inserted;
    RAISE NOTICE 'Suivi par lot realigne (site %): %', p_contract, v_count_rebut_updated;
    RAISE NOTICE 'Duree d''execution: %', v_duration;
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;
        RAISE NOTICE 'ERREUR lors de l''alimentation PART_CATALOG (PHL)';
        RAISE NOTICE 'Code d''erreur: %', SQLSTATE;
        RAISE NOTICE 'Message d''erreur: %', SQLERRM;
        RAISE NOTICE 'Duree avant erreur: %', v_duration;
        RAISE;
END;
$function$
;
