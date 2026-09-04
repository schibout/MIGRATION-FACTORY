-- =====================================================================
-- Enregistrement du module ETL "Articles Composants"
--
-- Une seule entree charge les DEUX sites : etl_composant_article.run_etl()
-- appelle les fonctions clean_data.alimenter_*_cmp() pour SJ puis CS
-- (module_params laisse vide ; y poser {"contract": "SJ"} n'en chargerait qu'un).
--
-- execution_order 12 : apres le module SAP "Donnees de base des Articles"
-- (ordre 8) qui fait le TRUNCATE des tables cibles, comme les articles PHL.
-- =====================================================================

BEGIN;

INSERT INTO public.etl_target_tables (
    table_name, display_name, description,
    source_schema, target_schema, python_module,
    execution_order, is_active, icon_name, domaine_fonctionnel, display_order,
    module_params, created_by
)
VALUES (
    'composant_article',
    'Articles Composants',
    'Chargement des composants Saint-Jean et Castel (source raw_data.composant_sj_cs) '
    'vers part_catalog, inventory_part, sales_part, purchase_part et manuf_part_attribute.',
    'raw_data', 'clean_data', 'etl_composant_article.py',
    12, TRUE, 'package', 'IFS_Articles', 25,
    NULL, 'migration_058'
)
ON CONFLICT (table_name) DO NOTHING;

COMMIT;
