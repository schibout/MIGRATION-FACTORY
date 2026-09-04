-- L'ancienne signature sans parametre doit disparaitre, sinon PostgreSQL cree une
-- surcharge et les appels sans argument deviennent ambigus.
DROP FUNCTION IF EXISTS clean_data.alimenter_inventory_part_cmp();
CREATE OR REPLACE FUNCTION clean_data.alimenter_inventory_part_cmp(p_contract text DEFAULT 'SJ')
 RETURNS void
 LANGUAGE plpgsql
AS $function$
-- Table directrice : raw_data.composant_sj_cs, filtree sur site = p_contract.
--
-- Valeurs par defaut : gabarits metier valeurParDefaut/inventoryPartStjn.csv et
-- inventoryPartCastel.csv, seedes en variante COMPOSANT (migration 059) et
-- ajustables via /configuration/valeurs-defaut. Le module ne lit AUCUNE ligne
-- STANDARD : plusieurs divergeaient du gabarit (company, type_code_db,
-- lead_time_code_db, shortage_flag_db, stock_management_db, qty_calc_rounding...).
--
-- Colonnes du gabarit laissees vides : elles ne sont pas dans l'INSERT
-- (part_product_family, country_of_origin, intrastat_conv_factor, hsn_sac_code,
-- customs_stat_no, statistical_code, type_designation, std_name_id...).
-- NOTE_ID est un identifiant genere par IFS, propre a chaque article : non alimente.
-- Les attributs physiques PHL (densite, alliage, dimensions, poids, forme) n'ont
-- pas d'equivalent dans la source composants.
DECLARE
    v_count_inserted INTEGER := 0;
    v_count_updated INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL;
BEGIN
    IF p_contract NOT IN ('SJ', 'CS') THEN
        RAISE EXCEPTION 'Site invalide: % (attendu: SJ ou CS)', p_contract;
    END IF;
    v_start_time := CURRENT_TIMESTAMP;
    RAISE NOTICE 'Debut de l''alimentation INVENTORY_PART (composants, site %) - %', p_contract, v_start_time;
    INSERT INTO clean_data.inventory_part (
        contract, part_no, description, description_copy, description_in_use, part_catalog_description,
        unit_meas, c_family_code, part_product_family, c_alloy_code, c_alloy_serie_code,
        zero_cost_flag, zero_cost_flag_db,
        inventory_valuation_method,
        inventory_valuation_method_db, create_date, last_activity_date, abc_class, asset_class,
        automatic_capability_check, automatic_capability_check_db, avail_activity_status,
        avail_activity_status_db, c_is_green, c_is_green_db, co_reserve_onh_analys_flag,
        co_reserve_onh_analys_flag_db, company, consumption_tax, consumption_tax_db, count_variance,
        cycle_code, cycle_code_db, cycle_period, dop_connection, dop_connection_db, dop_netting,
        dop_netting_db, estimated_material_cost, excl_ship_pack_proposal, excl_ship_pack_proposal_db,
        expected_leadtime, ext_service_cost_method, ext_service_cost_method_db, forecast_consumption_flag,
        forecast_consumption_flag_db, frequency_class, frequency_class_db, inventory_part_cost_level,
        inventory_part_cost_level_db, invoice_consideration, invoice_consideration_db, lead_time_code,
        lead_time_code_db, lifecycle_stage, lifecycle_stage_db, mandatory_expiration_date,
        mandatory_expiration_date_db, manuf_leadtime, min_durab_days_co_deliv, min_durab_days_planning,
        negative_on_hand, negative_on_hand_db, oe_alloc_assign_flag, oe_alloc_assign_flag_db,
        onhand_analysis_flag, onhand_analysis_flag_db, part_catalog_configurable,
        part_catalog_configurable_db, part_catalog_std_name_id, part_status, planner_buyer, purch_leadtime,
        qty_calc_rounding, reset_config_std_cost, reset_config_std_cost_db, shortage_flag, shortage_flag_db,
        stock_management, stock_management_db, supply_code, supply_code_db, tax_manuf_equivalent,
        tax_manuf_equivalent_db, type_code, type_code_db
    )
    SELECT DISTINCT ON (TRIM(cmp.code_produit))
        -- site passe en parametre
        p_contract as contract,
        -- code_produit = cle des composants
        SUBSTRING(TRIM(cmp.code_produit), 1, 25) as part_no,
        SUBSTRING(TRIM(COALESCE(NULLIF(TRIM(cmp.libelle_produit), ''), cmp.code_produit)), 1, 200) as description,
        SUBSTRING(TRIM(COALESCE(NULLIF(TRIM(cmp.libelle_produit), ''), cmp.code_produit)), 1, 200) as description_copy,
        SUBSTRING(TRIM(COALESCE(NULLIF(TRIM(cmp.libelle_produit), ''), cmp.code_produit)), 1, 200) as description_in_use,
        SUBSTRING(TRIM(COALESCE(NULLIF(TRIM(cmp.libelle_produit), ''), cmp.code_produit)), 1, 200) as part_catalog_description,
        -- unite via transcodification UOM (KG -> kg)
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(TRIM(cmp.unite), '')),
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(cmp.unite)), '')),
            NULLIF(TRIM(cmp.unite), ''),
            'PCE'
        ), 1, 10) as unit_meas,
        -- famille composant (AL, MS, TM...) ; PART_PRODUCT_FAMILY reste vide (gabarit),
        -- la famille ne vit que dans c_family_code
        NULLIF(SUBSTRING(TRIM(COALESCE(cmp.famille, '')), 1, 2), '') as c_family_code,
        CAST(NULL AS character varying) as part_product_family,
        -- Articles rebut (code produit commencant par R, ex. RP-5000) : le code
        -- alliage est la partie numerique de tete apres le tiret et la serie vaut ce
        -- premier chiffre suivi de 000. Meme regle que le module PHL ; les gabarits
        -- composants laissent ces deux colonnes vides pour les autres articles.
        CASE WHEN UPPER(TRIM(cmp.code_produit)) LIKE 'R%'
             THEN SUBSTRING(SUBSTRING(TRIM(cmp.code_produit) FROM '^[A-Za-z]+-([0-9]+)'), 1, 12)
        END as c_alloy_code,
        CASE WHEN UPPER(TRIM(cmp.code_produit)) LIKE 'R%'
             THEN LEFT(SUBSTRING(TRIM(cmp.code_produit) FROM '^[A-Za-z]+-([0-9]+)'), 1) || '000'
        END as c_alloy_serie_code,
        -- controle_cout : "Cout nul autorise" -> Zero Cost Allowed / Y
        CASE WHEN UPPER(TRIM(COALESCE(cmp.controle_cout, ''))) LIKE '%NUL%'
             THEN 'Zero Cost Allowed' ELSE 'Zero Cost Not Allowed' END as zero_cost_flag,
        CASE WHEN UPPER(TRIM(COALESCE(cmp.controle_cout, ''))) LIKE '%NUL%'
             THEN 'Y' ELSE 'N' END as zero_cost_flag_db,
        -- methode de valorisation : seule valeur du gabarit qui diverge entre sites
        -- (SJ = Standard Cost / ST, CS = Weighted Average / AV) -> variante par site
        public.get_default_value('clean_data.inventory_part', 'inventory_valuation_method',
            'COMPOSANT_' || p_contract) as inventory_valuation_method,
        public.get_default_value('clean_data.inventory_part', 'inventory_valuation_method_db',
            'COMPOSANT_' || p_contract) as inventory_valuation_method_db,
        CURRENT_TIMESTAMP as create_date,
        CURRENT_TIMESTAMP as last_activity_date,
        public.get_default_value('clean_data.inventory_part', 'abc_class', 'COMPOSANT') as abc_class,
        public.get_default_value('clean_data.inventory_part', 'asset_class', 'COMPOSANT') as asset_class,
        public.get_default_value('clean_data.inventory_part', 'automatic_capability_check', 'COMPOSANT') as automatic_capability_check,
        public.get_default_value('clean_data.inventory_part', 'automatic_capability_check_db', 'COMPOSANT') as automatic_capability_check_db,
        public.get_default_value('clean_data.inventory_part', 'avail_activity_status', 'COMPOSANT') as avail_activity_status,
        public.get_default_value('clean_data.inventory_part', 'avail_activity_status_db', 'COMPOSANT') as avail_activity_status_db,
        public.get_default_value('clean_data.inventory_part', 'c_is_green', 'COMPOSANT') as c_is_green,
        public.get_default_value('clean_data.inventory_part', 'c_is_green_db', 'COMPOSANT') as c_is_green_db,
        public.get_default_value('clean_data.inventory_part', 'co_reserve_onh_analys_flag', 'COMPOSANT') as co_reserve_onh_analys_flag,
        public.get_default_value('clean_data.inventory_part', 'co_reserve_onh_analys_flag_db', 'COMPOSANT') as co_reserve_onh_analys_flag_db,
        public.get_default_value('clean_data.inventory_part', 'company', 'COMPOSANT') as company,
        public.get_default_value('clean_data.inventory_part', 'consumption_tax', 'COMPOSANT') as consumption_tax,
        public.get_default_value('clean_data.inventory_part', 'consumption_tax_db', 'COMPOSANT') as consumption_tax_db,
        public.get_default_value('clean_data.inventory_part', 'count_variance', 'COMPOSANT')::numeric as count_variance,
        public.get_default_value('clean_data.inventory_part', 'cycle_code', 'COMPOSANT') as cycle_code,
        public.get_default_value('clean_data.inventory_part', 'cycle_code_db', 'COMPOSANT') as cycle_code_db,
        public.get_default_value('clean_data.inventory_part', 'cycle_period', 'COMPOSANT')::numeric as cycle_period,
        public.get_default_value('clean_data.inventory_part', 'dop_connection', 'COMPOSANT') as dop_connection,
        public.get_default_value('clean_data.inventory_part', 'dop_connection_db', 'COMPOSANT') as dop_connection_db,
        public.get_default_value('clean_data.inventory_part', 'dop_netting', 'COMPOSANT') as dop_netting,
        public.get_default_value('clean_data.inventory_part', 'dop_netting_db', 'COMPOSANT') as dop_netting_db,
        public.get_default_value('clean_data.inventory_part', 'estimated_material_cost', 'COMPOSANT')::numeric as estimated_material_cost,
        public.get_default_value('clean_data.inventory_part', 'excl_ship_pack_proposal', 'COMPOSANT') as excl_ship_pack_proposal,
        public.get_default_value('clean_data.inventory_part', 'excl_ship_pack_proposal_db', 'COMPOSANT') as excl_ship_pack_proposal_db,
        public.get_default_value('clean_data.inventory_part', 'expected_leadtime', 'COMPOSANT')::numeric as expected_leadtime,
        public.get_default_value('clean_data.inventory_part', 'ext_service_cost_method', 'COMPOSANT') as ext_service_cost_method,
        public.get_default_value('clean_data.inventory_part', 'ext_service_cost_method_db', 'COMPOSANT') as ext_service_cost_method_db,
        public.get_default_value('clean_data.inventory_part', 'forecast_consumption_flag', 'COMPOSANT') as forecast_consumption_flag,
        public.get_default_value('clean_data.inventory_part', 'forecast_consumption_flag_db', 'COMPOSANT') as forecast_consumption_flag_db,
        public.get_default_value('clean_data.inventory_part', 'frequency_class', 'COMPOSANT') as frequency_class,
        public.get_default_value('clean_data.inventory_part', 'frequency_class_db', 'COMPOSANT') as frequency_class_db,
        public.get_default_value('clean_data.inventory_part', 'inventory_part_cost_level', 'COMPOSANT') as inventory_part_cost_level,
        public.get_default_value('clean_data.inventory_part', 'inventory_part_cost_level_db', 'COMPOSANT') as inventory_part_cost_level_db,
        public.get_default_value('clean_data.inventory_part', 'invoice_consideration', 'COMPOSANT') as invoice_consideration,
        public.get_default_value('clean_data.inventory_part', 'invoice_consideration_db', 'COMPOSANT') as invoice_consideration_db,
        public.get_default_value('clean_data.inventory_part', 'lead_time_code', 'COMPOSANT') as lead_time_code,
        public.get_default_value('clean_data.inventory_part', 'lead_time_code_db', 'COMPOSANT') as lead_time_code_db,
        public.get_default_value('clean_data.inventory_part', 'lifecycle_stage', 'COMPOSANT') as lifecycle_stage,
        public.get_default_value('clean_data.inventory_part', 'lifecycle_stage_db', 'COMPOSANT') as lifecycle_stage_db,
        public.get_default_value('clean_data.inventory_part', 'mandatory_expiration_date', 'COMPOSANT') as mandatory_expiration_date,
        public.get_default_value('clean_data.inventory_part', 'mandatory_expiration_date_db', 'COMPOSANT') as mandatory_expiration_date_db,
        public.get_default_value('clean_data.inventory_part', 'manuf_leadtime', 'COMPOSANT')::numeric as manuf_leadtime,
        public.get_default_value('clean_data.inventory_part', 'min_durab_days_co_deliv', 'COMPOSANT')::numeric as min_durab_days_co_deliv,
        public.get_default_value('clean_data.inventory_part', 'min_durab_days_planning', 'COMPOSANT')::numeric as min_durab_days_planning,
        public.get_default_value('clean_data.inventory_part', 'negative_on_hand', 'COMPOSANT') as negative_on_hand,
        public.get_default_value('clean_data.inventory_part', 'negative_on_hand_db', 'COMPOSANT') as negative_on_hand_db,
        public.get_default_value('clean_data.inventory_part', 'oe_alloc_assign_flag', 'COMPOSANT') as oe_alloc_assign_flag,
        public.get_default_value('clean_data.inventory_part', 'oe_alloc_assign_flag_db', 'COMPOSANT') as oe_alloc_assign_flag_db,
        public.get_default_value('clean_data.inventory_part', 'onhand_analysis_flag', 'COMPOSANT') as onhand_analysis_flag,
        public.get_default_value('clean_data.inventory_part', 'onhand_analysis_flag_db', 'COMPOSANT') as onhand_analysis_flag_db,
        public.get_default_value('clean_data.inventory_part', 'part_catalog_configurable', 'COMPOSANT') as part_catalog_configurable,
        public.get_default_value('clean_data.inventory_part', 'part_catalog_configurable_db', 'COMPOSANT') as part_catalog_configurable_db,
        public.get_default_value('clean_data.inventory_part', 'part_catalog_std_name_id', 'COMPOSANT')::numeric as part_catalog_std_name_id,
        public.get_default_value('clean_data.inventory_part', 'part_status', 'COMPOSANT') as part_status,
        public.get_default_value('clean_data.inventory_part', 'planner_buyer', 'COMPOSANT') as planner_buyer,
        public.get_default_value('clean_data.inventory_part', 'purch_leadtime', 'COMPOSANT')::numeric as purch_leadtime,
        public.get_default_value('clean_data.inventory_part', 'qty_calc_rounding', 'COMPOSANT')::numeric as qty_calc_rounding,
        public.get_default_value('clean_data.inventory_part', 'reset_config_std_cost', 'COMPOSANT') as reset_config_std_cost,
        public.get_default_value('clean_data.inventory_part', 'reset_config_std_cost_db', 'COMPOSANT') as reset_config_std_cost_db,
        public.get_default_value('clean_data.inventory_part', 'shortage_flag', 'COMPOSANT') as shortage_flag,
        public.get_default_value('clean_data.inventory_part', 'shortage_flag_db', 'COMPOSANT') as shortage_flag_db,
        public.get_default_value('clean_data.inventory_part', 'stock_management', 'COMPOSANT') as stock_management,
        public.get_default_value('clean_data.inventory_part', 'stock_management_db', 'COMPOSANT') as stock_management_db,
        public.get_default_value('clean_data.inventory_part', 'supply_code', 'COMPOSANT') as supply_code,
        public.get_default_value('clean_data.inventory_part', 'supply_code_db', 'COMPOSANT') as supply_code_db,
        public.get_default_value('clean_data.inventory_part', 'tax_manuf_equivalent', 'COMPOSANT') as tax_manuf_equivalent,
        public.get_default_value('clean_data.inventory_part', 'tax_manuf_equivalent_db', 'COMPOSANT') as tax_manuf_equivalent_db,
        public.get_default_value('clean_data.inventory_part', 'type_code', 'COMPOSANT') as type_code,
        public.get_default_value('clean_data.inventory_part', 'type_code_db', 'COMPOSANT') as type_code_db
    FROM raw_data.composant_sj_cs cmp
    WHERE cmp.code_produit IS NOT NULL
      AND TRIM(cmp.code_produit) != ''
      -- Seules les lignes du site charge
      AND UPPER(TRIM(COALESCE(cmp.site, ''))) = p_contract
      -- L'article doit exister dans part_catalog (table de base)
      AND EXISTS (
          SELECT 1 FROM clean_data.part_catalog pc
          WHERE pc.part_no = SUBSTRING(TRIM(cmp.code_produit), 1, 25)
      )
      -- Ne pas dupliquer une ligne (contract, part_no) deja presente
      AND NOT EXISTS (
          SELECT 1 FROM clean_data.inventory_part ip
          WHERE ip.contract = p_contract
            AND ip.part_no = SUBSTRING(TRIM(cmp.code_produit), 1, 25)
      )
    ORDER BY TRIM(cmp.code_produit);
    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;
    -- Re-execution idempotente : l'INSERT ci-dessus ignore les lignes existantes,
    -- on realigne donc les colonnes du gabarit sur les lignes deja presentes
    -- (create_date et last_activity_date sont exclus : ils dateraient de la re-execution).
    WITH src AS (
        SELECT DISTINCT ON (TRIM(cmp.code_produit))
            SUBSTRING(TRIM(cmp.code_produit), 1, 25) as part_no,
            SUBSTRING(TRIM(COALESCE(NULLIF(TRIM(cmp.libelle_produit), ''), cmp.code_produit)), 1, 200) as description,
            SUBSTRING(TRIM(COALESCE(NULLIF(TRIM(cmp.libelle_produit), ''), cmp.code_produit)), 1, 200) as description_copy,
            SUBSTRING(TRIM(COALESCE(NULLIF(TRIM(cmp.libelle_produit), ''), cmp.code_produit)), 1, 200) as description_in_use,
            SUBSTRING(TRIM(COALESCE(NULLIF(TRIM(cmp.libelle_produit), ''), cmp.code_produit)), 1, 200) as part_catalog_description,
            SUBSTRING(COALESCE(
                public.get_transcodification('UOM', NULLIF(TRIM(cmp.unite), '')),
                public.get_transcodification('UOM', NULLIF(UPPER(TRIM(cmp.unite)), '')),
                NULLIF(TRIM(cmp.unite), ''),
                'PCE'
            ), 1, 10) as unit_meas,
            NULLIF(SUBSTRING(TRIM(COALESCE(cmp.famille, '')), 1, 2), '') as c_family_code,
            CAST(NULL AS character varying) as part_product_family,
            -- Articles rebut (code produit commencant par R, ex. RP-5000) : le code
            -- alliage est la partie numerique de tete apres le tiret et la serie vaut ce
            -- premier chiffre suivi de 000. Meme regle que le module PHL ; les gabarits
            -- composants laissent ces deux colonnes vides pour les autres articles.
            CASE WHEN UPPER(TRIM(cmp.code_produit)) LIKE 'R%'
                 THEN SUBSTRING(SUBSTRING(TRIM(cmp.code_produit) FROM '^[A-Za-z]+-([0-9]+)'), 1, 12)
            END as c_alloy_code,
            CASE WHEN UPPER(TRIM(cmp.code_produit)) LIKE 'R%'
                 THEN LEFT(SUBSTRING(TRIM(cmp.code_produit) FROM '^[A-Za-z]+-([0-9]+)'), 1) || '000'
            END as c_alloy_serie_code,
            CASE WHEN UPPER(TRIM(COALESCE(cmp.controle_cout, ''))) LIKE '%NUL%'
                 THEN 'Zero Cost Allowed' ELSE 'Zero Cost Not Allowed' END as zero_cost_flag,
            CASE WHEN UPPER(TRIM(COALESCE(cmp.controle_cout, ''))) LIKE '%NUL%'
                 THEN 'Y' ELSE 'N' END as zero_cost_flag_db,
            public.get_default_value('clean_data.inventory_part', 'inventory_valuation_method',
                'COMPOSANT_' || p_contract) as inventory_valuation_method,
            public.get_default_value('clean_data.inventory_part', 'inventory_valuation_method_db',
                'COMPOSANT_' || p_contract) as inventory_valuation_method_db,
            public.get_default_value('clean_data.inventory_part', 'abc_class', 'COMPOSANT') as abc_class,
            public.get_default_value('clean_data.inventory_part', 'asset_class', 'COMPOSANT') as asset_class,
            public.get_default_value('clean_data.inventory_part', 'automatic_capability_check', 'COMPOSANT') as automatic_capability_check,
            public.get_default_value('clean_data.inventory_part', 'automatic_capability_check_db', 'COMPOSANT') as automatic_capability_check_db,
            public.get_default_value('clean_data.inventory_part', 'avail_activity_status', 'COMPOSANT') as avail_activity_status,
            public.get_default_value('clean_data.inventory_part', 'avail_activity_status_db', 'COMPOSANT') as avail_activity_status_db,
            public.get_default_value('clean_data.inventory_part', 'c_is_green', 'COMPOSANT') as c_is_green,
            public.get_default_value('clean_data.inventory_part', 'c_is_green_db', 'COMPOSANT') as c_is_green_db,
            public.get_default_value('clean_data.inventory_part', 'co_reserve_onh_analys_flag', 'COMPOSANT') as co_reserve_onh_analys_flag,
            public.get_default_value('clean_data.inventory_part', 'co_reserve_onh_analys_flag_db', 'COMPOSANT') as co_reserve_onh_analys_flag_db,
            public.get_default_value('clean_data.inventory_part', 'company', 'COMPOSANT') as company,
            public.get_default_value('clean_data.inventory_part', 'consumption_tax', 'COMPOSANT') as consumption_tax,
            public.get_default_value('clean_data.inventory_part', 'consumption_tax_db', 'COMPOSANT') as consumption_tax_db,
            public.get_default_value('clean_data.inventory_part', 'count_variance', 'COMPOSANT')::numeric as count_variance,
            public.get_default_value('clean_data.inventory_part', 'cycle_code', 'COMPOSANT') as cycle_code,
            public.get_default_value('clean_data.inventory_part', 'cycle_code_db', 'COMPOSANT') as cycle_code_db,
            public.get_default_value('clean_data.inventory_part', 'cycle_period', 'COMPOSANT')::numeric as cycle_period,
            public.get_default_value('clean_data.inventory_part', 'dop_connection', 'COMPOSANT') as dop_connection,
            public.get_default_value('clean_data.inventory_part', 'dop_connection_db', 'COMPOSANT') as dop_connection_db,
            public.get_default_value('clean_data.inventory_part', 'dop_netting', 'COMPOSANT') as dop_netting,
            public.get_default_value('clean_data.inventory_part', 'dop_netting_db', 'COMPOSANT') as dop_netting_db,
            public.get_default_value('clean_data.inventory_part', 'estimated_material_cost', 'COMPOSANT')::numeric as estimated_material_cost,
            public.get_default_value('clean_data.inventory_part', 'excl_ship_pack_proposal', 'COMPOSANT') as excl_ship_pack_proposal,
            public.get_default_value('clean_data.inventory_part', 'excl_ship_pack_proposal_db', 'COMPOSANT') as excl_ship_pack_proposal_db,
            public.get_default_value('clean_data.inventory_part', 'expected_leadtime', 'COMPOSANT')::numeric as expected_leadtime,
            public.get_default_value('clean_data.inventory_part', 'ext_service_cost_method', 'COMPOSANT') as ext_service_cost_method,
            public.get_default_value('clean_data.inventory_part', 'ext_service_cost_method_db', 'COMPOSANT') as ext_service_cost_method_db,
            public.get_default_value('clean_data.inventory_part', 'forecast_consumption_flag', 'COMPOSANT') as forecast_consumption_flag,
            public.get_default_value('clean_data.inventory_part', 'forecast_consumption_flag_db', 'COMPOSANT') as forecast_consumption_flag_db,
            public.get_default_value('clean_data.inventory_part', 'frequency_class', 'COMPOSANT') as frequency_class,
            public.get_default_value('clean_data.inventory_part', 'frequency_class_db', 'COMPOSANT') as frequency_class_db,
            public.get_default_value('clean_data.inventory_part', 'inventory_part_cost_level', 'COMPOSANT') as inventory_part_cost_level,
            public.get_default_value('clean_data.inventory_part', 'inventory_part_cost_level_db', 'COMPOSANT') as inventory_part_cost_level_db,
            public.get_default_value('clean_data.inventory_part', 'invoice_consideration', 'COMPOSANT') as invoice_consideration,
            public.get_default_value('clean_data.inventory_part', 'invoice_consideration_db', 'COMPOSANT') as invoice_consideration_db,
            public.get_default_value('clean_data.inventory_part', 'lead_time_code', 'COMPOSANT') as lead_time_code,
            public.get_default_value('clean_data.inventory_part', 'lead_time_code_db', 'COMPOSANT') as lead_time_code_db,
            public.get_default_value('clean_data.inventory_part', 'lifecycle_stage', 'COMPOSANT') as lifecycle_stage,
            public.get_default_value('clean_data.inventory_part', 'lifecycle_stage_db', 'COMPOSANT') as lifecycle_stage_db,
            public.get_default_value('clean_data.inventory_part', 'mandatory_expiration_date', 'COMPOSANT') as mandatory_expiration_date,
            public.get_default_value('clean_data.inventory_part', 'mandatory_expiration_date_db', 'COMPOSANT') as mandatory_expiration_date_db,
            public.get_default_value('clean_data.inventory_part', 'manuf_leadtime', 'COMPOSANT')::numeric as manuf_leadtime,
            public.get_default_value('clean_data.inventory_part', 'min_durab_days_co_deliv', 'COMPOSANT')::numeric as min_durab_days_co_deliv,
            public.get_default_value('clean_data.inventory_part', 'min_durab_days_planning', 'COMPOSANT')::numeric as min_durab_days_planning,
            public.get_default_value('clean_data.inventory_part', 'negative_on_hand', 'COMPOSANT') as negative_on_hand,
            public.get_default_value('clean_data.inventory_part', 'negative_on_hand_db', 'COMPOSANT') as negative_on_hand_db,
            public.get_default_value('clean_data.inventory_part', 'oe_alloc_assign_flag', 'COMPOSANT') as oe_alloc_assign_flag,
            public.get_default_value('clean_data.inventory_part', 'oe_alloc_assign_flag_db', 'COMPOSANT') as oe_alloc_assign_flag_db,
            public.get_default_value('clean_data.inventory_part', 'onhand_analysis_flag', 'COMPOSANT') as onhand_analysis_flag,
            public.get_default_value('clean_data.inventory_part', 'onhand_analysis_flag_db', 'COMPOSANT') as onhand_analysis_flag_db,
            public.get_default_value('clean_data.inventory_part', 'part_catalog_configurable', 'COMPOSANT') as part_catalog_configurable,
            public.get_default_value('clean_data.inventory_part', 'part_catalog_configurable_db', 'COMPOSANT') as part_catalog_configurable_db,
            public.get_default_value('clean_data.inventory_part', 'part_catalog_std_name_id', 'COMPOSANT')::numeric as part_catalog_std_name_id,
            public.get_default_value('clean_data.inventory_part', 'part_status', 'COMPOSANT') as part_status,
            public.get_default_value('clean_data.inventory_part', 'planner_buyer', 'COMPOSANT') as planner_buyer,
            public.get_default_value('clean_data.inventory_part', 'purch_leadtime', 'COMPOSANT')::numeric as purch_leadtime,
            public.get_default_value('clean_data.inventory_part', 'qty_calc_rounding', 'COMPOSANT')::numeric as qty_calc_rounding,
            public.get_default_value('clean_data.inventory_part', 'reset_config_std_cost', 'COMPOSANT') as reset_config_std_cost,
            public.get_default_value('clean_data.inventory_part', 'reset_config_std_cost_db', 'COMPOSANT') as reset_config_std_cost_db,
            public.get_default_value('clean_data.inventory_part', 'shortage_flag', 'COMPOSANT') as shortage_flag,
            public.get_default_value('clean_data.inventory_part', 'shortage_flag_db', 'COMPOSANT') as shortage_flag_db,
            public.get_default_value('clean_data.inventory_part', 'stock_management', 'COMPOSANT') as stock_management,
            public.get_default_value('clean_data.inventory_part', 'stock_management_db', 'COMPOSANT') as stock_management_db,
            public.get_default_value('clean_data.inventory_part', 'supply_code', 'COMPOSANT') as supply_code,
            public.get_default_value('clean_data.inventory_part', 'supply_code_db', 'COMPOSANT') as supply_code_db,
            public.get_default_value('clean_data.inventory_part', 'tax_manuf_equivalent', 'COMPOSANT') as tax_manuf_equivalent,
            public.get_default_value('clean_data.inventory_part', 'tax_manuf_equivalent_db', 'COMPOSANT') as tax_manuf_equivalent_db,
            public.get_default_value('clean_data.inventory_part', 'type_code', 'COMPOSANT') as type_code,
            public.get_default_value('clean_data.inventory_part', 'type_code_db', 'COMPOSANT') as type_code_db
        FROM raw_data.composant_sj_cs cmp
        WHERE cmp.code_produit IS NOT NULL
          AND TRIM(cmp.code_produit) != ''
          AND UPPER(TRIM(COALESCE(cmp.site, ''))) = p_contract
        ORDER BY TRIM(cmp.code_produit)
    )
    UPDATE clean_data.inventory_part ip
    SET description = src.description,
        description_copy = src.description_copy,
        description_in_use = src.description_in_use,
        part_catalog_description = src.part_catalog_description,
        unit_meas = src.unit_meas,
        c_family_code = src.c_family_code,
        part_product_family = src.part_product_family,
        c_alloy_code = src.c_alloy_code,
        c_alloy_serie_code = src.c_alloy_serie_code,
        zero_cost_flag = src.zero_cost_flag,
        zero_cost_flag_db = src.zero_cost_flag_db,
        inventory_valuation_method = src.inventory_valuation_method,
        inventory_valuation_method_db = src.inventory_valuation_method_db,
        abc_class = src.abc_class,
        asset_class = src.asset_class,
        automatic_capability_check = src.automatic_capability_check,
        automatic_capability_check_db = src.automatic_capability_check_db,
        avail_activity_status = src.avail_activity_status,
        avail_activity_status_db = src.avail_activity_status_db,
        c_is_green = src.c_is_green,
        c_is_green_db = src.c_is_green_db,
        co_reserve_onh_analys_flag = src.co_reserve_onh_analys_flag,
        co_reserve_onh_analys_flag_db = src.co_reserve_onh_analys_flag_db,
        company = src.company,
        consumption_tax = src.consumption_tax,
        consumption_tax_db = src.consumption_tax_db,
        count_variance = src.count_variance,
        cycle_code = src.cycle_code,
        cycle_code_db = src.cycle_code_db,
        cycle_period = src.cycle_period,
        dop_connection = src.dop_connection,
        dop_connection_db = src.dop_connection_db,
        dop_netting = src.dop_netting,
        dop_netting_db = src.dop_netting_db,
        estimated_material_cost = src.estimated_material_cost,
        excl_ship_pack_proposal = src.excl_ship_pack_proposal,
        excl_ship_pack_proposal_db = src.excl_ship_pack_proposal_db,
        expected_leadtime = src.expected_leadtime,
        ext_service_cost_method = src.ext_service_cost_method,
        ext_service_cost_method_db = src.ext_service_cost_method_db,
        forecast_consumption_flag = src.forecast_consumption_flag,
        forecast_consumption_flag_db = src.forecast_consumption_flag_db,
        frequency_class = src.frequency_class,
        frequency_class_db = src.frequency_class_db,
        inventory_part_cost_level = src.inventory_part_cost_level,
        inventory_part_cost_level_db = src.inventory_part_cost_level_db,
        invoice_consideration = src.invoice_consideration,
        invoice_consideration_db = src.invoice_consideration_db,
        lead_time_code = src.lead_time_code,
        lead_time_code_db = src.lead_time_code_db,
        lifecycle_stage = src.lifecycle_stage,
        lifecycle_stage_db = src.lifecycle_stage_db,
        mandatory_expiration_date = src.mandatory_expiration_date,
        mandatory_expiration_date_db = src.mandatory_expiration_date_db,
        manuf_leadtime = src.manuf_leadtime,
        min_durab_days_co_deliv = src.min_durab_days_co_deliv,
        min_durab_days_planning = src.min_durab_days_planning,
        negative_on_hand = src.negative_on_hand,
        negative_on_hand_db = src.negative_on_hand_db,
        oe_alloc_assign_flag = src.oe_alloc_assign_flag,
        oe_alloc_assign_flag_db = src.oe_alloc_assign_flag_db,
        onhand_analysis_flag = src.onhand_analysis_flag,
        onhand_analysis_flag_db = src.onhand_analysis_flag_db,
        part_catalog_configurable = src.part_catalog_configurable,
        part_catalog_configurable_db = src.part_catalog_configurable_db,
        part_catalog_std_name_id = src.part_catalog_std_name_id,
        part_status = src.part_status,
        planner_buyer = src.planner_buyer,
        purch_leadtime = src.purch_leadtime,
        qty_calc_rounding = src.qty_calc_rounding,
        reset_config_std_cost = src.reset_config_std_cost,
        reset_config_std_cost_db = src.reset_config_std_cost_db,
        shortage_flag = src.shortage_flag,
        shortage_flag_db = src.shortage_flag_db,
        stock_management = src.stock_management,
        stock_management_db = src.stock_management_db,
        supply_code = src.supply_code,
        supply_code_db = src.supply_code_db,
        tax_manuf_equivalent = src.tax_manuf_equivalent,
        tax_manuf_equivalent_db = src.tax_manuf_equivalent_db,
        type_code = src.type_code,
        type_code_db = src.type_code_db
    FROM src
    WHERE ip.contract = p_contract
      AND ip.part_no = src.part_no
      AND (
           ip.description, ip.description_copy, ip.description_in_use, ip.part_catalog_description,
           ip.unit_meas, ip.c_family_code, ip.part_product_family, ip.c_alloy_code, ip.c_alloy_serie_code, ip.zero_cost_flag, ip.zero_cost_flag_db,
           ip.inventory_valuation_method, ip.inventory_valuation_method_db, ip.abc_class, ip.asset_class,
           ip.automatic_capability_check, ip.automatic_capability_check_db, ip.avail_activity_status,
           ip.avail_activity_status_db, ip.c_is_green, ip.c_is_green_db, ip.co_reserve_onh_analys_flag,
           ip.co_reserve_onh_analys_flag_db, ip.company, ip.consumption_tax, ip.consumption_tax_db,
           ip.count_variance, ip.cycle_code, ip.cycle_code_db, ip.cycle_period, ip.dop_connection,
           ip.dop_connection_db, ip.dop_netting, ip.dop_netting_db, ip.estimated_material_cost,
           ip.excl_ship_pack_proposal, ip.excl_ship_pack_proposal_db, ip.expected_leadtime,
           ip.ext_service_cost_method, ip.ext_service_cost_method_db, ip.forecast_consumption_flag,
           ip.forecast_consumption_flag_db, ip.frequency_class, ip.frequency_class_db,
           ip.inventory_part_cost_level, ip.inventory_part_cost_level_db, ip.invoice_consideration,
           ip.invoice_consideration_db, ip.lead_time_code, ip.lead_time_code_db, ip.lifecycle_stage,
           ip.lifecycle_stage_db, ip.mandatory_expiration_date, ip.mandatory_expiration_date_db,
           ip.manuf_leadtime, ip.min_durab_days_co_deliv, ip.min_durab_days_planning, ip.negative_on_hand,
           ip.negative_on_hand_db, ip.oe_alloc_assign_flag, ip.oe_alloc_assign_flag_db,
           ip.onhand_analysis_flag, ip.onhand_analysis_flag_db, ip.part_catalog_configurable,
           ip.part_catalog_configurable_db, ip.part_catalog_std_name_id, ip.part_status, ip.planner_buyer,
           ip.purch_leadtime, ip.qty_calc_rounding, ip.reset_config_std_cost, ip.reset_config_std_cost_db,
           ip.shortage_flag, ip.shortage_flag_db, ip.stock_management, ip.stock_management_db,
           ip.supply_code, ip.supply_code_db, ip.tax_manuf_equivalent, ip.tax_manuf_equivalent_db,
           ip.type_code, ip.type_code_db
          ) IS DISTINCT FROM (
           src.description, src.description_copy, src.description_in_use, src.part_catalog_description,
           src.unit_meas, src.c_family_code, src.part_product_family, src.c_alloy_code, src.c_alloy_serie_code, src.zero_cost_flag, src.zero_cost_flag_db,
           src.inventory_valuation_method, src.inventory_valuation_method_db, src.abc_class, src.asset_class,
           src.automatic_capability_check, src.automatic_capability_check_db, src.avail_activity_status,
           src.avail_activity_status_db, src.c_is_green, src.c_is_green_db, src.co_reserve_onh_analys_flag,
           src.co_reserve_onh_analys_flag_db, src.company, src.consumption_tax, src.consumption_tax_db,
           src.count_variance, src.cycle_code, src.cycle_code_db, src.cycle_period, src.dop_connection,
           src.dop_connection_db, src.dop_netting, src.dop_netting_db, src.estimated_material_cost,
           src.excl_ship_pack_proposal, src.excl_ship_pack_proposal_db, src.expected_leadtime,
           src.ext_service_cost_method, src.ext_service_cost_method_db, src.forecast_consumption_flag,
           src.forecast_consumption_flag_db, src.frequency_class, src.frequency_class_db,
           src.inventory_part_cost_level, src.inventory_part_cost_level_db, src.invoice_consideration,
           src.invoice_consideration_db, src.lead_time_code, src.lead_time_code_db, src.lifecycle_stage,
           src.lifecycle_stage_db, src.mandatory_expiration_date, src.mandatory_expiration_date_db,
           src.manuf_leadtime, src.min_durab_days_co_deliv, src.min_durab_days_planning,
           src.negative_on_hand, src.negative_on_hand_db, src.oe_alloc_assign_flag,
           src.oe_alloc_assign_flag_db, src.onhand_analysis_flag, src.onhand_analysis_flag_db,
           src.part_catalog_configurable, src.part_catalog_configurable_db, src.part_catalog_std_name_id,
           src.part_status, src.planner_buyer, src.purch_leadtime, src.qty_calc_rounding,
           src.reset_config_std_cost, src.reset_config_std_cost_db, src.shortage_flag, src.shortage_flag_db,
           src.stock_management, src.stock_management_db, src.supply_code, src.supply_code_db,
           src.tax_manuf_equivalent, src.tax_manuf_equivalent_db, src.type_code, src.type_code_db
          );
    GET DIAGNOSTICS v_count_updated = ROW_COUNT;
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Alimentation INVENTORY_PART (composants) terminee avec succes';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Composants inseres: %', v_count_inserted;
    RAISE NOTICE 'Composants realignes sur le gabarit: %', v_count_updated;
    RAISE NOTICE 'Duree d''execution: %', v_duration;
    RAISE NOTICE '====================================================';
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'ERREUR lors de l''alimentation INVENTORY_PART (composants)';
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'Code d''erreur: %', SQLSTATE;
        RAISE NOTICE 'Message: %', SQLERRM;
        RAISE NOTICE 'Duree avant erreur: %', v_duration;
        RAISE NOTICE '====================================================';
        RAISE;
END;
$function$
;
