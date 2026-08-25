-- Migration 032 : seed des valeurs par défaut ETL des 7 autres modules
-- Généré depuis les inventaires sql/<module>/inventaire_colonnes_valeurs_defaut.csv
-- (extract_default_values.py sur les procédures réexportées de la base, commit 409e3ab).
-- Les procédures ETL sont INCHANGÉES : ces lignes alimentent l'écran
-- Configuration > Valeurs par défaut ; elles ne seront effectives qu'une fois les
-- procédures branchées sur public.get_default_value().
-- Clés partagées entre modules à valeur identique : une seule ligne (1er module).
-- Clés à valeurs DIVERGENTES entre modules (17) : une ligne par module,
-- variante = nom du module en majuscules.
-- Même traitement pour les 3 clés de clean_data.payment_way_per_identity dont la
-- variante STANDARD est déjà occupée par le seed supplier avec une AUTRE valeur
-- (bloc en fin de fichier).

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.payment_way_per_identity', 'party_type', 'CUSTOMER', 'CONSTANTE', 'Customer', 'Source : pipelines customer (STANDARD occupé par supplier=Supplier)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.payment_way_per_identity', 'party_type_db', 'CUSTOMER', 'CONSTANTE', 'CUSTOMER', 'Source : pipelines customer (STANDARD occupé par supplier=SUPPLIER)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.payment_way_per_identity', 'way_id', 'CUSTOMERFILE', 'CONSTANTE', 'BANK_TRANSFER', 'Source : pipelines customer (STANDARD occupé par supplier=1)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'exclude_from_integrations', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'exclude_from_integrations_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'exclude_periodical_cap', 'STANDARD', 'CONSTANTE', 'INCLUDE', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'exclude_periodical_cap_db', 'STANDARD', 'CONSTANTE', 'INCLUDE', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'exclude_resource_progress', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'exclude_resource_progress_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'mandatory_invoice_comment', 'STANDARD', 'CONSTANTE', 'INHERIT', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'mandatory_invoice_comment_db', 'STANDARD', 'CONSTANTE', 'INHERIT', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'node_type', 'STANDARD', 'CONSTANTE', 'ACTIVITY', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'node_type_db', 'STANDARD', 'CONSTANTE', 'ACTIVITY', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'planned_cost_driver', 'STANDARD', 'CONSTANTE', 'CONNECTED_OBJECTS', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'planned_cost_driver_db', 'STANDARD', 'CONSTANTE', 'CONNECTED_OBJECTS', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'progress_method', 'STANDARD', 'CONSTANTE', 'ALL_CONNECTED_OBJECTS', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'progress_method_db', 'STANDARD', 'CONSTANTE', 'ALL_CONNECTED_OBJECTS', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.activity', 'sub_project_id', 'STANDARD', 'CONSTANTE', '10', 'Source : alimenter_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_comm_method', 'address_default', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_comm_method', 'comm_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_comm_method_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_comm_method', 'description', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_comm_method_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_comm_method', 'method_default', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_comm_method', 'method_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_comm_method_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_comm_method', 'method_id_db', 'STANDARD', 'CONSTANTE', 'PHONE', 'Source : sp_insert_cus_comm_method_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'party_type', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_comm_method_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'party_type_db', 'STANDARD', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_cus_comm_method_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_comm_method', 'valid_from', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_comm_method_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'valid_to', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_comm_method_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_comm_method', 'value', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_comm_method_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'amount_tolerance', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'automatic_invoice', 'STANDARD', 'CONSTANTE', 'N', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'def_authorizer', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_ident_invoice_info', 'def_currency', 'STANDARD', 'CONSTANTE', 'EUR', 'Source : sp_insert_cus_ident_invoice_info_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'def_preliminary_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_ident_invoice_info', 'def_vat_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'expire_date', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_ident_invoice_info', 'group_id', 'STANDARD', 'CONSTANTE', '0', 'Source : sp_insert_cus_ident_invoice_info_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'identity_type', 'CUSTOMER', 'CONSTANTE', 'Customer', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cus_ident_invoice_info', 'identity_type', 'CUSTOMERFILE', 'CONSTANTE', 'External', 'Source : sp_insert_cus_ident_invoice_info_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'identity_type_db', 'CUSTOMER', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cus_ident_invoice_info', 'identity_type_db', 'CUSTOMERFILE', 'CONSTANTE', 'EXTERN', 'Source : sp_insert_cus_ident_invoice_info_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_ident_invoice_info', 'identity_type_db', 'CUSTOMER_PHL', 'CONSTANTE', 'EXTERN', 'Source : sp_insert_cus_ident_invoice_info_from_client_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'invoice_fee', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_ident_invoice_info', 'national_bank_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'ncf_reference_check', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'no_invoice_copies', 'CUSTOMER', 'CONSTANTE', '1', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cus_ident_invoice_info', 'no_invoice_copies', 'CUSTOMERFILE', 'CONSTANTE', '1', 'Source : sp_insert_cus_ident_invoice_info_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_ident_invoice_info', 'no_invoice_copies', 'CUSTOMER_PHL', 'CONSTANTE', '0', 'Source : sp_insert_cus_ident_invoice_info_from_client_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'numeration_group', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'party_type', 'STANDARD', 'CONSTANTE', 'Customer', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'party_type_db', 'STANDARD', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_ident_invoice_info', 'pay_term_id', 'STANDARD', 'CONSTANTE', '30NETS', 'Source : sp_insert_cus_ident_invoice_info_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'paym_dev_days', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'percent_tolerance', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'print_tax_code_text', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'report_and_withhold', 'CUSTOMER', 'CONSTANTE', 'No Report', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cus_ident_invoice_info', 'report_and_withhold', 'CUSTOMERFILE', 'CONSTANTE', 'Blocked', 'Source : sp_insert_cus_ident_invoice_info_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'report_and_withhold_db', 'CUSTOMER', 'CONSTANTE', 'NO_REPORT', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cus_ident_invoice_info', 'report_and_withhold_db', 'CUSTOMERFILE', 'CONSTANTE', 'BLOCKED', 'Source : sp_insert_cus_ident_invoice_info_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_ident_invoice_info', 'report_and_withhold_db', 'CUSTOMER_PHL', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_client_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'rounding_tax_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'second_tin', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'tax_book_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'tax_book_type', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'tax_exempt', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'tax_exempt_valid_from', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'tax_exempt_valid_to', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_ident_invoice_info', 'tax_structure_id', 'STANDARD', 'CONSTANTE', 'DEFAULT', 'Source : sp_insert_cus_ident_invoice_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'amount_tolerance', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'ar_contact', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_identity_pay_info', 'blocked_for_payment', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_identity_pay_info_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'business_category', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'check_recipient', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'check_recipient_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'comm_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'corporation_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'deduction_group', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_identity_pay_info', 'default_payment_method', 'STANDARD', 'CONSTANTE', 'TRANSFER', 'Source : sp_insert_cus_identity_pay_info_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'disc_days_tolerance', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'format_no', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'interest_template', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'is_one_inv_per_pay', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'is_one_inv_per_pay_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'member_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'netting_allowed', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'next_payment_matching_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'other_payee_identity', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'output_media', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'output_media_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'party_type', 'STANDARD', 'CONSTANTE', 'Customer', 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'party_type_db', 'STANDARD', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'payment_advice', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'payment_advice_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'payment_delay', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'payment_mode', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'payment_mode_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'payment_receipt_type', 'CUSTOMER', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cus_identity_pay_info', 'payment_receipt_type', 'CUSTOMERFILE', 'CONSTANTE', 'No Receipt', 'Source : sp_insert_cus_identity_pay_info_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_identity_pay_info', 'payment_receipt_type', 'CUSTOMER_PHL', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_client_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'payment_receipt_type_db', 'CUSTOMER', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cus_identity_pay_info', 'payment_receipt_type_db', 'CUSTOMERFILE', 'CONSTANTE', 'NO_RECEIPT', 'Source : sp_insert_cus_identity_pay_info_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_identity_pay_info', 'payment_receipt_type_db', 'CUSTOMER_PHL', 'CONSTANTE', 'NO_RECEIPT', 'Source : sp_insert_cus_identity_pay_info_from_client_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'percent_tolerance', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'predicted_payment_delay', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'predicted_payment_delay_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'priority', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'reminder_template', 'CUSTOMER', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cus_identity_pay_info', 'reminder_template', 'CUSTOMERFILE', 'CONSTANTE', '1', 'Source : sp_insert_cus_identity_pay_info_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_identity_pay_info', 'reminder_template', 'CUSTOMER_PHL', 'CONSTANTE', '0', 'Source : sp_insert_cus_identity_pay_info_from_client_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'rule_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'send_interest_inv_to_payer', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'send_reminder_to_payer', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'send_stmt_of_acc_to_payer', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_identity_pay_info', 'template_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_identity_pay_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_paym_way_per_ident', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_cus_paym_way_per_ident_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_paym_way_per_ident', 'default_payment_way', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : sp_insert_cus_paym_way_per_ident_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_paym_way_per_ident', 'party_type', 'STANDARD', 'CONSTANTE', 'Customer', 'Source : sp_insert_cus_paym_way_per_ident_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_paym_way_per_ident', 'party_type_db', 'STANDARD', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_cus_paym_way_per_ident_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_paym_way_per_ident', 'way_id', 'STANDARD', 'CONSTANTE', 'SEPA', 'Source : sp_insert_cus_paym_way_per_ident_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_payment_address', 'account', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_payment_address_from_client_adresse_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_payment_address', 'bank_account_valid_date', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_payment_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_payment_address', 'bank_account_validated', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_payment_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_payment_address', 'bank_account_validated_db', 'CUSTOMER', 'CONSTANTE', 'NOT VALIDATED', 'Source : sp_insert_cus_payment_address_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cus_payment_address', 'bank_account_validated_db', 'CUSTOMERFILE', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_payment_address_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cus_payment_address', 'bank_account_validated_db', 'CUSTOMER_PHL', 'CONSTANTE', 'NOT VALIDATED', 'Source : sp_insert_cus_payment_address_from_client_adresse_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_payment_address', 'bic_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cus_payment_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_payment_address', 'blocked_for_use', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_payment_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_payment_address', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_cus_payment_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_payment_address', 'party_type', 'STANDARD', 'CONSTANTE', 'Customer', 'Source : sp_insert_cus_payment_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_payment_address', 'party_type_db', 'STANDARD', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_cus_payment_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_payment_address', 'way_id', 'STANDARD', 'CONSTANTE', 'SEPA', 'Source : sp_insert_cus_payment_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'acquisition_site', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'category', 'STANDARD', 'CONSTANTE', 'E', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'category_db', 'STANDARD', 'CONSTANTE', 'E', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'commission_receiver', 'STANDARD', 'CONSTANTE', 'DONOTCREATE', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'commission_receiver_db', 'STANDARD', 'CONSTANTE', 'DONOTCREATE', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'cycle_period', 'STANDARD', 'CONSTANTE', '0', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'date_del', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'discount', 'STANDARD', 'CONSTANTE', '0', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'discount_type', 'STANDARD', 'CONSTANTE', 'Standard', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'forward_agent_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'invoice_sort', 'STANDARD', 'CONSTANTE', 'N', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'invoice_sort_db', 'STANDARD', 'CONSTANTE', 'N', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'last_ivc_date', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'order_conf_flag', 'STANDARD', 'CONSTANTE', 'Y', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'order_conf_flag_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'order_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'pack_list_flag', 'STANDARD', 'CONSTANTE', 'Y', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer', 'pack_list_flag_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : sp_insert_cust_ord_customer_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer_address', 'contact', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer_address', 'cust_calendar_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cust_ord_customer_address', 'del_terms_location', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_address_from_client_adresse_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cust_ord_customer_address', 'delivery_terms', 'STANDARD', 'CONSTANTE', 'EXW', 'Source : sp_insert_cust_ord_customer_address_from_client_adresse_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer_address', 'delivery_time', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cust_ord_customer_address', 'district_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_address_from_client_adresse_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer_address', 'intrastat_exempt', 'CUSTOMER', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_address_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer_address', 'intrastat_exempt', 'CUSTOMERFILE', 'CONSTANTE', 'Include', 'Source : sp_insert_cust_ord_customer_address_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cust_ord_customer_address', 'intrastat_exempt', 'CUSTOMER_PHL', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_address_from_client_adresse_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer_address', 'intrastat_exempt_db', 'CUSTOMER', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_address_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer_address', 'intrastat_exempt_db', 'CUSTOMERFILE', 'CONSTANTE', 'INCLUDE', 'Source : sp_insert_cust_ord_customer_address_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cust_ord_customer_address', 'intrastat_exempt_db', 'CUSTOMER_PHL', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_address_from_client_adresse_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer_address', 'route_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.cust_ord_customer_address', 'ship_via_code', 'STANDARD', 'CONSTANTE', '01', 'Source : sp_insert_cust_ord_customer_address_from_client_adresse_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer_address', 'shipment_type', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer_address', 'shipment_uncon_struct', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cust_ord_customer_address', 'shipment_uncon_struct_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_addr_tax_number', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_customer_addr_tax_number_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_addr_tax_number', 'default_tax_id_number', 'STANDARD', 'CONSTANTE', 'True', 'Source : sp_insert_customer_addr_tax_number_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_addr_tax_number', 'default_tax_id_number_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : sp_insert_customer_addr_tax_number_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_addr_tax_number', 'tax_id_number', 'STANDARD', 'CONSTANTE', 'NO_TAX_ID', 'Source : sp_insert_customer_addr_tax_number_from_client_adresse_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_addr_tax_number', 'tax_id_type', 'STANDARD', 'CONSTANTE', '', 'Source : sp_insert_customer_addr_tax_number_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'allowed_due_amount', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'allowed_due_days', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'avg_days_for_payment', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'corp_credit_relation_exist', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'credit_analyst_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_credit_info', 'credit_block', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'credit_comments', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'credit_limit', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_credit_info', 'credit_number', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_client_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'credit_rating', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'credit_relationship_type', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'credit_relationship_type_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'last4q_sales', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'message_type', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'next_review_date', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'note_text', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'parent_company', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'parent_identity', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'party_type', 'STANDARD', 'CONSTANTE', 'Customer', 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_credit_info', 'party_type_db', 'STANDARD', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_customer_credit_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_del_tax_exempt', 'certificate_amount', 'STANDARD', 'CONSTANTE', '0', 'Source : sp_insert_customer_del_tax_exempt_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_del_tax_exempt', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_customer_del_tax_exempt_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_del_tax_exempt', 'exempt_certificate_type', 'STANDARD', 'CONSTANTE', '', 'Source : sp_insert_customer_del_tax_exempt_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_del_tax_exempt', 'exempt_certificate_type_db', 'STANDARD', 'CONSTANTE', 'BLANKET CERTIFICATE', 'Source : sp_insert_customer_del_tax_exempt_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_delivery_fee_code', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_customer_delivery_fee_code_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_delivery_fee_code', 'fee_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_delivery_fee_code_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_delivery_fee_code', 'tax_code_selection', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_delivery_fee_code_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_delivery_tax_info', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_customer_delivery_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_delivery_tax_info', 'supply_country', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_delivery_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_delivery_tax_info', 'tax_book_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_delivery_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_delivery_tax_info', 'tax_book_type', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_delivery_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_delivery_tax_info', 'tax_calc_structure_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_delivery_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_delivery_tax_info', 'tax_liability', 'STANDARD', 'CONSTANTE', 'TAX', 'Source : sp_insert_customer_delivery_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_delivery_tax_info', 'tax_structure_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_delivery_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_document_tax_info', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_customer_document_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_document_tax_info', 'delivery_country', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_document_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_document_tax_info', 'supply_country', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_document_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_document_tax_info', 'tax_id_error_message', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_document_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_document_tax_info', 'tax_id_type', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_document_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_document_tax_info', 'tax_office_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_document_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_document_tax_info', 'validated_date', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_document_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_document_tax_info', 'vat_no', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_document_tax_info_from_sap.sql (+ modules customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'b2b_customer', 'CUSTOMER', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_info_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.customer_info', 'b2b_customer', 'CUSTOMERFILE', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_info_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_info', 'b2b_customer', 'CUSTOMER_PHL', 'NULL', NULL, 'Source : sp_insert_customer_info_from_client_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'b2b_customer_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_info_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'business_classification', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_info_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'corporate_form', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_info_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'country', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'customer_category', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'customer_category_db', 'STANDARD', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_customer_info_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'customer_tax_usage_type', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_info_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'default_domain', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_info_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'default_language', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_info_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'identifier_ref_validation', 'CUSTOMER', 'CONSTANTE', '', 'Source : sp_insert_customer_info_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.customer_info', 'identifier_ref_validation', 'CUSTOMERFILE', 'CONSTANTE', '', 'Source : sp_insert_customer_info_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_info', 'identifier_ref_validation', 'CUSTOMER_PHL', 'NULL', NULL, 'Source : sp_insert_customer_info_from_client_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'identifier_ref_validation_db', 'STANDARD', 'CONSTANTE', '', 'Source : sp_insert_customer_info_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'main_representative', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'one_time', 'CUSTOMER', 'CONSTANTE', 'False', 'Source : sp_insert_customer_info_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.customer_info', 'one_time', 'CUSTOMERFILE', 'CONSTANTE', 'False', 'Source : sp_insert_customer_info_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_info', 'one_time', 'CUSTOMER_PHL', 'NULL', NULL, 'Source : sp_insert_customer_info_from_client_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'one_time_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_info_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'party_type', 'CUSTOMER', 'CONSTANTE', 'Customer', 'Source : sp_insert_customer_info_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.customer_info', 'party_type', 'CUSTOMERFILE', 'CONSTANTE', 'Customer', 'Source : sp_insert_customer_info_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_info', 'party_type', 'CUSTOMER_PHL', 'NULL', NULL, 'Source : sp_insert_customer_info_from_client_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'party_type_db', 'STANDARD', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_customer_info_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info', 'picture_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_info_address', 'default_domain', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_info_address_from_client_adresse_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_address', 'ean_location', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_address_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_address', 'jurisdiction_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_address_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_address', 'party_type', 'STANDARD', 'CONSTANTE', 'Customer', 'Source : sp_insert_customer_address_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_address', 'party_type_db', 'STANDARD', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_customer_address_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_address', 'primary_contact', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_address_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_address', 'secondary_contact', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_address_from_sap.sql (+ modules customerFile)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_info_address', 'valid_from', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_info_address_from_client_adresse_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_address', 'valid_to', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_address_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_info_address_type', 'address_type_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_address_type_single_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_info_address_type', 'def_address', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : sp_insert_customer_address_type_single_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.customer_info_address_type', 'default_domain', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_address_type_single_file.sql (+ modules customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_contact', 'address_primary', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : sp_insert_customer_info_contact_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_contact', 'address_secondary', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_info_contact_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_contact', 'contact_email', 'STANDARD', 'CONSTANTE', 'customer@company.com', 'Source : sp_insert_customer_info_contact_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_contact', 'contact_title', 'STANDARD', 'CONSTANTE', 'Customer Representative', 'Source : sp_insert_customer_info_contact_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_contact', 'customer_primary', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : sp_insert_customer_info_contact_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_contact', 'customer_secondary', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_info_contact_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_contact', 'role', 'STANDARD', 'CONSTANTE', 'Primary Contact', 'Source : sp_insert_customer_info_contact_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_info_contact', 'role_db', 'STANDARD', 'CONSTANTE', 'PRIMARY', 'Source : sp_insert_customer_info_contact_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_free_tax_code', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_customer_tax_free_tax_code_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_free_tax_code', 'delivery_type', 'STANDARD', 'CONSTANTE', 'Delivery Type', 'Source : sp_insert_customer_tax_free_tax_code_from_sap.sql (+ modules customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_free_tax_code', 'vat_free_vat_code', 'CUSTOMER', 'NULL', NULL, 'Source : sp_insert_customer_tax_free_tax_code_from_sap.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.customer_tax_free_tax_code', 'vat_free_vat_code', 'CUSTOMERFILE', 'CONSTANTE', 'N', 'Source : sp_insert_customer_tax_free_tax_code_from_file_customer.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_tax_free_tax_code', 'vat_free_vat_code', 'CUSTOMER_PHL', 'NULL', NULL, 'Source : sp_insert_customer_tax_free_tax_code_from_client_adresse_phl.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'business_transaction_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'component_a', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'component_a_identity', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'enable_for_tcs', 'STANDARD', 'CONSTANTE', 'False', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'enable_for_tcs_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'exc_from_spesometro_dec', 'STANDARD', 'CONSTANTE', 'False', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'exc_from_spesometro_dec_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer_phl', 'clean_data.customer_tax_info', 'fiscal_no', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_tax_info_from_client_adresse_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'icms_tax_payer', 'STANDARD', 'CONSTANTE', 'False', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'icms_tax_payer_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'out_inv_curr_rate_base', 'STANDARD', 'CONSTANTE', 'Invoice Date', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'out_inv_curr_rate_base_db', 'STANDARD', 'CONSTANTE', 'INVOICE_DATE', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'out_inv_vou_date_base', 'STANDARD', 'CONSTANTE', 'Invoice Date', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'out_inv_vou_date_base_db', 'STANDARD', 'CONSTANTE', 'INVOICE_DATE', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'permanent_establishment', 'STANDARD', 'CONSTANTE', 'False', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'permanent_establishment_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_exempt', 'STANDARD', 'CONSTANTE', 'False', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_exempt_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_exempt_valid_from', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_exempt_valid_to', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_office_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_rounding_level', 'STANDARD', 'CONSTANTE', 'Line Level', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_rounding_level_db', 'STANDARD', 'CONSTANTE', 'LINE_LEVEL', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_rounding_method', 'STANDARD', 'CONSTANTE', 'Round to the Nearest', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_rounding_method_db', 'STANDARD', 'CONSTANTE', 'ROUND_NEAREST', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_sell_curr_rate_base', 'STANDARD', 'CONSTANTE', 'Invoice Date', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_sell_curr_rate_base_db', 'STANDARD', 'CONSTANTE', 'INVOICE_DATE', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_withholding', 'STANDARD', 'CONSTANTE', 'Blocked', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'tax_withholding_db', 'STANDARD', 'CONSTANTE', 'BLOCKED', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'withholding_base_amount', 'STANDARD', 'CONSTANTE', 'Invoice Net Amount', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.customer_tax_info', 'withholding_base_amount_db', 'STANDARD', 'CONSTANTE', 'INVOICENET', 'Source : sp_insert_customer_tax_info_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'actif_achat', 'STANDARD', 'CONSTANTE', 'NON', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'actif_commercial', 'STANDARD', 'CONSTANTE', 'NON', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'actif_dans_centre', 'STANDARD', 'CONSTANTE', 'NON', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'actif_evaluation', 'STANDARD', 'CONSTANTE', 'NON', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'avec_stock', 'STANDARD', 'CONSTANTE', 'NON', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'langue', 'STANDARD', 'CONSTANTE', 'FR', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'nombre_centres_actifs', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'nombre_magasins', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'stock_total_bloque', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'stock_total_controle', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'stock_total_libre', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'valeur_stock_magasins_total', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'acquired_supply_type', 'STANDARD', 'CONSTANTE', 'Requisition', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'acquired_supply_type_db', 'STANDARD', 'CONSTANTE', 'R', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'carry_rate', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'lot_size_auto', 'STANDARD', 'CONSTANTE', 'Manual Lot Size', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'lot_size_auto_db', 'STANDARD', 'CONSTANTE', 'N', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'manuf_supply_type', 'STANDARD', 'CONSTANTE', 'Requisition', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'manuf_supply_type_db', 'STANDARD', 'CONSTANTE', 'R', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'maxweek_supply', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'mul_order_qty', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'order_point_qty_auto', 'STANDARD', 'CONSTANTE', 'Manual Order Point', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'order_point_qty_auto_db', 'STANDARD', 'CONSTANTE', 'N', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'order_requisition', 'STANDARD', 'CONSTANTE', 'Requisition', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'order_requisition_db', 'STANDARD', 'CONSTANTE', 'R', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'planning_method_auto', 'STANDARD', 'CONSTANTE', 'True', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'planning_method_auto_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'proposal_release', 'STANDARD', 'CONSTANTE', 'Release', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'proposal_release_db', 'STANDARD', 'CONSTANTE', 'RELEASE', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'safety_stock_auto', 'STANDARD', 'CONSTANTE', 'Manual Safety Stock', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'safety_stock_auto_db', 'STANDARD', 'CONSTANTE', 'N', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'sched_capacity', 'STANDARD', 'CONSTANTE', 'Infinite Capacity', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'sched_capacity_db', 'STANDARD', 'CONSTANTE', 'I', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'service_rate', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'setup_cost', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'shrinkage_fac', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'split_manuf_acquired', 'STANDARD', 'CONSTANTE', 'No Split', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.invent_part_plan', 'split_manuf_acquired_db', 'STANDARD', 'CONSTANTE', 'NO_SPLIT', 'Source : alimenter_inventory_part_planning.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'abc_class', 'STANDARD', 'NULL', NULL, 'Source : ajouter_article_silicium.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'asset_class', 'STANDARD', 'CONSTANTE', 'S', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'automatic_capability_check_db', 'STANDARD', 'CONSTANTE', 'NO AUTOMATIC CAPABILITY CHECK', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'avail_activity_status_db', 'STANDARD', 'CONSTANTE', 'CHANGED', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'c_density', 'STANDARD', 'CONSTANTE', '2.7', 'Source : alimenter_inventory_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'c_spire_code', 'STANDARD', 'CONSTANTE', 'S', 'Source : alimenter_inventory_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'co_reserve_onh_analys_flag_db', 'STANDARD', 'CONSTANTE', 'N', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'company', 'STANDARD', 'CONSTANTE', 'SJM', 'Source : alimenter_inventory_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'contract', 'STANDARD', 'CONSTANTE', 'SJ', 'Source : alimenter_inventory_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'count_variance', 'STANDARD', 'CONSTANTE', '0', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'country_of_origin', 'STANDARD', 'NULL', NULL, 'Source : ajouter_article_silicium.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'cycle_code_db', 'STANDARD', 'CONSTANTE', 'N', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'cycle_period', 'STANDARD', 'CONSTANTE', '0', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'dop_connection_db', 'STANDARD', 'CONSTANTE', 'AUT', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'dop_netting_db', 'STANDARD', 'CONSTANTE', 'NONET', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'excl_ship_pack_proposal_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'expected_leadtime', 'STANDARD', 'CONSTANTE', '0', 'Source : ajouter_article_silicium.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'ext_service_cost_method_db', 'STANDARD', 'CONSTANTE', 'EXCLUDE SERVICE COST', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'forecast_consumption_flag_db', 'STANDARD', 'CONSTANTE', 'FORECAST', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'frequency_class_db', 'STANDARD', 'CONSTANTE', 'VERY SLOW MOVER', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'hsn_sac_code', 'STANDARD', 'NULL', NULL, 'Source : ajouter_article_silicium.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'intrastat_conv_factor', 'STANDARD', 'NULL', NULL, 'Source : alimenter_inventory_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'inventory_part_cost_level_db', 'STANDARD', 'CONSTANTE', 'COST PER PART', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'inventory_valuation_method_db', 'STANDARD', 'CONSTANTE', 'ST', 'Source : ajouter_article_silicium.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'invoice_consideration_db', 'STANDARD', 'CONSTANTE', 'TRANSACTION BASED', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.inventory_part', 'lead_time_code_db', 'STANDARD', 'CONSTANTE', 'P', 'Source : alimenter_inventory_part.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'lifecycle_stage_db', 'STANDARD', 'CONSTANTE', 'DEVELOPMENT', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'mandatory_expiration_date_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'manuf_leadtime', 'STANDARD', 'CONSTANTE', '0', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'negative_on_hand_db', 'STANDARD', 'CONSTANTE', 'NEG ONHAND NOT OK', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'oe_alloc_assign_flag_db', 'STANDARD', 'CONSTANTE', 'N', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'onhand_analysis_flag_db', 'STANDARD', 'CONSTANTE', 'N', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'part_status', 'STANDARD', 'CONSTANTE', 'A', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'planner_buyer', 'STANDARD', 'CONSTANTE', '*', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'purch_leadtime', 'STANDARD', 'CONSTANTE', '0', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'qty_calc_rounding', 'STANDARD', 'CONSTANTE', '0', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'reset_config_std_cost_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'shortage_flag_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'stock_management_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'supply_code_db', 'STANDARD', 'CONSTANTE', 'IO', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.inventory_part', 'type_code_db', 'STANDARD', 'CONSTANTE', '4', 'Source : alimenter_inventory_part.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.inventory_part', 'zero_cost_flag_db', 'STANDARD', 'CONSTANTE', 'N', 'Source : alimenter_inventory_part.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task', 'adjusted_duration', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : create_alimenter_jt_task.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task', 'appointment_required', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : create_alimenter_jt_task.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task', 'company', 'STANDARD', 'CONSTANTE', 'TRIM', 'Source : create_alimenter_jt_task.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task', 'exclude_from_scheduling', 'STANDARD', 'CONSTANTE', 'False', 'Source : create_alimenter_jt_task.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task', 'exclude_from_scheduling_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : create_alimenter_jt_task.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task', 'fixed_start', 'STANDARD', 'NULL', NULL, 'Source : create_alimenter_jt_task.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task', 'objtype', 'STANDARD', 'CONSTANTE', 'JtTask', 'Source : create_alimenter_jt_task.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task', 'objversion', 'STANDARD', 'CONSTANTE', '1', 'Source : create_alimenter_jt_task.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task', 'remotely_fulfilled', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : create_alimenter_jt_task.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task', 'scheduled_manually', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : create_alimenter_jt_task.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task_resource', 'crew_time_invoicing', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : create_alimenter_jt_task_resource.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task_resource', 'offset_value', 'STANDARD', 'CONSTANTE', '0', 'Source : create_alimenter_jt_task_resource.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.jt_task_resource', 'sourcing_option_db', 'STANDARD', 'CONSTANTE', 'INTERNALLY_SOURCED', 'Source : create_alimenter_jt_task_resource.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'buy_unit_meas', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'catalog_no', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'cf_alt_on_hand_qty', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'cf_ecartqtedispo', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'cf_on_supply_qty', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'change_reason', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'changes_line_item_no', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'condition_code', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'consumed_qty', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'delivery', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'delivery_db', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'discount', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'external_id', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'fbuy_unit_price', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'generated', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'is_closed', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'job_id', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'list_price', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'list_price_curr', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'manual_line', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'markup', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'mobile_created', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'mobile_created_db', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'mobile_warranty', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'mobile_warranty_db', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'no_part_description', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'objversion', 'STANDARD', 'CONSTANTE', '1', 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'owner', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'part_ownership', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'part_ownership_db', 'STANDARD', 'CONSTANTE', 'COMPANY OWNED', 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'part_type', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'part_type_db', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'pegged_qty', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'pickup_task_id', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'place_in_facility_db', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'price_effective_date', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'price_list_no', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'price_source_db', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'price_source_id', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'purchase_method', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'purchase_method_db', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'qty', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'qty_assigned', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'qty_changed', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'qty_returned', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'qty_short', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'qty_to_invoice', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'quo_spare_seq', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'quo_task_seq', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'quotation_no', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'quotation_rev', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'rental', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'rental_db', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'rental_task_res_seq', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'repair_part_flag', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'rwo_contract', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'rwo_copy_prepost', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'rwo_copy_prepost_db', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'rwo_equip_object_seq', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'rwo_err_descr', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'rwo_lot_batch_no', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'rwo_mch_code', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'rwo_mch_contract', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'rwo_org_code', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'sale_unit_price', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'sale_unit_price_curr', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'sender_id', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'sender_type', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'sender_type_db', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'serial_in', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'serial_in_contract', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'service_type', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'supply_code', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'supply_code_db', 'STANDARD', 'CONSTANTE', 'INVENT_ORDER', 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'supply_source_ref1', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'supply_source_ref2', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'supply_source_ref3', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'supply_source_ref4', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'supply_source_ref_state', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'supply_source_ref_type', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'supply_source_ref_type_db', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'swap_part_db', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'task_plan_line_seq', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'tool_fac_row_no', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'wo_quo_no', 'STANDARD', 'NULL', NULL, 'Source : create_clean_data_maint_material_req_line.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'auto_replace_alt_comp_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'backflush_part_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'component_scrap', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'configuration_usage_db', 'STANDARD', 'CONSTANTE', 'Common', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'consider_lead_time_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'contract', 'STANDARD', 'CONSTANTE', 'SJ', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'cum_leadtime', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag_db', 'STANDARD', 'CONSTANTE', 'PLANNED', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'engineering_info_db', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'fixed_leadtime_day', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'fixed_leadtime_hour', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'include_firm_demands', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'include_firm_supplies', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'issue_overreported_qty_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'issue_planned_scrap_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'low_level', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'mrp_control_flag_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'optimize_new_delivery_date', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'order_gap_time', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'over_reporting_db', 'STANDARD', 'CONSTANTE', 'ALLOWED', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule', 'STANDARD', 'CONSTANTE', 'DIRECT', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'promise_planned_db', 'STANDARD', 'CONSTANTE', 'Promised', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'routing_effectivity_db', 'STANDARD', 'CONSTANTE', 'DATE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'run_crp', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'run_in_background', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'run_mrp', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'ship_dirty', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'ship_dirty_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'shrinkage_factor', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'structure_effectivity_db', 'STANDARD', 'CONSTANTE', 'DATE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'unprotected_lead_time', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'use_theoritical_density_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'variable_leadtime_day', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'variable_leadtime_hour', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_manuf_part_attribute_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'allow_as_not_consumed_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'catch_unit_enabled_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'component_lot_rule_db', 'ARTICLEPHL', 'CONSTANTE', 'MANY_LOTS_ALLOWED', 'Source : ajouter_article_silicium.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.part_catalog', 'component_lot_rule_db', 'INVENTORY', 'CONSTANTE', 'ONE_LOT_ALLOWED', 'Source : alimenter_part_catalog.sql (valeur divergente entre modules)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'condition_code_usage_db', 'STANDARD', 'CONSTANTE', 'NOT_ALLOW_COND_CODE', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'configurable_db', 'STANDARD', 'CONSTANTE', 'NOT CONFIGURED', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'eng_serial_tracking_code_db', 'STANDARD', 'CONSTANTE', 'NOT SERIAL TRACKING', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'lot_quantity_rule_db', 'STANDARD', 'CONSTANTE', 'MULTI_LOTS', 'Source : ajouter_article_silicium.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'lot_tracking_code_db', 'STANDARD', 'CONSTANTE', 'LOT TRACKING', 'Source : ajouter_article_silicium.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'multilevel_tracking_db', 'STANDARD', 'CONSTANTE', 'TRACKING_OFF', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'position_part_db', 'STANDARD', 'CONSTANTE', 'NOT POSITION PART', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'receipt_issue_serial_track_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'serial_rule_db', 'STANDARD', 'CONSTANTE', 'MANUAL', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'serial_tracking_code_db', 'STANDARD', 'CONSTANTE', 'NOT SERIAL TRACKING', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'stop_arrival_issued_serial_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'stop_new_serial_in_rma_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'sub_lot_rule_db', 'STANDARD', 'CONSTANTE', 'NO_SUBLOTS', 'Source : ajouter_article_silicium.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.payment_way_per_identity', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : sp_insert_payment_way_per_identity_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.payment_way_per_identity', 'default_payment_way', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : sp_insert_payment_way_per_identity_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.payment_way_per_identity', 'party_type', 'STANDARD', 'CONSTANTE', 'Customer', 'Source : sp_insert_payment_way_per_identity_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.payment_way_per_identity', 'party_type_db', 'STANDARD', 'CONSTANTE', 'CUSTOMER', 'Source : sp_insert_payment_way_per_identity_from_sap.sql (+ modules customerFile, customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.payment_way_per_identity', 'valid_to', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_payment_way_per_identity_from_sap.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.payment_way_per_identity', 'way_id', 'STANDARD', 'CONSTANTE', 'BANK_TRANSFER', 'Source : sp_insert_payment_way_per_identity_from_file_customer.sql (+ modules customer_phl)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_activity', 'exclude_from_integrations_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_project_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_activity', 'exclude_periodical_cap_db', 'STANDARD', 'CONSTANTE', 'INCLUDE', 'Source : alimenter_project_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_activity', 'exclude_resource_progress_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_project_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_activity', 'mandatory_invoice_comment_db', 'STANDARD', 'CONSTANTE', 'INHERIT', 'Source : alimenter_project_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_activity', 'node_type_db', 'STANDARD', 'CONSTANTE', 'ACTIVITY', 'Source : alimenter_project_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_activity', 'planned_cost_driver_db', 'STANDARD', 'CONSTANTE', 'CONNECTED_OBJECTS', 'Source : alimenter_project_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_activity', 'progress_method_db', 'STANDARD', 'CONSTANTE', 'ALL_CONNECTED_OBJECTS', 'Source : alimenter_project_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_activity', 'sub_project_id', 'STANDARD', 'CONSTANTE', '10', 'Source : alimenter_project_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_activity', 'task_id', 'STANDARD', 'NULL', NULL, 'Source : alimenter_project_activity.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_base', 'baseline_revision_number', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_ifs_project_base.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_base', 'category2_id', 'STANDARD', 'CONSTANTE', 'MECA', 'Source : alimenter_ifs_project_base.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_base', 'earned_value_method', 'STANDARD', 'CONSTANTE', 'Planned', 'Source : alimenter_ifs_project_base.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_base', 'material_allocation', 'STANDARD', 'CONSTANTE', 'Within Project', 'Source : alimenter_ifs_project_base.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_base', 'multi_currency_budgeting', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_ifs_project_base.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_base', 'program_id', 'STANDARD', 'CONSTANTE', 'CAPEX', 'Source : alimenter_ifs_project_base.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_base', 'project_misc_comp_method', 'STANDARD', 'CONSTANTE', 'Manually Planned', 'Source : alimenter_ifs_project_base.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_base', 'work_day_to_hours_conv', 'STANDARD', 'CONSTANTE', '7', 'Source : alimenter_ifs_project_base.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_margin_matrix', 'objversion', 'STANDARD', 'CONSTANTE', '1', 'Source : alimenter_ifs_project_margin_matrix.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_site_ext', 'auto_trans_from_std_inv_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_ifs_project_site_ext.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_site_ext', 'project_site_type_db', 'STANDARD', 'CONSTANTE', 'DEFAULTSITE', 'Source : alimenter_ifs_project_site_ext.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.project_site_ext', 'use_std_inv_in_pmrp_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_ifs_project_site_ext.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'acquisition_origin', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'acquisition_reason_id', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'acquisition_type', 'STANDARD', 'CONSTANTE', 'Purchase', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'acquisition_type_db', 'STANDARD', 'CONSTANTE', 'PURCHASE', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'action_authorized', 'STANDARD', 'CONSTANTE', 'Warning', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'action_authorized_db', 'STANDARD', 'CONSTANTE', 'WARNING', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'action_non_authorized', 'STANDARD', 'CONSTANTE', 'Warning', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'action_non_authorized_db', 'STANDARD', 'CONSTANTE', 'WARNING', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'buyer_code', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'close_code', 'STANDARD', 'CONSTANTE', 'Automatic', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'close_code_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'close_tolerance', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'contract', 'STANDARD', 'CONSTANTE', 'SJ', 'Source : alimenter_purchase_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'date_cre', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'dop_pegged_po_update_flag', 'STANDARD', 'CONSTANTE', 'Planned', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'dop_pegged_po_update_flag_db', 'STANDARD', 'CONSTANTE', 'PLANNED', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'eng_attribute', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'external_resource', 'STANDARD', 'CONSTANTE', 'No', 'Source : alimenter_purchase_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'external_resource_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_purchase_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'inventory_flag', 'STANDARD', 'CONSTANTE', 'Yes', 'Source : alimenter_purchase_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'inventory_flag_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : alimenter_purchase_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'nbs_code', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'note_id', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'note_text', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'objid', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'objversion', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'over_delivery', 'STANDARD', 'CONSTANTE', 'Yes', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'over_delivery_db', 'STANDARD', 'CONSTANTE', 'YES', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'over_delivery_tolerance', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'package_part_flag', 'STANDARD', 'CONSTANTE', 'No', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'package_part_flag_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'process_type', 'STANDARD', 'CONSTANTE', 'STD', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'qc_code', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'qc_date', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'qmr_approval_template', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'qsl_approval_template', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'qsr_approval_template', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'qualified_manufacturer', 'STANDARD', 'CONSTANTE', 'No', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'qualified_manufacturer_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'qualified_supplier', 'STANDARD', 'CONSTANTE', 'No', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'qualified_supplier_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'quality_system_level_id', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'standard_pack_size', 'STANDARD', 'CONSTANTE', '1', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'stat_grp', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'statistical_code', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'statistical_code_manuf', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'std_name_description', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'std_name_id', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'taxable', 'STANDARD', 'CONSTANTE', 'Yes', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'taxable_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.purchase_part', 'technical_coordinator_id', 'STANDARD', 'NULL', NULL, 'Source : alimenter_purchase_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'acquisition_type_db', 'STANDARD', 'CONSTANTE', 'PURCHASE', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'dist_order_receipt_type_db', 'STANDARD', 'CONSTANTE', 'NO AUTOMATIC RECPT', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'ext_svc_primary_vendor_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'external_service_allowed_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'issue_packaging_material_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'leadtime_auto_db', 'STANDARD', 'CONSTANTE', 'N', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'multisite_planned_part_db', 'STANDARD', 'CONSTANTE', 'NOT_MULTISITE_PLAN', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'part_ownership_db', 'STANDARD', 'CONSTANTE', 'COMPANY OWNED', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'primary_vendor_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'purchase_payment_type_db', 'STANDARD', 'CONSTANTE', 'NORMAL', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'qualified_supplier_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'quick_registered_part_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'receive_case_db', 'STANDARD', 'CONSTANTE', 'INVDIR', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'rental_primary_vendor_db', 'STANDARD', 'CONSTANTE', 'N', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'status_code', 'STANDARD', 'CONSTANTE', '2', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.purchase_part_supplier', 'use_price_incl_tax_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_purchase_part_supplier.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'activeind_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'allow_inc_pkg_rsrv_picklst', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'allow_incomp_pkg_delivery', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'catalog_group', 'STANDARD', 'CONSTANTE', '903028', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'catalog_type_db', 'STANDARD', 'CONSTANTE', 'INV', 'Source : alimenter_sales_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'close_tolerance', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'contract', 'STANDARD', 'CONSTANTE', 'SJ', 'Source : alimenter_sales_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'conv_factor', 'STANDARD', 'CONSTANTE', '1', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'cost', 'STANDARD', 'NULL', NULL, 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'country_of_origin', 'STANDARD', 'CONSTANTE', 'FR', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'create_sm_object_option_db', 'STANDARD', 'CONSTANTE', 'DONOTCREATESMOBJECT', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'customs_stat_no', 'STANDARD', 'NULL', NULL, 'Source : alimenter_sales_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'delivery_type', 'STANDARD', 'NULL', NULL, 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'expected_average_price', 'STANDARD', 'NULL', NULL, 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'export_to_external_app_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'inverted_conv_factor', 'STANDARD', 'CONSTANTE', '1', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'list_price', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'list_price_incl_tax', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'minimum_qty', 'STANDARD', 'NULL', NULL, 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'non_inv_part_type_db', 'STANDARD', 'NULL', NULL, 'Source : alimenter_sales_part_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'pack_comp_in_shpmnt', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'price_change_date', 'STANDARD', 'NULL', NULL, 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'price_conv_factor', 'STANDARD', 'CONSTANTE', '1', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'primary_catalog_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'quick_registered_part_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'rental_list_price', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'rental_list_price_incl_tax', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'sales_price_group_id', 'STANDARD', 'CONSTANTE', '*', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'sales_type_db', 'STANDARD', 'CONSTANTE', 'SALES', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'sourcing_option_db', 'STANDARD', 'CONSTANTE', 'NOTSUPPLIED', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'statistical_code', 'STANDARD', 'NULL', NULL, 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'tax_class_id', 'STANDARD', 'NULL', NULL, 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'tax_code', 'STANDARD', 'CONSTANTE', 'C05', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'taxable_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'use_price_incl_tax_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_sales_part_phl.sql (+ modules inventory)', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.sub_project', 'exclude_from_integrations_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_sub_project.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('projet', 'clean_data.sub_project', 'financially_completed_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : alimenter_sub_project.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
