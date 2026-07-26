-- =====================================================
-- Script SQL pour ajouter le module ETL Clients PHL à la table etl_target_tables
-- Date: 2025-12-08
-- Description: Insertion du module de chargement des clients PHL vers IFS
-- =====================================================

-- Insertion du module ETL Clients PHL
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
    25,
    'customer_info_phl',
    'Clients PHL',
    'Module ETL pour le chargement des données clients PHL depuis raw_data.client_phl et raw_data.client_adresse_phl vers clean_data.CUSTOMER_INFO et clean_data.CUSTOMER_INFO_ADDRESS. Alimente les tables avec les informations clients et adresses depuis les données PHL.',
    'raw_data',
    'clean_data',
    'etl_phl_customer.py',
    10,
    null,
    true,
    'person',
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    'ETL_SYSTEM',
    'IFS_Customers',
    21
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
WHERE id = 25;

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
    RAISE NOTICE '✅ Module ETL Clients PHL ajouté avec succès';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'ID: 25';
    RAISE NOTICE 'Nom affiché: Clients PHL';
    RAISE NOTICE 'Module Python: etl_phl_customer.py';
    RAISE NOTICE 'Domaine: IFS_Customers';
    RAISE NOTICE 'Statut: Actif';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Le module est maintenant disponible dans l''interface de chargement des données';
    RAISE NOTICE 'URL: http://10.190.100.58:3000/data-loading';
    RAISE NOTICE '========================================';
END $$;

