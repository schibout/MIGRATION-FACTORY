-- =====================================================
-- Script SQL pour ajouter le module ETL Projets à la table etl_target_tables
-- Date: 2025-11-21
-- Description: Insertion du module de chargement des projets SharePoint vers IFS
-- =====================================================

-- Insertion du module ETL Projets
INSERT INTO etl_target_tables (
    id,
    table_name,
    display_name,
    description,
    source_schema,
    target_schema,
    python_module,
    execution_order,
    dependent_on,
    is_active,
    icon_name,
    last_modified,
    created_at,
    created_by,
    domaine_fonctionnel,
    display_order
) VALUES (
    24,
    'project_base',
    'Projets IFS',
    'Module ETL pour le chargement des données projets depuis SharePoint ASAP vers IFS. Alimente les tables PROJECT_BASE, PROJECT_SITE_EXT et PROJECT_MARGIN_MATRIX avec mapping complet des champs (project_id, manager, secteurs, budgets, marges).',
    'raw_data',
    'clean_data',
    'etl_project.py',
    9,
    null,
    true,
    'assignment',
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    'ETL_SYSTEM',
    'IFS_Projects',
    20
)
ON CONFLICT (id) DO UPDATE SET
    table_name = EXCLUDED.table_name,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    source_schema = EXCLUDED.source_schema,
    target_schema = EXCLUDED.target_schema,
    python_module = EXCLUDED.python_module,
    execution_order = EXCLUDED.execution_order,
    dependent_on = EXCLUDED.dependent_on,
    is_active = EXCLUDED.is_active,
    icon_name = EXCLUDED.icon_name,
    last_modified = CURRENT_TIMESTAMP,
    domaine_fonctionnel = EXCLUDED.domaine_fonctionnel,
    display_order = EXCLUDED.display_order;

-- Vérification de l'insertion
SELECT 
    id,
    table_name,
    display_name,
    domaine_fonctionnel,
    python_module,
    execution_order,
    display_order,
    is_active,
    description
FROM etl_target_tables 
WHERE id = 24;

-- Afficher tous les modules ETL actifs triés par ordre d'exécution
SELECT 
    id,
    display_name,
    python_module,
    execution_order,
    is_active,
    domaine_fonctionnel
FROM etl_target_tables 
WHERE is_active = true
ORDER BY execution_order, display_order;

-- Message de confirmation
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Module ETL Projets ajouté avec succès';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'ID: 24';
    RAISE NOTICE 'Nom affiché: Projets IFS';
    RAISE NOTICE 'Module Python: etl_project.py';
    RAISE NOTICE 'Domaine: IFS_Projects';
    RAISE NOTICE 'Statut: Actif';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Le module est maintenant disponible dans l''interface de chargement des données';
    RAISE NOTICE 'URL: http://10.190.100.58:8080/data-loading';
    RAISE NOTICE '========================================';
END $$;
