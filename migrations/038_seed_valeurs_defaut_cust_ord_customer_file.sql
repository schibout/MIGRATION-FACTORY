-- Migration 038 : seed des valeurs par defaut de clean_data.cust_ord_customer
--                 (module customerFile)
--
-- POURQUOI : sp_insert_cust_ord_customer_from_file_customer.sql projetait ses ~100
-- constantes IFS en POSITIONNEL, avec le nom de colonne en commentaire au lieu d'un
-- alias SQL. L'inventaire automatique (sql/config/extract_default_values.py) ne voit
-- que les projections aliasees : ces constantes etaient donc invisibles de l'ecran
-- /configuration/valeurs-defaut et restaient codees en dur. Les alias ont ete ajoutes,
-- la procedure passe maintenant par public.get_default_value().
--
-- 17 cles etaient deja seedees a l'identique par la migration 032 (module customer) :
-- elles ne sont pas re-inserees. Une seule valeur DIVERGE entre les deux pipelines et
-- recoit donc une variante :
--   clean_data.cust_ord_customer.discount_type -> 'Standard' (STANDARD, module customer)
--                                              -> 'G'        (variante CUSTOMERFILE)
--
-- Valeurs identiques aux litteraux precedemment codes en dur : chargement inchange.

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'adv_inv_full_pay', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'adv_inv_full_pay_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'allow_auto_sub_of_parts', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'allow_auto_sub_of_parts_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'auto_despatch_adv_send', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'b2b_auto_create_co_from_sq', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'b2b_auto_create_co_from_sq_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'backorder_option', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'backorder_option_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'check_sales_grp_deliv_conf', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'check_sales_grp_deliv_conf_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'confirm_deliveries', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'confirm_deliveries_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'confirm_direct_deliveries', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'consol_rental_ivc_serial', 'STANDARD', 'CONSTANTE', 'SPECIFIED ON COMPANY', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'consol_rental_ivc_serial_db', 'STANDARD', 'CONSTANTE', 'SPECIFIED ON COMPANY', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'credit_control_group_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'cust_grp', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'cust_price_group_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'default_inv_currency', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'discount_type', 'CUSTOMERFILE', 'CONSTANTE', 'G', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'edi_authorize_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'edi_auto_approval_user', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'edi_auto_change_approval', 'STANDARD', 'CONSTANTE', 'MANUALLY', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'edi_auto_change_approval_db', 'STANDARD', 'CONSTANTE', 'MANUALLY', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'edi_auto_order_approval', 'STANDARD', 'CONSTANTE', 'MANUALLY', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'edi_auto_order_approval_db', 'STANDARD', 'CONSTANTE', 'MANUALLY', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'edi_site', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'email_invoice', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'email_invoice_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'email_order_conf', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'email_order_conf_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'exclude_from_scan_order', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'handl_unit_at_co_delivery', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'handl_unit_at_co_delivery_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'market_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'match_type', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'match_type_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'min_sales_amount', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'mul_tier_del_notification', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'mul_tier_del_notification_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'no_delnote_copies', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'note_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'print_amounts_incl_tax', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'print_amounts_incl_tax_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'print_control_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'print_delivered_lines', 'STANDARD', 'CONSTANTE', 'SHIPMENT', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'print_delivered_lines_db', 'STANDARD', 'CONSTANTE', 'SHIPMENT', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'print_withholding_tax', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'print_withholding_tax_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'priority', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'quick_registered_customer', 'STANDARD', 'CONSTANTE', 'NORMAL', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'quick_registered_customer_db', 'STANDARD', 'CONSTANTE', 'NORMAL', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'rec_adv_auto_approval_user', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'rec_adv_auto_match_diff', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'rec_adv_auto_match_diff_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'rec_adv_auto_matching', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'rec_adv_auto_matching_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'rec_adv_matching_option', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'rec_adv_matching_option_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'receive_pack_size_chg', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'receive_pack_size_chg_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'receiving_advice_type', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'receiving_advice_type_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'release_internal_order', 'STANDARD', 'CONSTANTE', 'MANUALLY', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'release_internal_order_db', 'STANDARD', 'CONSTANTE', 'MANUALLY', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'replicate_doc_text', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'replicate_doc_text_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'salesman_code', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'sbi_auto_approval_user', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'self_billing_match_option', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'self_billing_match_option_db', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'send_change_message', 'STANDARD', 'CONSTANTE', 'N', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'send_change_message_db', 'STANDARD', 'CONSTANTE', 'N', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'summarized_freight_charges', 'STANDARD', 'CONSTANTE', 'Y', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'summarized_freight_charges_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'summarized_source_lines', 'STANDARD', 'CONSTANTE', 'Y', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'summarized_source_lines_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'template_customer', 'STANDARD', 'CONSTANTE', 'NOT_TEMPLATE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'template_customer_db', 'STANDARD', 'CONSTANTE', 'NOT_TEMPLATE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'template_customer_desc', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'template_id', 'STANDARD', 'NULL', NULL, 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type NULL_EXPLICITE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'update_price_from_sbi', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customerFile', 'clean_data.cust_ord_customer', 'update_price_from_sbi_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cust_ord_customer_from_file_customer.sql (type CONSTANTE_FORCEE)', 'migration_038')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
