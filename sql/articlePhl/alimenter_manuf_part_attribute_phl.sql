-- =====================================================================
-- clean_data.alimenter_manuf_part_attribute_phl()
-- Alimente clean_data.manuf_part_attribute pour les articles FABRIQUES PHL.
--
-- Calque sur clean_data.alimenter_inventory_part_phl() :
--   - source raw_data.phl_article, contract 'SJ' (Saint-Jean)
--   - SUBSTRING(TRIM(...)) pour borner les longueurs
--   - SELECT DISTINCT ON (part_no) pour dedupliquer
--   - garde d'idempotence (NOT EXISTS) sur (contract, part_no)
--   - GET DIAGNOSTICS + RAISE NOTICE + bloc EXCEPTION
--
-- Specificite : manuf_part_attribute etend inventory_part. La garde EXISTS
-- pointe donc sur inventory_part (table parente), et non sur part_catalog.
--
-- Valeurs des colonnes _db = valeurs par defaut IFS de la spec
-- MANUF_PART_ATTRIBUTE (commentaire = libelle client correspondant).
-- Les colonnes d'affichage (sans _db) et les colonnes sans defaut fiable
-- sont laissees a NULL (cf. notes en bas de fichier).
-- =====================================================================
CREATE OR REPLACE FUNCTION clean_data.alimenter_manuf_part_attribute_phl()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_count_inserted INTEGER := 0;
    v_count_orphans INTEGER := 0;
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
        configuration_usage_db,
        dop_pegged_so_update_flag_db,
        mrp_control_flag_db,
        prod_part_as_supply_in_mrp_db,
        use_theoritical_density_db,
        over_reporting_db,
        issue_planned_scrap_db,
        adjust_on_op_qty_deviation_db,
        issue_overreported_qty_db,
        plan_manuf_sup_on_due_date_db,
        ship_dirty_db,
        auto_replace_alt_comp_db,
        consider_lead_time_db,
        -- quantites
        component_scrap,
        shrinkage_factor
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
        'Common'   as configuration_usage_db,         -- Common
        'PLANNED'  as dop_pegged_so_update_flag_db,   -- Planned
        'TRUE'     as mrp_control_flag_db,            -- True
        'FALSE'    as prod_part_as_supply_in_mrp_db,  -- False
        'FALSE'    as use_theoritical_density_db,     -- False (defaut ajoute, non present dans la spec)
        'ALLOWED'  as over_reporting_db,              -- Allowed
        'TRUE'     as issue_planned_scrap_db,         -- True
        'FALSE'    as adjust_on_op_qty_deviation_db,  -- False
        'FALSE'    as issue_overreported_qty_db,      -- False
        'TRUE'     as plan_manuf_sup_on_due_date_db,  -- Plan Manufacturing Supply on Due Date : active pour tous
        'FALSE'    as ship_dirty_db,                  -- False
        'FALSE'    as auto_replace_alt_comp_db,       -- False
        'TRUE'     as consider_lead_time_db,          -- True

        0 as component_scrap,
        0 as shrinkage_factor

    -- Source dedoublonnee (cf. v_phl_article_retenu.sql)
    FROM raw_data.v_phl_article_retenu phl
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

    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;

    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Alimentation MANUF_PART_ATTRIBUTE (PHL) terminee avec succes';
    RAISE NOTICE 'Lignes orphelines supprimees (sans inventory_part): %', v_count_orphans;
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Lignes inserees: %', v_count_inserted;
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
$function$;

-- =====================================================================
-- Execution (apres avoir cree la table clean_data.manuf_part_attribute) :
--   SELECT clean_data.alimenter_manuf_part_attribute_phl();
-- Volume attendu sur les donnees actuelles : ~1 749 lignes (823 F + 926 I).
-- =====================================================================