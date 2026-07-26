-- =====================================================
-- Script d'alimentation de la table PROJECT_MARGIN_MATRIX depuis SharePoint
-- Date: 2025-11-21
-- Description: Création de la matrice des marges pour les projets
-- =====================================================

CREATE OR REPLACE FUNCTION clean_data.alimenter_ifs_project_margin_matrix()
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
    v_inserted_count INTEGER := 0;
    rec RECORD;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Début alimentation PROJECT_MARGIN_MATRIX depuis SharePoint';
    RAISE NOTICE '========================================';
    
    -- Vider et réinsérer dans PROJECT_MARGIN_MATRIX
    TRUNCATE TABLE clean_data.PROJECT_MARGIN_MATRIX CASCADE;
    
    -- Insertion de la matrice des marges
    -- La matrice calcule les marges basées sur les budgets SharePoint
    INSERT INTO clean_data.PROJECT_MARGIN_MATRIX (
        company,
        project_id,
        
        -- Coûts et revenus
        total_cost,
        total_revenue,
        margin_amount,
        margin_percent,
        
        -- Budget détaillé
        budget_planned,
        budget_actual,
        budget_variance,
        budget_at_completion,
        
        -- Phases de budget
        budget_demanded,
        budget_delivered,
        budget_im_sap,
        budget_ex_sap,
        
        -- Métadonnées
        objid,
        objversion,
        last_updated,
        created_at
    )
    SELECT
        pb.company,
        pb.project_id,
        
        -- TOTAL_COST: Coût planifié
        COALESCE(pb.planned_cost, 0) as total_cost,
        
        -- TOTAL_REVENUE: Revenu planifié (0 si non défini)
        COALESCE(pb.planned_revenue, 0) as total_revenue,
        
        -- MARGIN_AMOUNT: Marge = Revenu - Coût
        (COALESCE(pb.planned_revenue, 0) - COALESCE(pb.planned_cost, 0)) as margin_amount,
        
        -- MARGIN_PERCENT: Pourcentage de marge
        CASE 
            WHEN COALESCE(pb.planned_revenue, 0) > 0 
            THEN ((COALESCE(pb.planned_revenue, 0) - COALESCE(pb.planned_cost, 0)) 
                  / pb.planned_revenue * 100)
            ELSE 0
        END as margin_percent,
        
        -- BUDGET_PLANNED: Budget initial
        COALESCE(sp.budget_initial, 0) as budget_planned,
        
        -- BUDGET_ACTUAL: Budget actuel/réel
        COALESCE(sp.budget_actual, sp.budget_total_sap, 0) as budget_actual,
        
        -- BUDGET_VARIANCE: Écart budgétaire
        (COALESCE(sp.budget_actual, sp.budget_total_sap, 0) - COALESCE(sp.budget_initial, 0)) as budget_variance,
        
        -- BUDGET_AT_COMPLETION: Budget à l'achèvement
        COALESCE(sp.budget_at_completion, sp.budget_actual, sp.budget_total_sap, 0) as budget_at_completion,
        
        -- Phases de budget SharePoint
        COALESCE(sp.budget_demanded, 0) as budget_demanded,
        COALESCE(sp.budget_delivered, 0) as budget_delivered,
        COALESCE(sp.budget_im_sap, 0) as budget_im_sap,
        COALESCE(sp.budget_ex_sap, 0) as budget_ex_sap,
        
        -- Métadonnées
        md5(pb.company || pb.project_id || 'margin')::uuid as objid,
        '1' as objversion,
        CURRENT_TIMESTAMP as last_updated,
        CURRENT_TIMESTAMP as created_at
        
    FROM clean_data.PROJECT_BASE pb
    LEFT JOIN raw_data.sharepoint_projets sp ON (
        CASE 
            WHEN pb.project_id ~ '^\d{2}\.\d{3}$' THEN pb.project_id = sp.code
            ELSE pb.project_id = LPAD(sp.sharepoint_id::TEXT, 10, '0')
        END
    )
    WHERE pb.project_id IS NOT NULL
    ORDER BY pb.project_id;
    
    GET DIAGNOSTICS v_inserted_count = ROW_COUNT;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Résumé de l''alimentation PROJECT_MARGIN_MATRIX';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Matrices de marge insérées: %', v_inserted_count;
    RAISE NOTICE 'Total matrices dans PROJECT_MARGIN_MATRIX: %', 
        (SELECT COUNT(*) FROM clean_data.PROJECT_MARGIN_MATRIX);
    RAISE NOTICE '';
    
    -- Statistiques globales
    RAISE NOTICE '=== STATISTIQUES BUDGÉTAIRES ===';
    FOR rec IN (
        SELECT 
            COUNT(*) as nb_projets,
            SUM(total_cost) as cout_total,
            SUM(total_revenue) as revenu_total,
            SUM(margin_amount) as marge_totale,
            AVG(margin_percent) as marge_moyenne_pct,
            SUM(budget_variance) as ecart_budget_total
        FROM clean_data.PROJECT_MARGIN_MATRIX
    ) LOOP
        RAISE NOTICE '  Nombre de projets: %', rec.nb_projets;
        RAISE NOTICE '  Coût total: % €', ROUND(rec.cout_total, 2);
        RAISE NOTICE '  Revenu total: % €', ROUND(rec.revenu_total, 2);
        RAISE NOTICE '  Marge totale: % €', ROUND(rec.marge_totale, 2);
        RAISE NOTICE '  Marge moyenne: % %%', ROUND(rec.marge_moyenne_pct, 2);
        RAISE NOTICE '  Écart budgétaire total: % €', ROUND(rec.ecart_budget_total, 2);
    END LOOP;
    
    -- Top 5 des projets par budget
    RAISE NOTICE '';
    RAISE NOTICE '=== TOP 5 PROJETS PAR BUDGET ===';
    FOR rec IN (
        SELECT 
            project_id,
            total_cost,
            margin_percent
        FROM clean_data.PROJECT_MARGIN_MATRIX
        ORDER BY total_cost DESC
        LIMIT 5
    ) LOOP
        RAISE NOTICE '  Projet % : % € (Marge: % %%)', 
            rec.project_id, 
            ROUND(rec.total_cost, 2), 
            ROUND(rec.margin_percent, 2);
    END LOOP;
    
    -- Projets avec écart budgétaire important
    RAISE NOTICE '';
    RAISE NOTICE '=== PROJETS AVEC ÉCART BUDGÉTAIRE > 10%% ===';
    FOR rec IN (
        SELECT 
            project_id,
            budget_planned,
            budget_actual,
            budget_variance,
            CASE 
                WHEN budget_planned > 0 
                THEN (budget_variance / budget_planned * 100)
                ELSE 0
            END as variance_percent
        FROM clean_data.PROJECT_MARGIN_MATRIX
        WHERE budget_planned > 0
          AND ABS(budget_variance / budget_planned * 100) > 10
        ORDER BY ABS(budget_variance) DESC
        LIMIT 10
    ) LOOP
        RAISE NOTICE '  Projet % : Planifié=% €, Réel=% €, Écart=% € (% %%)', 
            rec.project_id,
            ROUND(rec.budget_planned, 2),
            ROUND(rec.budget_actual, 2),
            ROUND(rec.budget_variance, 2),
            ROUND(rec.variance_percent, 2);
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Alimentation PROJECT_MARGIN_MATRIX terminée avec succès';
    RAISE NOTICE '========================================';

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION '❌ Erreur lors de l''alimentation PROJECT_MARGIN_MATRIX: %', SQLERRM;
END;
$function$;

-- Commentaire sur la fonction
COMMENT ON FUNCTION clean_data.alimenter_ifs_project_margin_matrix() IS 
'Alimente la table PROJECT_MARGIN_MATRIX avec les calculs de marges depuis SharePoint et PROJECT_BASE';
