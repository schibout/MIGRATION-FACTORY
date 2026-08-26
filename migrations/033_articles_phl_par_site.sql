-- Migration 033 : chargement des articles PHL par site (SJ = Saint-Jean, CS = Castel)
--
-- L'écran de chargement (etl_target_tables) gagne une colonne module_params :
-- des paramètres JSON transmis au run_etl() du module Python par api/etl.py.
-- Le module etl_phl_article.py est partagé par deux lignes : « Articles PHL
-- Saint-Jean » (l'ancienne ligne id=28, renommée) et « Articles PHL Castel »
-- (nouvelle), qui ne diffèrent que par module_params.contract.

ALTER TABLE public.etl_target_tables
    ADD COLUMN IF NOT EXISTS module_params JSONB;

COMMENT ON COLUMN public.etl_target_tables.module_params IS
'Paramètres JSON passés en kwargs au run_etl() du module Python (api/etl.py ne transmet que les clés acceptées par la signature).';

-- Ligne existante : devient explicitement Saint-Jean.
UPDATE public.etl_target_tables
SET display_name  = 'Articles PHL Saint-Jean',
    description   = 'Chargement des articles PHL pour le site Saint-Jean (contract SJ)',
    module_params = '{"contract": "SJ"}'::jsonb,
    last_modified = CURRENT_TIMESTAMP
WHERE table_name = 'inventory_part_phl';

-- La séquence de l'id est en retard sur les lignes insérées avec un id explicite :
-- sans resynchronisation, l'INSERT ci-dessous échoue en duplicate key (constaté
-- sur id=30). setval sur le MAX(id) réaligne la séquence.
SELECT setval('public.etl_target_tables_id_seq',
              (SELECT MAX(id) FROM public.etl_target_tables));

-- Nouvelle ligne : même module Python, site Castel.
INSERT INTO public.etl_target_tables
    (table_name, display_name, description, source_schema, target_schema,
     python_module, execution_order, dependent_on, is_active, icon_name,
     domaine_fonctionnel, display_order, module_params, created_by, created_at)
SELECT
    'inventory_part_phl_cs',
    'Articles PHL Castel',
    'Chargement des articles PHL pour le site Castel (contract CS)',
    source_schema, target_schema, python_module, execution_order, dependent_on,
    is_active, icon_name, domaine_fonctionnel, display_order + 1,
    '{"contract": "CS"}'::jsonb, 'migration_033', CURRENT_TIMESTAMP
FROM public.etl_target_tables
WHERE table_name = 'inventory_part_phl'
ON CONFLICT (table_name) DO NOTHING;
