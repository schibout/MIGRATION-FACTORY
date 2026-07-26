CREATE OR REPLACE FUNCTION clean_data.alimenter_ifs_project_role()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_inserted_count INTEGER := 0;
    v_project_count INTEGER := 0;
    rec RECORD;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Début alimentation PROJECT_ROLE';
    RAISE NOTICE '========================================';
    
    -- Vider et réinsérer dans PROJECT_ROLE
    TRUNCATE TABLE clean_data.project_role CASCADE;
    
    -- Compter le nombre de projets
    SELECT COUNT(*) INTO v_project_count
    FROM clean_data.project_base
    WHERE project_id IS NOT NULL;
    
    RAISE NOTICE 'Nombre de projets à traiter: %', v_project_count;
    RAISE NOTICE '';
    
    -- Insertion des rôles pour chaque projet
    -- Chaque projet reçoit automatiquement tous les rôles standards
    INSERT INTO clean_data.project_role (
        project_id,
        company,
        role_id
    )
    SELECT DISTINCT
        pb.project_id,
        pb.company,
        role.role_id
    FROM clean_data.project_base pb
    CROSS JOIN (
        VALUES 
            ('COR_MAINT'),
            ('ACH_CAPEX'),
            ('CDPROJET'),
            ('RSP'),
            ('RA'),
            ('RFP'),
            ('SPONSOR'),
            ('CLIENT_INT')
    ) AS role(role_id)
    WHERE pb.project_id IS NOT NULL
        AND pb.project_id <> ''
        AND pb.company IS NOT NULL
        AND pb.company <> ''
    ORDER BY pb.project_id, role.role_id;
    
    GET DIAGNOSTICS v_inserted_count = ROW_COUNT;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Résumé de l''alimentation PROJECT_ROLE';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Associations projet-rôle insérées: %', v_inserted_count;
    RAISE NOTICE 'Total associations dans PROJECT_ROLE: %', 
        (SELECT COUNT(*) FROM clean_data.project_role);
    RAISE NOTICE 'Rôles par projet: %', v_inserted_count / NULLIF(v_project_count, 0);
    RAISE NOTICE '';
    
    -- Statistiques par rôle
    RAISE NOTICE '=== RÉPARTITION PAR RÔLE ===';
    FOR rec IN (
        SELECT 
            role_id,
            COUNT(*) as nb_projets
        FROM clean_data.project_role
        GROUP BY role_id
        ORDER BY role_id
    ) LOOP
        RAISE NOTICE '  - % : % projets', rec.role_id, rec.nb_projets;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== RÉPARTITION PAR SOCIÉTÉ ===';
    FOR rec IN (
        SELECT 
            company,
            COUNT(*) as nb_associations
        FROM clean_data.project_role
        GROUP BY company
        ORDER BY nb_associations DESC
    ) LOOP
        RAISE NOTICE '  - % : % associations', rec.company, rec.nb_associations;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Alimentation PROJECT_ROLE terminée avec succès';
    RAISE NOTICE '========================================';

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION '❌ Erreur lors de l''alimentation PROJECT_ROLE: %', SQLERRM;
END;
$function$


