-- Migration 031 : table des valeurs par défaut ETL paramétrables
-- Pattern calqué sur la transcodification. Seed généré depuis
-- sql/supplier/inventaire_colonnes_valeurs_defaut.csv (voir Task 2).

CREATE TABLE IF NOT EXISTS public.etl_default_values (
    id            SERIAL PRIMARY KEY,
    module        VARCHAR(50)  NOT NULL,
    table_cible   VARCHAR(100) NOT NULL,
    colonne       VARCHAR(100) NOT NULL,
    variante      VARCHAR(30)  NOT NULL DEFAULT 'STANDARD',
    type_valeur   VARCHAR(20)  NOT NULL CHECK (type_valeur IN ('CONSTANTE','NULL')),
    valeur        TEXT,
    description   TEXT,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by    VARCHAR(50),
    updated_by    VARCHAR(50),
    CONSTRAINT uq_etl_default_values UNIQUE (table_cible, colonne, variante)
);

CREATE INDEX IF NOT EXISTS idx_edv_module ON public.etl_default_values(module);
CREATE INDEX IF NOT EXISTS idx_edv_table  ON public.etl_default_values(table_cible);

COMMENT ON TABLE public.etl_default_values IS
'Valeurs par défaut paramétrables injectées par les fonctions ETL via public.get_default_value(). Éditées depuis l''écran Configuration > Valeurs par défaut.';

-- Clé logique : constante intégrée dans une expression (03_alimenter_supplier_info_our_id.sql)
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_our_id', 'our_id_prefix', 'STANDARD', 'CONSTANTE', 'TRIMET',
        'Préfixe de OUR_ID (concaténé : <prefixe>-<numero_compte_fournisseur>)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- === SEED GÉNÉRÉ (Task 2) : coller ci-dessous le contenu de seed_supplier.sql ===
-- Seed supplier : 208 lignes générées depuis l'inventaire CSV
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.ifs_fournisseurs', 'address_id', 'STANDARD', 'CONSTANTE', '01', 'Source : 01_alimenter_ifs_fournisseurs.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.ifs_fournisseurs', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : 01_alimenter_ifs_fournisseurs.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'b2b_supplier', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'b2b_supplier_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'business_classification', 'STANDARD', 'NULL', NULL, 'Source : 02_alimenter_supplier_info_general.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'corporate_form', 'STANDARD', 'NULL', NULL, 'Source : 02_alimenter_supplier_info_general.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'default_domain', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'default_language', 'STANDARD', 'CONSTANTE', 'FR', 'Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'default_language_db', 'STANDARD', 'CONSTANTE', 'FR', 'Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'identifier_ref_validation_db', 'STANDARD', 'CONSTANTE', 'NONE', 'Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'one_time', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'one_time_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'party', 'STANDARD', 'NULL', NULL, 'Source : 02_alimenter_supplier_info_general.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'party_type', 'STANDARD', 'CONSTANTE', 'Supplier', 'Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'party_type_db', 'STANDARD', 'CONSTANTE', 'SUPPLIER', 'Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'picture_id', 'STANDARD', 'NULL', NULL, 'Source : 02_alimenter_supplier_info_general.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'supplier_category', 'STANDARD', 'CONSTANTE', 'Supplier', 'Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_general', 'supplier_category_db', 'STANDARD', 'CONSTANTE', 'SUPPLIER', 'Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address', 'address_id', 'STANDARD', 'CONSTANTE', '01', 'Source : 04_alimenter_supplier_info_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address', 'comm_id', 'STANDARD', 'NULL', NULL, 'Source : 04_alimenter_supplier_info_address.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address', 'default_domain', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : 04_alimenter_supplier_info_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address', 'output_media', 'STANDARD', 'CONSTANTE', '1', 'Source : 04_alimenter_supplier_info_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address', 'output_media_db', 'STANDARD', 'CONSTANTE', '1', 'Source : 04_alimenter_supplier_info_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address', 'party_type', 'STANDARD', 'CONSTANTE', 'Supplier', 'Source : 04_alimenter_supplier_info_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address', 'party_type_db', 'STANDARD', 'CONSTANTE', 'SUPPLIER', 'Source : 04_alimenter_supplier_info_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'address_type_code', 'DELIVERY', 'CONSTANTE', 'Delivery', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'address_type_code_db', 'DELIVERY', 'CONSTANTE', 'DELIVERY', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'def_address', 'DELIVERY', 'CONSTANTE', 'TRUE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'default_domain', 'DELIVERY', 'CONSTANTE', 'TRUE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'invoice', 'DELIVERY', 'CONSTANTE', 'FALSE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'party', 'DELIVERY', 'CONSTANTE', '', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'pay', 'DELIVERY', 'CONSTANTE', 'FALSE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'visit', 'DELIVERY', 'CONSTANTE', 'FALSE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'address_type_code', 'INVOICE', 'CONSTANTE', 'Document', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'address_type_code_db', 'INVOICE', 'CONSTANTE', 'INVOICE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'def_address', 'INVOICE', 'CONSTANTE', 'TRUE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'default_domain', 'INVOICE', 'CONSTANTE', 'TRUE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'invoice', 'INVOICE', 'CONSTANTE', 'TRUE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'party', 'INVOICE', 'CONSTANTE', 'FALSE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'pay', 'INVOICE', 'CONSTANTE', 'FALSE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'visit', 'INVOICE', 'CONSTANTE', 'FALSE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'address_type_code', 'PAY', 'CONSTANTE', 'Pay', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'address_type_code_db', 'PAY', 'CONSTANTE', 'PAY', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'def_address', 'PAY', 'CONSTANTE', 'TRUE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'default_domain', 'PAY', 'CONSTANTE', 'TRUE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'invoice', 'PAY', 'CONSTANTE', 'FALSE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'party', 'PAY', 'CONSTANTE', 'FALSE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'pay', 'PAY', 'CONSTANTE', 'TRUE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'visit', 'PAY', 'CONSTANTE', 'FALSE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'address_type_code', 'VISIT', 'CONSTANTE', 'Visit', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'address_type_code_db', 'VISIT', 'CONSTANTE', 'VISIT', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'def_address', 'VISIT', 'CONSTANTE', 'TRUE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'default_domain', 'VISIT', 'CONSTANTE', 'TRUE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'invoice', 'VISIT', 'CONSTANTE', 'FALSE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'party', 'VISIT', 'CONSTANTE', 'FALSE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'pay', 'VISIT', 'CONSTANTE', 'FALSE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_address_type', 'visit', 'VISIT', 'CONSTANTE', 'TRUE', 'Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'method_id', 'E_MAIL', 'CONSTANTE', 'E-Mail', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'method_id_db', 'E_MAIL', 'CONSTANTE', 'E_MAIL', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'party_type', 'E_MAIL', 'CONSTANTE', 'Supplier', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'party_type_db', 'E_MAIL', 'CONSTANTE', 'SUPPLIER', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'valid_to', 'E_MAIL', 'CONSTANTE', '2099-12-31', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'address_default', 'FAX', 'CONSTANTE', 'FALSE', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'method_id', 'FAX', 'CONSTANTE', 'Fax', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'method_id_db', 'FAX', 'CONSTANTE', 'FAX', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'party_type', 'FAX', 'CONSTANTE', 'Supplier', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'party_type_db', 'FAX', 'CONSTANTE', 'SUPPLIER', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'valid_to', 'FAX', 'CONSTANTE', '2099-12-31', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'address_default', 'PHONE', 'CONSTANTE', 'FALSE', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'method_id', 'PHONE', 'CONSTANTE', 'Phone', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'method_id_db', 'PHONE', 'CONSTANTE', 'PHONE', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'party_type', 'PHONE', 'CONSTANTE', 'Supplier', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'party_type_db', 'PHONE', 'CONSTANTE', 'SUPPLIER', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.comm_method', 'valid_to', 'PHONE', 'CONSTANTE', '2099-12-31', 'Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_address', 'delivery_terms', 'STANDARD', 'NULL', NULL, 'Source : 07_alimenter_supplier_address.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_address', 'route_id', 'STANDARD', 'NULL', NULL, 'Source : 07_alimenter_supplier_address.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_address', 'ship_via_code', 'STANDARD', 'NULL', NULL, 'Source : 07_alimenter_supplier_address.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_document_tax_info', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Source : 08_insert_supplier_document_tax_info.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_document_tax_info', 'company_addr_tax_id_type', 'STANDARD', 'CONSTANTE', '', 'Source : 08_insert_supplier_document_tax_info.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_document_tax_info', 'company_addr_tax_id_type_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 08_insert_supplier_document_tax_info.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_document_tax_info', 'reliability_status_db', 'STANDARD', 'CONSTANTE', 'NOT_SET', 'Source : 08_insert_supplier_document_tax_info.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_document_tax_info', 'tax_office_id', 'STANDARD', 'CONSTANTE', '', 'Source : 08_insert_supplier_document_tax_info.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'additional_cost_amount', 'STANDARD', 'CONSTANTE', '0', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'adhoc_pur_rqst_approval_db', 'STANDARD', 'CONSTANTE', 'MANUALLY', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'b2b_conf_order_with_diff_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'blanket_date_db', 'STANDARD', 'CONSTANTE', 'ORDERDATE', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'buyer_code', 'STANDARD', 'CONSTANTE', '*', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'category_db', 'STANDARD', 'CONSTANTE', 'E', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'coc_approval_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'cr_check_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'create_confirmation_chg_ord_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'delivery_rem_interval', 'STANDARD', 'CONSTANTE', '3', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'delivery_reminder_db', 'STANDARD', 'CONSTANTE', 'DELIVREM', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'dir_del_approval_db', 'STANDARD', 'CONSTANTE', 'AUTOMATICALLY', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'discount', 'STANDARD', 'CONSTANTE', '0', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'email_purchase_order_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'environmental_approval_db', 'STANDARD', 'CONSTANTE', 'APPROVED', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'express_order_allowed_db', 'STANDARD', 'CONSTANTE', '1', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'ord_conf_rem_interval', 'STANDARD', 'CONSTANTE', '7', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'ord_conf_reminder_db', 'STANDARD', 'CONSTANTE', 'CONFREM', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'order_conf_approval_db', 'STANDARD', 'CONSTANTE', 'AUTOMATICALLY', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'order_conf_diff_approval_db', 'STANDARD', 'CONSTANTE', 'MANUALLY', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'pack_list_flag_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'po_change_management_db', 'STANDARD', 'CONSTANTE', 'USE_SITE_DEFAULT', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'pricat_automatic_approval_db', 'STANDARD', 'CONSTANTE', 'NOT_APPLICABLE', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'print_amounts_incl_tax_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'purch_order_flag_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'qc_approval_db', 'STANDARD', 'CONSTANTE', 'Y', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'quick_registered_supplier_db', 'STANDARD', 'CONSTANTE', 'ORDINARY', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'rec_adv_sb_consignment_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'rec_adv_sb_mix_ownership_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'rec_adv_self_billing_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'receipt_ref_reminder_db', 'STANDARD', 'CONSTANTE', 'NO_RCPT_REMINDER', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'receiving_advice_type_db', 'STANDARD', 'CONSTANTE', 'USE_CUSTOMER_DEFAULT', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'supp_grp', 'STANDARD', 'CONSTANTE', 'DEFAULT', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'supplier_group', 'STANDARD', 'CONSTANTE', 'EXTERNAL', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'template_supplier_db', 'STANDARD', 'CONSTANTE', 'NOTEMPLATE', 'Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'allow_quantity_diff', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'allow_tolerance', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'automatic_invoice', 'STANDARD', 'CONSTANTE', 'N', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'create_tolerance_posting', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'digital_invoice', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'exc_from_spesometro_dec', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'exclude_invoice_image', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'exclude_posting_auth', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'identity_type', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'inc_inv_curr_rate_base', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'invoice_fee', 'STANDARD', 'NULL', NULL, 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'invoice_recipient_from', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'legal_identity', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'matching_level', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'ncf_reference_check', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'party_type', 'STANDARD', 'CONSTANTE', 'Supplier', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'party_type_db', 'STANDARD', 'CONSTANTE', 'SUPPLIER', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'po_ref_rec_ref_val_method', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'print_tax_code_text', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'report_and_withhold', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'second_tin', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'service_code_required', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'tax_buy_curr_rate_base', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'tax_certificate_form', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'tax_exempt', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'utility_bill_provider', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'voting_share_percentage', 'STANDARD', 'CONSTANTE', '', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'withholding_base_amount', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'ar_contact', 'STANDARD', 'NULL', NULL, 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'business_category', 'STANDARD', 'CONSTANTE', 'SUPPLIER', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'check_recipient', 'STANDARD', 'CONSTANTE', 'Payee', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'check_recipient_db', 'STANDARD', 'CONSTANTE', 'PAYEE', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'comm_id', 'STANDARD', 'CONSTANTE', '0', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'corporation_id', 'STANDARD', 'NULL', NULL, 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'customer_id', 'STANDARD', 'NULL', NULL, 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'deduction_group', 'STANDARD', 'NULL', NULL, 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'default_payment_method', 'STANDARD', 'CONSTANTE', 'BANK', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'disc_days_tolerance', 'STANDARD', 'CONSTANTE', '3', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'format_no', 'STANDARD', 'CONSTANTE', '1', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'interest_template', 'STANDARD', 'CONSTANTE', '1', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'is_one_inv_per_pay', 'STANDARD', 'CONSTANTE', 'False', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'is_one_inv_per_pay_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'member_id', 'STANDARD', 'NULL', NULL, 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'netting_allowed', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'next_payment_matching_id', 'STANDARD', 'CONSTANTE', '0', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'other_payee_identity', 'STANDARD', 'NULL', NULL, 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'output_media', 'STANDARD', 'CONSTANTE', 'Printout', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'output_media_db', 'STANDARD', 'CONSTANTE', '1', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'party_type', 'STANDARD', 'CONSTANTE', 'Supplier', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'party_type_db', 'STANDARD', 'CONSTANTE', 'SUPPLIER', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'payment_advice', 'STANDARD', 'CONSTANTE', 'No Advice', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'payment_advice_db', 'STANDARD', 'CONSTANTE', '1', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'payment_mode', 'STANDARD', 'CONSTANTE', 'Bank Transfer, Digital Wallet', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'payment_mode_db', 'STANDARD', 'CONSTANTE', '18', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'payment_receipt_type', 'STANDARD', 'CONSTANTE', 'No Receipt', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'payment_receipt_type_db', 'STANDARD', 'CONSTANTE', 'NO_RECEIPT', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'percent_tolerance', 'STANDARD', 'CONSTANTE', '5', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'predicted_payment_delay', 'STANDARD', 'CONSTANTE', 'False', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'predicted_payment_delay_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'priority', 'STANDARD', 'CONSTANTE', '1', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'reminder_template', 'STANDARD', 'CONSTANTE', 'DEFAULT', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'rule_id', 'STANDARD', 'NULL', NULL, 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'send_interest_inv_to_payer', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'send_reminder_to_payer', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'send_stmt_of_acc_to_payer', 'STANDARD', 'CONSTANTE', 'FALSE', 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'template_id', 'STANDARD', 'NULL', NULL, 'Source : 11_sp_insert_identity_pay_info_from_sap.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_way_per_identity', 'default_payment_way', 'STANDARD', 'CONSTANTE', 'TRUE', 'Source : 12_fn_upsert_payment_way_per_identity.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_way_per_identity', 'party_type', 'STANDARD', 'CONSTANTE', 'Supplier', 'Source : 12_fn_upsert_payment_way_per_identity.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_way_per_identity', 'party_type_db', 'STANDARD', 'CONSTANTE', 'SUPPLIER', 'Source : 12_fn_upsert_payment_way_per_identity.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_way_per_identity', 'way_id', 'STANDARD', 'CONSTANTE', '1', 'Source : 12_fn_upsert_payment_way_per_identity.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'account', 'ADRESSE_DEFAUT', 'NULL', NULL, 'Source : 14_fn_upsert_payment_address.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'bank_account_validated', 'ADRESSE_DEFAUT', 'CONSTANTE', 'Not Validated', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'bank_account_validated_db', 'ADRESSE_DEFAUT', 'CONSTANTE', 'FALSE', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'bic_code', 'ADRESSE_DEFAUT', 'NULL', NULL, 'Source : 14_fn_upsert_payment_address.sql (type NULL_EXPLICITE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'blocked_for_use', 'ADRESSE_DEFAUT', 'CONSTANTE', 'FALSE', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'company', 'ADRESSE_DEFAUT', 'CONSTANTE', 'TRIMET', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'default_address', 'ADRESSE_DEFAUT', 'CONSTANTE', 'TRUE', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'description', 'ADRESSE_DEFAUT', 'CONSTANTE', 'Adresse de paiement par défaut', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'mapping_type', 'ADRESSE_DEFAUT', 'CONSTANTE', 'DEFAULT', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'party_type', 'ADRESSE_DEFAUT', 'CONSTANTE', 'Supplier', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'party_type_db', 'ADRESSE_DEFAUT', 'CONSTANTE', 'SUPPLIER', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'way_id', 'ADRESSE_DEFAUT', 'CONSTANTE', 'SEPA', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'bank_account_validated', 'BANQUE', 'CONSTANTE', 'Not Validated', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'bank_account_validated_db', 'BANQUE', 'CONSTANTE', 'FALSE', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'blocked_for_use', 'BANQUE', 'CONSTANTE', 'FALSE', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'mapping_type', 'BANQUE', 'CONSTANTE', 'BANK_TRANSFER', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'party_type', 'BANQUE', 'CONSTANTE', 'Supplier', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'party_type_db', 'BANQUE', 'CONSTANTE', 'SUPPLIER', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'way_id', 'BANQUE', 'CONSTANTE', 'SEPA', 'Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_tax_info', 'use_supp_address_for_tax', 'STANDARD', 'CONSTANTE', 'True', 'Source : 15_fn_upsert_supplier_tax_info.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_tax_info', 'use_supp_address_for_tax_db', 'STANDARD', 'CONSTANTE', 'True', 'Source : 15_fn_upsert_supplier_tax_info.sql (type CONSTANTE_FORCEE)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
