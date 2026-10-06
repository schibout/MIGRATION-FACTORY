-- Le type de retour a change (void -> integer) : CREATE OR REPLACE le refuse.
DROP FUNCTION IF EXISTS clean_data.alimenter_part_catalog_sap();

-- Alimente clean_data.part_catalog pour les articles du fichier
-- raw_data.article_sap (perimetre seul), toutes les infos etant lues dans SAP
-- (mara / makt / marc / texte long). Inspiree de
-- clean_data.alimenter_part_catalog() (sql/inventory/).
--
-- Perimetre : les lignes du fichier dont le N° article est un MATNR SAP
-- (mandt 700). Les autres lignes du fichier (articles fabriques PHL, site CS,
-- lingots/dechets) sont chargees par les modules articlePhl / ArticleComposant.
--
-- TRUNCATE de part_catalog au debut (demande explicite) : la table est
-- partagee avec articlePhl / ArticleComposant, ce module doit donc tourner
-- AVANT eux (execution_order 8 < 12), sinon il efface leurs articles.
-- Module ETL : backend/etl_modules/etl_article_sap.py.
CREATE OR REPLACE FUNCTION clean_data.alimenter_part_catalog_sap()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_count_inserted INTEGER := 0;
    v_start_time TIMESTAMP;
    v_duration INTERVAL;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    RAISE NOTICE 'Debut de l''alimentation PART_CATALOG (article_sap) - %', v_start_time;

    -- article_sap ne fixe QUE le perimetre ; toutes les infos viennent de SAP.
    DROP TABLE IF EXISTS tmp_article_sap;
    CREATE TEMP TABLE tmp_article_sap ON COMMIT DROP AS
    SELECT DISTINCT ON (TRIM(a."N° article"))
        SUBSTRING(TRIM(a."N° article"), 1, 25) AS part_no,
        m.matnr,
        m.meins
    FROM raw_data.article_sap a
    -- MATNR numerique = complete a 18 zeros dans SAP, alphanumerique = tel quel
    JOIN raw_data.mara m
      ON m.mandt::text = '700'
     AND m.matnr::text IN (TRIM(a."N° article"), LPAD(TRIM(a."N° article"), 18, '0'))
    WHERE TRIM(COALESCE(a."N° article", '')) <> ''
    ORDER BY TRIM(a."N° article");

    TRUNCATE TABLE clean_data.part_catalog RESTART IDENTITY;
    RAISE NOTICE 'Table part_catalog videe';

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
        info_text
    )
    SELECT
        t.part_no,
        -- Designation SAP (makt, langue F)
        SUBSTRING(TRIM(COALESCE(k.maktx, '')), 1, 200) AS description,
        -- Unite de base SAP (mara.meins) transcodee UOM ; repli '*' (unite
        -- generique IFS), jamais l'unite SAP brute (rejetee par IFS).
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(t.meins)), '')),
            '*'
        ), 1, 30) AS unit_code,
        -- Suivi par lot : gestion de lot SAP (marc.xchar) sur une division STJN
        CASE WHEN lot.avec_lot THEN 'LOT TRACKING' ELSE 'NOT LOT TRACKING' END AS lot_tracking_code_db,
        public.get_default_value('clean_data.part_catalog', 'serial_rule_db') AS serial_rule_db,
        public.get_default_value('clean_data.part_catalog', 'serial_tracking_code_db') AS serial_tracking_code_db,
        public.get_default_value('clean_data.part_catalog', 'eng_serial_tracking_code_db') AS eng_serial_tracking_code_db,
        public.get_default_value('clean_data.part_catalog', 'configurable_db') AS configurable_db,
        public.get_default_value('clean_data.part_catalog', 'condition_code_usage_db') AS condition_code_usage_db,
        public.get_default_value('clean_data.part_catalog', 'sub_lot_rule_db') AS sub_lot_rule_db,
        CASE WHEN lot.avec_lot THEN 'MULTI_LOTS' ELSE 'ONE_LOT' END AS lot_quantity_rule_db,
        public.get_default_value('clean_data.part_catalog', 'position_part_db') AS position_part_db,
        public.get_default_value('clean_data.part_catalog', 'catch_unit_enabled_db') AS catch_unit_enabled_db,
        public.get_default_value('clean_data.part_catalog', 'multilevel_tracking_db') AS multilevel_tracking_db,
        public.get_default_value('clean_data.part_catalog', 'component_lot_rule_db', 'INVENTORY') AS component_lot_rule_db,
        public.get_default_value('clean_data.part_catalog', 'stop_arrival_issued_serial_db') AS stop_arrival_issued_serial_db,
        public.get_default_value('clean_data.part_catalog', 'allow_as_not_consumed_db') AS allow_as_not_consumed_db,
        public.get_default_value('clean_data.part_catalog', 'receipt_issue_serial_track_db') AS receipt_issue_serial_track_db,
        public.get_default_value('clean_data.part_catalog', 'stop_new_serial_in_rma_db') AS stop_new_serial_in_rma_db,
        -- Texte de commande SAP (MATERIAL / BEST, langue F), cf. alimenter_part_catalog()
        clean_data.texte_long_sap('MATERIAL', 'BEST', t.matnr, ARRAY['F']) AS info_text
    FROM tmp_article_sap t
    LEFT JOIN raw_data.makt k
      ON k.mandt::text = '700' AND k.matnr = t.matnr AND k.spras::text = 'F'
    CROSS JOIN LATERAL (
        SELECT EXISTS (
            SELECT 1 FROM raw_data.marc marc
            WHERE marc.mandt::text = '700'
              AND marc.matnr = t.matnr
              AND marc.werks::text IN ('9200', '9000')
              AND marc.xchar::text = 'X'
        ) AS avec_lot
    ) lot
    ORDER BY t.part_no;
    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;

    v_duration := CURRENT_TIMESTAMP - v_start_time;
    RAISE NOTICE 'PART_CATALOG (article_sap) : % articles inseres en %',
        v_count_inserted, v_duration;
    RETURN v_count_inserted;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERREUR alimentation PART_CATALOG (article_sap) : % - %', SQLSTATE, SQLERRM;
        RAISE;
END;
$function$
;
