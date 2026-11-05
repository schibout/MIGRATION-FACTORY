-- 130 : libelles du nouveau perimetre de clean_data.alimenter_equipment_serial :
-- equipements sous la structure (postes techniques) ET portant un code article.

UPDATE public.etl_export_queries
SET description = 'Équipements IFS (EQUIPMENT_SERIAL) : équipements sous la structure (postes techniques) et portant un code article ; ni postes techniques ni articles. Source : alimenter_equipment_serial',
    updated_at = now(),
    updated_by = 'migration_130'
WHERE table_schema = 'clean_data' AND table_name = 'equipment_serial';

UPDATE public.etl_target_tables
SET description = replace(description,
        'équipements sous un poste technique ou portant un code article, puis leurs enfants',
        'équipements sous la structure et portant un code article'),
    last_modified = CURRENT_TIMESTAMP
WHERE python_module = 'etl_equipment_functional.py';
