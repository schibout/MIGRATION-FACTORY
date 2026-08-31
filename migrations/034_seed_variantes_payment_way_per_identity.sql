-- Migration 034 : variantes manquantes de clean_data.payment_way_per_identity
--
-- La cle (clean_data.payment_way_per_identity, party_type / party_type_db / way_id) est
-- partagee par 4 pipelines avec des valeurs DIVERGENTES :
--   supplier     -> 'Supplier' / 'SUPPLIER' / '1'          (variante STANDARD, migration 031)
--   customer     -> 'Customer' / 'CUSTOMER'                (variante CUSTOMER, migration 032)
--   customerFile -> 'Customer' / 'CUSTOMER' / 'BANK_TRANSFER'
--   customer_phl -> 'Customer' / 'CUSTOMER' / 'BANK_TRANSFER'
-- La migration 032 n'avait cree la variante que pour le premier module divergent : sans les
-- lignes ci-dessous, brancher les procedures customerFile / customer_phl sur
-- public.get_default_value() sans variante leur ferait lire la ligne STANDARD du module
-- fournisseur ('Supplier'), donc changer silencieusement le resultat du chargement.
--
-- Valeurs identiques aux litteraux actuellement codes en dur : chargement inchange.

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.payment_way_per_identity', 'party_type', 'CUSTOMERFILE', 'CONSTANTE', 'Customer', 'Source : sp_insert_payment_way_per_identity_from_file_customer.sql (STANDARD occupe par supplier=Supplier)', 'migration_034')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.payment_way_per_identity', 'party_type_db', 'CUSTOMERFILE', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_payment_way_per_identity_from_file_customer.sql (STANDARD occupe par supplier=SUPPLIER)', 'migration_034')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.payment_way_per_identity', 'party_type', 'CUSTOMER_PHL', 'CONSTANTE', 'Customer', 'Source : sp_insert_payment_way_per_identity_from_client_phl.sql (STANDARD occupe par supplier=Supplier)', 'migration_034')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.payment_way_per_identity', 'party_type_db', 'CUSTOMER_PHL', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_payment_way_per_identity_from_client_phl.sql (STANDARD occupe par supplier=SUPPLIER)', 'migration_034')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.payment_way_per_identity', 'way_id', 'CUSTOMER_PHL', 'CONSTANTE', 'BANK_TRANSFER', 'Source : sp_insert_payment_way_per_identity_from_client_phl.sql (STANDARD occupe par supplier=1)', 'migration_034')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
