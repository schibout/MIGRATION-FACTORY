CREATE OR REPLACE FUNCTION clean_data.alimenter_sub_project()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_count_inserted INTEGER := 0;
    v_count_updated INTEGER := 0;
    v_count_errors INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    RAISE NOTICE 'Début de l''alimentation des sous-projets (SUB_PROJECT) - %', v_start_time;
    
    -- Vider la table cible avant insertion
    TRUNCATE TABLE clean_data.sub_project RESTART IDENTITY;
    RAISE NOTICE 'Table sub_project vidée';
    
    -- Insérer 3 sous-projets (10, 20, 30) pour chaque projet depuis project_base
    INSERT INTO clean_data.sub_project (
        project_id,
        sub_project_id,
        description,
        manager,
        financially_completed_db,
        exclude_from_integrations_db
    )
    SELECT 
        -- PROJECT_ID: Référence au projet parent depuis project_base (OBLIGATOIRE)
        pb.project_id,
        
        -- SUB_PROJECT_ID: 10, 20 ou 30 pour chaque projet (OBLIGATOIRE)
        sub.sub_project_id,
        
        -- DESCRIPTION: Descriptions spécifiques selon le sous-projet (OBLIGATOIRE)
        -- 10 = Suivi des portes, 20= Suivi des coûts CAPEX, 30= Suivi des coûts OPEX
        SUBSTRING(sub.description, 1, 255) as description,
        
        -- MANAGER: Chef de projet dans asap (utilisation de la fonction de recherche person_id)
        COALESCE(
            clean_data.get_person_id_from_sharepoint_user_id(sp.pm_id::VARCHAR),
            pb.manager
        ) as manager,
        
        -- FINANCIALLY_COMPLETED_DB: FALSE
        public.get_default_value('clean_data.sub_project', 'financially_completed_db', 'FALSE') as financially_completed_db,
        
        -- EXCLUDE_FROM_INTEGRATIONS_DB: FALSE
        public.get_default_value('clean_data.sub_project', 'exclude_from_integrations_db', 'FALSE') as exclude_from_integrations_db
        
    FROM clean_data.project_base pb
    LEFT JOIN raw_data.sharepoint_projets sp 
        ON pb.project_id = SUBSTRING(COALESCE(sp.project_number, sp.code), 1, 10)
    CROSS JOIN (
        VALUES 
            ('10', 'Suivi des portes'),
            ('20', 'Suivi des coûts CAPEX'),
            ('30', 'Suivi des coûts OPEX')
    ) AS sub(sub_project_id, description)
    ORDER BY pb.project_id, sub.sub_project_id;
    
    -- Compter les enregistrements insérés
    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;
    
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;
    
    -- Log des résultats
    RAISE NOTICE 'Alimentation des sous-projets terminée avec succès';
    RAISE NOTICE 'Nombre d''enregistrements traités: %', v_count_inserted;
    RAISE NOTICE 'Durée d''exécution: %', v_duration;
    RAISE NOTICE 'Début: %, Fin: %', v_start_time, v_end_time;
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;
        
        RAISE NOTICE 'ERREUR lors de l''alimentation des sous-projets';
        RAISE NOTICE 'Code d''erreur: %', SQLSTATE;
        RAISE NOTICE 'Message d''erreur: %', SQLERRM;
        RAISE NOTICE 'Durée avant erreur: %', v_duration;
        
        -- Relancer l'exception pour arrêter le processus ETL
        RAISE;
END;
$function$
