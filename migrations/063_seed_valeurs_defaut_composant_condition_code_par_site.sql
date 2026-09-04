-- =====================================================================
-- Condition code usage des composants : valeur dependante du site
--
-- Regle metier (2026-09-04) : sur Castel les articles autorisent le code
-- condition (ALLOW_COND_CODE). Les articles PHL etaient deja tous en
-- ALLOW_COND_CODE via la variante STANDARD ; seuls les composants etaient en
-- NOT_ALLOW_COND_CODE, valeur portee par les deux gabarits metier
-- (PartCatalog_ComposantSaintJean.csv et PartCatalog_ComposantCastel.csv).
--
-- Arbitrage retenu : Castel passe en ALLOW, Saint-Jean garde la valeur de son
-- gabarit. La variante COMPOSANT unique est donc remplacee par une variante par
-- site, comme pour multilevel_tracking (migration 057). part_catalog n'ayant
-- qu'une ligne par article, un code present sur les deux sites prend la valeur
-- de la ligne source retenue (Castel l'emporte, cf. alimenter_part_catalog_cmp).
-- =====================================================================

BEGIN;

DELETE FROM public.etl_default_values
WHERE table_cible = 'clean_data.part_catalog'
  AND colonne IN ('condition_code_usage', 'condition_code_usage_db')
  AND variante = 'COMPOSANT';

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage', 'COMPOSANT_SJ', 'CONSTANTE', 'Not Allow Condition Code', 'Source : PartCatalog_ComposantSaintJean.csv', 'migration_063')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage_db', 'COMPOSANT_SJ', 'CONSTANTE', 'NOT_ALLOW_COND_CODE', 'Source : PartCatalog_ComposantSaintJean.csv', 'migration_063')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage', 'COMPOSANT_CS', 'CONSTANTE', 'Allow Condition Code', 'Regle metier : sur Castel les articles autorisent le code condition', 'migration_063')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage_db', 'COMPOSANT_CS', 'CONSTANTE', 'ALLOW_COND_CODE', 'Regle metier : sur Castel les articles autorisent le code condition', 'migration_063')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

COMMIT;
