CREATE OR REPLACE FUNCTION clean_data.alimenter_inventory_part_planning()
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
    v_count_inserted INTEGER := 0;
    v_count_errors INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    RAISE NOTICE 'Début de l''alimentation de la planification des articles (INVENTORY_PART_PLANNING) - %', v_start_time;
    
    -- Vider la table cible avant insertion
    TRUNCATE TABLE clean_data.invent_part_plan RESTART IDENTITY;
    RAISE NOTICE 'Table invent_part_plan vidée';

    -- INDISPENSABLE avant le EXISTS sur inventory_part ci-dessous.
    -- inventory_part vient d'etre TRUNCATE puis rechargee par
    -- alimenter_inventory_part() dans LA MEME transaction : ses statistiques
    -- annoncent donc une table vide. Sans cet ANALYZE, le planificateur choisit
    -- une nested loop et, la table n'ayant aucun index, la fonction part sur
    -- ~24 000 x 18 000 comparaisons (plusieurs dizaines de minutes).
    -- Avec des statistiques a jour il choisit un hash semi-join (quelques s).
    ANALYZE clean_data.inventory_part;
    
    -- Insertion des données de planification depuis SAP
    INSERT INTO clean_data.invent_part_plan (
        -- Clés (Primary Key)
        contract,
        part_no,
        
        -- Dates
        last_activity_date,
        
        -- Tailles de lot
        lot_size,
        lot_size_auto,
        lot_size_auto_db,
        max_order_qty,
        min_order_qty,
        mul_order_qty,
        std_order_size,
        
        -- Point de commande et stock
        order_point_qty,
        order_point_qty_auto,
        order_point_qty_auto_db,
        safety_stock,
        safety_stock_auto,
        safety_stock_auto_db,
        
        -- Délais et couverture
        safety_lead_time,
        maxweek_supply,
        
        -- Coûts
        setup_cost,
        carry_rate,
        service_rate,
        shrinkage_fac,
        
        -- Méthode de planification
        planning_method,
        planning_method_auto,
        planning_method_auto_db,
        
        -- Type d'approvisionnement
        order_requisition,
        order_requisition_db,
        proposal_release,
        proposal_release_db,
        
        -- Split fabrication/achat
        percent_manufactured,
        percent_acquired,
        split_manuf_acquired,
        split_manuf_acquired_db,
        acquired_supply_type,
        acquired_supply_type_db,
        manuf_supply_type,
        manuf_supply_type_db,
        
        -- Capacité de planification
        sched_capacity,
        sched_capacity_db
    )
    SELECT DISTINCT
        -- Clés
        CASE 
            WHEN marc.werks = '9000' THEN 'CS'
            WHEN marc.werks = '9200' THEN 'SJ'
            ELSE 'SJ'
        END as contract,
        -- TRIM indispensable : inventory_part construit son part_no avec
        -- TRIM(LTRIM(...)). Sans lui, tout matnr avec un espace de fin donnait
        -- une cle differente => ligne de planification orpheline.
        SUBSTRING(TRIM(LTRIM(mara.matnr, '0')), 1, 25) as part_no,
        
        -- Dates
        CURRENT_TIMESTAMP as last_activity_date,
        
        -- Tailles de lot (sources SAP MARC)
        COALESCE(NULLIF(marc.bstmi, '')::numeric, 0) as lot_size,
        'Manual Lot Size' as lot_size_auto,
        'N' as lot_size_auto_db,
        COALESCE(NULLIF(marc.bstma, '')::numeric, 0) as max_order_qty,
        COALESCE(NULLIF(marc.bstmi, '')::numeric, 0) as min_order_qty,
        0 as mul_order_qty,
        COALESCE(NULLIF(marc.bstmi, '')::numeric, 0) as std_order_size,
        
        -- Point de commande et stock
        COALESCE(NULLIF(marc.minbe, '')::numeric, 0) as order_point_qty,
        'Manual Order Point' as order_point_qty_auto,
        'N' as order_point_qty_auto_db,
        COALESCE(NULLIF(marc.eisbe, '')::numeric, 0) as safety_stock,
        'Manual Safety Stock' as safety_stock_auto,
        'N' as safety_stock_auto_db,
        
        -- Délais et couverture
        COALESCE(NULLIF(marc.shflg, '')::numeric, 0) as safety_lead_time,
        0 as maxweek_supply,
        
        -- Coûts
        0 as setup_cost,
        0 as carry_rate,
        0 as service_rate,
        0 as shrinkage_fac,
        
        -- Méthode de planification (MARC.DISMM)
        CASE 
            -- Si VB, ZM, ZB → B (Planning Method Point commande)
            WHEN UPPER(marc.dismm) IN ('VB', 'ZM', 'ZB') THEN 'B'
            -- Si vide, M0, RP, PD, ZP → M (Planifié manuellement)
            WHEN UPPER(marc.dismm) IN ('', 'M0', 'RP', 'PD', 'ZP') OR marc.dismm IS NULL THEN 'M'
            -- Pour tout ce qui est Production → A (Lot pour lot)
            WHEN marc.beskz = 'E' THEN 'A'
            -- Par défaut → M
            ELSE 'M'
        END as planning_method,
        'True' as planning_method_auto,
        'TRUE' as planning_method_auto_db,
        
        -- Type d'approvisionnement
        'Requisition' as order_requisition,
        'R' as order_requisition_db,
        'Release' as proposal_release,
        'RELEASE' as proposal_release_db,
        
        -- Split fabrication/achat
        CASE 
            WHEN marc.beskz = 'E' THEN 100  -- 100% fabriqué si production
            ELSE 0
        END as percent_manufactured,
        CASE 
            WHEN marc.beskz = 'E' THEN 0    -- 0% acheté si production
            ELSE 100                         -- 100% acheté sinon
        END as percent_acquired,
        'No Split' as split_manuf_acquired,
        'NO_SPLIT' as split_manuf_acquired_db,
        'Requisition' as acquired_supply_type,
        'R' as acquired_supply_type_db,
        'Requisition' as manuf_supply_type,
        'R' as manuf_supply_type_db,
        
        -- Capacité de planification
        'Infinite Capacity' as sched_capacity,
        'I' as sched_capacity_db
        
    FROM raw_data.mara mara
    INNER JOIN raw_data.marc marc
        ON mara.matnr = marc.matnr
        AND marc.mandt = '700'

    WHERE
        -- Mandant SAP, comme alimenter_inventory_part(). Sans ce filtre, un meme
        -- article present dans plusieurs mandants produisait plusieurs lignes
        -- pour la meme cle (contract, part_no).
        mara.mandt = '700'
        -- Filtrer uniquement les articles stockables
        AND mara.mtart IN ('ERSA', 'HIBE', 'ROH', 'HALB', 'FERT')
        -- Sites Trimet : meme perimetre que alimenter_inventory_part().
        -- 9100 retire : il retombait sur le contract 'SJ' par defaut et
        -- fabriquait des cles (SJ, part_no) en doublon de celles du site 9200.
        AND marc.werks IN ('9200', '9000')
        AND mara.lvorm IS NULL   -- Non supprimés
        AND TRIM(mara.matnr) != ''
        -- Aucune ligne de planification sans son inventory_part : c'est la
        -- garantie structurelle contre les orphelins rejetes au chargement IFS.
        -- alimenter_inventory_part() est toujours appelee avant cette fonction
        -- (cf. etl_modules/etl_inventory_part.py).
        AND EXISTS (
            SELECT 1 FROM clean_data.inventory_part ip
            WHERE ip.part_no = SUBSTRING(TRIM(LTRIM(mara.matnr, '0')), 1, 25)
              AND ip.contract = CASE
                    WHEN marc.werks = '9000' THEN 'CS'
                    WHEN marc.werks = '9200' THEN 'SJ'
                    ELSE 'SJ'
                  END
        )

    ORDER BY contract, part_no;
    
    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;
    
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;
    
    -- Log des résultats
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Alimentation INVENTORY_PART_PLANNING terminée';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Articles planification insérés: %', v_count_inserted;
    RAISE NOTICE 'Durée d''exécution: %', v_duration;
    RAISE NOTICE 'Début: %, Fin: %', v_start_time, v_end_time;
    RAISE NOTICE '====================================================';
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;
        
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'ERREUR lors alimentation INVENTORY_PART_PLANNING';
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'Code d''erreur: %', SQLSTATE;
        RAISE NOTICE 'Message: %', SQLERRM;
        RAISE NOTICE 'Durée avant erreur: %', v_duration;
        RAISE NOTICE '====================================================';
        
        RAISE;
END;
$function$;

COMMENT ON FUNCTION clean_data.alimenter_inventory_part_planning() IS 
'Alimente la table INVENT_PART_PLAN depuis MARC SAP.
Mapping Planning Method (MARC.DISMM):
  - VB/ZM/ZB → B (Point commande)
  - vide/M0/RP/PD/ZP → M (Manuel)
  - Production (BESKZ=E) → A (Lot pour lot)
Sites: 9000=CAST, 9200=SJM, 9100=CAST';