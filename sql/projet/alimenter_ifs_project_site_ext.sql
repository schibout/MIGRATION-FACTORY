CREATE OR REPLACE FUNCTION clean_data.alimenter_ifs_project_site_ext()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_inserted_count INTEGER := 0;
    rec RECORD;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Début alimentation PROJECT_SITE_EXT depuis SharePoint';
    RAISE NOTICE '========================================';
    
    -- Vider et réinsérer dans PROJECT_SITE_EXT
    TRUNCATE TABLE clean_data.PROJECT_SITE_EXT CASCADE;
    
    -- Insertion de l'association projet-site
    -- Mapping du site géographique depuis group_name
    INSERT INTO clean_data.PROJECT_SITE_EXT (
        company,
        project_id,
        site,
        project_site_type_db,
        use_std_inv_in_pmrp_db,
        auto_trans_from_std_inv_db
    )
    SELECT
        pb.company,
        pb.project_id,
        SUBSTRING(
            CASE sp.group_name
                WHEN 'Saint Jean de Maurienne' THEN 'SJ'
                WHEN 'Castelsarrasin' THEN 'CS'
                ELSE 'SJ' -- Site par défaut: Saint Jean de Maurienne
            END,
            1, 5
        ) as site,
        'DEFAULTSITE' as project_site_type_db,
        'FALSE' as use_std_inv_in_pmrp_db,
        'FALSE' as auto_trans_from_std_inv_db
        
    FROM clean_data.project_base pb
    LEFT JOIN raw_data.sharepoint_projets sp
        ON pb.project_id = SUBSTRING(COALESCE(sp.project_number, sp.code), 1, 10)
    WHERE pb.project_id IS NOT NULL
    ORDER BY pb.project_id;
    
    GET DIAGNOSTICS v_inserted_count = ROW_COUNT;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Résumé de l''alimentation PROJECT_SITE_EXT';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Associations projet-site insérées: %', v_inserted_count;
    RAISE NOTICE 'Total associations dans PROJECT_SITE_EXT: %', 
        (SELECT COUNT(*) FROM clean_data.PROJECT_SITE_EXT);
    RAISE NOTICE '';
    
    -- Statistiques par site
    RAISE NOTICE '=== RÉPARTITION PAR SITE ===';
    FOR rec IN (
        SELECT 
            site,
            COUNT(*) as nb_projets
        FROM clean_data.PROJECT_SITE_EXT
        GROUP BY site
        ORDER BY nb_projets DESC
    ) LOOP
        RAISE NOTICE '  - % : % projets', rec.site, rec.nb_projets;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== RÉPARTITION PAR SOCIÉTÉ ===';
    FOR rec IN (
        SELECT 
            company,
            COUNT(*) as nb_associations
        FROM clean_data.PROJECT_SITE_EXT
        GROUP BY company
        ORDER BY nb_associations DESC
    ) LOOP
        RAISE NOTICE '  - % : % associations', rec.company, rec.nb_associations;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Alimentation PROJECT_SITE_EXT terminée avec succès';
    RAISE NOTICE '========================================';

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION '❌ Erreur lors de l''alimentation PROJECT_SITE_EXT: %', SQLERRM;
END;
$function$

