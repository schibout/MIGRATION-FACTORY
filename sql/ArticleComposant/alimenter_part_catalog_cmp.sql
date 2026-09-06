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
-- Valeurs par defaut : matrice site x famille SEULE (public.get_matrix_value,
-- migration 072), reglable dans /configuration/matrice-site-famille. Les gabarits
-- metier ComposantSaintJean.csv / ComposantCastel.csv y ont ete repris : les
-- ex-variantes COMPOSANT / COMPOSANT_SJ / COMPOSANT_CS (migrations 055 a 057) sont
-- devenues des regles par famille et par (site, famille). Aucune regle -> NULL.
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
        public.get_matrix_value('clean_data.part_catalog', 'std_name_id', p_contract, NULLIF(TRIM(cmp.famille), ''))::numeric as std_name_id,
        -- unit_code: unite via transcodification UOM (KG -> kg), sinon unite d'entree
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(TRIM(cmp.unite), '')),
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(cmp.unite)), '')),
            NULLIF(TRIM(cmp.unite), ''),
            'PCE'
        ), 1, 30) as unit_code,
        public.get_matrix_value('clean_data.part_catalog', 'freight_factor', p_contract, NULLIF(TRIM(cmp.famille), ''))::numeric as freight_factor,
        -- tracabilite_lot OUI/NON pilote le suivi par lot IFS (libelle + valeur _db)
        CASE WHEN UPPER(TRIM(COALESCE(cmp.tracabilite_lot, ''))) IN ('OUI', 'O', 'Y', 'YES', 'TRUE')
             THEN 'Lot Tracking'
             ELSE 'Not Lot Tracking'
        END as lot_tracking_code,
        CASE WHEN UPPER(TRIM(COALESCE(cmp.tracabilite_lot, ''))) IN ('OUI', 'O', 'Y', 'YES', 'TRUE')
             THEN 'LOT TRACKING'
             ELSE 'NOT LOT TRACKING'
        END as lot_tracking_code_db,
        -- Valeurs par defaut : matrice site x famille SEULE
        -- (/configuration/matrice-site-famille, public.get_matrix_value)
        public.get_matrix_value('clean_data.part_catalog', 'serial_rule', p_contract, NULLIF(TRIM(cmp.famille), '')) as serial_rule,
        public.get_matrix_value('clean_data.part_catalog', 'serial_rule_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as serial_rule_db,
        public.get_matrix_value('clean_data.part_catalog', 'serial_tracking_code', p_contract, NULLIF(TRIM(cmp.famille), '')) as serial_tracking_code,
        public.get_matrix_value('clean_data.part_catalog', 'serial_tracking_code_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as serial_tracking_code_db,
        public.get_matrix_value('clean_data.part_catalog', 'eng_serial_tracking_code', p_contract, NULLIF(TRIM(cmp.famille), '')) as eng_serial_tracking_code,
        public.get_matrix_value('clean_data.part_catalog', 'eng_serial_tracking_code_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as eng_serial_tracking_code_db,
        public.get_matrix_value('clean_data.part_catalog', 'configurable', p_contract, NULLIF(TRIM(cmp.famille), '')) as configurable,
        public.get_matrix_value('clean_data.part_catalog', 'configurable_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as configurable_db,
        -- condition code usage : ALLOW sur Castel (regle metier), NOT_ALLOW sur
        -- Saint-Jean (gabarit) -> regles matrice par (site, famille), migration 072
        public.get_matrix_value('clean_data.part_catalog', 'condition_code_usage', p_contract, NULLIF(TRIM(cmp.famille), '')) as condition_code_usage,
        public.get_matrix_value('clean_data.part_catalog', 'condition_code_usage_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as condition_code_usage_db,
        public.get_matrix_value('clean_data.part_catalog', 'sub_lot_rule', p_contract, NULLIF(TRIM(cmp.famille), '')) as sub_lot_rule,
        public.get_matrix_value('clean_data.part_catalog', 'sub_lot_rule_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as sub_lot_rule_db,
        public.get_matrix_value('clean_data.part_catalog', 'lot_quantity_rule', p_contract, NULLIF(TRIM(cmp.famille), '')) as lot_quantity_rule,
        public.get_matrix_value('clean_data.part_catalog', 'lot_quantity_rule_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as lot_quantity_rule_db,
        public.get_matrix_value('clean_data.part_catalog', 'position_part', p_contract, NULLIF(TRIM(cmp.famille), '')) as position_part,
        public.get_matrix_value('clean_data.part_catalog', 'position_part_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as position_part_db,
        public.get_matrix_value('clean_data.part_catalog', 'catch_unit_enabled', p_contract, NULLIF(TRIM(cmp.famille), '')) as catch_unit_enabled,
        public.get_matrix_value('clean_data.part_catalog', 'catch_unit_enabled_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as catch_unit_enabled_db,
        -- multilevel tracking : seule valeur du gabarit qui diverge entre les deux
        -- sites (SJ = Tracking Off, CS = Tracking On) -> regles matrice par (site, famille)
        public.get_matrix_value('clean_data.part_catalog', 'multilevel_tracking', p_contract, NULLIF(TRIM(cmp.famille), '')) as multilevel_tracking,
        public.get_matrix_value('clean_data.part_catalog', 'multilevel_tracking_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as multilevel_tracking_db,
        public.get_matrix_value('clean_data.part_catalog', 'component_lot_rule', p_contract, NULLIF(TRIM(cmp.famille), '')) as component_lot_rule,
        public.get_matrix_value('clean_data.part_catalog', 'component_lot_rule_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as component_lot_rule_db,
        public.get_matrix_value('clean_data.part_catalog', 'stop_arrival_issued_serial', p_contract, NULLIF(TRIM(cmp.famille), '')) as stop_arrival_issued_serial,
        public.get_matrix_value('clean_data.part_catalog', 'stop_arrival_issued_serial_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as stop_arrival_issued_serial_db,
        public.get_matrix_value('clean_data.part_catalog', 'allow_as_not_consumed', p_contract, NULLIF(TRIM(cmp.famille), '')) as allow_as_not_consumed,
        public.get_matrix_value('clean_data.part_catalog', 'allow_as_not_consumed_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as allow_as_not_consumed_db,
        public.get_matrix_value('clean_data.part_catalog', 'receipt_issue_serial_track', p_contract, NULLIF(TRIM(cmp.famille), '')) as receipt_issue_serial_track,
        public.get_matrix_value('clean_data.part_catalog', 'receipt_issue_serial_track_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as receipt_issue_serial_track_db,
        public.get_matrix_value('clean_data.part_catalog', 'stop_new_serial_in_rma', p_contract, NULLIF(TRIM(cmp.famille), '')) as stop_new_serial_in_rma,
        public.get_matrix_value('clean_data.part_catalog', 'stop_new_serial_in_rma_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as stop_new_serial_in_rma_db
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
               public.get_matrix_value('clean_data.part_catalog', 'multilevel_tracking', p_contract, NULLIF(TRIM(cmp.famille), '')) as multilevel_tracking,
               public.get_matrix_value('clean_data.part_catalog', 'multilevel_tracking_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as multilevel_tracking_db,
               public.get_matrix_value('clean_data.part_catalog', 'condition_code_usage', p_contract, NULLIF(TRIM(cmp.famille), '')) as condition_code_usage,
               public.get_matrix_value('clean_data.part_catalog', 'condition_code_usage_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as condition_code_usage_db,
               -- Valeurs de la matrice : elles dependent de la famille de la ligne
               -- source, elles doivent donc etre calculees ICI, ou l'alias cmp
               -- existe. Elles vivaient dans une CTE `def` SANS FROM, ce qui n'etait
               -- valable que tant qu'il s'agissait de constantes (migration 072).
               public.get_matrix_value('clean_data.part_catalog', 'std_name_id', p_contract, NULLIF(TRIM(cmp.famille), ''))::numeric as std_name_id,
               public.get_matrix_value('clean_data.part_catalog', 'freight_factor', p_contract, NULLIF(TRIM(cmp.famille), ''))::numeric as freight_factor,
               public.get_matrix_value('clean_data.part_catalog', 'serial_rule', p_contract, NULLIF(TRIM(cmp.famille), '')) as serial_rule,
               public.get_matrix_value('clean_data.part_catalog', 'serial_rule_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as serial_rule_db,
               public.get_matrix_value('clean_data.part_catalog', 'serial_tracking_code', p_contract, NULLIF(TRIM(cmp.famille), '')) as serial_tracking_code,
               public.get_matrix_value('clean_data.part_catalog', 'serial_tracking_code_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as serial_tracking_code_db,
               public.get_matrix_value('clean_data.part_catalog', 'eng_serial_tracking_code', p_contract, NULLIF(TRIM(cmp.famille), '')) as eng_serial_tracking_code,
               public.get_matrix_value('clean_data.part_catalog', 'eng_serial_tracking_code_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as eng_serial_tracking_code_db,
               public.get_matrix_value('clean_data.part_catalog', 'configurable', p_contract, NULLIF(TRIM(cmp.famille), '')) as configurable,
               public.get_matrix_value('clean_data.part_catalog', 'configurable_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as configurable_db,
               public.get_matrix_value('clean_data.part_catalog', 'sub_lot_rule', p_contract, NULLIF(TRIM(cmp.famille), '')) as sub_lot_rule,
               public.get_matrix_value('clean_data.part_catalog', 'sub_lot_rule_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as sub_lot_rule_db,
               public.get_matrix_value('clean_data.part_catalog', 'lot_quantity_rule', p_contract, NULLIF(TRIM(cmp.famille), '')) as lot_quantity_rule,
               public.get_matrix_value('clean_data.part_catalog', 'lot_quantity_rule_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as lot_quantity_rule_db,
               public.get_matrix_value('clean_data.part_catalog', 'position_part', p_contract, NULLIF(TRIM(cmp.famille), '')) as position_part,
               public.get_matrix_value('clean_data.part_catalog', 'position_part_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as position_part_db,
               public.get_matrix_value('clean_data.part_catalog', 'catch_unit_enabled', p_contract, NULLIF(TRIM(cmp.famille), '')) as catch_unit_enabled,
               public.get_matrix_value('clean_data.part_catalog', 'catch_unit_enabled_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as catch_unit_enabled_db,
               public.get_matrix_value('clean_data.part_catalog', 'component_lot_rule', p_contract, NULLIF(TRIM(cmp.famille), '')) as component_lot_rule,
               public.get_matrix_value('clean_data.part_catalog', 'component_lot_rule_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as component_lot_rule_db,
               public.get_matrix_value('clean_data.part_catalog', 'stop_arrival_issued_serial', p_contract, NULLIF(TRIM(cmp.famille), '')) as stop_arrival_issued_serial,
               public.get_matrix_value('clean_data.part_catalog', 'stop_arrival_issued_serial_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as stop_arrival_issued_serial_db,
               public.get_matrix_value('clean_data.part_catalog', 'allow_as_not_consumed', p_contract, NULLIF(TRIM(cmp.famille), '')) as allow_as_not_consumed,
               public.get_matrix_value('clean_data.part_catalog', 'allow_as_not_consumed_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as allow_as_not_consumed_db,
               public.get_matrix_value('clean_data.part_catalog', 'receipt_issue_serial_track', p_contract, NULLIF(TRIM(cmp.famille), '')) as receipt_issue_serial_track,
               public.get_matrix_value('clean_data.part_catalog', 'receipt_issue_serial_track_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as receipt_issue_serial_track_db,
               public.get_matrix_value('clean_data.part_catalog', 'stop_new_serial_in_rma', p_contract, NULLIF(TRIM(cmp.famille), '')) as stop_new_serial_in_rma,
               public.get_matrix_value('clean_data.part_catalog', 'stop_new_serial_in_rma_db', p_contract, NULLIF(TRIM(cmp.famille), '')) as stop_new_serial_in_rma_db
        FROM raw_data.composant_sj_cs cmp
        WHERE cmp.code_produit IS NOT NULL
          AND TRIM(cmp.code_produit) != ''
        ORDER BY TRIM(cmp.code_produit),
                 (UPPER(TRIM(COALESCE(cmp.tracabilite_lot, ''))) IN ('OUI', 'O', 'Y', 'YES', 'TRUE')) DESC,
                 cmp.site
    )
    UPDATE clean_data.part_catalog pc
    SET unit_code = src.unit_code,
        lot_tracking_code = CASE WHEN src.suivi_lot THEN 'Lot Tracking' ELSE 'Not Lot Tracking' END,
        lot_tracking_code_db = CASE WHEN src.suivi_lot THEN 'LOT TRACKING' ELSE 'NOT LOT TRACKING' END,
        language_description = SUBSTRING(pc.description, 1, 4000),
        std_name_id = src.std_name_id,
        freight_factor = src.freight_factor,
        serial_rule = src.serial_rule,
        serial_rule_db = src.serial_rule_db,
        serial_tracking_code = src.serial_tracking_code,
        serial_tracking_code_db = src.serial_tracking_code_db,
        eng_serial_tracking_code = src.eng_serial_tracking_code,
        eng_serial_tracking_code_db = src.eng_serial_tracking_code_db,
        configurable = src.configurable,
        configurable_db = src.configurable_db,
        condition_code_usage = src.condition_code_usage,
        condition_code_usage_db = src.condition_code_usage_db,
        sub_lot_rule = src.sub_lot_rule,
        sub_lot_rule_db = src.sub_lot_rule_db,
        lot_quantity_rule = src.lot_quantity_rule,
        lot_quantity_rule_db = src.lot_quantity_rule_db,
        position_part = src.position_part,
        position_part_db = src.position_part_db,
        catch_unit_enabled = src.catch_unit_enabled,
        catch_unit_enabled_db = src.catch_unit_enabled_db,
        multilevel_tracking = src.multilevel_tracking,
        multilevel_tracking_db = src.multilevel_tracking_db,
        component_lot_rule = src.component_lot_rule,
        component_lot_rule_db = src.component_lot_rule_db,
        stop_arrival_issued_serial = src.stop_arrival_issued_serial,
        stop_arrival_issued_serial_db = src.stop_arrival_issued_serial_db,
        allow_as_not_consumed = src.allow_as_not_consumed,
        allow_as_not_consumed_db = src.allow_as_not_consumed_db,
        receipt_issue_serial_track = src.receipt_issue_serial_track,
        receipt_issue_serial_track_db = src.receipt_issue_serial_track_db,
        stop_new_serial_in_rma = src.stop_new_serial_in_rma,
        stop_new_serial_in_rma_db = src.stop_new_serial_in_rma_db
    FROM src
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
           src.std_name_id, src.freight_factor,
           src.serial_rule, src.serial_rule_db,
           src.serial_tracking_code, src.serial_tracking_code_db,
           src.eng_serial_tracking_code, src.eng_serial_tracking_code_db,
           src.configurable, src.configurable_db,
           src.condition_code_usage, src.condition_code_usage_db,
           src.sub_lot_rule, src.sub_lot_rule_db,
           src.lot_quantity_rule, src.lot_quantity_rule_db,
           src.position_part, src.position_part_db,
           src.catch_unit_enabled, src.catch_unit_enabled_db,
           src.multilevel_tracking, src.multilevel_tracking_db,
           src.component_lot_rule, src.component_lot_rule_db,
           src.stop_arrival_issued_serial, src.stop_arrival_issued_serial_db,
           src.allow_as_not_consumed, src.allow_as_not_consumed_db,
           src.receipt_issue_serial_track, src.receipt_issue_serial_track_db,
           src.stop_new_serial_in_rma, src.stop_new_serial_in_rma_db);
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
