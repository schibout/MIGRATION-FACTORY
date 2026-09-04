-- =====================================================================
-- Valeurs par defaut ETL du module articleComposant
-- (source : raw_data.composant_sj_cs, procedures sql/ArticleComposant/)
--
-- Seules les cles qui divergent d'un module a l'autre recoivent une
-- variante dediee : sans ligne seedee, public.get_default_value(...,
-- 'COMPOSANT') renvoie NULL (la fonction n'a pas de repli).
-- Les autres appels du module utilisent la variante STANDARD, deja
-- seedee et partagee avec les modules inventory / articlePhl.
--
-- Valeurs identiques a la variante ARTICLEPHL (choix metier valide) :
-- elles sont ajustables independamment depuis /configuration/valeurs-defaut.
-- INSERT ... ON CONFLICT DO NOTHING : rejouable, ne remplace jamais une
-- valeur ajustee depuis l'ecran.
-- =====================================================================

BEGIN;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'type_code_db', 'COMPOSANT', 'CONSTANTE', '1', 'Source : alimenter_inventory_part_cmp.sql (valeur divergente entre modules)', 'migration_055')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'lead_time_code_db', 'COMPOSANT', 'CONSTANTE', 'Y', 'Source : alimenter_inventory_part_cmp.sql (valeur divergente entre modules)', 'migration_055')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'component_lot_rule_db', 'COMPOSANT', 'CONSTANTE', 'MANY_LOTS_ALLOWED', 'Source : alimenter_part_catalog_cmp.sql (valeur divergente entre modules)', 'migration_055')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

COMMIT;
