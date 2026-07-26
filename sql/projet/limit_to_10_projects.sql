-- Procédure pour limiter les données à 10 projets et leurs objets liés
-- Utile pour les tests et le développement

CREATE OR REPLACE FUNCTION clean_data.limit_to_10_projects()
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
    v_project_ids TEXT;
    v_count_projects INTEGER;
    v_count_activities INTEGER;
    v_count_sub_projects INTEGER;
    v_count_roles INTEGER;
    v_count_role_assignments INTEGER;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Limitation des données à 10 projets';
    RAISE NOTICE '========================================';
    
    -- Créer une table temporaire avec les 10 premiers project_id
    DROP TABLE IF EXISTS temp_project_ids;
    CREATE TEMP TABLE temp_project_ids AS
    SELECT project_id
    FROM clean_data.project_base
    ORDER BY project_id
    LIMIT 10;
    
    GET DIAGNOSTICS v_count_projects = ROW_COUNT;
    RAISE NOTICE 'Projets sélectionnés: %', v_count_projects;
    
    -- Afficher les project_id sélectionnés
    SELECT string_agg(project_id, ', ' ORDER BY project_id)
    INTO v_project_ids
    FROM temp_project_ids;
    RAISE NOTICE 'IDs des projets: %', v_project_ids;
    
    -- 1. Supprimer les activités des projets non sélectionnés
    DELETE FROM clean_data.activity
    WHERE project_id NOT IN (SELECT project_id FROM temp_project_ids);
    
    GET DIAGNOSTICS v_count_activities = ROW_COUNT;
    RAISE NOTICE 'Activités supprimées: %', v_count_activities;
    
    -- 2. Supprimer les sous-projets des projets non sélectionnés
    DELETE FROM clean_data.sub_project
    WHERE project_id NOT IN (SELECT project_id FROM temp_project_ids);
    
    GET DIAGNOSTICS v_count_sub_projects = ROW_COUNT;
    RAISE NOTICE 'Sous-projets supprimés: %', v_count_sub_projects;
    
    -- 3. Supprimer les affectations de rôles des projets non sélectionnés
    DELETE FROM clean_data.project_role_assignment
    WHERE project_id NOT IN (SELECT project_id FROM temp_project_ids);
    
    GET DIAGNOSTICS v_count_role_assignments = ROW_COUNT;
    RAISE NOTICE 'Affectations de rôles supprimées: %', v_count_role_assignments;
    
    -- 4. Supprimer les rôles des projets non sélectionnés
    DELETE FROM clean_data.project_role
    WHERE project_id NOT IN (SELECT project_id FROM temp_project_ids);
    
    GET DIAGNOSTICS v_count_roles = ROW_COUNT;
    RAISE NOTICE 'Rôles supprimés: %', v_count_roles;
    
    -- 5. Supprimer les extensions de site des projets non sélectionnés
    DELETE FROM clean_data.project_site_ext
    WHERE project_id NOT IN (SELECT project_id FROM temp_project_ids);
    
    RAISE NOTICE 'Extensions de site supprimées';
    
    -- 6. Supprimer les projets non sélectionnés de project_base
    DELETE FROM clean_data.project_base
    WHERE project_id NOT IN (SELECT project_id FROM temp_project_ids);
    
    RAISE NOTICE 'Projets supprimés de project_base';
    
    -- Statistiques finales
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Résumé final';
    RAISE NOTICE '========================================';
    
    SELECT COUNT(*) INTO v_count_projects FROM clean_data.project_base;
    RAISE NOTICE 'Projets restants: %', v_count_projects;
    
    SELECT COUNT(*) INTO v_count_activities FROM clean_data.activity;
    RAISE NOTICE 'Activités restantes: %', v_count_activities;
    
    SELECT COUNT(*) INTO v_count_sub_projects FROM clean_data.sub_project;
    RAISE NOTICE 'Sous-projets restants: %', v_count_sub_projects;
    
    SELECT COUNT(*) INTO v_count_role_assignments FROM clean_data.project_role_assignment;
    RAISE NOTICE 'Affectations de rôles restantes: %', v_count_role_assignments;
    
    SELECT COUNT(*) INTO v_count_roles FROM clean_data.project_role;
    RAISE NOTICE 'Rôles restants: %', v_count_roles;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Limitation terminée avec succès';
    RAISE NOTICE '========================================';
    
    -- Nettoyer la table temporaire
    DROP TABLE IF EXISTS temp_project_ids;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ ERREUR lors de la limitation des projets';
        RAISE NOTICE 'Code d''erreur: %', SQLSTATE;
        RAISE NOTICE 'Message d''erreur: %', SQLERRM;
        
        -- Nettoyer la table temporaire en cas d'erreur
        DROP TABLE IF EXISTS temp_project_ids;
        
        -- Relancer l'exception
        RAISE;
END;
$function$;

-- Commentaire sur la fonction
COMMENT ON FUNCTION clean_data.limit_to_10_projects() IS 
'Limite les données à 10 projets et supprime tous les objets liés aux autres projets. 
Utile pour les tests et le développement.';

