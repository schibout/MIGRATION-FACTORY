-- ============================================================================
-- 071 : articlePhl -- la matrice devient l'UNIQUE source des valeurs par defaut
--
-- DEMANDE : "pour les valeurs par defaut il faut utiliser exclusivement la
-- matrice des valeurs par defaut". Les 5 procedures alimenter_*_phl lisaient
-- leurs constantes a deux endroits :
--   * 239 appels a public.get_default_value()      -> public.etl_default_values
--   * 142 appels a public.get_default_value_ctx()  -> matrice, PUIS repli sur
--                                                     etl_default_values
-- Elles n'appellent plus que public.get_matrix_value(), qui lit la SEULE table
-- public.etl_default_value_matrix, sans repli.
--
-- CONSEQUENCE : une colonne sans ligne dans la matrice vaut NULL au chargement.
-- Pour que le comportement reste identique tant que personne ne touche a
-- l'ecran, ce fichier recopie d'abord dans la matrice, en regles JOKER
-- (contract NULL + part_family NULL = tous sites, toutes familles), les 142
-- constantes actives que les procedures resolvaient jusqu'ici. Les 206 autres
-- colonnes appelees resolvaient deja NULL (169 sans ligne seedee -- migration
-- 069 non jouee --, 36 lignes desactivees, 1 de type NULL) : ne rien inserer
-- pour elles preserve exactement ce comportement.
--
-- VARIANTE : get_matrix_value ne prend pas de variante. Les appels portaient
-- 'ARTICLEPHL' (173), 'FIL' (1) ou rien (207 = STANDARD), alors que l'ecran
-- Matrice Site x Famille ecrit toujours 'STANDARD' : chercher la matrice avec
-- la variante de l'appel aurait rendu illisibles les regles saisies sur 174
-- colonnes. Le seed ci-dessous est donc entierement en 'STANDARD'.
--
-- public.get_default_value() reste en place : les 8 autres modules ETL
-- (supplier, customer, inventory, operation, projet, pm_actions...) l'utilisent
-- toujours. Seul articlePhl passe a la matrice seule.
--
-- A JOUER AVEC : cd sql/articlePhl && ./compile.sh (les 5 procedures reecrites).
-- Rollback en bas de fichier.
-- ============================================================================

BEGIN;

-- ===========================================================================
-- 1. La fonction de lecture : la matrice, rien que la matrice
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.get_matrix_value(
    p_table       VARCHAR,
    p_colonne     VARCHAR,
    p_contract    VARCHAR,
    p_part_family VARCHAR
) RETURNS TEXT
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_type   VARCHAR(20);
    v_valeur TEXT;
BEGIN
    -- Regle la plus specifique d'abord : site + famille > site > famille > joker.
    -- Meme ordre que public.get_default_value_ctx(), a ceci pres qu'il n'y a ni
    -- variante dans la recherche ni repli sur public.etl_default_values.
    SELECT m.type_valeur, m.valeur
    INTO v_type, v_valeur
    FROM public.etl_default_value_matrix m
    WHERE m.table_cible = p_table
      AND m.colonne     = p_colonne
      AND m.is_active
      AND (m.contract    IS NULL OR m.contract    = p_contract)
      AND (m.part_family IS NULL OR m.part_family = p_part_family)
    ORDER BY (m.contract IS NOT NULL)::int + (m.part_family IS NOT NULL)::int DESC,
             (m.contract IS NOT NULL)::int DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN NULL;   -- aucune regle : la colonne reste vide
    END IF;

    RETURN CASE WHEN v_type = 'NULL' THEN NULL ELSE v_valeur END;

EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Erreur dans get_matrix_value: % - Table: %, Colonne: %, Site: %, Famille: %',
                      SQLERRM, p_table, p_colonne, p_contract, p_part_family;
        RETURN NULL;
END;
$function$;

COMMENT ON FUNCTION public.get_matrix_value(VARCHAR, VARCHAR, VARCHAR, VARCHAR) IS
'Valeur par defaut d''une colonne pour un site et une famille, lue UNIQUEMENT dans public.etl_default_value_matrix (ecran /configuration/matrice-site-famille). Aucun repli sur public.etl_default_values : une colonne sans regle vaut NULL. Utilisee par les 5 procedures clean_data.alimenter_*_phl (migration 071).';

-- ===========================================================================
-- 2. Reprise des constantes actives en regles joker
--
-- ON CONFLICT DO NOTHING : les 90 regles joker deja saisies dans l'ecran font
-- foi, ce seed ne les ecrase pas. Un INSERT par ligne (convention du depot).
-- ===========================================================================
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'asset_class', NULL, NULL, 'STANDARD', 'CONSTANTE', 'S', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'automatic_capability_check_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'NO AUTOMATIC CAPABILITY CHECK', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'c_density', NULL, NULL, 'STANDARD', 'CONSTANTE', '2.7', 'Repris de etl_default_values par la migration 071. Source : alimenter_inventory_part_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'company', NULL, NULL, 'STANDARD', 'CONSTANTE', 'TRIMET', 'Repris de etl_default_values par la migration 071. Societe TRIMET (le site est porte par CONTRACT) - regle metier 2026-09-04', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'co_reserve_onh_analys_flag_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'N', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'count_variance', NULL, NULL, 'STANDARD', 'CONSTANTE', '0', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'c_spire_code', NULL, NULL, 'STANDARD', 'CONSTANTE', 'S', 'Repris de etl_default_values par la migration 071. Source : alimenter_inventory_part_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'cycle_code_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'N', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'cycle_period', NULL, NULL, 'STANDARD', 'CONSTANTE', '0', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'dop_connection_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'AUT', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'dop_netting_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'NONET', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'excl_ship_pack_proposal_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FALSE', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'expected_leadtime', NULL, NULL, 'STANDARD', 'CONSTANTE', '0', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'ext_service_cost_method_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'EXCLUDE SERVICE COST', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'forecast_consumption_flag_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FORECAST', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'frequency_class_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'VERY SLOW MOVER', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'inventory_part_cost_level_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'COST PER PART', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'inventory_valuation_method_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'ST', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'invoice_consideration_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'TRANSACTION BASED', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'lead_time_code_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'Y', 'Repris de etl_default_values par la migration 071. Source : alimenter_inventory_part_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'lifecycle_stage_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'DEVELOPMENT', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'mandatory_expiration_date_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FALSE', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'manuf_leadtime', NULL, NULL, 'STANDARD', 'CONSTANTE', '0', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'negative_on_hand_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'NEG ONHAND NOT OK', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'onhand_analysis_flag_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'N', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'part_status', NULL, NULL, 'STANDARD', 'CONSTANTE', 'A', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'planner_buyer', NULL, NULL, 'STANDARD', 'CONSTANTE', '*', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'purch_leadtime', NULL, NULL, 'STANDARD', 'CONSTANTE', '0', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'qty_calc_rounding', NULL, NULL, 'STANDARD', 'CONSTANTE', '0', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'reset_config_std_cost_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FALSE', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'shortage_flag_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'Y', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'stock_management_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'Y', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'supply_code_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'IO', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'type_code_db', NULL, NULL, 'STANDARD', 'CONSTANTE', '1', 'Repris de etl_default_values par la migration 071. Source : alimenter_inventory_part_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'zero_cost_flag_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'Y', 'Repris de etl_default_values par la migration 071. Source : alimenter_inventory_part_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FALSE', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'auto_replace_alt_comp_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FALSE', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'backflush_part_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'Y', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'component_scrap', NULL, NULL, 'STANDARD', 'CONSTANTE', '0', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'configuration_usage_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'Common', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'consider_lead_time_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'TRUE', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'cum_leadtime', NULL, NULL, 'STANDARD', 'CONSTANTE', '0', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'PLANNED', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'engineering_info_db', NULL, NULL, 'STANDARD', 'CONSTANTE', '0', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'fixed_leadtime_day', NULL, NULL, 'STANDARD', 'CONSTANTE', '0', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'fixed_leadtime_hour', NULL, NULL, 'STANDARD', 'CONSTANTE', '0', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'include_firm_demands', NULL, NULL, 'STANDARD', 'CONSTANTE', 'TRUE', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'include_firm_supplies', NULL, NULL, 'STANDARD', 'CONSTANTE', 'TRUE', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'issue_overreported_qty_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FALSE', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'issue_planned_scrap_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'TRUE', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'low_level', NULL, NULL, 'STANDARD', 'CONSTANTE', '0', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'mrp_control_flag_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'TRUE', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'optimize_new_delivery_date', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FALSE', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'order_gap_time', NULL, NULL, 'STANDARD', 'CONSTANTE', '0', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule', NULL, NULL, 'STANDARD', 'CONSTANTE', 'DIRECT', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'over_reporting_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'ALLOWED', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date', NULL, NULL, 'STANDARD', 'CONSTANTE', '', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'TRUE', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FALSE', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'promise_planned_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'Promised', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'routing_effectivity_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'DATE', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'run_crp', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FALSE', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'run_in_background', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FALSE', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'run_mrp', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FALSE', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'ship_dirty', NULL, NULL, 'STANDARD', 'CONSTANTE', '', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'ship_dirty_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FALSE', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'shrinkage_factor', NULL, NULL, 'STANDARD', 'CONSTANTE', '0', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'structure_effectivity_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'DATE', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'unprotected_lead_time', NULL, NULL, 'STANDARD', 'CONSTANTE', '0', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'use_theoritical_density_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FALSE', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'variable_leadtime_day', NULL, NULL, 'STANDARD', 'CONSTANTE', '0', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'variable_leadtime_hour', NULL, NULL, 'STANDARD', 'CONSTANTE', '0', 'Repris de etl_default_values par la migration 071. Source : alimenter_manuf_part_attribute_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'allow_as_not_consumed_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FALSE', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'catch_unit_enabled_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FALSE', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'component_lot_rule_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'MANY_LOTS_ALLOWED', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (valeur divergente entre modules)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'condition_code_usage_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'ALLOW_COND_CODE', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'configurable_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'NOT CONFIGURED', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'eng_serial_tracking_code_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'NOT SERIAL TRACKING', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'lot_quantity_rule_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'MULTI_LOTS', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'lot_tracking_code_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'LOT TRACKING', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'multilevel_tracking_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'TRACKING_OFF', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'position_part_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'NOT POSITION PART', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'receipt_issue_serial_track_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FALSE', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'serial_rule_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'MANUAL', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'serial_tracking_code_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'NOT SERIAL TRACKING', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'stop_arrival_issued_serial_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'TRUE', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'stop_new_serial_in_rma_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'TRUE', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'sub_lot_rule_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'NO_SUBLOTS', 'Repris de etl_default_values par la migration 071. Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'acquisition_type', NULL, NULL, 'STANDARD', 'CONSTANTE', '', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'acquisition_type_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'PURCHASE', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'action_authorized', NULL, NULL, 'STANDARD', 'CONSTANTE', '', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'action_authorized_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'WARNING', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'action_non_authorized', NULL, NULL, 'STANDARD', 'CONSTANTE', '', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'action_non_authorized_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'WARNING', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'close_code', NULL, NULL, 'STANDARD', 'CONSTANTE', '', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'close_code_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'Y', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'close_tolerance', NULL, NULL, 'STANDARD', 'CONSTANTE', '0', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'company', NULL, NULL, 'STANDARD', 'CONSTANTE', 'TRIMET', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'dop_pegged_po_update_flag', NULL, NULL, 'STANDARD', 'CONSTANTE', '', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'dop_pegged_po_update_flag_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'PLANNED', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'external_resource', NULL, NULL, 'STANDARD', 'CONSTANTE', '', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'external_resource_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FALSE', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'inventory_flag', NULL, NULL, 'STANDARD', 'CONSTANTE', '', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'inventory_flag_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'Y', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'over_delivery', NULL, NULL, 'STANDARD', 'CONSTANTE', '', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'over_delivery_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'YES', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'over_delivery_tolerance', NULL, NULL, 'STANDARD', 'CONSTANTE', '0', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'package_part_flag', NULL, NULL, 'STANDARD', 'CONSTANTE', '', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'package_part_flag_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FALSE', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'process_type', NULL, NULL, 'STANDARD', 'CONSTANTE', 'STD', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'qualified_manufacturer', NULL, NULL, 'STANDARD', 'CONSTANTE', '', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'qualified_manufacturer_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FALSE', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'qualified_supplier', NULL, NULL, 'STANDARD', 'CONSTANTE', '', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'qualified_supplier_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FALSE', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'standard_pack_size', NULL, NULL, 'STANDARD', 'CONSTANTE', '1', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'taxable', NULL, NULL, 'STANDARD', 'CONSTANTE', '', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'taxable_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'TRUE', 'Repris de etl_default_values par la migration 071. Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'activeind_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'Y', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'allow_incomp_pkg_delivery', NULL, NULL, 'STANDARD', 'CONSTANTE', 'TRUE', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'allow_inc_pkg_rsrv_picklst', NULL, NULL, 'STANDARD', 'CONSTANTE', 'TRUE', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'catalog_group', NULL, NULL, 'STANDARD', 'CONSTANTE', '903028', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'catalog_type_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'INV', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'close_tolerance', NULL, NULL, 'STANDARD', 'CONSTANTE', '0', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'conv_factor', NULL, NULL, 'STANDARD', 'CONSTANTE', '1', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'country_of_origin', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FR', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'create_sm_object_option_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'DONOTCREATESMOBJECT', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'export_to_external_app_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FALSE', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'inverted_conv_factor', NULL, NULL, 'STANDARD', 'CONSTANTE', '1', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'list_price', NULL, NULL, 'STANDARD', 'CONSTANTE', '0', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'list_price_incl_tax', NULL, NULL, 'STANDARD', 'CONSTANTE', '0', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'pack_comp_in_shpmnt', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FALSE', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'price_conv_factor', NULL, NULL, 'STANDARD', 'CONSTANTE', '1', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'primary_catalog_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'TRUE', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'quick_registered_part_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FALSE', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'rental_list_price', NULL, NULL, 'STANDARD', 'CONSTANTE', '0', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'rental_list_price_incl_tax', NULL, NULL, 'STANDARD', 'CONSTANTE', '0', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'sales_price_group_id', NULL, NULL, 'STANDARD', 'CONSTANTE', '*', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'sales_type_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'SALES', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'sourcing_option_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'NOTSUPPLIED', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'taxable_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'TRUE', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'tax_code', NULL, NULL, 'STANDARD', 'CONSTANTE', 'C05', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'use_price_incl_tax_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'FALSE', 'Repris de etl_default_values par la migration 071. Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_071', 'migration_071')
ON CONFLICT DO NOTHING;

COMMIT;

-- ============================================================================
-- ROLLBACK
-- ============================================================================
-- BEGIN;
-- DELETE FROM public.etl_default_value_matrix WHERE created_by = 'migration_071';
-- DROP FUNCTION IF EXISTS public.get_matrix_value(VARCHAR, VARCHAR, VARCHAR, VARCHAR);
-- COMMIT;
-- Puis remettre les 5 procedures d'avant : git checkout sql/articlePhl && ./compile.sh
