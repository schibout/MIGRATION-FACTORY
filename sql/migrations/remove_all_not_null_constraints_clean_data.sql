-- Script pour supprimer toutes les contraintes NOT NULL de toutes les tables du schema clean_data
-- ATTENTION: Ce script modifie la structure de toutes les tables du schema clean_data

DO $$
DECLARE
    r RECORD;
    sql_command TEXT;
    total_modified INTEGER := 0;
BEGIN
    RAISE NOTICE 'Début de la suppression des contraintes NOT NULL dans le schema clean_data...';
    
    -- Parcourir toutes les colonnes avec NOT NULL dans le schema clean_data
    FOR r IN 
        SELECT 
            table_schema,
            table_name,
            column_name,
            data_type
        FROM information_schema.columns
        WHERE table_schema = 'clean_data'
          AND is_nullable = 'NO'
          AND table_name NOT LIKE 'pg_%'  -- Exclure les tables système
        ORDER BY table_name, column_name
    LOOP
        -- Construire la commande ALTER TABLE
        sql_command := format(
            'ALTER TABLE %I.%I ALTER COLUMN %I DROP NOT NULL',
            r.table_schema,
            r.table_name,
            r.column_name
        );
        
        -- Exécuter la commande
        BEGIN
            EXECUTE sql_command;
            total_modified := total_modified + 1;
            RAISE NOTICE '✓ %: Suppression NOT NULL sur %.%', 
                total_modified, r.table_name, r.column_name;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '✗ Erreur sur %.%: %', 
                    r.table_name, r.column_name, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE 'Terminé: % contraintes NOT NULL supprimées', total_modified;
END $$;

-- Vérification: Afficher les colonnes restantes avec NOT NULL
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'clean_data'
  AND is_nullable = 'NO'
  AND table_name NOT LIKE 'pg_%'
ORDER BY table_name, column_name;

