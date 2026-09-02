-- ============================================================================
-- 043 : valeurs par defaut de la devise fournisseur
-- ----------------------------------------------------------------------------
-- clean_data.ifs_fournisseurs.devise_principale a ete supprimee (colonne KPI
-- jamais alimentee : le bloc de calcul est commente dans le script
-- 01_alimenter_ifs_fournisseurs.sql). Les scripts 09 et 10 la lisaient via
-- COALESCE(f.devise_principale, 'EUR') -> erreur "column f.devise_principale
-- does not exist" au chargement.
--
-- Les deux appels passent desormais par public.get_default_value() ; ce seed
-- fournit les lignes correspondantes avec le repli identique a l'ancienne
-- valeur codee en dur ('EUR') -> comportement inchange.
-- ============================================================================

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier', 'currency_code', 'STANDARD', 'CONSTANTE', 'EUR',
        'Devise du fournisseur. Source : 09_sp_insert_supplier_from_sap.sql (remplace COALESCE(f.devise_principale, ''EUR''))', 'migration_043')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.identity_invoice_info', 'def_currency', 'STANDARD', 'CONSTANTE', 'EUR',
        'Devise par defaut de facturation. Source : 10_sp_insert_identity_invoice_info_from_sap.sql (remplace COALESCE(f.devise_principale, ''EUR''))', 'migration_043')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
