-- Migration 037 : seed des dernieres valeurs par defaut ETL codees en dur
--
-- Il s'agit des lignes marquees A_ARBITRER dans les inventaires : meme colonne, valeurs
-- DIFFERENTES selon le bloc du script. Elles exigeaient de nommer une variante par bloc,
-- ce que l'outil automatique ne fait pas. C'est desormais fait :
--
--   clean_data.cus_comm_method : une variante par moyen de communication
--     PHONE_PRINCIPAL / PHONE_SECONDAIRE / PHONE_ADRESSE / FAX / FAX_ADRESSE /
--     EMAIL_PRINCIPAL / TELEX / TELETEX
--     -> partagees par les pipelines customer (8 blocs) et customerFile (6 blocs),
--        dont les valeurs sont identiques bloc a bloc.
--
--   clean_data.inventory_part : ARTICLEPHL (flux PHL normal) vs SILICIUM (article
--     generique achete cree par clean_data.ajouter_article_silicium()).
--
-- Valeurs identiques aux litteraux precedemment codes en dur : chargement inchange.

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'address_default', 'EMAIL_PRINCIPAL', 'CONSTANTE', 'TRUE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'address_default', 'FAX', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'address_default', 'FAX_ADRESSE', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'address_default', 'PHONE_ADRESSE', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'address_default', 'PHONE_PRINCIPAL', 'CONSTANTE', 'TRUE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'address_default', 'PHONE_SECONDAIRE', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'address_default', 'TELETEX', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'address_default', 'TELEX', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'description', 'EMAIL_PRINCIPAL', 'CONSTANTE', 'Email principal', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'description', 'FAX', 'CONSTANTE', 'Fax', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'description', 'FAX_ADRESSE', 'CONSTANTE', 'Fax (adresse)', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'description', 'PHONE_ADRESSE', 'CONSTANTE', 'Téléphone (adresse)', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'description', 'PHONE_PRINCIPAL', 'CONSTANTE', 'Téléphone principal', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'description', 'PHONE_SECONDAIRE', 'CONSTANTE', 'Téléphone secondaire', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'description', 'TELETEX', 'CONSTANTE', 'Teletex', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'description', 'TELEX', 'CONSTANTE', 'Telex', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_default', 'EMAIL_PRINCIPAL', 'CONSTANTE', 'TRUE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_default', 'FAX', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_default', 'FAX_ADRESSE', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_default', 'PHONE_ADRESSE', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_default', 'PHONE_PRINCIPAL', 'CONSTANTE', 'TRUE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_default', 'PHONE_SECONDAIRE', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_default', 'TELETEX', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_default', 'TELEX', 'CONSTANTE', 'FALSE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id', 'EMAIL_PRINCIPAL', 'CONSTANTE', 'E-Mail', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id', 'FAX', 'CONSTANTE', 'Fax', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id', 'FAX_ADRESSE', 'CONSTANTE', 'Fax', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id', 'PHONE_ADRESSE', 'CONSTANTE', 'Phone', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id', 'PHONE_PRINCIPAL', 'CONSTANTE', 'Phone', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id', 'PHONE_SECONDAIRE', 'CONSTANTE', 'Phone', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id', 'TELETEX', 'CONSTANTE', 'Teletex', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id', 'TELEX', 'CONSTANTE', 'Telex', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id_db', 'EMAIL_PRINCIPAL', 'CONSTANTE', 'E_MAIL', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id_db', 'FAX', 'CONSTANTE', 'FAX', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id_db', 'FAX_ADRESSE', 'CONSTANTE', 'FAX', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id_db', 'PHONE_ADRESSE', 'CONSTANTE', 'PHONE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id_db', 'PHONE_PRINCIPAL', 'CONSTANTE', 'PHONE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id_db', 'PHONE_SECONDAIRE', 'CONSTANTE', 'PHONE', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id_db', 'TELETEX', 'CONSTANTE', 'TELETEX', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('customer', 'clean_data.cus_comm_method', 'method_id_db', 'TELEX', 'CONSTANTE', 'TELEX', 'Source : sp_insert_cus_comm_method_from_sap.sql / _from_file_customer.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'type_code_db', 'ARTICLEPHL', 'CONSTANTE', '1', 'Source : alimenter_inventory_part_phl.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'lead_time_code_db', 'ARTICLEPHL', 'CONSTANTE', 'Y', 'Source : alimenter_inventory_part_phl.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'zero_cost_flag_db', 'ARTICLEPHL', 'CONSTANTE', 'Y', 'Source : alimenter_inventory_part_phl.sql', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'type_code_db', 'SILICIUM', 'CONSTANTE', '3', 'Source : ajouter_article_silicium.sql (article achete)', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'lead_time_code_db', 'SILICIUM', 'CONSTANTE', 'P', 'Source : ajouter_article_silicium.sql (article achete)', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'zero_cost_flag_db', 'SILICIUM', 'CONSTANTE', 'N', 'Source : ajouter_article_silicium.sql (article achete)', 'migration_037')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
