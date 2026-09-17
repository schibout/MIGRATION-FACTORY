-- ============================================================================
-- Insertion du module ETL Equipment Functional dans etl_target_tables
-- Alimente clean_data.equipment_functional depuis iflot/iflotx/iflos/iloa + itob
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
    'Alimentation de la table EQUIPMENT_FUNCTIONAL depuis les tables SAP standard : iflot/iflotx/iflos/iloa (postes techniques, hiérarchie via tplma) et itob (équipements et sous-équipements via hequi). Insertion niveau par niveau (parents avant enfants).',
    'raw_data',
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
