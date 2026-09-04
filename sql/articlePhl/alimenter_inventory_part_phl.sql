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
        create_date
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
        public.get_default_value('clean_data.inventory_part', 'part_status') as part_status,
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
        NULLIF(SUBSTRING(TRIM(COALESCE(phl."AUTORISE CD COND_2", '')), 1, 9), '') as avail_activity_status_db,
        NULLIF(SUBSTRING(TRIM(COALESCE(phl."CONFIGURABLE", '')), 1, 4000), '') as part_catalog_configurable,
        NULLIF(SUBSTRING(TRIM(COALESCE(phl."CONFIGURABLE_2", '')), 1, 20), '') as part_catalog_configurable_db,
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
        -- -> variante STANDARD (valeur theorique 2.7). Les fils (21, 22, 23, RF) n'ont pas
        -- de densite -> variante FIL (fallback NULL). Les deux valeurs sont parametrables
        -- via l'ecran /configuration/valeurs-defaut (public.get_default_value).
        CASE
             -- Aucune densite pour les articles fils, quels que soient le site et la
             -- famille : la forme prime sur la famille (un fil classe en famille 19,
             -- 20 ou 24 ne doit pas recevoir la valeur theorique).
             WHEN UPPER(COALESCE(phl."FORME", '')) LIKE '%FIL%'
                  THEN public.get_default_value('clean_data.inventory_part', 'c_density', 'FIL')::numeric
             WHEN NULLIF(TRIM(COALESCE(phl."FAMILLE", '')), '') IN ('19', '20', '24')
                  THEN public.get_default_value('clean_data.inventory_part', 'c_density')::numeric
             ELSE public.get_default_value('clean_data.inventory_part', 'c_density', 'FIL')::numeric
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
        public.get_default_value('clean_data.inventory_part', 'c_spire_code') as c_spire_code,
        NULLIF(REPLACE(TRIM(COALESCE(phl."POIDS NET", '')), ',', '.'), '')::numeric as storage_weight_requirement,
        NULLIF(REPLACE(TRIM(COALESCE(phl."VOLUME NET", '')), ',', '.'), '')::numeric as storage_volume_requirement,
        public.get_default_value('clean_data.inventory_part', 'intrastat_conv_factor')::numeric as intrastat_conv_factor,
        -- Valeurs par defaut parametrables via l'ecran /configuration/valeurs-defaut
        -- (public.get_default_value, fallback = ancienne valeur codee en dur)
        public.get_default_value('clean_data.inventory_part', 'planner_buyer') as planner_buyer,
        public.get_default_value('clean_data.inventory_part', 'asset_class') as asset_class,
        public.get_default_value('clean_data.inventory_part', 'country_of_origin') as country_of_origin,
        public.get_default_value('clean_data.inventory_part', 'type_code_db', 'ARTICLEPHL') as type_code_db,
        public.get_default_value('clean_data.inventory_part', 'supply_code_db') as supply_code_db,
        public.get_default_value('clean_data.inventory_part', 'expected_leadtime')::numeric as expected_leadtime,
        public.get_default_value('clean_data.inventory_part', 'manuf_leadtime')::numeric as manuf_leadtime,
        public.get_default_value('clean_data.inventory_part', 'purch_leadtime')::numeric as purch_leadtime,
        public.get_default_value('clean_data.inventory_part', 'lead_time_code_db', 'ARTICLEPHL') as lead_time_code_db,
        public.get_default_value('clean_data.inventory_part', 'inventory_valuation_method_db') as inventory_valuation_method_db,
        public.get_default_value('clean_data.inventory_part', 'count_variance')::numeric as count_variance,
        public.get_default_value('clean_data.inventory_part', 'cycle_code_db') as cycle_code_db,
        public.get_default_value('clean_data.inventory_part', 'cycle_period')::numeric as cycle_period,
        public.get_default_value('clean_data.inventory_part', 'qty_calc_rounding')::numeric as qty_calc_rounding,
        public.get_default_value('clean_data.inventory_part', 'zero_cost_flag_db', 'ARTICLEPHL') as zero_cost_flag_db,
        public.get_default_value('clean_data.inventory_part', 'onhand_analysis_flag_db') as onhand_analysis_flag_db,
        public.get_default_value('clean_data.inventory_part', 'shortage_flag_db') as shortage_flag_db,
        public.get_default_value('clean_data.inventory_part', 'forecast_consumption_flag_db') as forecast_consumption_flag_db,
        public.get_default_value('clean_data.inventory_part', 'stock_management_db') as stock_management_db,
        public.get_default_value('clean_data.inventory_part', 'dop_connection_db') as dop_connection_db,
        public.get_default_value('clean_data.inventory_part', 'negative_on_hand_db') as negative_on_hand_db,
        public.get_default_value('clean_data.inventory_part', 'invoice_consideration_db') as invoice_consideration_db,
        public.get_default_value('clean_data.inventory_part', 'inventory_part_cost_level_db') as inventory_part_cost_level_db,
        public.get_default_value('clean_data.inventory_part', 'ext_service_cost_method_db') as ext_service_cost_method_db,
        public.get_default_value('clean_data.inventory_part', 'automatic_capability_check_db') as automatic_capability_check_db,
        public.get_default_value('clean_data.inventory_part', 'dop_netting_db') as dop_netting_db,
        public.get_default_value('clean_data.inventory_part', 'co_reserve_onh_analys_flag_db') as co_reserve_onh_analys_flag_db,
        public.get_default_value('clean_data.inventory_part', 'mandatory_expiration_date_db') as mandatory_expiration_date_db,
        public.get_default_value('clean_data.inventory_part', 'excl_ship_pack_proposal_db') as excl_ship_pack_proposal_db,
        public.get_default_value('clean_data.inventory_part', 'reset_config_std_cost_db') as reset_config_std_cost_db,
        public.get_default_value('clean_data.inventory_part', 'lifecycle_stage_db') as lifecycle_stage_db,
        public.get_default_value('clean_data.inventory_part', 'frequency_class_db') as frequency_class_db,
        public.get_default_value('clean_data.inventory_part', 'abc_class') as abc_class,
        public.get_default_value('clean_data.inventory_part', 'hsn_sac_code') as hsn_sac_code,
        public.get_default_value('clean_data.inventory_part', 'company') as company,
        CURRENT_TIMESTAMP as create_date
    FROM raw_data.v_phl_article_retenu phl
    LEFT JOIN raw_data.phl_article_densite dens
      ON TRIM(dens.identifiant) = TRIM(phl."N. ARTICLE")
    WHERE phl."N. ARTICLE" IS NOT NULL
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
            -- -> variante STANDARD (valeur theorique 2.7). Les fils (21, 22, 23, RF) n'ont pas
            -- de densite -> variante FIL (fallback NULL). Les deux valeurs sont parametrables
            -- via l'ecran /configuration/valeurs-defaut (public.get_default_value).
            CASE
                 -- Aucune densite pour les articles fils, quels que soient le site et la
                 -- famille : la forme prime sur la famille (un fil classe en famille 19,
                 -- 20 ou 24 ne doit pas recevoir la valeur theorique).
                 WHEN UPPER(COALESCE(phl."FORME", '')) LIKE '%FIL%'
                      THEN public.get_default_value('clean_data.inventory_part', 'c_density', 'FIL')::numeric
                 WHEN NULLIF(TRIM(COALESCE(phl."FAMILLE", '')), '') IN ('19', '20', '24')
                      THEN public.get_default_value('clean_data.inventory_part', 'c_density')::numeric
                 ELSE public.get_default_value('clean_data.inventory_part', 'c_density', 'FIL')::numeric
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
            public.get_default_value('clean_data.inventory_part', 'c_spire_code') as c_spire_code,
            NULLIF(REPLACE(TRIM(COALESCE(phl."POIDS NET", '')), ',', '.'), '')::numeric as storage_weight_requirement,
            NULLIF(REPLACE(TRIM(COALESCE(phl."VOLUME NET", '')), ',', '.'), '')::numeric as storage_volume_requirement,
            public.get_default_value('clean_data.inventory_part', 'intrastat_conv_factor')::numeric as intrastat_conv_factor
        FROM raw_data.v_phl_article_retenu phl
        LEFT JOIN raw_data.phl_article_densite dens
          ON TRIM(dens.identifiant) = TRIM(phl."N. ARTICLE")
        WHERE phl."N. ARTICLE" IS NOT NULL
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
    FROM (SELECT public.get_default_value('clean_data.part_catalog', 'lot_quantity_rule_db') as rule_db) def,
         raw_data.v_phl_article_retenu phl
    WHERE pc.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
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
    FROM (SELECT
              public.get_default_value('clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date_db') as plan_db,
              public.get_default_value('clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date') as plan_lbl
         ) def,
         raw_data.v_phl_article_retenu phl
    WHERE mpa.contract = p_contract
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
