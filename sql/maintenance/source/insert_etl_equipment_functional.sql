-- ============================================================================
-- Insertion du module ETL Equipment Functional dans etl_target_tables
-- Alimente equipment_functional, equipment_serial, equipment_object_spare et
-- equipment_spare_structure depuis clean_data.maintenance_object (IH02)
-- ============================================================================

DELETE FROM public.etl_target_tables
WHERE table_name = 'equipment_functional';

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
    'equipment_functional',
    'Postes techniques & Équipements (IFS)',
    'Structure de maintenance IFS depuis l''écran IH02 (clean_data.maintenance_object), dans l''ordre : 1. alimenter_equipment_functional (postes techniques -> EQUIPMENT_FUNCTIONAL), 2. alimenter_equipment_serial (équipements sous un poste technique ou portant un code article, puis leurs enfants -> EQUIPMENT_SERIAL), 3. load_equipment_object_spare (nomenclatures des postes -> EQUIPMENT_OBJECT_SPARE), 4. load_equipment_spare_structure (nomenclatures des articles -> EQUIPMENT_SPARE_STRUCTURE). Parents avant enfants.',
    'clean_data',
    'clean_data',
    'etl_equipment_functional.py',
    10,
    NULL,
    true,
    'engineering',
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    'ETL_SYSTEM',
    'IFS_Maintenance',
    21
);

SELECT id, table_name, display_name, python_module, is_active, domaine_fonctionnel
FROM public.etl_target_tables
WHERE table_name = 'equipment_functional';
