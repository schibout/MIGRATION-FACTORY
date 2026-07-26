-- Script pour supprimer toutes les contraintes (PRIMARY KEY, FOREIGN KEY, UNIQUE, CHECK, NOT NULL) 
-- de toutes les tables du schema clean_data
-- ATTENTION: Ce script modifie la structure de toutes les tables du schema clean_data

DO $$
DECLARE
    r RECORD;
    sql_command TEXT;
    total_deleted INTEGER := 0;
BEGIN
    RAISE NOTICE 'Début de la suppression de toutes les contraintes dans le schema clean_data...';
    RAISE NOTICE '================================================================================';
    
    -- 1. Supprimer les FOREIGN KEY (en premier car elles référencent les PRIMARY KEY)
    RAISE NOTICE 'Étape 1: Suppression des FOREIGN KEY...';
    FOR r IN 
        SELECT 
            tc.table_schema,
            tc.table_name,
            tc.constraint_name
        FROM information_schema.table_constraints tc
        WHERE tc.table_schema = 'clean_data'
          AND tc.constraint_type = 'FOREIGN KEY'
          AND tc.table_name NOT LIKE 'pg_%'
        ORDER BY tc.table_name, tc.constraint_name
    LOOP
        sql_command := format(
            'ALTER TABLE %I.%I DROP CONSTRAINT IF EXISTS %I CASCADE',
            r.table_schema,
            r.table_name,
            r.constraint_name
        );
        
        BEGIN
            EXECUTE sql_command;
            total_deleted := total_deleted + 1;
            RAISE NOTICE '  ✓ FOREIGN KEY supprimée: %.% (%.%)', 
                r.table_name, r.constraint_name, total_deleted, 'FK';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '  ✗ Erreur sur %.%: %', 
                    r.table_name, r.constraint_name, SQLERRM;
        END;
    END LOOP;
    
    -- 2. Supprimer les PRIMARY KEY
    RAISE NOTICE '';
    RAISE NOTICE 'Étape 2: Suppression des PRIMARY KEY...';
    FOR r IN 
        SELECT 
            tc.table_schema,
            tc.table_name,
            tc.constraint_name
        FROM information_schema.table_constraints tc
        WHERE tc.table_schema = 'clean_data'
          AND tc.constraint_type = 'PRIMARY KEY'
          AND tc.table_name NOT LIKE 'pg_%'
        ORDER BY tc.table_name, tc.constraint_name
    LOOP
        sql_command := format(
            'ALTER TABLE %I.%I DROP CONSTRAINT IF EXISTS %I CASCADE',
            r.table_schema,
            r.table_name,
            r.constraint_name
        );
        
        BEGIN
            EXECUTE sql_command;
            total_deleted := total_deleted + 1;
            RAISE NOTICE '  ✓ PRIMARY KEY supprimée: %.% (%.%)', 
                r.table_name, r.constraint_name, total_deleted, 'PK';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '  ✗ Erreur sur %.%: %', 
                    r.table_name, r.constraint_name, SQLERRM;
        END;
    END LOOP;
    
    -- 3. Supprimer les contraintes UNIQUE
    RAISE NOTICE '';
    RAISE NOTICE 'Étape 3: Suppression des contraintes UNIQUE...';
    FOR r IN 
        SELECT 
            tc.table_schema,
            tc.table_name,
            tc.constraint_name
        FROM information_schema.table_constraints tc
        WHERE tc.table_schema = 'clean_data'
          AND tc.constraint_type = 'UNIQUE'
          AND tc.table_name NOT LIKE 'pg_%'
        ORDER BY tc.table_name, tc.constraint_name
    LOOP
        sql_command := format(
            'ALTER TABLE %I.%I DROP CONSTRAINT IF EXISTS %I CASCADE',
            r.table_schema,
            r.table_name,
            r.constraint_name
        );
        
        BEGIN
            EXECUTE sql_command;
            total_deleted := total_deleted + 1;
            RAISE NOTICE '  ✓ UNIQUE supprimée: %.% (%.%)', 
                r.table_name, r.constraint_name, total_deleted, 'UQ';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '  ✗ Erreur sur %.%: %', 
                    r.table_name, r.constraint_name, SQLERRM;
        END;
    END LOOP;
    
    -- 4. Supprimer les contraintes CHECK
    RAISE NOTICE '';
    RAISE NOTICE 'Étape 4: Suppression des contraintes CHECK...';
    FOR r IN 
        SELECT 
            tc.table_schema,
            tc.table_name,
            tc.constraint_name
        FROM information_schema.table_constraints tc
        WHERE tc.table_schema = 'clean_data'
          AND tc.constraint_type = 'CHECK'
          AND tc.table_name NOT LIKE 'pg_%'
        ORDER BY tc.table_name, tc.constraint_name
    LOOP
        sql_command := format(
            'ALTER TABLE %I.%I DROP CONSTRAINT IF EXISTS %I CASCADE',
            r.table_schema,
            r.table_name,
            r.constraint_name
        );
        
        BEGIN
            EXECUTE sql_command;
            total_deleted := total_deleted + 1;
            RAISE NOTICE '  ✓ CHECK supprimée: %.% (%.%)', 
                r.table_name, r.constraint_name, total_deleted, 'CK';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '  ✗ Erreur sur %.%: %', 
                    r.table_name, r.constraint_name, SQLERRM;
        END;
    END LOOP;
    
    -- 5. Supprimer les contraintes NOT NULL
    RAISE NOTICE '';
    RAISE NOTICE 'Étape 5: Suppression des contraintes NOT NULL...';
    FOR r IN 
        SELECT 
            table_schema,
            table_name,
            column_name
        FROM information_schema.columns
        WHERE table_schema = 'clean_data'
          AND is_nullable = 'NO'
          AND table_name NOT LIKE 'pg_%'
        ORDER BY table_name, column_name
    LOOP
        sql_command := format(
            'ALTER TABLE %I.%I ALTER COLUMN %I DROP NOT NULL',
            r.table_schema,
            r.table_name,
            r.column_name
        );
        
        BEGIN
            EXECUTE sql_command;
            total_deleted := total_deleted + 1;
            RAISE NOTICE '  ✓ NOT NULL supprimée: %.% (%.%)', 
                r.table_name, r.column_name, total_deleted, 'NN';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '  ✗ Erreur sur %.%: %', 
                    r.table_name, r.column_name, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '================================================================================';
    RAISE NOTICE 'Terminé: % contraintes supprimées au total', total_deleted;
END $$;

-- Vérification: Afficher les contraintes restantes
SELECT 
    tc.constraint_type,
    tc.table_name,
    tc.constraint_name
FROM information_schema.table_constraints tc
WHERE tc.table_schema = 'clean_data'
  AND tc.table_name NOT LIKE 'pg_%'
ORDER BY tc.constraint_type, tc.table_name, tc.constraint_name;

-- Vérification: Afficher les colonnes restantes avec NOT NULL
SELECT 
    table_name,
    column_name,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'clean_data'
  AND is_nullable = 'NO'
  AND table_name NOT LIKE 'pg_%'
ORDER BY table_name, column_name;

