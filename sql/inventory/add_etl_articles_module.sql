-- Script SQL pour ajouter le module ETL Articles à la table etl_target_tables
-- À exécuter dans votre base de données PostgreSQL

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
    23,
    'inventory_part',
    'Articles d''inventaire',
    'Module ETL pour le chargement des données articles d''inventaire (INVENTORY_PART) depuis SAP R/3 4.6C vers IFS. Gestion complète des articles avec traçabilité lot/série, mapping des types d''articles, données de planification et informations douanières.',
    'raw_data',
    'public',
    'etl_article.py',
    8,
    null,
    true,
    'package',
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    'ETL_SYSTEM',
    'IFS_Articles',
    19
);

-- Vérification de l'insertion
SELECT 
    id,
    table_name,
    display_name,
    domaine_fonctionnel,
    python_module,
    execution_order,
    display_order,
    is_active
FROM etl_target_tables 
WHERE id = 23;
