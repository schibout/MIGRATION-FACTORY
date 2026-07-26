-- Script: Ajout de la table EQUIPMENT_SPARE_STRUCTURE pour l'export
-- Date: 2026-06-09
-- Description: Ajouter la table equipment_spare_structure dans etl_export_queries
--              (structure hiérarchique des pièces de rechange : kit → composants)

-- EQUIPMENT_SPARE_STRUCTURE
INSERT INTO etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by)
VALUES (
    'equipment_spare_structure',
    'clean_data',
    'Maintenance - Structure des pièces de rechange',
    'spare_seq, spare_contract, spare_id, component_spare_id, component_spare_contract, qty, part_ownership_db',
    'Structure hiérarchique des pièces de rechange (kit ERSA → composants) depuis MARA/MAST/STKO/STPO',
    'maintenance',
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
WHERE table_name = 'equipment_spare_structure' AND table_schema = 'clean_data';
