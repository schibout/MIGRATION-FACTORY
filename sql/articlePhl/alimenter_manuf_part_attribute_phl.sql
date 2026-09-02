-- L'ancienne signature sans parametre doit disparaitre, sinon PostgreSQL cree une
-- surcharge et les appels sans argument deviennent ambigus.
DROP FUNCTION IF EXISTS clean_data.alimenter_manuf_part_attribute_phl();
CREATE OR REPLACE FUNCTION clean_data.alimenter_manuf_part_attribute_phl(p_contract text DEFAULT 'SJ')
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_count_inserted INTEGER := 0;
    v_count_orphans INTEGER := 0;
    v_count_density_updated INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL;
BEGIN
    IF p_contract NOT IN ('SJ', 'CS') THEN
        RAISE EXCEPTION 'Site invalide: % (attendu: SJ ou CS)', p_contract;
    END IF;
    v_start_time := CURRENT_TIMESTAMP;
    RAISE NOTICE 'Debut de l''alimentation MANUF_PART_ATTRIBUTE (articles fabriques PHL, site %) - %', p_contract, v_start_time;
    INSERT INTO clean_data.manuf_part_attribute (
        contract,
        part_no,
        -- flags / attributs (valeurs _db)
        backflush_part_db,
        engineering_info_db,
        structure_effectivity_db,
        routing_effectivity_db,
        promise_planned_db,
        default_print_unit,
        configuration_usage_db,
        dop_pegged_so_update_flag_db,
        mrp_control_flag_db,
        prod_part_as_supply_in_mrp_db,
        use_theoritical_density_db,
        density,
        over_reporting_db,
        issue_planned_scrap_db,
        adjust_on_op_qty_deviation_db,
        issue_overreported_qty_db,
        plan_manuf_sup_on_due_date_db,
        plan_manuf_sup_on_due_date,
        ship_dirty_db,
        ship_dirty,
        auto_replace_alt_comp_db,
        consider_lead_time_db,
        unprotected_lead_time,
        run_mrp,
        run_crp,
        include_firm_demands,
        include_firm_supplies,
        optimize_new_delivery_date,
        run_in_background,
        -- quantites
        component_scrap,
        shrinkage_factor,
        cum_leadtime,
        order_gap_time,
        low_level,
        fixed_leadtime_day,
        variable_leadtime_hour,
        variable_leadtime_day,
        fixed_leadtime_hour,
        overhaul_scrap_rule
    )
    SELECT DISTINCT ON (TRIM(phl."N. ARTICLE"))
        -- CONTRACT: site passe en parametre (SJ = Saint-Jean, CS = Castel)
        p_contract as contract,
        -- PART_NO: N. ARTICLE = cle des articles PHL
        SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25) as part_no,
        -- Valeurs par defaut parametrables via l'ecran /configuration/valeurs-defaut
        -- (public.get_default_value, fallback = ancienne valeur codee en dur)
        public.get_default_value('clean_data.manuf_part_attribute', 'backflush_part_db') as backflush_part_db,              -- All Locations
        public.get_default_value('clean_data.manuf_part_attribute', 'engineering_info_db') as engineering_info_db,          -- Not Mandatory
        public.get_default_value('clean_data.manuf_part_attribute', 'structure_effectivity_db') as structure_effectivity_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'routing_effectivity_db') as routing_effectivity_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'promise_planned_db') as promise_planned_db,
        SUBSTRING(pc.unit_code, 1, 10) as default_print_unit, -- Default Print Unit depuis PART_CATALOG.UNIT_CODE
        public.get_default_value('clean_data.manuf_part_attribute', 'configuration_usage_db') as configuration_usage_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag_db') as dop_pegged_so_update_flag_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'mrp_control_flag_db') as mrp_control_flag_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp_db') as prod_part_as_supply_in_mrp_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'use_theoritical_density_db') as use_theoritical_density_db,
        NULLIF(REPLACE(TRIM(COALESCE(dens.densite, '')), ',', '.'), '')::numeric as density,
        public.get_default_value('clean_data.manuf_part_attribute', 'over_reporting_db') as over_reporting_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'issue_planned_scrap_db') as issue_planned_scrap_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation_db') as adjust_on_op_qty_deviation_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'issue_overreported_qty_db') as issue_overreported_qty_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date_db') as plan_manuf_sup_on_due_date_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date') as plan_manuf_sup_on_due_date,
        public.get_default_value('clean_data.manuf_part_attribute', 'ship_dirty_db') as ship_dirty_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'ship_dirty') as ship_dirty,
        public.get_default_value('clean_data.manuf_part_attribute', 'auto_replace_alt_comp_db') as auto_replace_alt_comp_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'consider_lead_time_db') as consider_lead_time_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'unprotected_lead_time')::numeric as unprotected_lead_time,
        public.get_default_value('clean_data.manuf_part_attribute', 'run_mrp') as run_mrp,
        public.get_default_value('clean_data.manuf_part_attribute', 'run_crp') as run_crp,
        public.get_default_value('clean_data.manuf_part_attribute', 'include_firm_demands') as include_firm_demands,
        public.get_default_value('clean_data.manuf_part_attribute', 'include_firm_supplies') as include_firm_supplies,
        public.get_default_value('clean_data.manuf_part_attribute', 'optimize_new_delivery_date') as optimize_new_delivery_date,
        public.get_default_value('clean_data.manuf_part_attribute', 'run_in_background') as run_in_background,
        public.get_default_value('clean_data.manuf_part_attribute', 'component_scrap')::numeric as component_scrap,
        public.get_default_value('clean_data.manuf_part_attribute', 'shrinkage_factor')::numeric as shrinkage_factor,
        public.get_default_value('clean_data.manuf_part_attribute', 'cum_leadtime')::numeric as cum_leadtime,
        public.get_default_value('clean_data.manuf_part_attribute', 'order_gap_time')::numeric as order_gap_time,
        public.get_default_value('clean_data.manuf_part_attribute', 'low_level')::numeric as low_level,
        public.get_default_value('clean_data.manuf_part_attribute', 'fixed_leadtime_day')::numeric as fixed_leadtime_day,
        public.get_default_value('clean_data.manuf_part_attribute', 'variable_leadtime_hour')::numeric as variable_leadtime_hour,
        public.get_default_value('clean_data.manuf_part_attribute', 'variable_leadtime_day')::numeric as variable_leadtime_day,
        public.get_default_value('clean_data.manuf_part_attribute', 'fixed_leadtime_hour')::numeric as fixed_leadtime_hour,
        public.get_default_value('clean_data.manuf_part_attribute', 'overhaul_scrap_rule') as overhaul_scrap_rule
    -- Source dedoublonnee (cf. v_phl_article_retenu.sql)
    FROM raw_data.v_phl_article_retenu phl
    LEFT JOIN raw_data.phl_article_densite dens
      ON TRIM(dens.identifiant) = TRIM(phl."N. ARTICLE")
    LEFT JOIN clean_data.part_catalog pc
      ON pc.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
    WHERE phl."N. ARTICLE" IS NOT NULL
      AND TRIM(phl."N. ARTICLE") != ''
      -- Articles fabriques uniquement : produits finis (F) et intermediaires (I)
      AND UPPER(LEFT(TRIM(phl."STATUT"), 1)) IN ('F', 'I')
      -- L'article doit deja exister dans inventory_part (table parente)
      AND EXISTS (
          SELECT 1 FROM clean_data.inventory_part ip
          WHERE ip.contract = p_contract
            AND ip.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
      )
      -- Idempotence : ne pas reinserer une ligne (contract, part_no) deja presente
      AND NOT EXISTS (
          SELECT 1 FROM clean_data.manuf_part_attribute m
          WHERE m.contract = p_contract
            AND m.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
      )
    ORDER BY TRIM(phl."N. ARTICLE");
    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;
    -- Mettre a jour la densite des lignes deja presentes lors d'une re-execution idempotente.
    UPDATE clean_data.manuf_part_attribute mpa
    SET density = NULLIF(REPLACE(TRIM(COALESCE(dens.densite, '')), ',', '.'), '')::numeric
    FROM raw_data.phl_article_densite dens
    WHERE mpa.contract = p_contract
      AND mpa.part_no = TRIM(dens.identifiant)
      AND mpa.density IS DISTINCT FROM NULLIF(REPLACE(TRIM(COALESCE(dens.densite, '')), ',', '.'), '')::numeric;
    GET DIAGNOSTICS v_count_density_updated = ROW_COUNT;
    -- Forcer DEFAULT_PRINT_UNIT depuis PART_CATALOG.UNIT_CODE sur les lignes existantes.
    UPDATE clean_data.manuf_part_attribute m
    SET default_print_unit = SUBSTRING(pc.unit_code, 1, 10)
    FROM clean_data.part_catalog pc
    WHERE m.contract = p_contract
      AND pc.part_no = m.part_no
      AND m.default_print_unit IS DISTINCT FROM SUBSTRING(pc.unit_code, 1, 10);
    -- Purge des orphelins.
    -- Cette table n'est vidée par personne : le chargeur PHL insère en APPEND
    -- (garde NOT EXISTS) alors que alimenter_inventory_part() fait un TRUNCATE
    -- de la table parente à chaque run. Les lignes d'un run précédent dont
    -- l'article n'est plus dans inventory_part survivaient donc indéfiniment et
    -- étaient rejetées au chargement IFS.
    -- Statistiques a jour avant l'anti-join (inventory_part est rechargee dans
    -- la meme transaction et n'a aucun index) : sans cela le planificateur
    -- choisit une nested loop au lieu d'un hash anti-join.
    ANALYZE clean_data.inventory_part;
    DELETE FROM clean_data.manuf_part_attribute m
    WHERE NOT EXISTS (
        SELECT 1 FROM clean_data.inventory_part ip
        WHERE ip.contract = m.contract
          AND ip.part_no  = m.part_no
    );
    GET DIAGNOSTICS v_count_orphans = ROW_COUNT;
    -- Forcer Plan Manufacturing Supply on Due Date (parametrable, defaut TRUE) aussi sur les lignes existantes.
    UPDATE clean_data.manuf_part_attribute m
    SET plan_manuf_sup_on_due_date_db = def.plan_db,
        plan_manuf_sup_on_due_date = def.plan_lbl
    FROM (SELECT
              public.get_default_value('clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date_db') as plan_db,
              public.get_default_value('clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date') as plan_lbl
         ) def,
         raw_data.v_phl_article_retenu phl
    WHERE m.contract = p_contract
      AND m.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
      AND phl."N. ARTICLE" IS NOT NULL
      AND TRIM(phl."N. ARTICLE") != ''
      AND UPPER(LEFT(TRIM(phl."STATUT"), 1)) IN ('F', 'I')
      AND (m.plan_manuf_sup_on_due_date_db, m.plan_manuf_sup_on_due_date)
          IS DISTINCT FROM (def.plan_db, def.plan_lbl);
    -- Forcer les delais/niveaux de planification et flags MRP a la valeur cible (parametrable
    -- via l'ecran valeurs par defaut) sur toutes les lignes PHL existantes.
    UPDATE clean_data.manuf_part_attribute m
    SET cum_leadtime = def.cum_leadtime,
        order_gap_time = def.order_gap_time,
        low_level = def.low_level,
        fixed_leadtime_day = def.fixed_leadtime_day,
        variable_leadtime_hour = def.variable_leadtime_hour,
        variable_leadtime_day = def.variable_leadtime_day,
        fixed_leadtime_hour = def.fixed_leadtime_hour,
        overhaul_scrap_rule = def.overhaul_scrap_rule,
        unprotected_lead_time = def.unprotected_lead_time,
        run_mrp = def.run_mrp,
        run_crp = def.run_crp,
        include_firm_demands = def.include_firm_demands,
        include_firm_supplies = def.include_firm_supplies,
        optimize_new_delivery_date = def.optimize_new_delivery_date,
        run_in_background = def.run_in_background,
        ship_dirty = def.ship_dirty
    FROM (SELECT
              public.get_default_value('clean_data.manuf_part_attribute', 'cum_leadtime')::numeric as cum_leadtime,
              public.get_default_value('clean_data.manuf_part_attribute', 'order_gap_time')::numeric as order_gap_time,
              public.get_default_value('clean_data.manuf_part_attribute', 'low_level')::numeric as low_level,
              public.get_default_value('clean_data.manuf_part_attribute', 'fixed_leadtime_day')::numeric as fixed_leadtime_day,
              public.get_default_value('clean_data.manuf_part_attribute', 'variable_leadtime_hour')::numeric as variable_leadtime_hour,
              public.get_default_value('clean_data.manuf_part_attribute', 'variable_leadtime_day')::numeric as variable_leadtime_day,
              public.get_default_value('clean_data.manuf_part_attribute', 'fixed_leadtime_hour')::numeric as fixed_leadtime_hour,
              public.get_default_value('clean_data.manuf_part_attribute', 'overhaul_scrap_rule') as overhaul_scrap_rule,
              public.get_default_value('clean_data.manuf_part_attribute', 'unprotected_lead_time')::numeric as unprotected_lead_time,
              public.get_default_value('clean_data.manuf_part_attribute', 'run_mrp') as run_mrp,
              public.get_default_value('clean_data.manuf_part_attribute', 'run_crp') as run_crp,
              public.get_default_value('clean_data.manuf_part_attribute', 'include_firm_demands') as include_firm_demands,
              public.get_default_value('clean_data.manuf_part_attribute', 'include_firm_supplies') as include_firm_supplies,
              public.get_default_value('clean_data.manuf_part_attribute', 'optimize_new_delivery_date') as optimize_new_delivery_date,
              public.get_default_value('clean_data.manuf_part_attribute', 'run_in_background') as run_in_background,
              public.get_default_value('clean_data.manuf_part_attribute', 'ship_dirty') as ship_dirty
         ) def,
         raw_data.v_phl_article_retenu phl
    WHERE m.contract = p_contract
      AND m.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
      AND phl."N. ARTICLE" IS NOT NULL
      AND TRIM(phl."N. ARTICLE") != ''
      AND UPPER(LEFT(TRIM(phl."STATUT"), 1)) IN ('F', 'I')
      AND (m.cum_leadtime IS DISTINCT FROM def.cum_leadtime
        OR m.order_gap_time IS DISTINCT FROM def.order_gap_time
        OR m.low_level IS DISTINCT FROM def.low_level
        OR m.fixed_leadtime_day IS DISTINCT FROM def.fixed_leadtime_day
        OR m.variable_leadtime_hour IS DISTINCT FROM def.variable_leadtime_hour
        OR m.variable_leadtime_day IS DISTINCT FROM def.variable_leadtime_day
        OR m.fixed_leadtime_hour IS DISTINCT FROM def.fixed_leadtime_hour
        OR m.overhaul_scrap_rule IS DISTINCT FROM def.overhaul_scrap_rule
        OR m.unprotected_lead_time IS DISTINCT FROM def.unprotected_lead_time
        OR m.run_mrp IS DISTINCT FROM def.run_mrp
        OR m.run_crp IS DISTINCT FROM def.run_crp
        OR m.include_firm_demands IS DISTINCT FROM def.include_firm_demands
        OR m.include_firm_supplies IS DISTINCT FROM def.include_firm_supplies
        OR m.optimize_new_delivery_date IS DISTINCT FROM def.optimize_new_delivery_date
        OR m.run_in_background IS DISTINCT FROM def.run_in_background
        OR m.ship_dirty IS DISTINCT FROM def.ship_dirty);
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Alimentation MANUF_PART_ATTRIBUTE (PHL) terminee avec succes';
    RAISE NOTICE 'Lignes orphelines supprimees (sans inventory_part): %', v_count_orphans;
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Lignes inserees: %', v_count_inserted;
    RAISE NOTICE 'Densites mises a jour: %', v_count_density_updated;
    RAISE NOTICE 'Duree d''execution: %', v_duration;
    RAISE NOTICE '====================================================';
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'ERREUR lors de l''alimentation MANUF_PART_ATTRIBUTE (PHL)';
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'Code d''erreur: %', SQLSTATE;
        RAISE NOTICE 'Message: %', SQLERRM;
        RAISE NOTICE 'Duree avant erreur: %', v_duration;
        RAISE NOTICE '====================================================';
        RAISE;
END;
$function$
;
