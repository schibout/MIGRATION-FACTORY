CREATE OR REPLACE FUNCTION clean_data.alimenter_manuf_part_attribute_phl()
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
    v_start_time := CURRENT_TIMESTAMP;
    RAISE NOTICE 'Debut de l''alimentation MANUF_PART_ATTRIBUTE (articles fabriques PHL) - %', v_start_time;
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
        -- CONTRACT: SJ (Saint-Jean) pour tous les PHL
        'SJ' as contract,
        -- PART_NO: N. ARTICLE = cle des articles PHL
        SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25) as part_no,
        'Y'        as backflush_part_db,              -- All Locations
        '0'        as engineering_info_db,            -- Not Mandatory
        'DATE'     as structure_effectivity_db,       -- Date
        'DATE'     as routing_effectivity_db,         -- Date
        'Promised' as promise_planned_db,             -- Promised
        SUBSTRING(pc.unit_code, 1, 10) as default_print_unit, -- Default Print Unit depuis PART_CATALOG.UNIT_CODE
        'Common'   as configuration_usage_db,         -- Common
        'PLANNED'  as dop_pegged_so_update_flag_db,   -- Planned
        'TRUE'     as mrp_control_flag_db,            -- True
        'FALSE'    as prod_part_as_supply_in_mrp_db,  -- False
        'FALSE'    as use_theoritical_density_db,     -- False (defaut ajoute, non present dans la spec)
        NULLIF(REPLACE(TRIM(COALESCE(dens.densite, '')), ',', '.'), '')::numeric as density,
        'ALLOWED'  as over_reporting_db,              -- Allowed
        'TRUE'     as issue_planned_scrap_db,         -- True
        'FALSE'    as adjust_on_op_qty_deviation_db,  -- False
        'FALSE'    as issue_overreported_qty_db,      -- False
        'TRUE'     as plan_manuf_sup_on_due_date_db,  -- Plan Manufacturing Supply on Due Date : active pour tous
        'TRUE'     as plan_manuf_sup_on_due_date,
        'FALSE'    as ship_dirty_db,                  -- False
        'FALSE'    as ship_dirty,                     -- False
        'FALSE'    as auto_replace_alt_comp_db,       -- False
        'TRUE'     as consider_lead_time_db,          -- True
        0          as unprotected_lead_time,
        'FALSE'    as run_mrp,
        'FALSE'    as run_crp,
        'TRUE'     as include_firm_demands,
        'TRUE'     as include_firm_supplies,
        'FALSE'    as optimize_new_delivery_date,
        'FALSE'    as run_in_background,
        0 as component_scrap,
        0 as shrinkage_factor,
        0 as cum_leadtime,
        0 as order_gap_time,
        0 as low_level,
        0 as fixed_leadtime_day,
        0 as variable_leadtime_hour,
        0 as variable_leadtime_day,
        0 as fixed_leadtime_hour,
        'DIRECT' as overhaul_scrap_rule
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
          WHERE ip.contract = 'SJ'
            AND ip.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
      )
      -- Idempotence : ne pas reinserer une ligne (contract, part_no) deja presente
      AND NOT EXISTS (
          SELECT 1 FROM clean_data.manuf_part_attribute m
          WHERE m.contract = 'SJ'
            AND m.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
      )
    ORDER BY TRIM(phl."N. ARTICLE");
    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;
    -- Mettre a jour la densite des lignes deja presentes lors d'une re-execution idempotente.
    UPDATE clean_data.manuf_part_attribute mpa
    SET density = NULLIF(REPLACE(TRIM(COALESCE(dens.densite, '')), ',', '.'), '')::numeric
    FROM raw_data.phl_article_densite dens
    WHERE mpa.contract = 'SJ'
      AND mpa.part_no = TRIM(dens.identifiant)
      AND mpa.density IS DISTINCT FROM NULLIF(REPLACE(TRIM(COALESCE(dens.densite, '')), ',', '.'), '')::numeric;
    GET DIAGNOSTICS v_count_density_updated = ROW_COUNT;
    -- Forcer DEFAULT_PRINT_UNIT depuis PART_CATALOG.UNIT_CODE sur les lignes existantes.
    UPDATE clean_data.manuf_part_attribute m
    SET default_print_unit = SUBSTRING(pc.unit_code, 1, 10)
    FROM clean_data.part_catalog pc
    WHERE m.contract = 'SJ'
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
    -- Forcer Plan Manufacturing Supply on Due Date a TRUE aussi sur les lignes existantes.
    UPDATE clean_data.manuf_part_attribute m
    SET plan_manuf_sup_on_due_date_db = 'TRUE',
        plan_manuf_sup_on_due_date = 'TRUE'
    FROM raw_data.v_phl_article_retenu phl
    WHERE m.contract = 'SJ'
      AND m.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
      AND phl."N. ARTICLE" IS NOT NULL
      AND TRIM(phl."N. ARTICLE") != ''
      AND UPPER(LEFT(TRIM(phl."STATUT"), 1)) IN ('F', 'I')
      AND (m.plan_manuf_sup_on_due_date_db, m.plan_manuf_sup_on_due_date)
          IS DISTINCT FROM ('TRUE', 'TRUE');
    -- Forcer les delais/niveaux de planification et flags MRP a la valeur cible sur toutes les lignes PHL existantes.
    UPDATE clean_data.manuf_part_attribute m
    SET cum_leadtime = 0,
        order_gap_time = 0,
        low_level = 0,
        fixed_leadtime_day = 0,
        variable_leadtime_hour = 0,
        variable_leadtime_day = 0,
        fixed_leadtime_hour = 0,
        overhaul_scrap_rule = 'DIRECT',
        unprotected_lead_time = 0,
        run_mrp = 'FALSE',
        run_crp = 'FALSE',
        include_firm_demands = 'TRUE',
        include_firm_supplies = 'TRUE',
        optimize_new_delivery_date = 'FALSE',
        run_in_background = 'FALSE',
        ship_dirty = 'FALSE'
    FROM raw_data.v_phl_article_retenu phl
    WHERE m.contract = 'SJ'
      AND m.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
      AND phl."N. ARTICLE" IS NOT NULL
      AND TRIM(phl."N. ARTICLE") != ''
      AND UPPER(LEFT(TRIM(phl."STATUT"), 1)) IN ('F', 'I')
      AND (m.cum_leadtime IS DISTINCT FROM 0
        OR m.order_gap_time IS DISTINCT FROM 0
        OR m.low_level IS DISTINCT FROM 0
        OR m.fixed_leadtime_day IS DISTINCT FROM 0
        OR m.variable_leadtime_hour IS DISTINCT FROM 0
        OR m.variable_leadtime_day IS DISTINCT FROM 0
        OR m.fixed_leadtime_hour IS DISTINCT FROM 0
        OR m.overhaul_scrap_rule IS DISTINCT FROM 'DIRECT'
        OR m.unprotected_lead_time IS DISTINCT FROM 0
        OR m.run_mrp IS DISTINCT FROM 'FALSE'
        OR m.run_crp IS DISTINCT FROM 'FALSE'
        OR m.include_firm_demands IS DISTINCT FROM 'TRUE'
        OR m.include_firm_supplies IS DISTINCT FROM 'TRUE'
        OR m.optimize_new_delivery_date IS DISTINCT FROM 'FALSE'
        OR m.run_in_background IS DISTINCT FROM 'FALSE'
        OR m.ship_dirty IS DISTINCT FROM 'FALSE');
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
