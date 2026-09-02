-- ============================================================================
-- 045 : valeurs par defaut de clean_data.supplier_addr_tax_number
-- ----------------------------------------------------------------------------
-- Alimente par clean_data.sp_insert_supplier_addr_tax_number()
-- (sql/supplier/16_sp_insert_supplier_addr_tax_number.sql), qui produit une
-- ligne par type de numero fiscal : TVA intracommunautaire, SIREN, SIRET.
--
-- Une VARIANTE par type, comme comm_method le fait pour PHONE / FAX / E_MAIL :
-- les 3 libelles restent modifiables depuis l'ecran sans toucher au code.
--
-- Depuis la migration 044, get_default_value n'a plus de repli : sans ces
-- lignes la procedure ecrirait NULL dans tax_id_type et company.
--
-- default_tax_id_number_db : un seul numero peut etre le defaut cote IFS.
-- La TVA intracommunautaire est retenue ; SIREN et SIRET sont a FALSE.
-- ============================================================================

-- --- company ---------------------------------------------------------------
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_addr_tax_number', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET',
        'Code societe', 'migration_045')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- --- tax_id_type : un libelle par type de numero ---------------------------
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_addr_tax_number', 'tax_id_type', 'TVA_UE', 'CONSTANTE', 'TVA UE',
        'Type du numero de TVA intracommunautaire (source : ifs_fournisseurs.tva)', 'migration_045')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_addr_tax_number', 'tax_id_type', 'SIREN', 'CONSTANTE', 'SIREN',
        'Type du numero SIREN (source : ifs_fournisseurs.numero_siren)', 'migration_045')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_addr_tax_number', 'tax_id_type', 'SIRET', 'CONSTANTE', 'SIRET',
        'Type du numero SIRET (source : ifs_fournisseurs.siret)', 'migration_045')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- --- default_tax_id_number_db : la TVA UE est le numero par defaut ----------
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_addr_tax_number', 'default_tax_id_number_db', 'TVA_UE', 'CONSTANTE', 'TRUE',
        'La TVA intracommunautaire est le numero fiscal par defaut du fournisseur', 'migration_045')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_addr_tax_number', 'default_tax_id_number_db', 'SIREN', 'CONSTANTE', 'FALSE',
        'Le SIREN n''est pas le numero fiscal par defaut', 'migration_045')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_addr_tax_number', 'default_tax_id_number_db', 'SIRET', 'CONSTANTE', 'FALSE',
        'Le SIRET n''est pas le numero fiscal par defaut', 'migration_045')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
