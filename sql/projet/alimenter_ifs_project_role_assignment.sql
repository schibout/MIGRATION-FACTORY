CREATE OR REPLACE FUNCTION clean_data.alimenter_ifs_project_role_assignment()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_inserted_count INTEGER := 0;
    v_project_count INTEGER := 0;
    v_seq_no NUMERIC := 1;
    rec RECORD;
    v_person_id VARCHAR;
    
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
            sp.maintenance_correspondent_id,
            sp.acheteur_capex_id,
            sp.pm_id,
            sp.sponsor_id,
            sp.client_correspondent_id
        FROM clean_data.project_base pb
        LEFT JOIN raw_data.sharepoint_projets sp ON pb.project_id = sp.project_number
        WHERE pb.project_id IS NOT NULL 
            AND pb.project_id <> ''
            AND pb.company IS NOT NULL
            AND pb.company <> ''
        ORDER BY pb.project_id
    ) LOOP
        
        -- COR_MAINT -> Correspondant Maintenance
        v_person_id := clean_data.get_person_id_from_sharepoint_user_id(rec.maintenance_correspondent_id);
        IF v_person_id IS NOT NULL AND v_person_id <> '' THEN
            INSERT INTO clean_data.project_role_assignment (
                assign_seq_no, project_id, company, role_id, person_id, system_generated
            ) VALUES (
                v_seq_no, rec.project_id, rec.company, 'COR_MAINT', v_person_id, 'FALSE'
            );
            v_seq_no := v_seq_no + 1;
            v_inserted_count := v_inserted_count + 1;
        END IF;
        
        -- ACH_CAPEX -> Acheteur CAPEX
        v_person_id := clean_data.get_person_id_from_sharepoint_user_id(rec.acheteur_capex_id);
        IF v_person_id IS NOT NULL AND v_person_id <> '' THEN
            INSERT INTO clean_data.project_role_assignment (
                assign_seq_no, project_id, company, role_id, person_id, system_generated
            ) VALUES (
                v_seq_no, rec.project_id, rec.company, 'ACH_CAPEX', v_person_id, 'FALSE'
            );
            v_seq_no := v_seq_no + 1;
            v_inserted_count := v_inserted_count + 1;
        END IF;
        
        -- CDPROJET -> Chef de projet (PM)
        v_person_id := clean_data.get_person_id_from_sharepoint_user_id(rec.pm_id);
        IF v_person_id IS NOT NULL AND v_person_id <> '' THEN
            INSERT INTO clean_data.project_role_assignment (
                assign_seq_no, project_id, company, role_id, person_id, system_generated
            ) VALUES (
                v_seq_no, rec.project_id, rec.company, 'CDPROJET', v_person_id, 'FALSE'
            );
            v_seq_no := v_seq_no + 1;
            v_inserted_count := v_inserted_count + 1;
        END IF;
        
        -- RSP -> Chef de projet (même personne)
        v_person_id := clean_data.get_person_id_from_sharepoint_user_id(rec.pm_id);
        IF v_person_id IS NOT NULL AND v_person_id <> '' THEN
            INSERT INTO clean_data.project_role_assignment (
                assign_seq_no, project_id, company, role_id, person_id, system_generated
            ) VALUES (
                v_seq_no, rec.project_id, rec.company, 'RSP', v_person_id, 'FALSE'
            );
            v_seq_no := v_seq_no + 1;
            v_inserted_count := v_inserted_count + 1;
        END IF;
        
        -- RA -> Chef de projet (même personne)
        v_person_id := clean_data.get_person_id_from_sharepoint_user_id(rec.pm_id);
        IF v_person_id IS NOT NULL AND v_person_id <> '' THEN
            INSERT INTO clean_data.project_role_assignment (
                assign_seq_no, project_id, company, role_id, person_id, system_generated
            ) VALUES (
                v_seq_no, rec.project_id, rec.company, 'RA', v_person_id, 'FALSE'
            );
            v_seq_no := v_seq_no + 1;
            v_inserted_count := v_inserted_count + 1;
        END IF;
        
        -- RFP -> Chef de projet (même personne)
        v_person_id := clean_data.get_person_id_from_sharepoint_user_id(rec.pm_id);
        IF v_person_id IS NOT NULL AND v_person_id <> '' THEN
            INSERT INTO clean_data.project_role_assignment (
                assign_seq_no, project_id, company, role_id, person_id, system_generated
            ) VALUES (
                v_seq_no, rec.project_id, rec.company, 'RFP', v_person_id, 'FALSE'
            );
            v_seq_no := v_seq_no + 1;
            v_inserted_count := v_inserted_count + 1;
        END IF;
        
        -- SPONSOR -> Sponsor
        v_person_id := clean_data.get_person_id_from_sharepoint_user_id(rec.sponsor_id);
        IF v_person_id IS NOT NULL AND v_person_id <> '' THEN
            INSERT INTO clean_data.project_role_assignment (
                assign_seq_no, project_id, company, role_id, person_id, system_generated
            ) VALUES (
                v_seq_no, rec.project_id, rec.company, 'SPONSOR', v_person_id, 'FALSE'
            );
            v_seq_no := v_seq_no + 1;
            v_inserted_count := v_inserted_count + 1;
        END IF;
        
        -- CLIENT_INT -> Correspondant Client
        v_person_id := clean_data.get_person_id_from_sharepoint_user_id(rec.client_correspondent_id);
        IF v_person_id IS NOT NULL AND v_person_id <> '' THEN
            INSERT INTO clean_data.project_role_assignment (
                assign_seq_no, project_id, company, role_id, person_id, system_generated
            ) VALUES (
                v_seq_no, rec.project_id, rec.company, 'CLIENT_INT', v_person_id, 'FALSE'
            );
            v_seq_no := v_seq_no + 1;
            v_inserted_count := v_inserted_count + 1;
        END IF;
        
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
