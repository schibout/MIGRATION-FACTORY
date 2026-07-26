CREATE OR REPLACE FUNCTION clean_data.alimenter_ifs_project_role_assignment()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_inserted_count INTEGER := 0;
    v_project_count INTEGER := 0;
    v_seq_no NUMERIC := 1;
    rec RECORD;
    
    -- Fonction imbriquée pour insérer une affectation
    PROCEDURE insert_role_assignment(
        p_project_id VARCHAR,
        p_company VARCHAR,
        p_role_id VARCHAR,
        p_person_id VARCHAR
    ) AS $$
    BEGIN
        IF p_person_id IS NOT NULL AND p_person_id <> '' THEN
            INSERT INTO clean_data.project_role_assignment (
                assign_seq_no,
                project_id,
                company,
                role_id,
                person_id,
                system_generated
            )
            VALUES (
                v_seq_no,
                p_project_id,
                p_company,
                p_role_id,
                p_person_id,
                'FALSE'
            );
            v_seq_no := v_seq_no + 1;
            v_inserted_count := v_inserted_count + 1;
        END IF;
    END;
    $$;
    
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Début alimentation PROJECT_ROLE_ASSIGNMENT';
    RAISE NOTICE '========================================';
    
    -- Vider et réinsérer dans PROJECT_ROLE_ASSIGNMENT
    TRUNCATE TABLE clean_data.project_role_assignment CASCADE;
    
    -- Compter le nombre de projets
    SELECT COUNT(*) INTO v_project_count
    FROM clean_data.project_base
    WHERE project_id IS NOT NULL;
    
    RAISE NOTICE 'Nombre de projets à traiter: %', v_project_count;
    RAISE NOTICE '';
    
    -- Boucle sur tous les projets
    FOR rec IN (
        SELECT DISTINCT
            pb.project_id,
            pb.company,
            um.person_id AS cor_maint,
            ua.person_id AS ach_capex,
            up.person_id AS chef_projet,
            us.person_id AS sponsor,
            uc.person_id AS client_int
        FROM clean_data.project_base pb
        LEFT JOIN raw_data.sharepoint_projets sp
            ON pb.project_id = SUBSTRING(COALESCE(sp.project_number, sp.code), 1, 10)
        -- person_id directement depuis raw_data.sharepoint_users (comme alimenter_project_activity)
        LEFT JOIN raw_data.sharepoint_users um ON um.sharepoint_user_id = sp.maintenance_correspondent_id
        LEFT JOIN raw_data.sharepoint_users ua ON ua.sharepoint_user_id = sp.acheteur_capex_id
        LEFT JOIN raw_data.sharepoint_users up ON up.sharepoint_user_id = sp.pm_id
        LEFT JOIN raw_data.sharepoint_users us ON us.sharepoint_user_id = sp.sponsor_id
        LEFT JOIN raw_data.sharepoint_users uc ON uc.sharepoint_user_id = sp.client_correspondent_id
        WHERE pb.project_id IS NOT NULL
            AND pb.project_id <> ''
            AND pb.company IS NOT NULL
            AND pb.company <> ''
        ORDER BY pb.project_id
    ) LOOP
        -- COR_MAINT -> Correspondant Maintenance
        CALL insert_role_assignment(
            rec.project_id,
            rec.company,
            'COR_MAINT',
            rec.cor_maint
        );
        
        -- ACH_CAPEX -> Acheteur CAPEX
        CALL insert_role_assignment(
            rec.project_id,
            rec.company,
            'ACH_CAPEX',
            rec.ach_capex
        );
        
        -- CDPROJET -> Chef de projet
        CALL insert_role_assignment(
            rec.project_id,
            rec.company,
            'CDPROJET',
            rec.chef_projet
        );
        
        -- RSP -> Chef de projet (même personne)
        CALL insert_role_assignment(
            rec.project_id,
            rec.company,
            'RSP',
            rec.chef_projet
        );
        
        -- RA -> Chef de projet (même personne)
        CALL insert_role_assignment(
            rec.project_id,
            rec.company,
            'RA',
            rec.chef_projet
        );
        
        -- RFP -> Chef de projet (même personne)
        CALL insert_role_assignment(
            rec.project_id,
            rec.company,
            'RFP',
            rec.chef_projet
        );
        
        -- SPONSOR -> Sponsor
        CALL insert_role_assignment(
            rec.project_id,
            rec.company,
            'SPONSOR',
            rec.sponsor
        );
        
        -- CLIENT_INT -> Correspondant/ Client du projet
        CALL insert_role_assignment(
            rec.project_id,
            rec.company,
            'CLIENT_INT',
            rec.client_int
        );
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Résumé de l''alimentation PROJECT_ROLE_ASSIGNMENT';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Affectations projet-rôle-personne insérées: %', v_inserted_count;
    RAISE NOTICE 'Total affectations dans PROJECT_ROLE_ASSIGNMENT: %', 
        (SELECT COUNT(*) FROM clean_data.project_role_assignment);
    RAISE NOTICE '';
    
    -- Statistiques par rôle
    RAISE NOTICE '=== RÉPARTITION PAR RÔLE ===';
    FOR rec IN (
        SELECT 
            role_id,
            COUNT(*) as nb_affectations,
            COUNT(DISTINCT person_id) as nb_personnes
        FROM clean_data.project_role_assignment
        GROUP BY role_id
        ORDER BY role_id
    ) LOOP
        RAISE NOTICE '  - % : % affectations, % personnes distinctes', 
            rec.role_id, rec.nb_affectations, rec.nb_personnes;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== RÉPARTITION PAR SOCIÉTÉ ===';
    FOR rec IN (
        SELECT 
            company,
            COUNT(*) as nb_affectations
        FROM clean_data.project_role_assignment
        GROUP BY company
        ORDER BY nb_affectations DESC
    ) LOOP
        RAISE NOTICE '  - % : % affectations', rec.company, rec.nb_affectations;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== PROJETS SANS AFFECTATION ===';
    FOR rec IN (
        SELECT 
            pb.project_id,
            pb.company
        FROM clean_data.project_base pb
        LEFT JOIN clean_data.project_role_assignment pra 
            ON pb.project_id = pra.project_id AND pb.company = pra.company
        WHERE pra.project_id IS NULL
            AND pb.project_id IS NOT NULL
            AND pb.project_id <> ''
        ORDER BY pb.project_id
        LIMIT 10
    ) LOOP
        RAISE NOTICE '  - Projet % (%) : Aucune affectation', rec.project_id, rec.company;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Alimentation PROJECT_ROLE_ASSIGNMENT terminée avec succès';
    RAISE NOTICE '========================================';

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION '❌ Erreur lors de l''alimentation PROJECT_ROLE_ASSIGNMENT: %', SQLERRM;
END;
$function$


