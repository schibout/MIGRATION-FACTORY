-- L'ancienne signature sans parametre doit disparaitre, sinon PostgreSQL cree une
-- surcharge et les appels sans argument deviennent ambigus.
DROP FUNCTION IF EXISTS clean_data.alimenter_part_catalog_cmp();
CREATE OR REPLACE FUNCTION clean_data.alimenter_part_catalog_cmp(p_contract text DEFAULT 'SJ')
 RETURNS void
 LANGUAGE plpgsql
AS $function$
-- Table directrice : raw_data.composant_sj_cs (composants SJ / CS).
-- Cle naturelle de la source = (site, code_produit) ; part_catalog n'a pas de site,
-- l'article est donc insere une seule fois quel que soit le site charge (garde NOT EXISTS)
-- et p_contract n'influe pas sur le contenu (accepte pour l'homogeneite du module).
-- Un meme code_produit peut exister sur les deux sites avec une tracabilite lot
-- differente (aujourd'hui CS = OUI, SJ = NON) : on retient alors LOT TRACKING,
-- un article suivi par lot sur un site ne pouvant pas etre declare non suivi dans IFS.
-- Le site de la ligne retenue pilote aussi le multilevel tracking (SJ = Tracking Off,
-- CS = Tracking On), seule autre valeur du gabarit a diverger entre les deux sites.
-- Valeurs par defaut : gabarits metier ComposantSaintJean.csv / ComposantCastel.csv,
-- seedees en variantes COMPOSANT, COMPOSANT_SJ et COMPOSANT_CS (migrations 055 a 057)
-- et ajustables via /configuration/valeurs-defaut.
DECLARE
    v_count_inserted INTEGER := 0;
    v_count_realigned INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL;
BEGIN
    IF p_contract NOT IN ('SJ', 'CS') THEN
        RAISE EXCEPTION 'Site invalide: % (attendu: SJ ou CS)', p_contract;
    END IF;
    v_start_time := CURRENT_TIMESTAMP;
    RAISE NOTICE 'Debut de l''alimentation PART_CATALOG (composants) - %', v_start_time;
    INSERT INTO clean_data.part_catalog (
        part_no,
        description,
        language_description,
        std_name_id,
        unit_code,
        freight_factor,
        lot_tracking_code,
        lot_tracking_code_db,
        serial_rule,
        serial_rule_db,
        serial_tracking_code,
        serial_tracking_code_db,
        eng_serial_tracking_code,
        eng_serial_tracking_code_db,
        configurable,
        configurable_db,
        condition_code_usage,
        condition_code_usage_db,
        sub_lot_rule,
        sub_lot_rule_db,
        lot_quantity_rule,
        lot_quantity_rule_db,
        position_part,
        position_part_db,
        catch_unit_enabled,
        catch_unit_enabled_db,
        multilevel_tracking,
        multilevel_tracking_db,
        component_lot_rule,
        component_lot_rule_db,
        stop_arrival_issued_serial,
        stop_arrival_issued_serial_db,
        allow_as_not_consumed,
        allow_as_not_consumed_db,
        receipt_issue_serial_track,
        receipt_issue_serial_track_db,
        stop_new_serial_in_rma,
        stop_new_serial_in_rma_db
    )
    SELECT DISTINCT ON (TRIM(cmp.code_produit))
        -- part_no: code_produit = cle des composants
        SUBSTRING(TRIM(cmp.code_produit), 1, 25) as part_no,
        SUBSTRING(TRIM(COALESCE(NULLIF(TRIM(cmp.libelle_produit), ''), cmp.code_produit)), 1, 200) as description,
        -- language_description : meme libelle que description (gabarit metier)
        SUBSTRING(TRIM(COALESCE(NULLIF(TRIM(cmp.libelle_produit), ''), cmp.code_produit)), 1, 4000) as language_description,
        public.get_default_value('clean_data.part_catalog', 'std_name_id', 'COMPOSANT')::numeric as std_name_id,
        -- unit_code: unite via transcodification UOM (KG -> kg), sinon unite d'entree
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(TRIM(cmp.unite), '')),
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(cmp.unite)), '')),
            NULLIF(TRIM(cmp.unite), ''),
            'PCE'
        ), 1, 30) as unit_code,
        public.get_default_value('clean_data.part_catalog', 'freight_factor', 'COMPOSANT')::numeric as freight_factor,
        -- tracabilite_lot OUI/NON pilote le suivi par lot IFS (libelle + valeur _db)
        CASE WHEN UPPER(TRIM(COALESCE(cmp.tracabilite_lot, ''))) IN ('OUI', 'O', 'Y', 'YES', 'TRUE')
             THEN 'Lot Tracking'
             ELSE 'Not Lot Tracking'
        END as lot_tracking_code,
        CASE WHEN UPPER(TRIM(COALESCE(cmp.tracabilite_lot, ''))) IN ('OUI', 'O', 'Y', 'YES', 'TRUE')
             THEN 'LOT TRACKING'
             ELSE 'NOT LOT TRACKING'
        END as lot_tracking_code_db,
        -- Valeurs par defaut parametrables via l'ecran /configuration/valeurs-defaut
        -- (public.get_default_value)
        public.get_default_value('clean_data.part_catalog', 'serial_rule', 'COMPOSANT') as serial_rule,
        public.get_default_value('clean_data.part_catalog', 'serial_rule_db') as serial_rule_db,
        public.get_default_value('clean_data.part_catalog', 'serial_tracking_code', 'COMPOSANT') as serial_tracking_code,
        public.get_default_value('clean_data.part_catalog', 'serial_tracking_code_db') as serial_tracking_code_db,
        public.get_default_value('clean_data.part_catalog', 'eng_serial_tracking_code', 'COMPOSANT') as eng_serial_tracking_code,
        public.get_default_value('clean_data.part_catalog', 'eng_serial_tracking_code_db') as eng_serial_tracking_code_db,
        public.get_default_value('clean_data.part_catalog', 'configurable', 'COMPOSANT') as configurable,
        public.get_default_value('clean_data.part_catalog', 'configurable_db') as configurable_db,
        -- condition code usage : ALLOW sur Castel (regle metier), NOT_ALLOW sur
        -- Saint-Jean (gabarit) -> variante par site, comme le multilevel tracking
        public.get_default_value('clean_data.part_catalog', 'condition_code_usage',
            'COMPOSANT_' || UPPER(TRIM(COALESCE(cmp.site, 'SJ')))) as condition_code_usage,
        public.get_default_value('clean_data.part_catalog', 'condition_code_usage_db',
            'COMPOSANT_' || UPPER(TRIM(COALESCE(cmp.site, 'SJ')))) as condition_code_usage_db,
        public.get_default_value('clean_data.part_catalog', 'sub_lot_rule', 'COMPOSANT') as sub_lot_rule,
        public.get_default_value('clean_data.part_catalog', 'sub_lot_rule_db') as sub_lot_rule_db,
        public.get_default_value('clean_data.part_catalog', 'lot_quantity_rule', 'COMPOSANT') as lot_quantity_rule,
        public.get_default_value('clean_data.part_catalog', 'lot_quantity_rule_db', 'COMPOSANT') as lot_quantity_rule_db,
        public.get_default_value('clean_data.part_catalog', 'position_part', 'COMPOSANT') as position_part,
        public.get_default_value('clean_data.part_catalog', 'position_part_db') as position_part_db,
        public.get_default_value('clean_data.part_catalog', 'catch_unit_enabled', 'COMPOSANT') as catch_unit_enabled,
        public.get_default_value('clean_data.part_catalog', 'catch_unit_enabled_db') as catch_unit_enabled_db,
        -- multilevel tracking : seule valeur du gabarit qui diverge entre les deux
        -- sites (SJ = Tracking Off, CS = Tracking On) -> variante par site
        public.get_default_value('clean_data.part_catalog', 'multilevel_tracking',
            'COMPOSANT_' || UPPER(TRIM(COALESCE(cmp.site, 'SJ')))) as multilevel_tracking,
        public.get_default_value('clean_data.part_catalog', 'multilevel_tracking_db',
            'COMPOSANT_' || UPPER(TRIM(COALESCE(cmp.site, 'SJ')))) as multilevel_tracking_db,
        public.get_default_value('clean_data.part_catalog', 'component_lot_rule', 'COMPOSANT') as component_lot_rule,
        public.get_default_value('clean_data.part_catalog', 'component_lot_rule_db', 'COMPOSANT') as component_lot_rule_db,
        public.get_default_value('clean_data.part_catalog', 'stop_arrival_issued_serial', 'COMPOSANT') as stop_arrival_issued_serial,
        public.get_default_value('clean_data.part_catalog', 'stop_arrival_issued_serial_db') as stop_arrival_issued_serial_db,
        public.get_default_value('clean_data.part_catalog', 'allow_as_not_consumed', 'COMPOSANT') as allow_as_not_consumed,
        public.get_default_value('clean_data.part_catalog', 'allow_as_not_consumed_db') as allow_as_not_consumed_db,
        public.get_default_value('clean_data.part_catalog', 'receipt_issue_serial_track', 'COMPOSANT') as receipt_issue_serial_track,
        public.get_default_value('clean_data.part_catalog', 'receipt_issue_serial_track_db') as receipt_issue_serial_track_db,
        public.get_default_value('clean_data.part_catalog', 'stop_new_serial_in_rma', 'COMPOSANT') as stop_new_serial_in_rma,
        public.get_default_value('clean_data.part_catalog', 'stop_new_serial_in_rma_db') as stop_new_serial_in_rma_db
    FROM raw_data.composant_sj_cs cmp
    WHERE cmp.code_produit IS NOT NULL
      AND TRIM(cmp.code_produit) != ''
      -- Ne pas dupliquer un part_no deja present (articles SAP/PHL ou re-execution)
      AND NOT EXISTS (
          SELECT 1 FROM clean_data.part_catalog pc
          WHERE pc.part_no = SUBSTRING(TRIM(cmp.code_produit), 1, 25)
      )
    -- LOT TRACKING l'emporte quand le code existe sur les deux sites
    ORDER BY TRIM(cmp.code_produit),
             (UPPER(TRIM(COALESCE(cmp.tracabilite_lot, ''))) IN ('OUI', 'O', 'Y', 'YES', 'TRUE')) DESC,
             cmp.site;
    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;
    -- Re-execution idempotente : l'INSERT ci-dessus ignore les part_no existants,
    -- on realigne donc les lignes composants deja presentes sur le gabarit.
    WITH src AS (
        -- Une seule ligne source par code, avec le meme arbitrage que l'INSERT :
        -- la ligne suivie par lot l'emporte, puis le site (CS avant SJ). Le site
        -- ainsi retenu pilote aussi le multilevel tracking.
        SELECT DISTINCT ON (TRIM(cmp.code_produit))
               SUBSTRING(TRIM(cmp.code_produit), 1, 25) as part_no,
               UPPER(TRIM(COALESCE(cmp.tracabilite_lot, ''))) IN ('OUI', 'O', 'Y', 'YES', 'TRUE') as suivi_lot,
               SUBSTRING(COALESCE(
                   public.get_transcodification('UOM', NULLIF(TRIM(cmp.unite), '')),
                   public.get_transcodification('UOM', NULLIF(UPPER(TRIM(cmp.unite)), '')),
                   NULLIF(TRIM(cmp.unite), ''),
                   'PCE'
               ), 1, 30) as unit_code,
               public.get_default_value('clean_data.part_catalog', 'multilevel_tracking',
                   'COMPOSANT_' || UPPER(TRIM(COALESCE(cmp.site, 'SJ')))) as multilevel_tracking,
               public.get_default_value('clean_data.part_catalog', 'multilevel_tracking_db',
                   'COMPOSANT_' || UPPER(TRIM(COALESCE(cmp.site, 'SJ')))) as multilevel_tracking_db,
               public.get_default_value('clean_data.part_catalog', 'condition_code_usage',
                   'COMPOSANT_' || UPPER(TRIM(COALESCE(cmp.site, 'SJ')))) as condition_code_usage,
               public.get_default_value('clean_data.part_catalog', 'condition_code_usage_db',
                   'COMPOSANT_' || UPPER(TRIM(COALESCE(cmp.site, 'SJ')))) as condition_code_usage_db
        FROM raw_data.composant_sj_cs cmp
        WHERE cmp.code_produit IS NOT NULL
          AND TRIM(cmp.code_produit) != ''
        ORDER BY TRIM(cmp.code_produit),
                 (UPPER(TRIM(COALESCE(cmp.tracabilite_lot, ''))) IN ('OUI', 'O', 'Y', 'YES', 'TRUE')) DESC,
                 cmp.site
    ), def AS (
        SELECT
            public.get_default_value('clean_data.part_catalog', 'std_name_id', 'COMPOSANT')::numeric as std_name_id,
            public.get_default_value('clean_data.part_catalog', 'freight_factor', 'COMPOSANT')::numeric as freight_factor,
            public.get_default_value('clean_data.part_catalog', 'serial_rule', 'COMPOSANT') as serial_rule,
            public.get_default_value('clean_data.part_catalog', 'serial_rule_db') as serial_rule_db,
            public.get_default_value('clean_data.part_catalog', 'serial_tracking_code', 'COMPOSANT') as serial_tracking_code,
            public.get_default_value('clean_data.part_catalog', 'serial_tracking_code_db') as serial_tracking_code_db,
            public.get_default_value('clean_data.part_catalog', 'eng_serial_tracking_code', 'COMPOSANT') as eng_serial_tracking_code,
            public.get_default_value('clean_data.part_catalog', 'eng_serial_tracking_code_db') as eng_serial_tracking_code_db,
            public.get_default_value('clean_data.part_catalog', 'configurable', 'COMPOSANT') as configurable,
            public.get_default_value('clean_data.part_catalog', 'configurable_db') as configurable_db,
            public.get_default_value('clean_data.part_catalog', 'sub_lot_rule', 'COMPOSANT') as sub_lot_rule,
            public.get_default_value('clean_data.part_catalog', 'sub_lot_rule_db') as sub_lot_rule_db,
            public.get_default_value('clean_data.part_catalog', 'lot_quantity_rule', 'COMPOSANT') as lot_quantity_rule,
            public.get_default_value('clean_data.part_catalog', 'lot_quantity_rule_db', 'COMPOSANT') as lot_quantity_rule_db,
            public.get_default_value('clean_data.part_catalog', 'position_part', 'COMPOSANT') as position_part,
            public.get_default_value('clean_data.part_catalog', 'position_part_db') as position_part_db,
            public.get_default_value('clean_data.part_catalog', 'catch_unit_enabled', 'COMPOSANT') as catch_unit_enabled,
            public.get_default_value('clean_data.part_catalog', 'catch_unit_enabled_db') as catch_unit_enabled_db,
            public.get_default_value('clean_data.part_catalog', 'component_lot_rule', 'COMPOSANT') as component_lot_rule,
            public.get_default_value('clean_data.part_catalog', 'component_lot_rule_db', 'COMPOSANT') as component_lot_rule_db,
            public.get_default_value('clean_data.part_catalog', 'stop_arrival_issued_serial', 'COMPOSANT') as stop_arrival_issued_serial,
            public.get_default_value('clean_data.part_catalog', 'stop_arrival_issued_serial_db') as stop_arrival_issued_serial_db,
            public.get_default_value('clean_data.part_catalog', 'allow_as_not_consumed', 'COMPOSANT') as allow_as_not_consumed,
            public.get_default_value('clean_data.part_catalog', 'allow_as_not_consumed_db') as allow_as_not_consumed_db,
            public.get_default_value('clean_data.part_catalog', 'receipt_issue_serial_track', 'COMPOSANT') as receipt_issue_serial_track,
            public.get_default_value('clean_data.part_catalog', 'receipt_issue_serial_track_db') as receipt_issue_serial_track_db,
            public.get_default_value('clean_data.part_catalog', 'stop_new_serial_in_rma', 'COMPOSANT') as stop_new_serial_in_rma,
            public.get_default_value('clean_data.part_catalog', 'stop_new_serial_in_rma_db') as stop_new_serial_in_rma_db
    )
    UPDATE clean_data.part_catalog pc
    SET unit_code = src.unit_code,
        lot_tracking_code = CASE WHEN src.suivi_lot THEN 'Lot Tracking' ELSE 'Not Lot Tracking' END,
        lot_tracking_code_db = CASE WHEN src.suivi_lot THEN 'LOT TRACKING' ELSE 'NOT LOT TRACKING' END,
        language_description = SUBSTRING(pc.description, 1, 4000),
        std_name_id = def.std_name_id,
        freight_factor = def.freight_factor,
        serial_rule = def.serial_rule,
        serial_rule_db = def.serial_rule_db,
        serial_tracking_code = def.serial_tracking_code,
        serial_tracking_code_db = def.serial_tracking_code_db,
        eng_serial_tracking_code = def.eng_serial_tracking_code,
        eng_serial_tracking_code_db = def.eng_serial_tracking_code_db,
        configurable = def.configurable,
        configurable_db = def.configurable_db,
        condition_code_usage = src.condition_code_usage,
        condition_code_usage_db = src.condition_code_usage_db,
        sub_lot_rule = def.sub_lot_rule,
        sub_lot_rule_db = def.sub_lot_rule_db,
        lot_quantity_rule = def.lot_quantity_rule,
        lot_quantity_rule_db = def.lot_quantity_rule_db,
        position_part = def.position_part,
        position_part_db = def.position_part_db,
        catch_unit_enabled = def.catch_unit_enabled,
        catch_unit_enabled_db = def.catch_unit_enabled_db,
        multilevel_tracking = src.multilevel_tracking,
        multilevel_tracking_db = src.multilevel_tracking_db,
        component_lot_rule = def.component_lot_rule,
        component_lot_rule_db = def.component_lot_rule_db,
        stop_arrival_issued_serial = def.stop_arrival_issued_serial,
        stop_arrival_issued_serial_db = def.stop_arrival_issued_serial_db,
        allow_as_not_consumed = def.allow_as_not_consumed,
        allow_as_not_consumed_db = def.allow_as_not_consumed_db,
        receipt_issue_serial_track = def.receipt_issue_serial_track,
        receipt_issue_serial_track_db = def.receipt_issue_serial_track_db,
        stop_new_serial_in_rma = def.stop_new_serial_in_rma,
        stop_new_serial_in_rma_db = def.stop_new_serial_in_rma_db
    FROM src, def
    WHERE pc.part_no = src.part_no
      AND (pc.unit_code,
           pc.lot_tracking_code,
           pc.lot_tracking_code_db,
           pc.language_description,
           pc.std_name_id, pc.freight_factor,
           pc.serial_rule, pc.serial_rule_db,
           pc.serial_tracking_code, pc.serial_tracking_code_db,
           pc.eng_serial_tracking_code, pc.eng_serial_tracking_code_db,
           pc.configurable, pc.configurable_db,
           pc.condition_code_usage, pc.condition_code_usage_db,
           pc.sub_lot_rule, pc.sub_lot_rule_db,
           pc.lot_quantity_rule, pc.lot_quantity_rule_db,
           pc.position_part, pc.position_part_db,
           pc.catch_unit_enabled, pc.catch_unit_enabled_db,
           pc.multilevel_tracking, pc.multilevel_tracking_db,
           pc.component_lot_rule, pc.component_lot_rule_db,
           pc.stop_arrival_issued_serial, pc.stop_arrival_issued_serial_db,
           pc.allow_as_not_consumed, pc.allow_as_not_consumed_db,
           pc.receipt_issue_serial_track, pc.receipt_issue_serial_track_db,
           pc.stop_new_serial_in_rma, pc.stop_new_serial_in_rma_db)
          IS DISTINCT FROM
          (src.unit_code,
           CASE WHEN src.suivi_lot THEN 'Lot Tracking' ELSE 'Not Lot Tracking' END,
           CASE WHEN src.suivi_lot THEN 'LOT TRACKING' ELSE 'NOT LOT TRACKING' END,
           SUBSTRING(pc.description, 1, 4000),
           def.std_name_id, def.freight_factor,
           def.serial_rule, def.serial_rule_db,
           def.serial_tracking_code, def.serial_tracking_code_db,
           def.eng_serial_tracking_code, def.eng_serial_tracking_code_db,
           def.configurable, def.configurable_db,
           src.condition_code_usage, src.condition_code_usage_db,
           def.sub_lot_rule, def.sub_lot_rule_db,
           def.lot_quantity_rule, def.lot_quantity_rule_db,
           def.position_part, def.position_part_db,
           def.catch_unit_enabled, def.catch_unit_enabled_db,
           src.multilevel_tracking, src.multilevel_tracking_db,
           def.component_lot_rule, def.component_lot_rule_db,
           def.stop_arrival_issued_serial, def.stop_arrival_issued_serial_db,
           def.allow_as_not_consumed, def.allow_as_not_consumed_db,
           def.receipt_issue_serial_track, def.receipt_issue_serial_track_db,
           def.stop_new_serial_in_rma, def.stop_new_serial_in_rma_db);
    GET DIAGNOSTICS v_count_realigned = ROW_COUNT;
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;
    RAISE NOTICE 'Alimentation PART_CATALOG (composants) terminee avec succes';
    RAISE NOTICE 'Composants inseres: %', v_count_inserted;
    RAISE NOTICE 'Composants realignes sur le gabarit: %', v_count_realigned;
    RAISE NOTICE 'Duree d''execution: %', v_duration;
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;
        RAISE NOTICE 'ERREUR lors de l''alimentation PART_CATALOG (composants)';
        RAISE NOTICE 'Code d''erreur: %', SQLSTATE;
        RAISE NOTICE 'Message d''erreur: %', SQLERRM;
        RAISE NOTICE 'Duree avant erreur: %', v_duration;
        RAISE;
END;
$function$
;
