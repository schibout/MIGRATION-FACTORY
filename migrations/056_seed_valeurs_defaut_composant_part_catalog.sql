-- =====================================================================
-- Valeurs par defaut PART_CATALOG du module articleComposant
--
-- Source : sql/ArticleComposant/ComposantSaintJean.csv (gabarit de
-- chargement IFS PART_CATALOG fourni par le metier pour les composants).
-- part_catalog n'a pas de site : ces valeurs valent pour SJ comme pour CS,
-- une seule ligne existant par article.
--
-- Variante COMPOSANT car les valeurs divergent des autres modules
-- (condition_code_usage_db et lot_quantity_rule_db notamment). Les
-- colonnes libellE ne sont seedees par aucun autre module : sans ligne
-- ici, public.get_default_value renverrait NULL (pas de repli).
--
-- INSERT ... ON CONFLICT DO NOTHING : rejouable, ne remplace jamais une
-- valeur ajustee depuis l'ecran /configuration/valeurs-defaut.
-- =====================================================================

BEGIN;

-- Valeurs _db divergentes des autres modules
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage_db', 'COMPOSANT', 'CONSTANTE', 'NOT_ALLOW_COND_CODE', 'Source : ComposantSaintJean.csv (valeur divergente entre modules)', 'migration_056')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'lot_quantity_rule_db', 'COMPOSANT', 'CONSTANTE', 'ONE_LOT', 'Source : ComposantSaintJean.csv (valeur divergente entre modules)', 'migration_056')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- Libelles IFS associes aux valeurs _db
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage', 'COMPOSANT', 'CONSTANTE', 'Not Allow Condition Code', 'Source : ComposantSaintJean.csv', 'migration_056')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'lot_quantity_rule', 'COMPOSANT', 'CONSTANTE', 'One Lot Per Production Order', 'Source : ComposantSaintJean.csv', 'migration_056')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_rule', 'COMPOSANT', 'CONSTANTE', 'Manual', 'Source : ComposantSaintJean.csv', 'migration_056')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_tracking_code', 'COMPOSANT', 'CONSTANTE', 'Not Serial Tracking', 'Source : ComposantSaintJean.csv', 'migration_056')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'eng_serial_tracking_code', 'COMPOSANT', 'CONSTANTE', 'Not Serial Tracking', 'Source : ComposantSaintJean.csv', 'migration_056')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'configurable', 'COMPOSANT', 'CONSTANTE', 'Not Configured', 'Source : ComposantSaintJean.csv', 'migration_056')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'sub_lot_rule', 'COMPOSANT', 'CONSTANTE', 'No Sub Lots Allowed', 'Source : ComposantSaintJean.csv', 'migration_056')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'position_part', 'COMPOSANT', 'CONSTANTE', 'Not a Position Part', 'Source : ComposantSaintJean.csv', 'migration_056')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'catch_unit_enabled', 'COMPOSANT', 'CONSTANTE', 'False', 'Source : ComposantSaintJean.csv', 'migration_056')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking', 'COMPOSANT', 'CONSTANTE', 'Tracking Off', 'Source : ComposantSaintJean.csv', 'migration_056')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'component_lot_rule', 'COMPOSANT', 'CONSTANTE', 'Many Lots Allowed', 'Source : ComposantSaintJean.csv', 'migration_056')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_arrival_issued_serial', 'COMPOSANT', 'CONSTANTE', 'True', 'Source : ComposantSaintJean.csv', 'migration_056')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'allow_as_not_consumed', 'COMPOSANT', 'CONSTANTE', 'False', 'Source : ComposantSaintJean.csv', 'migration_056')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'receipt_issue_serial_track', 'COMPOSANT', 'CONSTANTE', 'False', 'Source : ComposantSaintJean.csv', 'migration_056')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_new_serial_in_rma', 'COMPOSANT', 'CONSTANTE', 'True', 'Source : ComposantSaintJean.csv', 'migration_056')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- Colonnes numeriques du gabarit (cast explicite cote procedure)
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'std_name_id', 'COMPOSANT', 'CONSTANTE', '0', 'Source : ComposantSaintJean.csv', 'migration_056')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'freight_factor', 'COMPOSANT', 'CONSTANTE', '1', 'Source : ComposantSaintJean.csv', 'migration_056')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

COMMIT;
