-- ============================================================================
-- 047 : valeurs par defaut du module supplier encore codees en dur
-- ----------------------------------------------------------------------------
-- Controle du 2026-09-02 sur sql/supplier/ :
--   * 217 appels distincts a public.get_default_value() -> TOUS ont deja leur
--     ligne dans public.etl_default_values (aucun appel orphelin, aucun risque
--     de NULL silencieux depuis la migration 044).
--   * les projections litterales `'X' as colonne` restantes sont hors perimetre
--     (colonnes d'audit, compteurs de statistiques, `1 as bank_seq`).
--   * SEUL RESTE : 10 repli de COALESCE(<source SAP>, <litteral>) — invisibles
--     pour l'inventaire automatique (extract_default_values.py ignore les
--     expressions derivees) et donc jamais parametres.
--
-- Cette migration seede ces 10 valeurs. ELLE NE CHANGE RIEN A ELLE SEULE :
-- les scripts ETL doivent etre modifies pour remplacer le litteral par
-- l'appel a get_default_value (liste en bas de fichier), puis recompiles.
--
-- Rappel de typage : get_default_value retourne TEXT, aucun cast implicite
-- vers numeric -> les 4 colonnes numeriques exigent `::numeric` cote script.
--
-- NON SEEDE ICI (deja present) :
--   clean_data.payment_way_per_identity.company / STANDARD -> 'TRIMET'
--   (ligne module 'customer', valeur identique : le script 12 du module
--   supplier peut la lire telle quelle, sans variante).
-- ============================================================================

-- --- clean_data.supplier (script 09) ---------------------------------------
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'days_before_delivery', 'STANDARD', 'CONSTANTE', '30',
        'Delai de livraison en jours quand lfm1.plifz est absent (numerique)', 'migration_047')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'days_before_arrival', 'STANDARD', 'CONSTANTE', '30',
        'Delai avant arrivee en jours quand lfm1.plifz est absent (numerique)', 'migration_047')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- --- clean_data.identity_invoice_info (script 10) ---------------------------
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET',
        'Code societe quand ifs_fournisseurs.company est NULL', 'migration_047')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- --- clean_data.identity_pay_info (script 11) -------------------------------
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET',
        'Code societe quand ifs_fournisseurs.company est NULL', 'migration_047')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'payment_delay', 'STANDARD', 'CONSTANTE', '30',
        'Delai de paiement en jours quand lfm1.plifz est absent (numerique)', 'migration_047')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_pay_info', 'amount_tolerance', 'STANDARD', 'CONSTANTE', '100',
        'Tolerance de montant quand lfm1.minbw est absent (numerique)', 'migration_047')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- --- clean_data.supplier_delivery_tax_code (script 13) ----------------------
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_delivery_tax_code', 'address_id', 'STANDARD', 'CONSTANTE', 'DEFAULT_ADDR',
        'Identifiant d''adresse quand le fournisseur n''a aucune supplier_info_address', 'migration_047')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_delivery_tax_code', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET',
        'Code societe quand ifs_fournisseurs.company est NULL', 'migration_047')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- --- clean_data.payment_address, variante BANQUE (script 14, etape 2) -------
-- La variante ADRESSE_DEFAUT a deja sa ligne company ; l'etape bancaire, elle,
-- portait encore le litteral.
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.payment_address', 'company', 'BANQUE', 'CONSTANTE', 'TRIMET',
        'Code societe des adresses de paiement bancaires (lfbk)', 'migration_047')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- --- clean_data.supplier_tax_info (script 15) -------------------------------
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_tax_info', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET',
        'Code societe quand ifs_fournisseurs.company est NULL', 'migration_047')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- ============================================================================
-- MODIFICATIONS DES SCRIPTS ETL A APPLIQUER ENSUITE (puis recompiler) :
--
-- sql/supplier/09_sp_insert_supplier_from_sap.sql:81-82
--   COALESCE(m.plifz::numeric, 30) as days_before_delivery
--   -> COALESCE(m.plifz::numeric, public.get_default_value('clean_data.supplier','days_before_delivery')::numeric)
--   idem days_before_arrival
--
-- sql/supplier/10_...:24, 11_...:65, 12_...:33, 13_...:33, 14_...:119, 15_...:39
--   COALESCE(f.company, 'TRIMET')
--   -> COALESCE(f.company, public.get_default_value('<table cible>','company'[, '<variante>']))
--   (script 12 : table 'clean_data.payment_way_per_identity', ligne existante ;
--    script 14 : variante 'BANQUE')
--
-- sql/supplier/11_...:77-78
--   COALESCE(m.plifz::numeric, 30)  -> ...'payment_delay')::numeric
--   COALESCE(m.minbw::numeric, 100) -> ...'amount_tolerance')::numeric
--
-- sql/supplier/13_...:32
--   COALESCE(sia.address_id, 'DEFAULT_ADDR')
--   -> COALESCE(sia.address_id, public.get_default_value('clean_data.supplier_delivery_tax_code','address_id'))
-- ============================================================================

-- ROLLBACK :
-- DELETE FROM public.etl_default_values WHERE created_by = 'migration_047';
