-- L'ancienne signature sans parametre doit disparaitre, sinon PostgreSQL cree une
-- surcharge et les appels sans argument deviennent ambigus.
DROP FUNCTION IF EXISTS clean_data.alimenter_manuf_part_attribute_cmp();
CREATE OR REPLACE FUNCTION clean_data.alimenter_manuf_part_attribute_cmp(p_contract text DEFAULT 'SJ')
 RETURNS void
 LANGUAGE plpgsql
AS $function$
-- Table directrice : raw_data.composant_sj_cs, filtree sur site = p_contract.
--
-- TOUS les composants sont charges, achetes compris : le gabarit metier
-- valeurParDefaut/manuf_part_attribute.csv documente ALBE et DC1000, deux
-- composants achetes. Le filtre sur type_article de la version heritee du module
-- PHL (articles fabriques seulement) a donc ete retire.
--
-- Valeurs par defaut : ce meme gabarit, seede en variante COMPOSANT
-- (migration 062) et ajustable via /configuration/valeurs-defaut. Ses deux lignes
-- SJ et CS sont identiques : pas de variante par site.
--
-- DENSITY est vide au gabarit et la source composants ne porte pas de densite :
-- colonne non alimentee. PROCESS_TYPE, LEADTIME_SOURCE, LOT_BATCH_STRING,
-- MANUF_ENGINEER, OVER_REPORT_TOLERANCE, SHIP_DIRTY_REPAIR_CODE et les colonnes
-- CREATED_FROM_* sont vides au gabarit : hors INSERT.
DECLARE
    v_count_inserted INTEGER := 0;
    v_count_updated INTEGER := 0;
    v_count_orphans INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL;
BEGIN
    IF p_contract NOT IN ('SJ', 'CS') THEN
        RAISE EXCEPTION 'Site invalide: % (attendu: SJ ou CS)', p_contract;
    END IF;
    v_start_time := CURRENT_TIMESTAMP;
    RAISE NOTICE 'Debut de l''alimentation MANUF_PART_ATTRIBUTE (composants, site %) - %', p_contract, v_start_time;
    INSERT INTO clean_data.manuf_part_attribute (
        contract, part_no, default_print_unit, adjust_on_op_qty_deviation, adjust_on_op_qty_deviation_db,
        auto_replace_alt_comp, auto_replace_alt_comp_db, backflush_part, backflush_part_db, close_tolerance,
        component_scrap, configuration_usage, configuration_usage_db, consider_lead_time,
        consider_lead_time_db, cum_leadtime, dop_pegged_so_update_flag, dop_pegged_so_update_flag_db,
        engineering_info, engineering_info_db, fixed_leadtime_day, fixed_leadtime_hour, include_firm_demands,
        include_firm_supplies, issue_overreported_qty, issue_overreported_qty_db, issue_planned_scrap,
        issue_planned_scrap_db, issue_type, issue_type_db, low_level, mrp_control_flag, mrp_control_flag_db,
        optimize_new_delivery_date, order_gap_time, over_reporting, over_reporting_db, overhaul_scrap_rule,
        overhaul_scrap_rule_db, plan_manuf_sup_on_due_date, plan_manuf_sup_on_due_date_db,
        prod_part_as_supply_in_mrp, prod_part_as_supply_in_mrp_db, promise_planned, promise_planned_db,
        routing_effectivity, routing_effectivity_db, run_crp, run_in_background, run_mrp, ship_dirty,
        ship_dirty_db, shrinkage_factor, structure_effectivity, structure_effectivity_db,
        unprotected_lead_time, use_theoritical_density, use_theoritical_density_db, variable_leadtime_day,
        variable_leadtime_hour
    )
    SELECT DISTINCT ON (TRIM(cmp.code_produit))
        -- site passe en parametre (SJ = Saint-Jean, CS = Castel)
        p_contract as contract,
        -- code_produit = cle des composants
        SUBSTRING(TRIM(cmp.code_produit), 1, 25) as part_no,
        -- Default Print Unit depuis PART_CATALOG.UNIT_CODE
        SUBSTRING(pc.unit_code, 1, 10) as default_print_unit,
        public.get_default_value('clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation', 'COMPOSANT') as adjust_on_op_qty_deviation,
        public.get_default_value('clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation_db', 'COMPOSANT') as adjust_on_op_qty_deviation_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'auto_replace_alt_comp', 'COMPOSANT') as auto_replace_alt_comp,
        public.get_default_value('clean_data.manuf_part_attribute', 'auto_replace_alt_comp_db', 'COMPOSANT') as auto_replace_alt_comp_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'backflush_part', 'COMPOSANT') as backflush_part,
        public.get_default_value('clean_data.manuf_part_attribute', 'backflush_part_db', 'COMPOSANT') as backflush_part_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'close_tolerance', 'COMPOSANT')::numeric as close_tolerance,
        public.get_default_value('clean_data.manuf_part_attribute', 'component_scrap', 'COMPOSANT')::numeric as component_scrap,
        public.get_default_value('clean_data.manuf_part_attribute', 'configuration_usage', 'COMPOSANT') as configuration_usage,
        public.get_default_value('clean_data.manuf_part_attribute', 'configuration_usage_db', 'COMPOSANT') as configuration_usage_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'consider_lead_time', 'COMPOSANT') as consider_lead_time,
        public.get_default_value('clean_data.manuf_part_attribute', 'consider_lead_time_db', 'COMPOSANT') as consider_lead_time_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'cum_leadtime', 'COMPOSANT')::numeric as cum_leadtime,
        public.get_default_value('clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag', 'COMPOSANT') as dop_pegged_so_update_flag,
        public.get_default_value('clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag_db', 'COMPOSANT') as dop_pegged_so_update_flag_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'engineering_info', 'COMPOSANT') as engineering_info,
        public.get_default_value('clean_data.manuf_part_attribute', 'engineering_info_db', 'COMPOSANT') as engineering_info_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'fixed_leadtime_day', 'COMPOSANT')::numeric as fixed_leadtime_day,
        public.get_default_value('clean_data.manuf_part_attribute', 'fixed_leadtime_hour', 'COMPOSANT')::numeric as fixed_leadtime_hour,
        public.get_default_value('clean_data.manuf_part_attribute', 'include_firm_demands', 'COMPOSANT') as include_firm_demands,
        public.get_default_value('clean_data.manuf_part_attribute', 'include_firm_supplies', 'COMPOSANT') as include_firm_supplies,
        public.get_default_value('clean_data.manuf_part_attribute', 'issue_overreported_qty', 'COMPOSANT') as issue_overreported_qty,
        public.get_default_value('clean_data.manuf_part_attribute', 'issue_overreported_qty_db', 'COMPOSANT') as issue_overreported_qty_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'issue_planned_scrap', 'COMPOSANT') as issue_planned_scrap,
        public.get_default_value('clean_data.manuf_part_attribute', 'issue_planned_scrap_db', 'COMPOSANT') as issue_planned_scrap_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'issue_type', 'COMPOSANT') as issue_type,
        public.get_default_value('clean_data.manuf_part_attribute', 'issue_type_db', 'COMPOSANT') as issue_type_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'low_level', 'COMPOSANT')::numeric as low_level,
        public.get_default_value('clean_data.manuf_part_attribute', 'mrp_control_flag', 'COMPOSANT') as mrp_control_flag,
        public.get_default_value('clean_data.manuf_part_attribute', 'mrp_control_flag_db', 'COMPOSANT') as mrp_control_flag_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'optimize_new_delivery_date', 'COMPOSANT') as optimize_new_delivery_date,
        public.get_default_value('clean_data.manuf_part_attribute', 'order_gap_time', 'COMPOSANT')::numeric as order_gap_time,
        public.get_default_value('clean_data.manuf_part_attribute', 'over_reporting', 'COMPOSANT') as over_reporting,
        public.get_default_value('clean_data.manuf_part_attribute', 'over_reporting_db', 'COMPOSANT') as over_reporting_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'overhaul_scrap_rule', 'COMPOSANT') as overhaul_scrap_rule,
        public.get_default_value('clean_data.manuf_part_attribute', 'overhaul_scrap_rule_db', 'COMPOSANT') as overhaul_scrap_rule_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date', 'COMPOSANT') as plan_manuf_sup_on_due_date,
        public.get_default_value('clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date_db', 'COMPOSANT') as plan_manuf_sup_on_due_date_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp', 'COMPOSANT') as prod_part_as_supply_in_mrp,
        public.get_default_value('clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp_db', 'COMPOSANT') as prod_part_as_supply_in_mrp_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'promise_planned', 'COMPOSANT') as promise_planned,
        public.get_default_value('clean_data.manuf_part_attribute', 'promise_planned_db', 'COMPOSANT') as promise_planned_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'routing_effectivity', 'COMPOSANT') as routing_effectivity,
        public.get_default_value('clean_data.manuf_part_attribute', 'routing_effectivity_db', 'COMPOSANT') as routing_effectivity_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'run_crp', 'COMPOSANT') as run_crp,
        public.get_default_value('clean_data.manuf_part_attribute', 'run_in_background', 'COMPOSANT') as run_in_background,
        public.get_default_value('clean_data.manuf_part_attribute', 'run_mrp', 'COMPOSANT') as run_mrp,
        public.get_default_value('clean_data.manuf_part_attribute', 'ship_dirty', 'COMPOSANT') as ship_dirty,
        public.get_default_value('clean_data.manuf_part_attribute', 'ship_dirty_db', 'COMPOSANT') as ship_dirty_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'shrinkage_factor', 'COMPOSANT')::numeric as shrinkage_factor,
        public.get_default_value('clean_data.manuf_part_attribute', 'structure_effectivity', 'COMPOSANT') as structure_effectivity,
        public.get_default_value('clean_data.manuf_part_attribute', 'structure_effectivity_db', 'COMPOSANT') as structure_effectivity_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'unprotected_lead_time', 'COMPOSANT')::numeric as unprotected_lead_time,
        public.get_default_value('clean_data.manuf_part_attribute', 'use_theoritical_density', 'COMPOSANT') as use_theoritical_density,
        public.get_default_value('clean_data.manuf_part_attribute', 'use_theoritical_density_db', 'COMPOSANT') as use_theoritical_density_db,
        public.get_default_value('clean_data.manuf_part_attribute', 'variable_leadtime_day', 'COMPOSANT')::numeric as variable_leadtime_day,
        public.get_default_value('clean_data.manuf_part_attribute', 'variable_leadtime_hour', 'COMPOSANT')::numeric as variable_leadtime_hour
    FROM raw_data.composant_sj_cs cmp
    LEFT JOIN clean_data.part_catalog pc
      ON pc.part_no = SUBSTRING(TRIM(cmp.code_produit), 1, 25)
    WHERE cmp.code_produit IS NOT NULL
      AND TRIM(cmp.code_produit) != ''
      -- Seules les lignes du site charge
      AND UPPER(TRIM(COALESCE(cmp.site, ''))) = p_contract
      -- L'article doit deja exister dans inventory_part (table parente)
      AND EXISTS (
          SELECT 1 FROM clean_data.inventory_part ip
          WHERE ip.contract = p_contract
            AND ip.part_no = SUBSTRING(TRIM(cmp.code_produit), 1, 25)
      )
      -- Idempotence : ne pas reinserer une ligne (contract, part_no) deja presente
      AND NOT EXISTS (
          SELECT 1 FROM clean_data.manuf_part_attribute m
          WHERE m.contract = p_contract
            AND m.part_no = SUBSTRING(TRIM(cmp.code_produit), 1, 25)
      )
    ORDER BY TRIM(cmp.code_produit);
    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;
    -- Re-execution idempotente : realignement des lignes composants deja presentes
    -- sur le gabarit.
    WITH src AS (
        SELECT DISTINCT ON (TRIM(cmp.code_produit))
            SUBSTRING(TRIM(cmp.code_produit), 1, 25) as part_no,
            SUBSTRING(pc.unit_code, 1, 10) as default_print_unit,
            public.get_default_value('clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation', 'COMPOSANT') as adjust_on_op_qty_deviation,
            public.get_default_value('clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation_db', 'COMPOSANT') as adjust_on_op_qty_deviation_db,
            public.get_default_value('clean_data.manuf_part_attribute', 'auto_replace_alt_comp', 'COMPOSANT') as auto_replace_alt_comp,
            public.get_default_value('clean_data.manuf_part_attribute', 'auto_replace_alt_comp_db', 'COMPOSANT') as auto_replace_alt_comp_db,
            public.get_default_value('clean_data.manuf_part_attribute', 'backflush_part', 'COMPOSANT') as backflush_part,
            public.get_default_value('clean_data.manuf_part_attribute', 'backflush_part_db', 'COMPOSANT') as backflush_part_db,
            public.get_default_value('clean_data.manuf_part_attribute', 'close_tolerance', 'COMPOSANT')::numeric as close_tolerance,
            public.get_default_value('clean_data.manuf_part_attribute', 'component_scrap', 'COMPOSANT')::numeric as component_scrap,
            public.get_default_value('clean_data.manuf_part_attribute', 'configuration_usage', 'COMPOSANT') as configuration_usage,
            public.get_default_value('clean_data.manuf_part_attribute', 'configuration_usage_db', 'COMPOSANT') as configuration_usage_db,
            public.get_default_value('clean_data.manuf_part_attribute', 'consider_lead_time', 'COMPOSANT') as consider_lead_time,
            public.get_default_value('clean_data.manuf_part_attribute', 'consider_lead_time_db', 'COMPOSANT') as consider_lead_time_db,
            public.get_default_value('clean_data.manuf_part_attribute', 'cum_leadtime', 'COMPOSANT')::numeric as cum_leadtime,
            public.get_default_value('clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag', 'COMPOSANT') as dop_pegged_so_update_flag,
            public.get_default_value('clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag_db', 'COMPOSANT') as dop_pegged_so_update_flag_db,
            public.get_default_value('clean_data.manuf_part_attribute', 'engineering_info', 'COMPOSANT') as engineering_info,
            public.get_default_value('clean_data.manuf_part_attribute', 'engineering_info_db', 'COMPOSANT') as engineering_info_db,
            public.get_default_value('clean_data.manuf_part_attribute', 'fixed_leadtime_day', 'COMPOSANT')::numeric as fixed_leadtime_day,
            public.get_default_value('clean_data.manuf_part_attribute', 'fixed_leadtime_hour', 'COMPOSANT')::numeric as fixed_leadtime_hour,
            public.get_default_value('clean_data.manuf_part_attribute', 'include_firm_demands', 'COMPOSANT') as include_firm_demands,
            public.get_default_value('clean_data.manuf_part_attribute', 'include_firm_supplies', 'COMPOSANT') as include_firm_supplies,
            public.get_default_value('clean_data.manuf_part_attribute', 'issue_overreported_qty', 'COMPOSANT') as issue_overreported_qty,
            public.get_default_value('clean_data.manuf_part_attribute', 'issue_overreported_qty_db', 'COMPOSANT') as issue_overreported_qty_db,
            public.get_default_value('clean_data.manuf_part_attribute', 'issue_planned_scrap', 'COMPOSANT') as issue_planned_scrap,
            public.get_default_value('clean_data.manuf_part_attribute', 'issue_planned_scrap_db', 'COMPOSANT') as issue_planned_scrap_db,
            public.get_default_value('clean_data.manuf_part_attribute', 'issue_type', 'COMPOSANT') as issue_type,
            public.get_default_value('clean_data.manuf_part_attribute', 'issue_type_db', 'COMPOSANT') as issue_type_db,
            public.get_default_value('clean_data.manuf_part_attribute', 'low_level', 'COMPOSANT')::numeric as low_level,
            public.get_default_value('clean_data.manuf_part_attribute', 'mrp_control_flag', 'COMPOSANT') as mrp_control_flag,
            public.get_default_value('clean_data.manuf_part_attribute', 'mrp_control_flag_db', 'COMPOSANT') as mrp_control_flag_db,
            public.get_default_value('clean_data.manuf_part_attribute', 'optimize_new_delivery_date', 'COMPOSANT') as optimize_new_delivery_date,
            public.get_default_value('clean_data.manuf_part_attribute', 'order_gap_time', 'COMPOSANT')::numeric as order_gap_time,
            public.get_default_value('clean_data.manuf_part_attribute', 'over_reporting', 'COMPOSANT') as over_reporting,
            public.get_default_value('clean_data.manuf_part_attribute', 'over_reporting_db', 'COMPOSANT') as over_reporting_db,
            public.get_default_value('clean_data.manuf_part_attribute', 'overhaul_scrap_rule', 'COMPOSANT') as overhaul_scrap_rule,
            public.get_default_value('clean_data.manuf_part_attribute', 'overhaul_scrap_rule_db', 'COMPOSANT') as overhaul_scrap_rule_db,
            public.get_default_value('clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date', 'COMPOSANT') as plan_manuf_sup_on_due_date,
            public.get_default_value('clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date_db', 'COMPOSANT') as plan_manuf_sup_on_due_date_db,
            public.get_default_value('clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp', 'COMPOSANT') as prod_part_as_supply_in_mrp,
            public.get_default_value('clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp_db', 'COMPOSANT') as prod_part_as_supply_in_mrp_db,
            public.get_default_value('clean_data.manuf_part_attribute', 'promise_planned', 'COMPOSANT') as promise_planned,
            public.get_default_value('clean_data.manuf_part_attribute', 'promise_planned_db', 'COMPOSANT') as promise_planned_db,
            public.get_default_value('clean_data.manuf_part_attribute', 'routing_effectivity', 'COMPOSANT') as routing_effectivity,
            public.get_default_value('clean_data.manuf_part_attribute', 'routing_effectivity_db', 'COMPOSANT') as routing_effectivity_db,
            public.get_default_value('clean_data.manuf_part_attribute', 'run_crp', 'COMPOSANT') as run_crp,
            public.get_default_value('clean_data.manuf_part_attribute', 'run_in_background', 'COMPOSANT') as run_in_background,
            public.get_default_value('clean_data.manuf_part_attribute', 'run_mrp', 'COMPOSANT') as run_mrp,
            public.get_default_value('clean_data.manuf_part_attribute', 'ship_dirty', 'COMPOSANT') as ship_dirty,
            public.get_default_value('clean_data.manuf_part_attribute', 'ship_dirty_db', 'COMPOSANT') as ship_dirty_db,
            public.get_default_value('clean_data.manuf_part_attribute', 'shrinkage_factor', 'COMPOSANT')::numeric as shrinkage_factor,
            public.get_default_value('clean_data.manuf_part_attribute', 'structure_effectivity', 'COMPOSANT') as structure_effectivity,
            public.get_default_value('clean_data.manuf_part_attribute', 'structure_effectivity_db', 'COMPOSANT') as structure_effectivity_db,
            public.get_default_value('clean_data.manuf_part_attribute', 'unprotected_lead_time', 'COMPOSANT')::numeric as unprotected_lead_time,
            public.get_default_value('clean_data.manuf_part_attribute', 'use_theoritical_density', 'COMPOSANT') as use_theoritical_density,
            public.get_default_value('clean_data.manuf_part_attribute', 'use_theoritical_density_db', 'COMPOSANT') as use_theoritical_density_db,
            public.get_default_value('clean_data.manuf_part_attribute', 'variable_leadtime_day', 'COMPOSANT')::numeric as variable_leadtime_day,
            public.get_default_value('clean_data.manuf_part_attribute', 'variable_leadtime_hour', 'COMPOSANT')::numeric as variable_leadtime_hour
        FROM raw_data.composant_sj_cs cmp
        LEFT JOIN clean_data.part_catalog pc
          ON pc.part_no = SUBSTRING(TRIM(cmp.code_produit), 1, 25)
        WHERE cmp.code_produit IS NOT NULL
          AND TRIM(cmp.code_produit) != ''
          AND UPPER(TRIM(COALESCE(cmp.site, ''))) = p_contract
        ORDER BY TRIM(cmp.code_produit)
    )
    UPDATE clean_data.manuf_part_attribute m
    SET default_print_unit = src.default_print_unit,
        adjust_on_op_qty_deviation = src.adjust_on_op_qty_deviation,
        adjust_on_op_qty_deviation_db = src.adjust_on_op_qty_deviation_db,
        auto_replace_alt_comp = src.auto_replace_alt_comp,
        auto_replace_alt_comp_db = src.auto_replace_alt_comp_db,
        backflush_part = src.backflush_part,
        backflush_part_db = src.backflush_part_db,
        close_tolerance = src.close_tolerance,
        component_scrap = src.component_scrap,
        configuration_usage = src.configuration_usage,
        configuration_usage_db = src.configuration_usage_db,
        consider_lead_time = src.consider_lead_time,
        consider_lead_time_db = src.consider_lead_time_db,
        cum_leadtime = src.cum_leadtime,
        dop_pegged_so_update_flag = src.dop_pegged_so_update_flag,
        dop_pegged_so_update_flag_db = src.dop_pegged_so_update_flag_db,
        engineering_info = src.engineering_info,
        engineering_info_db = src.engineering_info_db,
        fixed_leadtime_day = src.fixed_leadtime_day,
        fixed_leadtime_hour = src.fixed_leadtime_hour,
        include_firm_demands = src.include_firm_demands,
        include_firm_supplies = src.include_firm_supplies,
        issue_overreported_qty = src.issue_overreported_qty,
        issue_overreported_qty_db = src.issue_overreported_qty_db,
        issue_planned_scrap = src.issue_planned_scrap,
        issue_planned_scrap_db = src.issue_planned_scrap_db,
        issue_type = src.issue_type,
        issue_type_db = src.issue_type_db,
        low_level = src.low_level,
        mrp_control_flag = src.mrp_control_flag,
        mrp_control_flag_db = src.mrp_control_flag_db,
        optimize_new_delivery_date = src.optimize_new_delivery_date,
        order_gap_time = src.order_gap_time,
        over_reporting = src.over_reporting,
        over_reporting_db = src.over_reporting_db,
        overhaul_scrap_rule = src.overhaul_scrap_rule,
        overhaul_scrap_rule_db = src.overhaul_scrap_rule_db,
        plan_manuf_sup_on_due_date = src.plan_manuf_sup_on_due_date,
        plan_manuf_sup_on_due_date_db = src.plan_manuf_sup_on_due_date_db,
        prod_part_as_supply_in_mrp = src.prod_part_as_supply_in_mrp,
        prod_part_as_supply_in_mrp_db = src.prod_part_as_supply_in_mrp_db,
        promise_planned = src.promise_planned,
        promise_planned_db = src.promise_planned_db,
        routing_effectivity = src.routing_effectivity,
        routing_effectivity_db = src.routing_effectivity_db,
        run_crp = src.run_crp,
        run_in_background = src.run_in_background,
        run_mrp = src.run_mrp,
        ship_dirty = src.ship_dirty,
        ship_dirty_db = src.ship_dirty_db,
        shrinkage_factor = src.shrinkage_factor,
        structure_effectivity = src.structure_effectivity,
        structure_effectivity_db = src.structure_effectivity_db,
        unprotected_lead_time = src.unprotected_lead_time,
        use_theoritical_density = src.use_theoritical_density,
        use_theoritical_density_db = src.use_theoritical_density_db,
        variable_leadtime_day = src.variable_leadtime_day,
        variable_leadtime_hour = src.variable_leadtime_hour
    FROM src
    WHERE m.contract = p_contract
      AND m.part_no = src.part_no
      AND (
           m.default_print_unit, m.adjust_on_op_qty_deviation, m.adjust_on_op_qty_deviation_db,
           m.auto_replace_alt_comp, m.auto_replace_alt_comp_db, m.backflush_part, m.backflush_part_db,
           m.close_tolerance, m.component_scrap, m.configuration_usage, m.configuration_usage_db,
           m.consider_lead_time, m.consider_lead_time_db, m.cum_leadtime, m.dop_pegged_so_update_flag,
           m.dop_pegged_so_update_flag_db, m.engineering_info, m.engineering_info_db, m.fixed_leadtime_day,
           m.fixed_leadtime_hour, m.include_firm_demands, m.include_firm_supplies, m.issue_overreported_qty,
           m.issue_overreported_qty_db, m.issue_planned_scrap, m.issue_planned_scrap_db, m.issue_type,
           m.issue_type_db, m.low_level, m.mrp_control_flag, m.mrp_control_flag_db,
           m.optimize_new_delivery_date, m.order_gap_time, m.over_reporting, m.over_reporting_db,
           m.overhaul_scrap_rule, m.overhaul_scrap_rule_db, m.plan_manuf_sup_on_due_date,
           m.plan_manuf_sup_on_due_date_db, m.prod_part_as_supply_in_mrp, m.prod_part_as_supply_in_mrp_db,
           m.promise_planned, m.promise_planned_db, m.routing_effectivity, m.routing_effectivity_db,
           m.run_crp, m.run_in_background, m.run_mrp, m.ship_dirty, m.ship_dirty_db, m.shrinkage_factor,
           m.structure_effectivity, m.structure_effectivity_db, m.unprotected_lead_time,
           m.use_theoritical_density, m.use_theoritical_density_db, m.variable_leadtime_day,
           m.variable_leadtime_hour
          ) IS DISTINCT FROM (
           src.default_print_unit, src.adjust_on_op_qty_deviation, src.adjust_on_op_qty_deviation_db,
           src.auto_replace_alt_comp, src.auto_replace_alt_comp_db, src.backflush_part,
           src.backflush_part_db, src.close_tolerance, src.component_scrap, src.configuration_usage,
           src.configuration_usage_db, src.consider_lead_time, src.consider_lead_time_db, src.cum_leadtime,
           src.dop_pegged_so_update_flag, src.dop_pegged_so_update_flag_db, src.engineering_info,
           src.engineering_info_db, src.fixed_leadtime_day, src.fixed_leadtime_hour,
           src.include_firm_demands, src.include_firm_supplies, src.issue_overreported_qty,
           src.issue_overreported_qty_db, src.issue_planned_scrap, src.issue_planned_scrap_db,
           src.issue_type, src.issue_type_db, src.low_level, src.mrp_control_flag, src.mrp_control_flag_db,
           src.optimize_new_delivery_date, src.order_gap_time, src.over_reporting, src.over_reporting_db,
           src.overhaul_scrap_rule, src.overhaul_scrap_rule_db, src.plan_manuf_sup_on_due_date,
           src.plan_manuf_sup_on_due_date_db, src.prod_part_as_supply_in_mrp,
           src.prod_part_as_supply_in_mrp_db, src.promise_planned, src.promise_planned_db,
           src.routing_effectivity, src.routing_effectivity_db, src.run_crp, src.run_in_background,
           src.run_mrp, src.ship_dirty, src.ship_dirty_db, src.shrinkage_factor, src.structure_effectivity,
           src.structure_effectivity_db, src.unprotected_lead_time, src.use_theoritical_density,
           src.use_theoritical_density_db, src.variable_leadtime_day, src.variable_leadtime_hour
          );
    GET DIAGNOSTICS v_count_updated = ROW_COUNT;
    -- Purge des orphelins.
    -- Cette table n'est videe par personne : les chargeurs PHL et composants inserent
    -- en APPEND (garde NOT EXISTS) alors que alimenter_inventory_part() fait un TRUNCATE
    -- de la table parente a chaque run. Les lignes d'un run precedent dont l'article
    -- n'est plus dans inventory_part survivaient donc indefiniment et etaient rejetees
    -- au chargement IFS.
    -- Statistiques a jour avant l'anti-join (inventory_part est rechargee dans la meme
    -- transaction et n'a aucun index) : sans cela le planificateur choisit une nested
    -- loop au lieu d'un hash anti-join.
    ANALYZE clean_data.inventory_part;
    DELETE FROM clean_data.manuf_part_attribute m
    WHERE NOT EXISTS (
        SELECT 1 FROM clean_data.inventory_part ip
        WHERE ip.contract = m.contract
          AND ip.part_no  = m.part_no
    );
    GET DIAGNOSTICS v_count_orphans = ROW_COUNT;
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Alimentation MANUF_PART_ATTRIBUTE (composants) terminee avec succes';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Composants inseres: %', v_count_inserted;
    RAISE NOTICE 'Composants realignes sur le gabarit: %', v_count_updated;
    RAISE NOTICE 'Lignes orphelines supprimees (sans inventory_part): %', v_count_orphans;
    RAISE NOTICE 'Duree d''execution: %', v_duration;
    RAISE NOTICE '====================================================';
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'ERREUR lors de l''alimentation MANUF_PART_ATTRIBUTE (composants)';
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'Code d''erreur: %', SQLSTATE;
        RAISE NOTICE 'Message: %', SQLERRM;
        RAISE NOTICE 'Duree avant erreur: %', v_duration;
        RAISE NOTICE '====================================================';
        RAISE;
END;
$function$
;
