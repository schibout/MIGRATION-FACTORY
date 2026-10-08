-- Migration 104 : valeurs par defaut et transcodifications de la reprise
-- des commandes d'achat IFS (Lot 11, clean_data.purchase_order*).
--
-- 1. public.etl_default_values (module commandeAchat) : constantes lues par
--    clean_data.alimenter_purchase_order() via public.get_default_value().
--    Source : spec Lot11_AchatAppro_CommandeAchat_V4.1 (colonne « Mapping en
--    dur ») et, a defaut, valeur unique du fichier modele Lot11_*_V2.csv.
--    Lignes particulieres :
--      - purchase_order.order_date = DATE DE BASCULE (AAAA-MM-JJ) : ORDER_DATE
--        de toutes les commandes et point de depart de la fenetre d'eligibilite ;
--      - purchase_order.mois_anteriorite = largeur de cette fenetre (mois) ;
--      - purchase_order.address1..city, variante = site (SJ / CS) : adresse de
--        livraison = adresse du site de la commande (regle ADDR_STATE de la spec) ;
--      - purchase_order.addr_no / doc_addr_no / delivery_terms / ship_via_code :
--        REPLIS, la valeur vient d'abord de la fiche fournisseur IFS (clean_data).
-- 2. public."TranscodificationTable" :
--      - PAY_TERM    : condition de paiement SAP -> IFS ;
--      - COST_CENTER : ancien centre de couts SAP -> centre de couts IFS.
--    DEDUITES du fichier modele V2 (rapprochement avec commande_achat_ifs le
--    2026-10-08) faute de l'onglet '16_Conditions Paiements' / 'Mapping Final
--    anciens CC' : A VALIDER par le metier dans l'ecran Transcodification.
--    PAY_TERM ne reprend que les codes a correspondance unique : F045, M015 et
--    M100 donnent plusieurs codes IFS selon le fournisseur (repli fiche
--    fournisseur IFS).
-- A jouer AVANT sql/commandeAchat/compile.sh. Rejouable (ON CONFLICT DO NOTHING).

BEGIN;


-- clean_data.purchase_order
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'addr_no', 'STANDARD', 'CONSTANTE', '1', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'authorize_code', 'STANDARD', 'CONSTANTE', '*', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'buyer_code', 'STANDARD', 'CONSTANTE', '*', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'delivery_address', 'STANDARD', 'CONSTANTE', '1', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'delivery_terms', 'STANDARD', 'CONSTANTE', 'DDP', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'language_code', 'STANDARD', 'CONSTANTE', 'fr', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'ship_via_code', 'STANDARD', 'CONSTANTE', '10', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'order_code', 'STANDARD', 'CONSTANTE', '1', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'order_date', 'STANDARD', 'CONSTANTE', '2026-09-01', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'pick_list_flag', 'STANDARD', 'CONSTANTE', 'No Pick List Printed', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'pick_list_flag_db', 'STANDARD', 'CONSTANTE', 'N', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'communicated', 'STANDARD', 'CONSTANTE', 'True', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'communicated_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'revision', 'STANDARD', 'CONSTANTE', '1', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'country_code', 'STANDARD', 'CONSTANTE', 'FR', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'blanket_date', 'STANDARD', 'CONSTANTE', 'Order Date', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'blanket_date_db', 'STANDARD', 'CONSTANTE', 'ORDERDATE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'schedule_agreement_order', 'STANDARD', 'CONSTANTE', 'Not Scheduling Order', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'schedule_agreement_order_db', 'STANDARD', 'CONSTANTE', 'NOT SCHEDULE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'addr_flag', 'STANDARD', 'CONSTANTE', 'Yes', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'addr_flag_db', 'STANDARD', 'CONSTANTE', 'Y', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'central_order_flag', 'STANDARD', 'CONSTANTE', 'Not Central Order', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'central_order_flag_db', 'STANDARD', 'CONSTANTE', 'NOT CENTRAL ORDER', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'centralized_order_site', 'STANDARD', 'CONSTANTE', 'Purchasing Site', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'centralized_order_site_db', 'STANDARD', 'CONSTANTE', 'PURCHASING_SITE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'consolidated_flag', 'STANDARD', 'CONSTANTE', 'Not Consolidated', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'consolidated_flag_db', 'STANDARD', 'CONSTANTE', 'NOT CONSOLIDATED', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'document_address_id', 'STANDARD', 'CONSTANTE', '1', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'doc_addr_no', 'STANDARD', 'CONSTANTE', '1', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'intrastat_exempt', 'STANDARD', 'CONSTANTE', 'Include', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'intrastat_exempt_db', 'STANDARD', 'CONSTANTE', 'INCLUDE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'project_address_flag', 'STANDARD', 'CONSTANTE', 'No', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'project_address_flag_db', 'STANDARD', 'CONSTANTE', 'N', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'authorization_rejected', 'STANDARD', 'CONSTANTE', 'False', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'authorization_rejected_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'use_price_incl_tax_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'tax_liability', 'STANDARD', 'CONSTANTE', 'TAX', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'pending_changes', 'STANDARD', 'CONSTANTE', 'False', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'pending_changes_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'communicated_via', 'STANDARD', 'CONSTANTE', 'E-mail', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'communicated_via_db', 'STANDARD', 'CONSTANTE', 'EMAIL', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'adhoc_purchased', 'STANDARD', 'CONSTANTE', 'False', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'adhoc_purchased_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'use_delivery_doc_address', 'STANDARD', 'CONSTANTE', 'FALSE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'use_supplier_doc_address', 'STANDARD', 'CONSTANTE', 'FALSE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'mois_anteriorite', 'STANDARD', 'CONSTANTE', '6', 'Fenetre d''eligibilite : commandes creees dans les N mois precedant la date de bascule (order_date)', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'address1', 'SJ', 'CONSTANTE', 'Trimet France,Usine de St Jean', 'Adresse de livraison du site SJ', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'address2', 'SJ', 'CONSTANTE', '1192 Rue H. Sainte-Claire Deville', 'Adresse de livraison du site SJ', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'address3', 'SJ', 'CONSTANTE', 'CS30114', 'Adresse de livraison du site SJ', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'zip_code', 'SJ', 'CONSTANTE', '73302', 'Adresse de livraison du site SJ', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'city', 'SJ', 'CONSTANTE', 'ST JEAN DE MAURIENNE CEDEX', 'Adresse de livraison du site SJ', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'address1', 'CS', 'CONSTANTE', 'Trimet France,Usine Castelsarrasin', 'Adresse de livraison du site CS', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'address2', 'CS', 'CONSTANTE', '18 chemin des 2 ponts', 'Adresse de livraison du site CS', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'address3', 'CS', 'NULL', NULL, 'Adresse de livraison du site CS', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'zip_code', 'CS', 'CONSTANTE', '82101', 'Adresse de livraison du site CS', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order', 'city', 'CS', 'CONSTANTE', 'CASTELSARRASIN', 'Adresse de livraison du site CS', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- clean_data.purchase_order_line_part
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'release_no', 'STANDARD', 'CONSTANTE', '1', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'additional_cost_amount', 'STANDARD', 'CONSTANTE', '0', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'additional_cost_incl_tax', 'STANDARD', 'CONSTANTE', '0', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'conv_factor', 'STANDARD', 'CONSTANTE', '1', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'close_code', 'STANDARD', 'CONSTANTE', 'Manual', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'close_code_db', 'STANDARD', 'CONSTANTE', 'N', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'price_conv_factor', 'STANDARD', 'CONSTANTE', '1', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'demand_code_db', 'STANDARD', 'CONSTANTE', 'PO', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'ord_conf_reminder_db', 'STANDARD', 'CONSTANTE', 'NOCONFREM', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'delivery_reminder_db', 'STANDARD', 'CONSTANTE', 'NODELIVREM', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'receive_case_db', 'STANDARD', 'CONSTANTE', 'ARRINV', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'purchase_payment_type_db', 'STANDARD', 'CONSTANTE', 'NORMAL', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'automatic_invoice_db', 'STANDARD', 'CONSTANTE', 'MANUAL', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'currency_type', 'STANDARD', 'CONSTANTE', '2', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'addr_flag_db', 'STANDARD', 'CONSTANTE', 'Y', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'default_addr_flag_db', 'STANDARD', 'CONSTANTE', 'N', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'freeze_flag', 'STANDARD', 'CONSTANTE', 'Free', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'freeze_flag_db', 'STANDARD', 'CONSTANTE', 'FREE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'intrastat_exempt', 'STANDARD', 'CONSTANTE', 'Include', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'intrastat_exempt_db', 'STANDARD', 'CONSTANTE', 'INCLUDE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'taxable', 'STANDARD', 'CONSTANTE', 'True', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'taxable_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'inventory_part', 'STANDARD', 'CONSTANTE', 'False', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'inventory_part_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'project_address', 'STANDARD', 'CONSTANTE', 'No', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'project_address_db', 'STANDARD', 'CONSTANTE', 'N', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'rental', 'STANDARD', 'CONSTANTE', 'False', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'rental_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'external_project_resource', 'STANDARD', 'CONSTANTE', 'False', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'external_project_resource_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'sample_percent', 'STANDARD', 'CONSTANTE', '0', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'sample_qty', 'STANDARD', 'CONSTANTE', '0', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'create_fa_obj', 'STANDARD', 'CONSTANTE', 'False', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'create_fa_obj_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'fa_obj_per_unit', 'STANDARD', 'CONSTANTE', 'False', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'fa_obj_per_unit_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'tax_liability', 'STANDARD', 'CONSTANTE', 'TAX', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'tax_liability_type', 'STANDARD', 'CONSTANTE', 'Taxable', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'tax_liability_type_db', 'STANDARD', 'CONSTANTE', 'TAX', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'ignore_default_taxes_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'post_on_purchasing_comp_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'eng_chg_level', 'STANDARD', 'CONSTANTE', '1', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'order_code', 'STANDARD', 'CONSTANTE', '1', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'ord_conf_rem_num', 'STANDARD', 'CONSTANTE', '0', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'delivery_rem_num', 'STANDARD', 'CONSTANTE', '0', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'is_exchange_part', 'STANDARD', 'CONSTANTE', 'FALSE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'part_ownership', 'STANDARD', 'CONSTANTE', 'Company Owned', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'part_ownership_db', 'STANDARD', 'CONSTANTE', 'COMPANY OWNED', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'exchange_item', 'STANDARD', 'CONSTANTE', 'Item not exchanged', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'exchange_item_db', 'STANDARD', 'CONSTANTE', 'ITEM NOT EXCHANGED', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'qty_scrapped_supplier', 'STANDARD', 'CONSTANTE', '0', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'issue_packaging_material', 'STANDARD', 'CONSTANTE', 'False', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'issue_packaging_material_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_part', 'sup_loaned_part_return', 'STANDARD', 'CONSTANTE', 'FALSE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- clean_data.purchase_order_line_nopart
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'release_no', 'STANDARD', 'CONSTANTE', '1', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'additional_cost_amount', 'STANDARD', 'CONSTANTE', '0', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'additional_cost_incl_tax', 'STANDARD', 'CONSTANTE', '0', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'conv_factor', 'STANDARD', 'CONSTANTE', '1', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'close_code', 'STANDARD', 'CONSTANTE', 'Manual', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'close_code_db', 'STANDARD', 'CONSTANTE', 'N', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'price_conv_factor', 'STANDARD', 'CONSTANTE', '1', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'demand_code_db', 'STANDARD', 'CONSTANTE', 'PO', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'ord_conf_reminder_db', 'STANDARD', 'CONSTANTE', 'NOCONFREM', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'delivery_reminder_db', 'STANDARD', 'CONSTANTE', 'NODELIVREM', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'receive_case_db', 'STANDARD', 'CONSTANTE', 'ARRINV', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'purchase_payment_type_db', 'STANDARD', 'CONSTANTE', 'NORMAL', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'automatic_invoice_db', 'STANDARD', 'CONSTANTE', 'MANUAL', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'currency_type', 'STANDARD', 'CONSTANTE', '2', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'addr_flag_db', 'STANDARD', 'CONSTANTE', 'Y', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'default_addr_flag_db', 'STANDARD', 'CONSTANTE', 'N', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'company', 'STANDARD', 'CONSTANTE', 'TRIMET', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'freeze_flag', 'STANDARD', 'CONSTANTE', 'Free', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'freeze_flag_db', 'STANDARD', 'CONSTANTE', 'FREE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'intrastat_exempt', 'STANDARD', 'CONSTANTE', 'Include', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'intrastat_exempt_db', 'STANDARD', 'CONSTANTE', 'INCLUDE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'taxable', 'STANDARD', 'CONSTANTE', 'True', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'taxable_db', 'STANDARD', 'CONSTANTE', 'TRUE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'inventory_part', 'STANDARD', 'CONSTANTE', 'False', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'inventory_part_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'project_address', 'STANDARD', 'CONSTANTE', 'No', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'project_address_db', 'STANDARD', 'CONSTANTE', 'N', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'rental', 'STANDARD', 'CONSTANTE', 'False', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'rental_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'external_project_resource', 'STANDARD', 'CONSTANTE', 'False', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'external_project_resource_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'sample_percent', 'STANDARD', 'CONSTANTE', '0', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'sample_qty', 'STANDARD', 'CONSTANTE', '0', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'create_fa_obj', 'STANDARD', 'CONSTANTE', 'False', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'create_fa_obj_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'fa_obj_per_unit', 'STANDARD', 'CONSTANTE', 'False', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'fa_obj_per_unit_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'tax_liability', 'STANDARD', 'CONSTANTE', 'TAX', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'tax_liability_type', 'STANDARD', 'CONSTANTE', 'Taxable', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'tax_liability_type_db', 'STANDARD', 'CONSTANTE', 'TAX', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'ignore_default_taxes_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'post_on_purchasing_comp_db', 'STANDARD', 'CONSTANTE', 'FALSE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'close_tolerance', 'STANDARD', 'CONSTANTE', '0', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'hide_price', 'STANDARD', 'CONSTANTE', 'Hide None', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'hide_price_db', 'STANDARD', 'CONSTANTE', '1', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'ord_conf_rem_num', 'STANDARD', 'CONSTANTE', '0', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'delivery_rem_num', 'STANDARD', 'CONSTANTE', '0', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.purchase_order_line_nopart', 'is_exchange_part', 'STANDARD', 'CONSTANTE', 'FALSE', 'Spec Lot11 V4.1 / fichier V2', 'migration_104')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- Transcodifications (deduites du fichier V2, a valider)
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('PAY_TERM', 'SAP', 'IFS', 'C015', '20NETS', 'Condition de paiement, deduite du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('PAY_TERM', 'SAP', 'IFS', 'C030', '30FM15', 'Condition de paiement, deduite du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('PAY_TERM', 'SAP', 'IFS', 'C045', '45NETS', 'Condition de paiement, deduite du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('PAY_TERM', 'SAP', 'IFS', 'F000', 'DF000', 'Condition de paiement, deduite du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('PAY_TERM', 'SAP', 'IFS', 'F005', '30NETS', 'Condition de paiement, deduite du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('PAY_TERM', 'SAP', 'IFS', 'F014', '15NETS', 'Condition de paiement, deduite du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('PAY_TERM', 'SAP', 'IFS', 'F015', '15NETS', 'Condition de paiement, deduite du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('PAY_TERM', 'SAP', 'IFS', 'F020', '20NETS', 'Condition de paiement, deduite du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('PAY_TERM', 'SAP', 'IFS', 'F030', '30NETS', 'Condition de paiement, deduite du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('PAY_TERM', 'SAP', 'IFS', 'M045', '30FM15', 'Condition de paiement, deduite du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('PAY_TERM', 'SAP', 'IFS', 'M110', '60NETS', 'Condition de paiement, deduite du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('PAY_TERM', 'SAP', 'IFS', 'PRF', '30NETS', 'Condition de paiement, deduite du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '90E230000', '90E230000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '90S110000', '90S110000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '90S150000', '90S110000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '90S230000', '90S230000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '90S239000', '90S110000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '90S252000', '90S252000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '90V300028', '90V300028', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92G599901', '92G599901', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92G909015', '92G909015', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S110000', '92C110000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S120000', '92C120000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S120050', '92C120050', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S120100', '92C120100', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S120120', '92C120120', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S120150', '92C120150', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S121000', '92S121000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S121020', '92C121020', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S130000', '92S130000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S140000', '92C140000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S150000', '92C150000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S150010', '92C150010', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S160000', '92C160000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S180000', '92C180000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210000', '92S210000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210020', '92S210020', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210030', '92S210030', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210040', '92S210040', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210050', '92S210050', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210060', '92S210060', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210061', '92S210061', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210062', '92S210062', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210070', '92S221000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210200', '92S210200', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210202', '92S210202', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210990', '92S210990', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S220010', '92S220010', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S220030', '92S220030', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S220040', '92S220040', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S220050', '92S220050', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S220070', '92S220070', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S220090', '92S220090', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S220099', '92S220099', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S220200', '92S220200', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S220201', '92S220201', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S220202', '92S220202', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S220990', '92S220990', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S221000', '92S221000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S221010', '92S221000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S221020', '92S221000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S221200', '92S221200', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S230000', '92S230000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S230090', '92S230090', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S230990', '92S230000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S232000', '92S232000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S232020', '92S232001', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S232070', '92S232070', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S233030', '92S233030', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S233035', '92S233035', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S233040', '92S233040', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S239000', '92E239000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S239100', '92S239100', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S250020', '92S250020', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S250050', '92S250050', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S251000', '92S251000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S252000', '92C252000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S252010', '92C252010', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S252020', '92C252020', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S252030', '92S252030', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S310000', '92S310000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S311010', '92C311010', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S330010', '92C330010', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S330020', '92C330020', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S350000', '92S350000', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92V300022', '92V300022', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92V300023', '92V300022', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92V300024', '92V300022', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92V300030', '92V300022', 'Centre de couts, deduit du fichier Lot11 V2', 'migration_104', true)
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;

COMMIT;
