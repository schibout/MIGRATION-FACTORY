-- 121 : description du module ETL « Postes techniques & Equipements (IFS) » mise a jour :
-- il lit clean_data.maintenance_object (IH02) et alimente aussi equipment_serial
-- (clean_data.alimenter_equipment_serial, appelee apres alimenter_equipment_functional).

UPDATE public.etl_target_tables
SET description = 'Structure de maintenance IFS depuis l''écran IH02 (clean_data.maintenance_object), dans l''ordre : 1. alimenter_equipment_functional (postes techniques -> EQUIPMENT_FUNCTIONAL), 2. alimenter_equipment_serial (équipements sous un poste technique ou portant un code article, puis leurs enfants -> EQUIPMENT_SERIAL), 3. load_equipment_object_spare (nomenclatures des postes -> EQUIPMENT_OBJECT_SPARE), 4. load_equipment_spare_structure (nomenclatures des articles -> EQUIPMENT_SPARE_STRUCTURE). Parents avant enfants.',
    source_schema = 'clean_data',
    last_modified = CURRENT_TIMESTAMP
WHERE python_module = 'etl_equipment_functional.py';
