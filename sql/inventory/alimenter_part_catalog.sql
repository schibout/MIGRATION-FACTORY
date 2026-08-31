-- DROP FUNCTION clean_data.alimenter_part_catalog();

CREATE OR REPLACE FUNCTION clean_data.alimenter_part_catalog()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_count_inserted INTEGER := 0;
    v_count_updated INTEGER := 0;
    v_count_errors INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    RAISE NOTICE 'Début de l''alimentation du catalogue des pièces (PART_CATALOG) - %', v_start_time;
    
    -- Vider la table cible avant insertion
    TRUNCATE TABLE clean_data.part_catalog RESTART IDENTITY;
    RAISE NOTICE 'Table part_catalog vidée';
    
    -- Insérer les données depuis ifs_article_maitre - Colonnes obligatoires uniquement
    INSERT INTO clean_data.part_catalog (
        -- Colonnes obligatoires (NOT NULL)
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
    SELECT 
        -- Colonnes obligatoires (NOT NULL)
        -- part_no: numero_article SAP (pas de transcodification, l'article garde son ID)
        SUBSTRING(TRIM(LTRIM(va.numero_article, '0')), 1, 25) as part_no,
        SUBSTRING(TRIM(COALESCE(va.designation, '')), 1, 200) as description,
        -- unit_code: unité de base via transcodification UOM (SAP->IFS), sinon unité d'entrée
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(va.unite_base)), '')),
            UPPER(TRIM(va.unite_base))
        ), 1, 30) as unit_code,
        
        -- Colonnes obligatoires _db (valeurs courtes selon documentation)
        CASE 
            WHEN va.avec_gestion_lot = 'OUI' THEN 'LOT TRACKING'
            ELSE 'NOT LOT TRACKING'
        END as lot_tracking_code_db,
        public.get_default_value('clean_data.part_catalog', 'serial_rule_db', 'MANUAL') as serial_rule_db,
        public.get_default_value('clean_data.part_catalog', 'serial_tracking_code_db', 'NOT SERIAL TRACKING') as serial_tracking_code_db,
        public.get_default_value('clean_data.part_catalog', 'eng_serial_tracking_code_db', 'NOT SERIAL TRACKING') as eng_serial_tracking_code_db,
        public.get_default_value('clean_data.part_catalog', 'configurable_db', 'NOT CONFIGURED') as configurable_db,
        public.get_default_value('clean_data.part_catalog', 'condition_code_usage_db', 'NOT_ALLOW_COND_CODE') as condition_code_usage_db,
        public.get_default_value('clean_data.part_catalog', 'sub_lot_rule_db', 'NO_SUBLOTS') as sub_lot_rule_db,
        -- Allow Many Lots per Production Order : actif des que l'article est suivi en lot
        CASE
            WHEN va.avec_gestion_lot = 'OUI' THEN 'MULTI_LOTS'
            ELSE 'ONE_LOT'
        END as lot_quantity_rule_db,
        public.get_default_value('clean_data.part_catalog', 'position_part_db', 'NOT POSITION PART') as position_part_db,
        public.get_default_value('clean_data.part_catalog', 'catch_unit_enabled_db', 'FALSE') as catch_unit_enabled_db,
        public.get_default_value('clean_data.part_catalog', 'multilevel_tracking_db', 'TRACKING_OFF') as multilevel_tracking_db,
        public.get_default_value('clean_data.part_catalog', 'component_lot_rule_db', 'ONE_LOT_ALLOWED', 'INVENTORY') as component_lot_rule_db,
        public.get_default_value('clean_data.part_catalog', 'stop_arrival_issued_serial_db', 'TRUE') as stop_arrival_issued_serial_db,
        public.get_default_value('clean_data.part_catalog', 'allow_as_not_consumed_db', 'FALSE') as allow_as_not_consumed_db,
        public.get_default_value('clean_data.part_catalog', 'receipt_issue_serial_track_db', 'FALSE') as receipt_issue_serial_track_db,
        public.get_default_value('clean_data.part_catalog', 'stop_new_serial_in_rma_db', 'TRUE') as stop_new_serial_in_rma_db
        
    FROM clean_data.ifs_article_maitre va
    WHERE va.numero_article IS NOT NULL
    AND TRIM(COALESCE(va.numero_article, '')) != ''
    ORDER BY COALESCE(va.numero_article, '');

    -- Compter les enregistrements insérés
    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;

    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;

    -- Log des résultats
    RAISE NOTICE 'Alimentation du catalogue des pièces terminée avec succès';
    RAISE NOTICE 'Nombre d''enregistrements traités: %', v_count_inserted;
    RAISE NOTICE 'Durée d''exécution: %', v_duration;
    RAISE NOTICE 'Début: %, Fin: %', v_start_time, v_end_time;
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;
        
        RAISE NOTICE 'ERREUR lors de l''alimentation du catalogue des pièces';
        RAISE NOTICE 'Code d''erreur: %', SQLSTATE;
        RAISE NOTICE 'Message d''erreur: %', SQLERRM;
        RAISE NOTICE 'Durée avant erreur: %', v_duration;
        
        -- Relancer l'exception pour arrêter le processus ETL
        RAISE;
END;
$function$
;
