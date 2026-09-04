-- =====================================================================
-- Valeurs par defaut PURCHASE_PART du module articleComposant
--
-- Source : sql/ArticleComposant/valeurParDefaut/purchase_part.csv (gabarit de
-- chargement IFS fourni par le metier ; ses deux lignes SJ et CS sont identiques
-- hors colonnes propres a l'article -> pas de variante par site).
--
-- Comme pour inventory_part, le module lit toutes ses constantes en variante
-- COMPOSANT et ne depend plus des lignes STANDARD d'autres modules, dont
-- certaines divergeaient du gabarit (action_non_authorized_db WARNING vs NONE,
-- over_delivery_db YES et process_type STD alors que le gabarit les laisse vides).
--
-- INSERT ... ON CONFLICT DO NOTHING : rejouable, ne remplace jamais une valeur
-- ajustee depuis l'ecran /configuration/valeurs-defaut.
-- =====================================================================

BEGIN;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'acquisition_type', 'COMPOSANT', 'CONSTANTE', 'Purchase Only', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'acquisition_type_db', 'COMPOSANT', 'CONSTANTE', 'PURCHASE', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'action_authorized', 'COMPOSANT', 'CONSTANTE', 'Warning', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'action_authorized_db', 'COMPOSANT', 'CONSTANTE', 'WARNING', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'action_non_authorized', 'COMPOSANT', 'CONSTANTE', 'None', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'action_non_authorized_db', 'COMPOSANT', 'CONSTANTE', 'NONE', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'close_code', 'COMPOSANT', 'CONSTANTE', 'Automatic', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'close_code_db', 'COMPOSANT', 'CONSTANTE', 'Y', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'close_tolerance', 'COMPOSANT', 'CONSTANTE', '0', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'company', 'COMPOSANT', 'CONSTANTE', 'TRIMET', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'dop_pegged_po_update_flag', 'COMPOSANT', 'CONSTANTE', 'Planned', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'dop_pegged_po_update_flag_db', 'COMPOSANT', 'CONSTANTE', 'PLANNED', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'external_resource', 'COMPOSANT', 'CONSTANTE', 'False', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'external_resource_db', 'COMPOSANT', 'CONSTANTE', 'FALSE', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'inventory_flag', 'COMPOSANT', 'CONSTANTE', 'Inventory Part', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'inventory_flag_db', 'COMPOSANT', 'CONSTANTE', 'Y', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'package_part_flag', 'COMPOSANT', 'CONSTANTE', 'False', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'package_part_flag_db', 'COMPOSANT', 'CONSTANTE', 'FALSE', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'qualified_manufacturer', 'COMPOSANT', 'CONSTANTE', 'False', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'qualified_manufacturer_db', 'COMPOSANT', 'CONSTANTE', 'FALSE', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'qualified_supplier', 'COMPOSANT', 'CONSTANTE', 'False', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'qualified_supplier_db', 'COMPOSANT', 'CONSTANTE', 'FALSE', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'standard_pack_size', 'COMPOSANT', 'CONSTANTE', '1', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'std_name_description', 'COMPOSANT', 'CONSTANTE', '*', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'std_name_id', 'COMPOSANT', 'CONSTANTE', '0', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'taxable', 'COMPOSANT', 'CONSTANTE', 'True', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articleComposant', 'clean_data.purchase_part', 'taxable_db', 'COMPOSANT', 'CONSTANTE', 'TRUE', 'Source : purchase_part.csv', 'migration_060')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

COMMIT;
