-- =====================================================
-- 138 : valeurs par defaut articles alignees sur l'UAT IFS (2026-11-27, l'UAT fait foi)
-- Source : docs/Documentation Articles/Matrice_valeurs_defaut_articles_IFS.xlsx
-- Lues par clean_data.aligner_articles_uat() (sql/inventory/aligner_articles_uat.sql)
-- et, pour les variantes STANDARD deja lues, par les chargements sql/inventory/.
-- Modifiables ensuite dans l'ecran Valeurs par defaut. Idempotent.
-- Rollback : remettre les anciennes valeurs indiquees en commentaire.
-- =====================================================

BEGIN;

INSERT INTO public.etl_default_values
       (module, table_cible, colonne, variante, type_valeur, valeur, description, is_active, created_by, updated_by)
VALUES
-- Part Catalog : constantes
('inventory', 'clean_data.part_catalog', 'freight_factor',     'STANDARD', 'CONSTANTE', '1',          'UAT : facteur de fret 1', TRUE, 'migration_138', 'migration_138'),
('inventory', 'clean_data.part_catalog', 'std_name_id',        'STANDARD', 'CONSTANTE', '0',          'UAT : nom standard 0', TRUE, 'migration_138', 'migration_138'),
('inventory', 'clean_data.part_catalog', 'uom_for_weight_net', 'STANDARD', 'CONSTANTE', 'kg',         'UAT : unite de poids kg', TRUE, 'migration_138', 'migration_138'),
('inventory', 'clean_data.part_catalog', 'weight_net',         'STANDARD', 'CONSTANTE', '0',          'UAT : poids net 0', TRUE, 'migration_138', 'migration_138'),
('inventory', 'clean_data.part_catalog', 'lot_quantity_rule_db', 'STANDARD', 'CONSTANTE', 'MULTI_LOTS', 'UAT : MULTI_LOTS pour tous les articles', TRUE, 'migration_138', 'migration_138'),
-- Part Catalog : articles d'objets serie
('inventory', 'clean_data.part_catalog', 'serial_tracking_code_db',       'OBJET_SERIE', 'CONSTANTE', 'SERIAL TRACKING', 'UAT : article d''objet serie suivi en serie', TRUE, 'migration_138', 'migration_138'),
('inventory', 'clean_data.part_catalog', 'eng_serial_tracking_code_db',   'OBJET_SERIE', 'CONSTANTE', 'SERIAL TRACKING', 'UAT : article d''objet serie suivi en serie', TRUE, 'migration_138', 'migration_138'),
('inventory', 'clean_data.part_catalog', 'receipt_issue_serial_track_db', 'OBJET_SERIE', 'CONSTANTE', 'TRUE',            'UAT : suivi serie en reception / sortie', TRUE, 'migration_138', 'migration_138'),
('inventory', 'clean_data.part_catalog', 'condition_code_usage_db',       'OBJET_SERIE', 'CONSTANTE', 'ALLOW_COND_CODE', 'UAT : code condition autorise', TRUE, 'migration_138', 'migration_138'),
-- Inventory Part : constantes
('inventory', 'clean_data.inventory_part', 'consumption_tax_db',            'STANDARD', 'CONSTANTE', 'FALSE',                'UAT', TRUE, 'migration_138', 'migration_138'),
('inventory', 'clean_data.inventory_part', 'invoice_consideration_db',      'STANDARD', 'CONSTANTE', 'IGNORE INVOICE PRICE', 'UAT (ancien : TRANSACTION BASED)', TRUE, 'migration_138', 'migration_138'),
('inventory', 'clean_data.inventory_part', 'min_durab_days_co_deliv',       'STANDARD', 'CONSTANTE', '0',                    'UAT', TRUE, 'migration_138', 'migration_138'),
('inventory', 'clean_data.inventory_part', 'min_durab_days_planning',       'STANDARD', 'CONSTANTE', '0',                    'UAT', TRUE, 'migration_138', 'migration_138'),
('inventory', 'clean_data.inventory_part', 'putaway_zone_refill_option_db', 'STANDARD', 'CONSTANTE', 'FROM_ALL_LOCATIONS',   'UAT', TRUE, 'migration_138', 'migration_138'),
('inventory', 'clean_data.inventory_part', 'storage_depth_requirement',     'STANDARD', 'CONSTANTE', '0',                    'UAT', TRUE, 'migration_138', 'migration_138'),
('inventory', 'clean_data.inventory_part', 'storage_height_requirement',    'STANDARD', 'CONSTANTE', '0',                    'UAT', TRUE, 'migration_138', 'migration_138'),
('inventory', 'clean_data.inventory_part', 'storage_width_requirement',     'STANDARD', 'CONSTANTE', '0',                    'UAT', TRUE, 'migration_138', 'migration_138'),
('inventory', 'clean_data.inventory_part', 'tax_manuf_equivalent_db',       'STANDARD', 'CONSTANTE', 'FALSE',                'UAT', TRUE, 'migration_138', 'migration_138'),
('inventory', 'clean_data.inventory_part', 'zero_cost_flag_db',             'STANDARD', 'CONSTANTE', 'N',                    'UAT : cout zero interdit (ancien : Y)', TRUE, 'migration_138', 'migration_138'),
('inventory', 'clean_data.inventory_part', 'shortage_flag_db',              'STANDARD', 'CONSTANTE', 'N',                    'UAT (ancien : Y)', TRUE, 'migration_138', 'migration_138'),
('inventory', 'clean_data.inventory_part', 'shortage_flag_db',              'OBJET_SERIE_NLAG', 'CONSTANTE', 'Y',            'UAT : objets serie NLAG', TRUE, 'migration_138', 'migration_138'),
('inventory', 'clean_data.inventory_part', 'qty_calc_rounding',             'HORS_PCS', 'CONSTANTE', '3',                    'UAT : 3 pour toute unite autre que PCS (STANDARD = 0 pour PCS)', TRUE, 'migration_138', 'migration_138'),
-- Exception article 400010 (HALB, recycles cuits) : variante = n° article
('inventory', 'clean_data.inventory_part', 'inventory_valuation_method_db', '400010', 'CONSTANTE', 'ST',            'UAT : exception 400010 valorisation ST', TRUE, 'migration_138', 'migration_138'),
('inventory', 'clean_data.inventory_part', 'negative_on_hand_db',           '400010', 'CONSTANTE', 'NEG ONHAND OK', 'UAT : exception 400010 stock negatif autorise', TRUE, 'migration_138', 'migration_138'),
('inventory', 'clean_data.inventory_part', 'part_cost_group_id',            '400010', 'CONSTANTE', 'ANREC',         'UAT : exception 400010 groupe de couts ANREC', TRUE, 'migration_138', 'migration_138'),
-- Famille de produits si le fichier finance ne la donne pas (variante = categorie SAP)
('inventory', 'clean_data.inventory_part', 'part_product_family',           'ERSA', 'CONSTANTE', 'MAG',                      'UAT : MAG pour ERSA', TRUE, 'migration_138', 'migration_138'),
('inventory', 'clean_data.inventory_part', 'part_product_family',           'HIBE', 'CONSTANTE', 'MAG',                      'UAT : MAG pour HIBE', TRUE, 'migration_138', 'migration_138'),
-- Purchase Part : constantes
('inventory', 'clean_data.purchase_part', 'buyer_code',       'STANDARD', 'CONSTANTE', '*',             'UAT : acheteur *', TRUE, 'migration_138', 'migration_138'),
('inventory', 'clean_data.purchase_part', 'over_delivery_db', 'STANDARD', 'CONSTANTE', 'PERFORM_CHECK', 'UAT (ancien : YES)', TRUE, 'migration_138', 'migration_138'),
('inventory', 'clean_data.purchase_part', 'std_name_id',      'STANDARD', 'CONSTANTE', '0',             'UAT : nom standard 0', TRUE, 'migration_138', 'migration_138')
-- Classe ABC, unites d'achat, texte de commande, groupes : donnees article de Migration Factory, pas de defaut
ON CONFLICT (table_cible, colonne, variante) DO UPDATE
   SET type_valeur = EXCLUDED.type_valeur,
       valeur      = EXCLUDED.valeur,
       description = EXCLUDED.description,
       is_active   = TRUE,
       updated_at  = CURRENT_TIMESTAMP,
       updated_by  = 'migration_138';

COMMIT;

SELECT table_cible, variante, count(*) AS lignes
  FROM public.etl_default_values
 WHERE updated_by = 'migration_138'
 GROUP BY 1, 2 ORDER BY 1, 2;
