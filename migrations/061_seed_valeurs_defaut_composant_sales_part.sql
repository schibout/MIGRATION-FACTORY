-- =====================================================================
-- Valeurs par defaut SALES_PART du module articleComposant
--
-- Source : sql/ArticleComposant/valeurParDefaut/salesPart.csv (gabarit de
-- chargement IFS fourni par le metier, une ligne Saint-Jean ; aucune divergence
-- connue avec Castel -> variante COMPOSANT unique, comme pour purchase_part).
--
-- Le module lit toutes ses constantes en variante COMPOSANT et ne depend plus
-- des lignes STANDARD d'autres modules (sourcing_option_db valait NOTSUPPLIED
-- alors que le gabarit demande INVENTORYORDER).
--
-- INSERT ... ON CONFLICT DO NOTHING : rejouable, ne remplace jamais une valeur
-- ajustee depuis l'ecran /configuration/valeurs-defaut.
-- =====================================================================

BEGIN;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'activeind', 'COMPOSANT', 'CONSTANTE', 'Active part', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'activeind_db', 'COMPOSANT', 'CONSTANTE', 'Y', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'allow_inc_pkg_rsrv_picklst', 'COMPOSANT', 'CONSTANTE', 'TRUE', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'allow_incomp_pkg_delivery', 'COMPOSANT', 'CONSTANTE', 'TRUE', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'catalog_group', 'COMPOSANT', 'CONSTANTE', '903028', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'catalog_type', 'COMPOSANT', 'CONSTANTE', 'Inventory part', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'catalog_type_db', 'COMPOSANT', 'CONSTANTE', 'INV', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'close_tolerance', 'COMPOSANT', 'CONSTANTE', '0', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'conv_factor', 'COMPOSANT', 'CONSTANTE', '1', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'country_of_origin', 'COMPOSANT', 'CONSTANTE', 'FR', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'create_sm_object_option', 'COMPOSANT', 'CONSTANTE', 'Do not create SM object', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'create_sm_object_option_db', 'COMPOSANT', 'CONSTANTE', 'DONOTCREATESMOBJECT', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'export_to_external_app', 'COMPOSANT', 'CONSTANTE', 'False', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'export_to_external_app_db', 'COMPOSANT', 'CONSTANTE', 'FALSE', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'inverted_conv_factor', 'COMPOSANT', 'CONSTANTE', '1', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'list_price', 'COMPOSANT', 'CONSTANTE', '0', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'list_price_incl_tax', 'COMPOSANT', 'CONSTANTE', '0', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type', 'COMPOSANT', 'CONSTANTE', 'Goods', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type_db', 'COMPOSANT', 'CONSTANTE', 'GOODS', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'pack_comp_in_shpmnt', 'COMPOSANT', 'CONSTANTE', 'FALSE', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'price_conv_factor', 'COMPOSANT', 'CONSTANTE', '1', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'primary_catalog', 'COMPOSANT', 'CONSTANTE', 'True', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'primary_catalog_db', 'COMPOSANT', 'CONSTANTE', 'TRUE', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'quick_registered_part', 'COMPOSANT', 'CONSTANTE', 'False', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'quick_registered_part_db', 'COMPOSANT', 'CONSTANTE', 'FALSE', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'rental_list_price', 'COMPOSANT', 'CONSTANTE', '0', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'rental_list_price_incl_tax', 'COMPOSANT', 'CONSTANTE', '0', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sales_price_group_id', 'COMPOSANT', 'CONSTANTE', '*', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sales_type', 'COMPOSANT', 'CONSTANTE', 'Sales Only', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sales_type_db', 'COMPOSANT', 'CONSTANTE', 'SALES', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option', 'COMPOSANT', 'CONSTANTE', 'Inventory Order', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option_db', 'COMPOSANT', 'CONSTANTE', 'INVENTORYORDER', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'tax_code', 'COMPOSANT', 'CONSTANTE', 'C05', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'taxable', 'COMPOSANT', 'CONSTANTE', 'True', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'taxable_db', 'COMPOSANT', 'CONSTANTE', 'TRUE', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'use_price_incl_tax', 'COMPOSANT', 'CONSTANTE', 'False', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'use_price_incl_tax_db', 'COMPOSANT', 'CONSTANTE', 'FALSE', 'Source : salesPart.csv', 'migration_061')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

COMMIT;
