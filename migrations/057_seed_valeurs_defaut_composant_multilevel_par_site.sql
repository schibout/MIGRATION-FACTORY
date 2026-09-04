-- =====================================================================
-- Multilevel tracking des composants : valeur dependante du site
--
-- Source : sql/ArticleComposant/ComposantSaintJean.csv (TRACKING_OFF) et
-- sql/ArticleComposant/ComposantCastel.csv (TRACKING_ON). Seule colonne du
-- gabarit, avec la tracabilite lot, a diverger entre les deux sites.
--
-- La variante unique COMPOSANT posee par la migration 056 est donc remplacee
-- par une variante par site. part_catalog n'ayant qu'une ligne par article,
-- un code present sur les deux sites prend la valeur de la ligne source
-- retenue (cf. commentaire de clean_data.alimenter_part_catalog_cmp).
-- =====================================================================

BEGIN;

DELETE FROM public.etl_default_values
WHERE table_cible = 'clean_data.part_catalog'
  AND colonne IN ('multilevel_tracking', 'multilevel_tracking_db')
  AND variante = 'COMPOSANT';

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking', 'COMPOSANT_SJ', 'CONSTANTE', 'Tracking Off', 'Source : ComposantSaintJean.csv', 'migration_057')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking_db', 'COMPOSANT_SJ', 'CONSTANTE', 'TRACKING_OFF', 'Source : ComposantSaintJean.csv', 'migration_057')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking', 'COMPOSANT_CS', 'CONSTANTE', 'Tracking On', 'Source : ComposantCastel.csv', 'migration_057')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking_db', 'COMPOSANT_CS', 'CONSTANTE', 'TRACKING_ON', 'Source : ComposantCastel.csv', 'migration_057')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

COMMIT;
