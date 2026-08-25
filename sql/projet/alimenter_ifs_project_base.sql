CREATE OR REPLACE FUNCTION clean_data.alimenter_ifs_project_base()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_inserted_count INTEGER := 0;
    v_updated_count INTEGER := 0;
    v_error_count INTEGER := 0;
    rec RECORD;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Début alimentation project_base depuis SharePoint';
    RAISE NOTICE '========================================';
    
    -- Vider et réinsérer dans project_base
    TRUNCATE TABLE clean_data.project_base CASCADE;
    
    -- Insertion des données de base des projets depuis SharePoint
    INSERT INTO clean_data.project_base (
        project_id,
        name,
        description,
        actual_start,
        manager,
        company,
        calendar_id,
        program_id,
        category1_id,
        category2_id,
        planned_cost,
        date_created,
        baseline_revision_number,
        earned_value_method,
        earned_value_method_db,
        material_allocation,
        material_allocation_db,
        financially_responsible,
        budget_control_on_db,
        control_as_budgeted_db,
        control_on_total_budget_db,
        proj_unique_purchase_db,
        proj_unique_sale_db,
        multi_currency_budgeting,
        multi_currency_budgeting_db,
        project_misc_comp_method,
        project_misc_comp_method_db,
        plan_project_transaction_db,
        work_day_to_hours_conv
    )
    SELECT 
        -- PROJECT_ID: project_number depuis SharePoint
        SUBSTRING(COALESCE(sp.project_number, sp.code), 1, 10) as project_id,
        
        -- NAME: 35 premiers caractères du titre (OBLIGATOIRE)
        SUBSTRING(COALESCE(sp.title, 'Projet ' || sp.sharepoint_id), 1, 35) as name,
        
        -- DESCRIPTION: Description limitée à 2000 caractères
        SUBSTRING(COALESCE(sp.site_url_description, ''), 1, 2000) as description,
        
        -- ACTUAL_START: Date de début SharePoint
        sp.start_date::DATE as actual_start,
        
        -- MANAGER: person_id depuis sharepoint_users (OBLIGATOIRE)
        SUBSTRING(
            COALESCE(
                pm_user.person_id,
                'THOMAS.PATOUILLARD'
            ),
            1, 20
        ) as manager,
        
        -- COMPANY: 'TRIMET' en production (OBLIGATOIRE)
        SUBSTRING('TRIMET', 1, 20) as company,
        
        -- CALENDAR_ID: Valeur par défaut '*' (OBLIGATOIRE)
        SUBSTRING('*', 1, 10) as calendar_id,
        
        -- PROGRAM_ID: CAPEX
        'CAPEX' as program_id,
        
        -- CATEGORY1_ID: Recherche via table de transcodification
        COALESCE(
            public.get_transcodification('CATEGORIE_1', sp.sector, 'ASAP', 'IFS'),
            'SS_STAT'
        ) as category1_id,
        
        -- CATEGORY2_ID: MECA
        'MECA' as category2_id,
        
        -- PLANNED_COST: Budget initial SharePoint
        COALESCE(sp.budget_initial, sp.budget_total_sap, 0) as planned_cost,
        
        -- DATE_CREATED: Date de début SharePoint ou created
        COALESCE(sp.start_date, sp.created)::DATE as date_created,
        
        -- BASELINE_REVISION_NUMBER: '0' par défaut
        '0' as baseline_revision_number,
        
        -- EARNED_VALUE_METHOD: 'Planned' par défaut (OBLIGATOIRE)
        'Planned' as earned_value_method,
        
        -- EARNED_VALUE_METHOD_DB: 'PLANNED'
        SUBSTRING('PLANNED', 1, 20) as earned_value_method_db,
        
        -- MATERIAL_ALLOCATION: 'Within Project' par défaut (OBLIGATOIRE)
        'Within Project' as material_allocation,
        
        -- MATERIAL_ALLOCATION_DB: 'WITHIN_PROJECT'
        SUBSTRING('WITHIN_PROJECT', 1, 25) as material_allocation_db,
        
        -- FINANCIALLY_RESPONSIBLE: person_id depuis sharepoint_users du sponsor
        SUBSTRING(
            COALESCE(
                sponsor_user.person_id,
                'PEGGY.TRACOL'
            ),
            1, 20
        ) as financially_responsible,
        
        -- BUDGET_CONTROL_ON_DB: 'FALSE'
        SUBSTRING('FALSE', 1, 20) as budget_control_on_db,
        
        -- CONTROL_AS_BUDGETED_DB: 'FALSE'
        SUBSTRING('FALSE', 1, 20) as control_as_budgeted_db,
        
        -- CONTROL_ON_TOTAL_BUDGET_DB: 'FALSE'
        SUBSTRING('FALSE', 1, 20) as control_on_total_budget_db,
        
        -- PROJ_UNIQUE_PURCHASE_DB: 'FALSE'
        SUBSTRING('FALSE', 1, 5) as proj_unique_purchase_db,
        
        -- PROJ_UNIQUE_SALE_DB: 'FALSE'
        SUBSTRING('FALSE', 1, 5) as proj_unique_sale_db,
        
        -- MULTI_CURRENCY_BUDGETING: 'FALSE' par défaut (OBLIGATOIRE)
        'FALSE' as multi_currency_budgeting,
        
        -- MULTI_CURRENCY_BUDGETING_DB: 'FALSE'
        SUBSTRING('FALSE', 1, 5) as multi_currency_budgeting_db,
        
        -- PROJECT_MISC_COMP_METHOD: 'Manually Planned' par défaut (OBLIGATOIRE)
        'Manually Planned' as project_misc_comp_method,
        
        -- PROJECT_MISC_COMP_METHOD_DB: 'MANUALLY_PLANNED'
        SUBSTRING('MANUALLY_PLANNED', 1, 20) as project_misc_comp_method_db,
        
        -- PLAN_PROJECT_TRANSACTION_DB: 'FALSE'
        SUBSTRING('FALSE', 1, 20) as plan_project_transaction_db,
        
        -- WORK_DAY_TO_HOURS_CONV: 7 (au lieu de 8)
        7 as work_day_to_hours_conv
        
    FROM raw_data.sharepoint_projets sp
    LEFT JOIN raw_data.sharepoint_users pm_user 
        ON sp.pm_id = pm_user.sharepoint_user_id
    LEFT JOIN raw_data.sharepoint_users sponsor_user 
        ON sp.sponsor_id = sponsor_user.sharepoint_user_id
    WHERE COALESCE(sp.project_number, sp.code) IS NOT NULL -- Projets avec un identifiant (project_number OU code)
        AND sp.sharepoint_id IS NOT NULL
        AND COALESCE(sp.global_status, '') NOT IN ('Clôturé', 'Annulé') -- Exclure les projets clôturés et annulés
        -- Ne garder QUE les projets présents dans l'export raw_data.sharepoint_project_to_save
        AND sp.project_number IN (
            SELECT "Numéro du projet"
            FROM raw_data.sharepoint_project_to_save
            WHERE "Numéro du projet" IS NOT NULL
        )
    ORDER BY sp.sharepoint_id;
    
    GET DIAGNOSTICS v_inserted_count = ROW_COUNT;
    
    -- Mise à jour de la date de modification
    UPDATE clean_data.project_base 
    SET date_modified = CURRENT_DATE,
        updated_at = CURRENT_TIMESTAMP;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Résumé de l''alimentation project_base';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Projets insérés: %', v_inserted_count;
    RAISE NOTICE 'Total projets dans project_base: %', (SELECT COUNT(*) FROM clean_data.project_base);
    RAISE NOTICE '';
    
    -- Statistiques par secteur
    RAISE NOTICE '=== RÉPARTITION PAR SECTEUR (CATEGORY1) ===';
    FOR rec IN (
        SELECT 
            category1_id,
            COUNT(*) as nb_projets,
            SUM(planned_cost) as budget_total
        FROM clean_data.project_base
        GROUP BY category1_id
        ORDER BY nb_projets DESC
    ) LOOP
        RAISE NOTICE '  - % : % projets (Budget: %)', 
            rec.category1_id, rec.nb_projets, COALESCE(rec.budget_total, 0);
    END LOOP;
    
    -- Statistiques par company
    RAISE NOTICE '';
    RAISE NOTICE '=== RÉPARTITION PAR SOCIÉTÉ ===';
    FOR rec IN (
        SELECT 
            company,
            COUNT(*) as nb_projets
        FROM clean_data.project_base
        GROUP BY company
        ORDER BY nb_projets DESC
    ) LOOP
        RAISE NOTICE '  - % : % projets', rec.company, rec.nb_projets;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Alimentation project_base terminée avec succès';
    RAISE NOTICE '========================================';

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION '❌ Erreur lors de l''alimentation project_base: %', SQLERRM;
END;
$function$
