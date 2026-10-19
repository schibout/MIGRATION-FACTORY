-- 122 : libelle du module ETL etl_equipment_functional.py dans l'ecran Chargement des donnees.

UPDATE public.etl_target_tables
SET display_name = 'Maintenance - Structure de maintenance et équipements',
    last_modified = CURRENT_TIMESTAMP
WHERE python_module = 'etl_equipment_functional.py';
