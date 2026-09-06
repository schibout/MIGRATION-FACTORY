-- L'ancienne signature sans parametre doit disparaitre, sinon PostgreSQL cree une
-- surcharge et les appels sans argument deviennent ambigus.
DROP FUNCTION IF EXISTS clean_data.alimenter_inventory_part_phl();
CREATE OR REPLACE FUNCTION clean_data.alimenter_inventory_part_phl(p_contract text DEFAULT 'SJ')
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_count_inserted INTEGER := 0;
    v_count_updated INTEGER := 0;
    v_count_updated_part_catalog INTEGER := 0;
    v_count_updated_manuf_part_attribute INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL;
BEGIN
    IF p_contract NOT IN ('SJ', 'CS') THEN
        RAISE EXCEPTION 'Site invalide: % (attendu: SJ ou CS)', p_contract;
    END IF;
    v_start_time := CURRENT_TIMESTAMP;
    RAISE NOTICE 'Debut de l''alimentation INVENTORY_PART (articles PHL, site %) - %', p_contract, v_start_time;
    INSERT INTO clean_data.inventory_part (
        contract,
        part_no,
        description,
        description_copy,
        part_cat_lang_description,
        note_text,
        unit_meas,
        part_status,
        std_name_id,
        part_product_code,
        part_product_family,
        prime_commodity,
        accounting_group,
        type_code,
        supply_code,
        cust_warranty_id,
        sup_warranty_id,
        avail_activity_status,
        avail_activity_status_db,
        part_catalog_configurable,
        part_catalog_configurable_db,
        input_unit_meas_group_id,
        type_designation,
        customs_stat_no,
        statistical_code,
        oe_alloc_assign_flag,
        oe_alloc_assign_flag_db,
        c_diameter,
        c_density,
        c_alloy_code,
        c_alloy_serie_code,
        c_family_code,
        c_epaisseur_brut,
        c_longueur_brut,
        c_largeur_brut,
        c_commercial_weight,
        c_forme_code,
        c_sawing_code,
        c_load_standard_code,
        c_final_state_code,
        c_spire_code,
        storage_weight_requirement,
        storage_volume_requirement,
        intrastat_conv_factor,
        planner_buyer,
        asset_class,
        country_of_origin,
        type_code_db,
        supply_code_db,
        expected_leadtime,
        manuf_leadtime,
        purch_leadtime,
        lead_time_code_db,
        inventory_valuation_method_db,
        count_variance,
        cycle_code_db,
        cycle_period,
        qty_calc_rounding,
        zero_cost_flag_db,
        onhand_analysis_flag_db,
        shortage_flag_db,
        forecast_consumption_flag_db,
        stock_management_db,
        dop_connection_db,
        negative_on_hand_db,
        invoice_consideration_db,
        inventory_part_cost_level_db,
        ext_service_cost_method_db,
        automatic_capability_check_db,
        dop_netting_db,
        co_reserve_onh_analys_flag_db,
        mandatory_expiration_date_db,
        excl_ship_pack_proposal_db,
        reset_config_std_cost_db,
        lifecycle_stage_db,
        frequency_class_db,
        abc_class,
        hsn_sac_code,
        company,
        create_date,
        hazard_code,
        note_id,
        second_commodity,
        catch_unit_meas,
        abc_class_locked_until,
        cycle_code,
        dim_quality,
        durability_day,
        lead_time_code,
        onhand_analysis_flag,
        earliest_ultd_supply_date,
        supersedes,
        zero_cost_flag,
        eng_attribute,
        shortage_flag,
        forecast_consumption_flag,
        stock_management,
        part_cost_group_id,
        dop_connection,
        inventory_valuation_method,
        negative_on_hand,
        technical_coordinator_id,
        invoice_consideration,
        actual_cost_activated,
        max_actual_cost_update,
        region_of_origin,
        inventory_part_cost_level,
        ext_service_cost_method,
        supply_chain_part_group,
        automatic_capability_check,
        dop_netting,
        co_reserve_onh_analys_flag,
        lifecycle_stage,
        life_stage_locked_until,
        frequency_class,
        freq_class_locked_until,
        first_stat_issue_date,
        latest_stat_issue_date,
        latest_stat_affecting_date,
        decline_date,
        expired_date,
        decline_issue_counter,
        expired_issue_counter,
        min_durab_days_co_deliv,
        min_durab_days_planning,
        storage_width_requirement,
        storage_height_requirement,
        storage_depth_requirement,
        min_storage_temperature,
        max_storage_temperature,
        min_storage_humidity,
        max_storage_humidity,
        standard_putaway_qty,
        putaway_zone_refill_option,
        putaway_zone_refill_option_db,
        reset_config_std_cost,
        mandatory_expiration_date,
        excl_ship_pack_proposal,
        acquisition_origin,
        acquisition_reason_id,
        product_category_id,
        consumption_tax,
        consumption_tax_db,
        tax_manuf_equivalent,
        tax_manuf_equivalent_db,
        c_amma_type,
        c_amma_type_db,
        c_recasting_type,
        c_recasting_type_db,
        c_is_green,
        c_is_green_db,
        c_green_percentage,
        c_green_percentage_db,
        part_catalog_description,
        part_catalog_std_name_id,
        estimated_material_cost,
        description_in_use,
        last_activity_date
    )
    SELECT DISTINCT ON (TRIM(phl."N. ARTICLE"))
        p_contract as contract,
        SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25) as part_no,
        SUBSTRING(TRIM(COALESCE(NULLIF(phl."DESCRIPTION", ''), phl."DESCRIPTION LANGUE", phl."N. ARTICLE")), 1, 200) as description,
        SUBSTRING(TRIM(COALESCE(NULLIF(phl."DESCRIPTION", ''), phl."DESCRIPTION LANGUE", phl."N. ARTICLE")), 1, 200) as description_copy,
        NULLIF(SUBSTRING(TRIM(COALESCE(phl."DESCRIPTION LANGUE", '')), 1, 200), '') as part_cat_lang_description,
        NULLIF(SUBSTRING(TRIM(COALESCE(phl."TEXTE INFO", '')), 1, 2000), '') as note_text,
        CASE
            WHEN LOWER(TRIM(COALESCE(phl."U/M", ''))) = 't' THEN 'kg'
            ELSE SUBSTRING(COALESCE(
                public.get_transcodification('UOM', NULLIF(TRIM(phl."U/M"), ''), 'PHL', 'IFS'),
                public.get_transcodification('UOM', NULLIF(UPPER(TRIM(phl."U/M")), ''), 'PHL', 'IFS'),
                public.get_transcodification('UOM', NULLIF(TRIM(phl."U/M"), '')),
                public.get_transcodification('UOM', NULLIF(UPPER(TRIM(phl."U/M")), '')),
                NULLIF(TRIM(phl."U/M"), ''),
                'PCE'
            ), 1, 10)
        END as unit_meas,
        public.get_matrix_value('clean_data.inventory_part', 'part_status', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as part_status,
        NULLIF(NULLIF(TRIM(COALESCE(phl."ID NOM STD", '')), ''), '0')::numeric as std_name_id,
        NULLIF(SUBSTRING(TRIM(COALESCE(phl."NUM PRODUIT", '')), 1, 5), '') as part_product_code,
        NULLIF(SUBSTRING(TRIM(COALESCE(phl."FAMILLE", '')), 1, 5), '') as part_product_family,
        NULLIF(SUBSTRING(TRIM(COALESCE(phl."GP PRINCP ARTICLE", '')), 1, 5), '') as prime_commodity,
        NULLIF(SUBSTRING(TRIM(COALESCE(phl."CLASSIF TYPE PROD.", '')), 1, 5), '') as accounting_group,
        NULLIF(SUBSTRING(TRIM(COALESCE(phl."ARTICLE POSITION", '')), 1, 4000), '') as type_code,
        NULLIF(SUBSTRING(TRIM(COALESCE(phl."RECEPT./SORTIE", '')), 1, 4000), '') as supply_code,
        NULLIF(NULLIF(TRIM(COALESCE(phl."ID GARANTIE CLIENT", '')), ''), '0')::numeric as cust_warranty_id,
        NULLIF(NULLIF(TRIM(COALESCE(phl."GARANTIE FOURNI.", '')), ''), '0')::numeric as sup_warranty_id,
        NULLIF(SUBSTRING(TRIM(COALESCE(phl."AUTORISE CD COND", '')), 1, 4000), '') as avail_activity_status,
        -- Colonne source videe en amont par nettoyer_phl_article() : le repli
        -- parametrable est donc la seule valeur reellement chargee.
        COALESCE(
            NULLIF(SUBSTRING(TRIM(COALESCE(phl."AUTORISE CD COND_2", '')), 1, 9), ''),
            public.get_matrix_value('clean_data.inventory_part', 'avail_activity_status_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))
        ) as avail_activity_status_db,
        NULLIF(SUBSTRING(TRIM(COALESCE(phl."CONFIGURABLE", '')), 1, 4000), '') as part_catalog_configurable,
        -- Idem : "CONFIGURABLE_2" est videe par nettoyer_phl_article().
        COALESCE(
            NULLIF(SUBSTRING(TRIM(COALESCE(phl."CONFIGURABLE_2", '')), 1, 20), ''),
            public.get_matrix_value('clean_data.inventory_part', 'part_catalog_configurable_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))
        ) as part_catalog_configurable_db,
        NULLIF(SUBSTRING(TRIM(COALESCE(phl."ENTREE ID GP U/M", '')), 1, 30), '') as input_unit_meas_group_id,
        NULLIF(SUBSTRING(TRIM(COALESCE(phl."N.DESSIN TECHN.", '')), 1, 25), '') as type_designation,
        NULLIF(SUBSTRING(TRIM(COALESCE(phl."CODE CEST", '')), 1, 15), '') as customs_stat_no,
        NULLIF(SUBSTRING(TRIM(COALESCE(phl."CODE FCI", '')), 1, 15), '') as statistical_code,
        CASE UPPER(TRIM(COALESCE(phl."ARR.BC NUM SORTIS", 'FALSE')))
            WHEN 'TRUE' THEN 'RESERVE ORDER ENTRY'
            ELSE 'NOT RESERVE ORDER ENTRY'
        END as oe_alloc_assign_flag,
        CASE UPPER(TRIM(COALESCE(phl."ARR.BC NUM SORTIS_2", 'FALSE')))
            WHEN 'TRUE' THEN 'Y'
            ELSE 'N'
        END as oe_alloc_assign_flag_db,
        NULLIF(REPLACE(TRIM(COALESCE(phl."DIAMETRE", '')), ',', '.'), '')::numeric as c_diameter,
        -- Densite : requise uniquement pour les plaques / tes / lingots (familles 20, 24, 19)
        -- -> valeur theorique 2.7 ; les fils (21, 22, 23, RF) n'ont pas de densite -> NULL.
        -- Depuis la migration 071 la distinction ne passe plus par une variante mais par
        -- la famille elle-meme, dans la matrice (/configuration/matrice-site-famille).
        CASE
             -- Aucune densite pour les articles fils, quels que soient le site et la
             -- famille : la forme prime sur la famille (un fil classe en famille 19,
             -- 20 ou 24 ne doit pas recevoir la valeur theorique).
             WHEN UPPER(COALESCE(phl."FORME", '')) LIKE '%FIL%'
                  THEN public.get_matrix_value('clean_data.inventory_part', 'c_density', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric
             WHEN NULLIF(TRIM(COALESCE(phl."FAMILLE", '')), '') IN ('19', '20', '24')
                  THEN public.get_matrix_value('clean_data.inventory_part', 'c_density', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric
             ELSE public.get_matrix_value('clean_data.inventory_part', 'c_density', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric
        END as c_density,
        -- Articles rebut (code article commencant par R, ex. RP-105003) : quand
        -- l'alliage n'est pas renseigne dans le fichier PHL, il est deduit du code
        -- article -- partie numerique de tete apres le tiret (RP-105003 -> 105003,
        -- RF-137050G10 -> 137050) -- et la serie vaut ce premier chiffre suivi de
        -- 000 (1 -> 1000, 5 -> 5000). Un code sans partie numerique (RP-RP DIVERS)
        -- laisse les deux colonnes vides.
        COALESCE(
            NULLIF(SUBSTRING(TRIM(COALESCE(phl."ALLIAGE", '')), 1, 12), ''),
            CASE WHEN UPPER(TRIM(phl."N. ARTICLE")) LIKE 'R%'
                 THEN SUBSTRING(SUBSTRING(TRIM(phl."N. ARTICLE") FROM '^[A-Za-z]+-([0-9]+)'), 1, 12)
            END
        ) as c_alloy_code,
        COALESCE(
            NULLIF(TRIM(COALESCE(phl."SERIE ALL", '')), ''),
            CASE WHEN UPPER(TRIM(phl."N. ARTICLE")) LIKE 'R%'
                 THEN LEFT(SUBSTRING(TRIM(phl."N. ARTICLE") FROM '^[A-Za-z]+-([0-9]+)'), 1) || '000'
            END
        ) as c_alloy_serie_code,
        NULLIF(SUBSTRING(TRIM(COALESCE(phl."FAMILLE", '')), 1, 5), '') as c_family_code,
        NULLIF(REPLACE(TRIM(COALESCE(phl."EPAISSEUR", '')), ',', '.'), '')::numeric as c_epaisseur_brut,
        NULLIF(REPLACE(TRIM(COALESCE(phl."LONGUEUR", '')), ',', '.'), '')::numeric as c_longueur_brut,
        NULLIF(REPLACE(TRIM(COALESCE(phl."LARGEUR", '')), ',', '.'), '')::numeric as c_largeur_brut,
        NULLIF(REPLACE(TRIM(COALESCE(phl."POIDS COMMERCIAL", '')), ',', '.'), '')::numeric as c_commercial_weight,
        NULLIF(SUBSTRING(TRIM(COALESCE(
            public.get_transcodification('FORME', NULLIF(TRIM(phl."FORME"), ''), 'PHL', 'IFS'),
            phl."FORME",
            ''
        )), 1, 25), '') as c_forme_code,
        NULLIF(SUBSTRING(TRIM(COALESCE(phl."SCIAGE", '')), 1, 2), '') as c_sawing_code,
        NULLIF(SUBSTRING(TRIM(COALESCE(phl."NORME CHARGE", '')), 1, 3), '') as c_load_standard_code,
        NULLIF(SUBSTRING(TRIM(COALESCE(phl."STATUT", '')), 1, 3), '') as c_final_state_code,
        public.get_matrix_value('clean_data.inventory_part', 'c_spire_code', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as c_spire_code,
        NULLIF(REPLACE(TRIM(COALESCE(phl."POIDS NET", '')), ',', '.'), '')::numeric as storage_weight_requirement,
        NULLIF(REPLACE(TRIM(COALESCE(phl."VOLUME NET", '')), ',', '.'), '')::numeric as storage_volume_requirement,
        public.get_matrix_value('clean_data.inventory_part', 'intrastat_conv_factor', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as intrastat_conv_factor,
        -- Valeurs par defaut : matrice site x famille SEULE
        -- (/configuration/matrice-site-famille, public.get_matrix_value)
        public.get_matrix_value('clean_data.inventory_part', 'planner_buyer', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as planner_buyer,
        public.get_matrix_value('clean_data.inventory_part', 'asset_class', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as asset_class,
        public.get_matrix_value('clean_data.inventory_part', 'country_of_origin', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as country_of_origin,
        public.get_matrix_value('clean_data.inventory_part', 'type_code_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as type_code_db,
        public.get_matrix_value('clean_data.inventory_part', 'supply_code_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as supply_code_db,
        public.get_matrix_value('clean_data.inventory_part', 'expected_leadtime', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as expected_leadtime,
        public.get_matrix_value('clean_data.inventory_part', 'manuf_leadtime', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as manuf_leadtime,
        public.get_matrix_value('clean_data.inventory_part', 'purch_leadtime', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as purch_leadtime,
        public.get_matrix_value('clean_data.inventory_part', 'lead_time_code_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as lead_time_code_db,
        public.get_matrix_value('clean_data.inventory_part', 'inventory_valuation_method_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as inventory_valuation_method_db,
        public.get_matrix_value('clean_data.inventory_part', 'count_variance', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as count_variance,
        public.get_matrix_value('clean_data.inventory_part', 'cycle_code_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as cycle_code_db,
        public.get_matrix_value('clean_data.inventory_part', 'cycle_period', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as cycle_period,
        public.get_matrix_value('clean_data.inventory_part', 'qty_calc_rounding', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as qty_calc_rounding,
        public.get_matrix_value('clean_data.inventory_part', 'zero_cost_flag_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as zero_cost_flag_db,
        public.get_matrix_value('clean_data.inventory_part', 'onhand_analysis_flag_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as onhand_analysis_flag_db,
        public.get_matrix_value('clean_data.inventory_part', 'shortage_flag_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as shortage_flag_db,
        public.get_matrix_value('clean_data.inventory_part', 'forecast_consumption_flag_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as forecast_consumption_flag_db,
        public.get_matrix_value('clean_data.inventory_part', 'stock_management_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as stock_management_db,
        public.get_matrix_value('clean_data.inventory_part', 'dop_connection_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as dop_connection_db,
        public.get_matrix_value('clean_data.inventory_part', 'negative_on_hand_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as negative_on_hand_db,
        public.get_matrix_value('clean_data.inventory_part', 'invoice_consideration_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as invoice_consideration_db,
        public.get_matrix_value('clean_data.inventory_part', 'inventory_part_cost_level_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as inventory_part_cost_level_db,
        public.get_matrix_value('clean_data.inventory_part', 'ext_service_cost_method_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as ext_service_cost_method_db,
        public.get_matrix_value('clean_data.inventory_part', 'automatic_capability_check_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as automatic_capability_check_db,
        public.get_matrix_value('clean_data.inventory_part', 'dop_netting_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as dop_netting_db,
        public.get_matrix_value('clean_data.inventory_part', 'co_reserve_onh_analys_flag_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as co_reserve_onh_analys_flag_db,
        public.get_matrix_value('clean_data.inventory_part', 'mandatory_expiration_date_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as mandatory_expiration_date_db,
        public.get_matrix_value('clean_data.inventory_part', 'excl_ship_pack_proposal_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as excl_ship_pack_proposal_db,
        public.get_matrix_value('clean_data.inventory_part', 'reset_config_std_cost_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as reset_config_std_cost_db,
        public.get_matrix_value('clean_data.inventory_part', 'lifecycle_stage_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as lifecycle_stage_db,
        public.get_matrix_value('clean_data.inventory_part', 'frequency_class_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as frequency_class_db,
        public.get_matrix_value('clean_data.inventory_part', 'abc_class', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as abc_class,
        public.get_matrix_value('clean_data.inventory_part', 'hsn_sac_code', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as hsn_sac_code,
        public.get_matrix_value('clean_data.inventory_part', 'company', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as company,
        CURRENT_TIMESTAMP as create_date,
        -- Colonnes non alimentees par le fichier PHL : valeur pilotee par
        -- l'ecran /configuration/valeurs-defaut (variante ARTICLEPHL).
        public.get_matrix_value('clean_data.inventory_part', 'hazard_code', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as hazard_code,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'note_id', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as note_id,
        public.get_matrix_value('clean_data.inventory_part', 'second_commodity', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as second_commodity,
        public.get_matrix_value('clean_data.inventory_part', 'catch_unit_meas', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as catch_unit_meas,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'abc_class_locked_until', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::timestamp as abc_class_locked_until,
        public.get_matrix_value('clean_data.inventory_part', 'cycle_code', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as cycle_code,
        public.get_matrix_value('clean_data.inventory_part', 'dim_quality', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as dim_quality,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'durability_day', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as durability_day,
        public.get_matrix_value('clean_data.inventory_part', 'lead_time_code', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as lead_time_code,
        public.get_matrix_value('clean_data.inventory_part', 'onhand_analysis_flag', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as onhand_analysis_flag,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'earliest_ultd_supply_date', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::timestamp as earliest_ultd_supply_date,
        public.get_matrix_value('clean_data.inventory_part', 'supersedes', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as supersedes,
        public.get_matrix_value('clean_data.inventory_part', 'zero_cost_flag', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as zero_cost_flag,
        public.get_matrix_value('clean_data.inventory_part', 'eng_attribute', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as eng_attribute,
        public.get_matrix_value('clean_data.inventory_part', 'shortage_flag', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as shortage_flag,
        public.get_matrix_value('clean_data.inventory_part', 'forecast_consumption_flag', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as forecast_consumption_flag,
        public.get_matrix_value('clean_data.inventory_part', 'stock_management', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as stock_management,
        public.get_matrix_value('clean_data.inventory_part', 'part_cost_group_id', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as part_cost_group_id,
        public.get_matrix_value('clean_data.inventory_part', 'dop_connection', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as dop_connection,
        public.get_matrix_value('clean_data.inventory_part', 'inventory_valuation_method', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as inventory_valuation_method,
        public.get_matrix_value('clean_data.inventory_part', 'negative_on_hand', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as negative_on_hand,
        public.get_matrix_value('clean_data.inventory_part', 'technical_coordinator_id', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as technical_coordinator_id,
        public.get_matrix_value('clean_data.inventory_part', 'invoice_consideration', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as invoice_consideration,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'actual_cost_activated', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::timestamp as actual_cost_activated,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'max_actual_cost_update', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as max_actual_cost_update,
        public.get_matrix_value('clean_data.inventory_part', 'region_of_origin', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as region_of_origin,
        public.get_matrix_value('clean_data.inventory_part', 'inventory_part_cost_level', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as inventory_part_cost_level,
        public.get_matrix_value('clean_data.inventory_part', 'ext_service_cost_method', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as ext_service_cost_method,
        public.get_matrix_value('clean_data.inventory_part', 'supply_chain_part_group', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as supply_chain_part_group,
        public.get_matrix_value('clean_data.inventory_part', 'automatic_capability_check', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as automatic_capability_check,
        public.get_matrix_value('clean_data.inventory_part', 'dop_netting', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as dop_netting,
        public.get_matrix_value('clean_data.inventory_part', 'co_reserve_onh_analys_flag', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as co_reserve_onh_analys_flag,
        public.get_matrix_value('clean_data.inventory_part', 'lifecycle_stage', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as lifecycle_stage,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'life_stage_locked_until', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::timestamp as life_stage_locked_until,
        public.get_matrix_value('clean_data.inventory_part', 'frequency_class', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as frequency_class,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'freq_class_locked_until', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::timestamp as freq_class_locked_until,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'first_stat_issue_date', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::timestamp as first_stat_issue_date,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'latest_stat_issue_date', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::timestamp as latest_stat_issue_date,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'latest_stat_affecting_date', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::timestamp as latest_stat_affecting_date,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'decline_date', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::timestamp as decline_date,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'expired_date', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::timestamp as expired_date,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'decline_issue_counter', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as decline_issue_counter,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'expired_issue_counter', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as expired_issue_counter,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'min_durab_days_co_deliv', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as min_durab_days_co_deliv,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'min_durab_days_planning', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as min_durab_days_planning,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'storage_width_requirement', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as storage_width_requirement,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'storage_height_requirement', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as storage_height_requirement,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'storage_depth_requirement', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as storage_depth_requirement,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'min_storage_temperature', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as min_storage_temperature,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'max_storage_temperature', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as max_storage_temperature,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'min_storage_humidity', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as min_storage_humidity,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'max_storage_humidity', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as max_storage_humidity,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'standard_putaway_qty', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as standard_putaway_qty,
        public.get_matrix_value('clean_data.inventory_part', 'putaway_zone_refill_option', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as putaway_zone_refill_option,
        public.get_matrix_value('clean_data.inventory_part', 'putaway_zone_refill_option_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as putaway_zone_refill_option_db,
        public.get_matrix_value('clean_data.inventory_part', 'reset_config_std_cost', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as reset_config_std_cost,
        public.get_matrix_value('clean_data.inventory_part', 'mandatory_expiration_date', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as mandatory_expiration_date,
        public.get_matrix_value('clean_data.inventory_part', 'excl_ship_pack_proposal', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as excl_ship_pack_proposal,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'acquisition_origin', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as acquisition_origin,
        public.get_matrix_value('clean_data.inventory_part', 'acquisition_reason_id', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as acquisition_reason_id,
        public.get_matrix_value('clean_data.inventory_part', 'product_category_id', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as product_category_id,
        public.get_matrix_value('clean_data.inventory_part', 'consumption_tax', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as consumption_tax,
        public.get_matrix_value('clean_data.inventory_part', 'consumption_tax_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as consumption_tax_db,
        public.get_matrix_value('clean_data.inventory_part', 'tax_manuf_equivalent', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as tax_manuf_equivalent,
        public.get_matrix_value('clean_data.inventory_part', 'tax_manuf_equivalent_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as tax_manuf_equivalent_db,
        public.get_matrix_value('clean_data.inventory_part', 'c_amma_type', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as c_amma_type,
        public.get_matrix_value('clean_data.inventory_part', 'c_amma_type_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as c_amma_type_db,
        public.get_matrix_value('clean_data.inventory_part', 'c_recasting_type', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as c_recasting_type,
        public.get_matrix_value('clean_data.inventory_part', 'c_recasting_type_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as c_recasting_type_db,
        public.get_matrix_value('clean_data.inventory_part', 'c_is_green', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as c_is_green,
        public.get_matrix_value('clean_data.inventory_part', 'c_is_green_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as c_is_green_db,
        public.get_matrix_value('clean_data.inventory_part', 'c_green_percentage', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as c_green_percentage,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'c_green_percentage_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as c_green_percentage_db,
        public.get_matrix_value('clean_data.inventory_part', 'part_catalog_description', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as part_catalog_description,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'part_catalog_std_name_id', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as part_catalog_std_name_id,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'estimated_material_cost', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::numeric as estimated_material_cost,
        public.get_matrix_value('clean_data.inventory_part', 'description_in_use', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as description_in_use,
        NULLIF(public.get_matrix_value('clean_data.inventory_part', 'last_activity_date', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')), '')::timestamp as last_activity_date
    FROM raw_data.v_phl_article_retenu phl
    LEFT JOIN raw_data.phl_article_densite dens
      ON TRIM(dens.identifiant) = TRIM(phl."N. ARTICLE")
    WHERE phl."N. ARTICLE" IS NOT NULL
      AND phl.site = p_contract   -- cloisonnement par site (cf. v_phl_article_retenu)
      AND TRIM(phl."N. ARTICLE") != ''
      AND UPPER(LEFT(TRIM(phl."STATUT"), 1)) IN ('F', 'I')
      AND EXISTS (
          SELECT 1 FROM clean_data.part_catalog pc
          WHERE pc.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
      )
      AND NOT EXISTS (
          SELECT 1 FROM clean_data.inventory_part ip
          WHERE ip.contract = p_contract
            AND ip.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
      )
    ORDER BY TRIM(phl."N. ARTICLE");
    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;
    WITH src AS (
        SELECT DISTINCT ON (TRIM(phl."N. ARTICLE"))
            SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25) as part_no,
            CASE
            WHEN LOWER(TRIM(COALESCE(phl."U/M", ''))) = 't' THEN 'kg'
            ELSE SUBSTRING(COALESCE(
                public.get_transcodification('UOM', NULLIF(TRIM(phl."U/M"), ''), 'PHL', 'IFS'),
                public.get_transcodification('UOM', NULLIF(UPPER(TRIM(phl."U/M")), ''), 'PHL', 'IFS'),
                public.get_transcodification('UOM', NULLIF(TRIM(phl."U/M"), '')),
                public.get_transcodification('UOM', NULLIF(UPPER(TRIM(phl."U/M")), '')),
                NULLIF(TRIM(phl."U/M"), ''),
                'PCE'
            ), 1, 10)
        END as unit_meas,
            NULLIF(REPLACE(TRIM(COALESCE(phl."DIAMETRE", '')), ',', '.'), '')::numeric as c_diameter,
            -- Densite : requise uniquement pour les plaques / tes / lingots (familles 20, 24, 19)
            -- -> valeur theorique 2.7 ; les fils (21, 22, 23, RF) n'ont pas de densite -> NULL.
            -- Depuis la migration 071 la distinction ne passe plus par une variante mais par
            -- la famille elle-meme, dans la matrice (/configuration/matrice-site-famille).
            CASE
                 -- Aucune densite pour les articles fils, quels que soient le site et la
                 -- famille : la forme prime sur la famille (un fil classe en famille 19,
                 -- 20 ou 24 ne doit pas recevoir la valeur theorique).
                 WHEN UPPER(COALESCE(phl."FORME", '')) LIKE '%FIL%'
                      THEN public.get_matrix_value('clean_data.inventory_part', 'c_density', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric
                 WHEN NULLIF(TRIM(COALESCE(phl."FAMILLE", '')), '') IN ('19', '20', '24')
                      THEN public.get_matrix_value('clean_data.inventory_part', 'c_density', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric
                 ELSE public.get_matrix_value('clean_data.inventory_part', 'c_density', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric
            END as c_density,
            -- Articles rebut (code article commencant par R, ex. RP-105003) : quand
            -- l'alliage n'est pas renseigne dans le fichier PHL, il est deduit du code
            -- article -- partie numerique de tete apres le tiret (RP-105003 -> 105003,
            -- RF-137050G10 -> 137050) -- et la serie vaut ce premier chiffre suivi de
            -- 000 (1 -> 1000, 5 -> 5000). Un code sans partie numerique (RP-RP DIVERS)
            -- laisse les deux colonnes vides.
            COALESCE(
                NULLIF(SUBSTRING(TRIM(COALESCE(phl."ALLIAGE", '')), 1, 12), ''),
                CASE WHEN UPPER(TRIM(phl."N. ARTICLE")) LIKE 'R%'
                     THEN SUBSTRING(SUBSTRING(TRIM(phl."N. ARTICLE") FROM '^[A-Za-z]+-([0-9]+)'), 1, 12)
                END
            ) as c_alloy_code,
            COALESCE(
                NULLIF(TRIM(COALESCE(phl."SERIE ALL", '')), ''),
                CASE WHEN UPPER(TRIM(phl."N. ARTICLE")) LIKE 'R%'
                     THEN LEFT(SUBSTRING(TRIM(phl."N. ARTICLE") FROM '^[A-Za-z]+-([0-9]+)'), 1) || '000'
                END
            ) as c_alloy_serie_code,
            NULLIF(SUBSTRING(TRIM(COALESCE(phl."FAMILLE", '')), 1, 5), '') as c_family_code,
            NULLIF(REPLACE(TRIM(COALESCE(phl."EPAISSEUR", '')), ',', '.'), '')::numeric as c_epaisseur_brut,
            NULLIF(REPLACE(TRIM(COALESCE(phl."LONGUEUR", '')), ',', '.'), '')::numeric as c_longueur_brut,
            NULLIF(REPLACE(TRIM(COALESCE(phl."LARGEUR", '')), ',', '.'), '')::numeric as c_largeur_brut,
            NULLIF(REPLACE(TRIM(COALESCE(phl."POIDS COMMERCIAL", '')), ',', '.'), '')::numeric as c_commercial_weight,
            NULLIF(SUBSTRING(TRIM(COALESCE(
            public.get_transcodification('FORME', NULLIF(TRIM(phl."FORME"), ''), 'PHL', 'IFS'),
            phl."FORME",
            ''
        )), 1, 25), '') as c_forme_code,
            NULLIF(SUBSTRING(TRIM(COALESCE(phl."SCIAGE", '')), 1, 2), '') as c_sawing_code,
            NULLIF(SUBSTRING(TRIM(COALESCE(phl."NORME CHARGE", '')), 1, 3), '') as c_load_standard_code,
            NULLIF(SUBSTRING(TRIM(COALESCE(phl."STATUT", '')), 1, 3), '') as c_final_state_code,
            public.get_matrix_value('clean_data.inventory_part', 'c_spire_code', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as c_spire_code,
            NULLIF(REPLACE(TRIM(COALESCE(phl."POIDS NET", '')), ',', '.'), '')::numeric as storage_weight_requirement,
            NULLIF(REPLACE(TRIM(COALESCE(phl."VOLUME NET", '')), ',', '.'), '')::numeric as storage_volume_requirement,
            public.get_matrix_value('clean_data.inventory_part', 'intrastat_conv_factor', p_contract, NULLIF(TRIM(phl."FAMILLE"), ''))::numeric as intrastat_conv_factor
        FROM raw_data.v_phl_article_retenu phl
        LEFT JOIN raw_data.phl_article_densite dens
          ON TRIM(dens.identifiant) = TRIM(phl."N. ARTICLE")
        WHERE phl."N. ARTICLE" IS NOT NULL
          AND phl.site = p_contract   -- cloisonnement par site (cf. v_phl_article_retenu)
          AND TRIM(phl."N. ARTICLE") != ''
          AND UPPER(LEFT(TRIM(phl."STATUT"), 1)) IN ('F', 'I')
        ORDER BY TRIM(phl."N. ARTICLE")
    )
    UPDATE clean_data.inventory_part ip
    SET unit_meas = src.unit_meas,
        c_diameter = src.c_diameter,
        c_density = src.c_density,
        c_alloy_code = src.c_alloy_code,
        c_alloy_serie_code = src.c_alloy_serie_code,
        c_family_code = src.c_family_code,
        c_epaisseur_brut = src.c_epaisseur_brut,
        c_longueur_brut = src.c_longueur_brut,
        c_largeur_brut = src.c_largeur_brut,
        c_commercial_weight = src.c_commercial_weight,
        c_forme_code = src.c_forme_code,
        c_sawing_code = src.c_sawing_code,
        c_load_standard_code = src.c_load_standard_code,
        c_final_state_code = src.c_final_state_code,
        c_spire_code = src.c_spire_code,
        storage_weight_requirement = src.storage_weight_requirement,
        storage_volume_requirement = src.storage_volume_requirement,
        intrastat_conv_factor = src.intrastat_conv_factor
    FROM src
    WHERE ip.contract = p_contract
      AND ip.part_no = src.part_no
      AND (ip.unit_meas, ip.c_diameter, ip.c_density, ip.c_alloy_code, ip.c_alloy_serie_code, ip.c_family_code,
           ip.c_epaisseur_brut, ip.c_longueur_brut, ip.c_largeur_brut, ip.c_commercial_weight,
           ip.c_forme_code, ip.c_sawing_code, ip.c_load_standard_code, ip.c_final_state_code, ip.c_spire_code,
           ip.storage_weight_requirement, ip.storage_volume_requirement, ip.intrastat_conv_factor)
          IS DISTINCT FROM
          (src.unit_meas, src.c_diameter, src.c_density, src.c_alloy_code, src.c_alloy_serie_code, src.c_family_code,
           src.c_epaisseur_brut, src.c_longueur_brut, src.c_largeur_brut, src.c_commercial_weight,
           src.c_forme_code, src.c_sawing_code, src.c_load_standard_code, src.c_final_state_code, src.c_spire_code,
           src.storage_weight_requirement, src.storage_volume_requirement, src.intrastat_conv_factor);
    GET DIAGNOSTICS v_count_updated = ROW_COUNT;
    -- PHL : forcer "Allow Many Lots per Production Order" a True
    -- Champ IFS PART_CATALOG.LOT_QUANTITY_RULE_DB = MULTI_LOTS.
    UPDATE clean_data.part_catalog pc
    SET lot_quantity_rule_db = def.rule_db,
        lot_quantity_rule = 'Many Lots Per Production Order'
    -- LATERAL et phl declare AVANT : la valeur depend desormais de la famille
    -- de l'article (public.get_matrix_value), donc de la ligne phl courante.
    FROM raw_data.v_phl_article_retenu phl,
         LATERAL (SELECT public.get_matrix_value('clean_data.part_catalog', 'lot_quantity_rule_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as rule_db) def
    WHERE pc.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
      AND phl.site = p_contract   -- cloisonnement par site (cf. v_phl_article_retenu)
      AND phl."N. ARTICLE" IS NOT NULL
      AND TRIM(phl."N. ARTICLE") != ''
      AND UPPER(LEFT(TRIM(phl."STATUT"), 1)) IN ('F', 'I')
      AND (pc.lot_quantity_rule_db, pc.lot_quantity_rule)
          IS DISTINCT FROM (def.rule_db, 'Many Lots Per Production Order');
    GET DIAGNOSTICS v_count_updated_part_catalog = ROW_COUNT;
    -- PHL : forcer "Plan Manufacturing Supply on Due Date" a True
    -- Champs IFS MANUF_PART_ATTRIBUTE.PLAN_MANUF_SUP_ON_DUE_DATE_DB et libelle = TRUE.
    UPDATE clean_data.manuf_part_attribute mpa
    SET plan_manuf_sup_on_due_date_db = def.plan_db,
        plan_manuf_sup_on_due_date = def.plan_lbl
    -- LATERAL et phl declare AVANT : voir le commentaire de l'UPDATE precedent.
    FROM raw_data.v_phl_article_retenu phl,
         LATERAL (SELECT
              public.get_matrix_value('clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date_db', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as plan_db,
              public.get_matrix_value('clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date', p_contract, NULLIF(TRIM(phl."FAMILLE"), '')) as plan_lbl
         ) def
    WHERE mpa.contract = p_contract
      AND phl.site = p_contract   -- cloisonnement par site (cf. v_phl_article_retenu)
      AND mpa.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
      AND phl."N. ARTICLE" IS NOT NULL
      AND TRIM(phl."N. ARTICLE") != ''
      AND UPPER(LEFT(TRIM(phl."STATUT"), 1)) IN ('F', 'I')
      AND (mpa.plan_manuf_sup_on_due_date_db, mpa.plan_manuf_sup_on_due_date)
          IS DISTINCT FROM (def.plan_db, def.plan_lbl);
    GET DIAGNOSTICS v_count_updated_manuf_part_attribute = ROW_COUNT;
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Alimentation INVENTORY_PART (PHL) terminee avec succes';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Articles PHL inseres: %', v_count_inserted;
    RAISE NOTICE 'Articles PHL mis a jour (champs custom): %', v_count_updated;
    RAISE NOTICE 'PART_CATALOG PHL mis a jour (Allow Many Lots per Production Order): %', v_count_updated_part_catalog;
    RAISE NOTICE 'MANUF_PART_ATTRIBUTE PHL mis a jour (Plan Manufacturing Supply on Due Date): %', v_count_updated_manuf_part_attribute;
    RAISE NOTICE 'Duree d''execution: %', v_duration;
    RAISE NOTICE '====================================================';
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'ERREUR lors de l''alimentation INVENTORY_PART (PHL)';
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'Code d''erreur: %', SQLSTATE;
        RAISE NOTICE 'Message: %', SQLERRM;
        RAISE NOTICE 'Duree avant erreur: %', v_duration;
        RAISE NOTICE '====================================================';
        RAISE;
END;
$function$
;
