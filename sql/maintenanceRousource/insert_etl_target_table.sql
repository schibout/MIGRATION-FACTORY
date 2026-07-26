-- ============================================================================
-- Script d'insertion du module ETL Maintenance Resource dans etl_target_tables
-- Date: 2025-02-02
-- Description: Ajoute la configuration pour le module ETL des ressources de maintenance
-- ============================================================================

-- Vérifier si l'entrée existe déjà et la supprimer pour éviter les doublons
DELETE FROM public.etl_target_tables 
WHERE table_name = 'maintenance_resource';

-- Insérer le nouveau module ETL
INSERT INTO public.etl_target_tables (
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
    'maintenance_resource',
    'Ressources de Maintenance IFS',
    'Module ETL pour le chargement des données de ressources de maintenance depuis raw_data vers clean_data. Alimente les tables: ifs_person, resource_detail_file, resource_connection, resource_availability, resource_parent et maint_person_resource avec transformation des identifiants de personnes.',
    'raw_data',
    'clean_data',
    'etl_maintenance_resource.py',
    11,
    NULL,
    true,
    'build',
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    'ETL_SYSTEM',
    'IFS_Maintenance',
    22
);

-- Vérification de l'insertion
SELECT id, table_name, display_name, python_module, is_active, domaine_fonctionnel
FROM public.etl_target_tables 
WHERE table_name = 'maintenance_resource';
