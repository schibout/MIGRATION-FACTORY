-- Script: Ajout de la table PROJECT_ACTIVITY_CLASS pour l'export
-- Date: 2026-05-29
-- Description: Ajouter la table PROJECT_ACTIVITY_CLASS dans etl_export_queries

-- PROJECT_ACTIVITY_CLASS
INSERT INTO etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by)
VALUES (
    'project_activity_class',
    'clean_data',
    'Projets - Activity Class',
    'project_id, sub_project_id, activity_no, activity_seq, activity_class_seq, value, activity_class_id',
    'Table des activity_class (PORTE, STATUT_PORTE, QUAL_PORTE) par activité projet IFS Cloud',
    'project',
    true,
    'admin',
    'admin'
)
ON CONFLICT (table_name, table_schema) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    column_list  = EXCLUDED.column_list,
    description  = EXCLUDED.description,
    category     = EXCLUDED.category,
    is_active    = EXCLUDED.is_active,
    updated_by   = EXCLUDED.updated_by,
    updated_at   = CURRENT_TIMESTAMP;

-- Vérification
SELECT id, table_name, display_name, category, is_active
FROM etl_export_queries
WHERE table_name = 'project_activity_class' AND table_schema = 'clean_data';
