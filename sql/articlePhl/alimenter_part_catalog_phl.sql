-- Alimentation de PART_CATALOG pour les articles PHL (source: raw_data.phl_article)
-- INSERT en append : s'execute APRES alimenter_part_catalog() (qui fait le TRUNCATE).
-- Mapping riche : les colonnes "_2" de phl_article contiennent deja les codes _db IFS.
-- Booleens forces en MAJUSCULE (contrainte de chargement IFS).

CREATE OR REPLACE FUNCTION clean_data.alimenter_part_catalog_phl()
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
        stop_new_serial_in_rma_db
    )
    SELECT DISTINCT ON (TRIM(phl."N. ARTICLE"))
        -- part_no: N. ARTICLE = cle des articles PHL
        SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25) as part_no,
        SUBSTRING(TRIM(COALESCE(NULLIF(phl."DESCRIPTION", ''), phl."DESCRIPTION LANGUE", phl."N. ARTICLE")), 1, 200) as description,
        -- unit_code: U/M via transcodification UOM (SAP->IFS), sinon unite d'entree
        -- (meme logique que clean_data.alimenter_part_catalog())
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(phl."U/M")), '')),
            NULLIF(TRIM(phl."U/M"), ''),
            'PCE'
        ), 1, 30) as unit_code,

        -- Valeurs _db pour les articles PHL (type I et F)
        'LOT TRACKING' as lot_tracking_code_db,
        'MANUAL' as serial_rule_db,
        'NOT SERIAL TRACKING' as serial_tracking_code_db,
        'NOT SERIAL TRACKING' as eng_serial_tracking_code_db,
        'NOT CONFIGURED' as configurable_db,
        'ALLOW_COND_CODE' as condition_code_usage_db,
        'NO_SUBLOTS' as sub_lot_rule_db,
        'MULTI_LOTS' as lot_quantity_rule_db,
        'NOT POSITION PART' as position_part_db,
        'FALSE' as catch_unit_enabled_db,
        'TRACKING_OFF' as multilevel_tracking_db,
        'MANY_LOTS_ALLOWED' as component_lot_rule_db,
        'TRUE' as stop_arrival_issued_serial_db,
        'FALSE' as allow_as_not_consumed_db,
        'FALSE' as receipt_issue_serial_track_db,
        'TRUE' as stop_new_serial_in_rma_db

    -- Source dedoublonnee (cf. v_phl_article_retenu.sql)
    FROM raw_data.v_phl_article_retenu phl
    WHERE phl."N. ARTICLE" IS NOT NULL
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

    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;

    RAISE NOTICE 'Alimentation PART_CATALOG (PHL) terminee avec succes';
    RAISE NOTICE 'Articles PHL inseres: %', v_count_inserted;
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
