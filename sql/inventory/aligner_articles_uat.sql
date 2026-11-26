-- ============================================================================
-- Alignement des articles SAP sur l'UAT IFS (regle du 2026-11-27 : l'UAT fait foi)
-- Source : docs/Documentation Articles/Matrice_valeurs_defaut_articles_IFS.xlsx
--          (quick reports UAT du 26/11/2026, 70 articles).
--
-- Seules les VALEURS PAR DEFAUT suivent l'UAT (demande du 2026-11-27). Les donnees
-- de l'article (description, unites de stock et d'achat, texte de commande, groupes
-- et famille du fichier finance, classe ABC...) restent celles de Migration Factory, meme vides.
--
-- UN SEUL programme pour toutes les valeurs de la matrice : il passe APRES les
-- chargements (part_catalog, inventory_part, purchase_part) et corrige leurs
-- lignes. Il est appele a la fin des modules ETL Articles (order 8) et Article
-- SAP (order 11, qui recharge part_catalog) : il est idempotent.
--
-- Perimetre : articles de clean_data.article_perimetre (Finance > Articles). Les
-- articles PHL / composants (matrice Site x Famille) ne sont pas touches.
--
-- Toutes les valeurs viennent de l'ecran Valeurs par defaut
-- (public.etl_default_values, migration 138) : variante STANDARD pour les
-- constantes, variante = profil pour les regles par profil :
--   OBJET_SERIE       article porte par un objet serie (clean_data.equipment_serial)
--   OBJET_SERIE_NLAG  objet serie de categorie NLAG
--   ERSA, HIBE...     categorie SAP (mara.mtart)
--   HORS_PCS          unite de stock autre que PCS (qty_calc_rounding)
-- Une valeur absente ou desactivee laisse la valeur du chargement.
--
-- La presence des lignes est geree par les chargements eux-memes :
--   inventory_part / invent_part_plan : NLAG d'objet serie inclus
--   purchase_part : IBAU inclus (sans MARC, site SJ), INVENTORY_FLAG = N
--
-- Un article HIBE d'objet serie n'est pas suivi en serie (464669 en UAT) ;
-- exceptions par article (variante = n° article, ex. 400010 : valorisation ST,
-- stock negatif, groupe de couts ANREC).
-- Retourne une ligne par regle : nombre de lignes modifiees.
-- ============================================================================
CREATE OR REPLACE FUNCTION clean_data.aligner_articles_uat()
 RETURNS TABLE (r_regle TEXT, r_table TEXT, r_lignes INTEGER)
 LANGUAGE plpgsql
AS $function$
DECLARE
    c_pc CONSTANT TEXT := 'clean_data.part_catalog';
    c_ip CONSTANT TEXT := 'clean_data.inventory_part';
    c_pp CONSTANT TEXT := 'clean_data.purchase_part';
BEGIN
    DROP TABLE IF EXISTS tmp_profil_uat;
    CREATE TEMP TABLE tmp_profil_uat ON COMMIT DROP AS
    SELECT p.numero_article AS part_no,
           m.mtart::text AS mtart,
           p.numero_article IN (SELECT es.part_no FROM clean_data.equipment_serial es
                                 WHERE es.part_no IS NOT NULL) AS serie
      FROM clean_data.article_perimetre p
      LEFT JOIN raw_data.mara m
        ON m.mandt::text = '700'
       AND m.matnr::text = CASE WHEN p.numero_article ~ '^[0-9]+$'
                                THEN LPAD(p.numero_article, 18, '0')
                                ELSE p.numero_article END;
    CREATE UNIQUE INDEX ON tmp_profil_uat (part_no);
    ANALYZE tmp_profil_uat;

    -- Valeurs par defaut lues UNE fois (et non par ligne : ~450 000 appels sinon)
    DROP TABLE IF EXISTS tmp_defaut_uat;
    CREATE TEMP TABLE tmp_defaut_uat ON COMMIT DROP AS
    SELECT table_cible, colonne, variante, valeur
      FROM public.etl_default_values
     WHERE is_active AND type_valeur = 'CONSTANTE'
       AND table_cible IN (c_pc, c_ip, c_pp);

    -- ---------------------------------------------------------------- Part Catalog
    UPDATE clean_data.part_catalog pc
       SET freight_factor       = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_pc AND d.colonne = 'freight_factor' AND d.variante = 'STANDARD')::numeric, pc.freight_factor),
           std_name_id          = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_pc AND d.colonne = 'std_name_id' AND d.variante = 'STANDARD')::numeric, pc.std_name_id),
           uom_for_weight_net   = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_pc AND d.colonne = 'uom_for_weight_net' AND d.variante = 'STANDARD'), pc.uom_for_weight_net),
           weight_net           = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_pc AND d.colonne = 'weight_net' AND d.variante = 'STANDARD')::numeric, pc.weight_net),
           lot_quantity_rule_db = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_pc AND d.colonne = 'lot_quantity_rule_db' AND d.variante = 'STANDARD'), pc.lot_quantity_rule_db)
      FROM tmp_profil_uat t
     WHERE pc.part_no = t.part_no;
    r_regle := 'Constantes (fret, poids, nom standard, regle de lot)'; r_table := 'part_catalog';
    GET DIAGNOSTICS r_lignes = ROW_COUNT; RETURN NEXT;

    UPDATE clean_data.part_catalog pc
       SET serial_tracking_code_db       = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_pc AND d.colonne = 'serial_tracking_code_db' AND d.variante = 'OBJET_SERIE'), pc.serial_tracking_code_db),
           eng_serial_tracking_code_db   = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_pc AND d.colonne = 'eng_serial_tracking_code_db' AND d.variante = 'OBJET_SERIE'), pc.eng_serial_tracking_code_db),
           receipt_issue_serial_track_db = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_pc AND d.colonne = 'receipt_issue_serial_track_db' AND d.variante = 'OBJET_SERIE'), pc.receipt_issue_serial_track_db),
           condition_code_usage_db       = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_pc AND d.colonne = 'condition_code_usage_db' AND d.variante = 'OBJET_SERIE'), pc.condition_code_usage_db)
      FROM tmp_profil_uat t
     WHERE pc.part_no = t.part_no AND t.serie
       -- HIBE (matiere consommable) : pas de suivi en serie en UAT (464669)
       AND t.mtart IS DISTINCT FROM 'HIBE';
    r_regle := 'Objets serie (hors HIBE) : suivi en serie, code condition'; r_table := 'part_catalog';
    GET DIAGNOSTICS r_lignes = ROW_COUNT; RETURN NEXT;

    -- -------------------------------------------------------------- Inventory Part
    UPDATE clean_data.inventory_part ip
       -- abc_class : donnee article (classe ABC SAP, marc.maabc), jamais forcee
       SET consumption_tax_db            = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_ip AND d.colonne = 'consumption_tax_db' AND d.variante = 'STANDARD'), ip.consumption_tax_db),
           invoice_consideration_db      = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_ip AND d.colonne = 'invoice_consideration_db' AND d.variante = 'STANDARD'), ip.invoice_consideration_db),
           min_durab_days_co_deliv       = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_ip AND d.colonne = 'min_durab_days_co_deliv' AND d.variante = 'STANDARD')::numeric, ip.min_durab_days_co_deliv),
           min_durab_days_planning       = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_ip AND d.colonne = 'min_durab_days_planning' AND d.variante = 'STANDARD')::numeric, ip.min_durab_days_planning),
           putaway_zone_refill_option_db = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_ip AND d.colonne = 'putaway_zone_refill_option_db' AND d.variante = 'STANDARD'), ip.putaway_zone_refill_option_db),
           storage_depth_requirement     = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_ip AND d.colonne = 'storage_depth_requirement' AND d.variante = 'STANDARD')::numeric, ip.storage_depth_requirement),
           storage_height_requirement    = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_ip AND d.colonne = 'storage_height_requirement' AND d.variante = 'STANDARD')::numeric, ip.storage_height_requirement),
           storage_width_requirement     = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_ip AND d.colonne = 'storage_width_requirement' AND d.variante = 'STANDARD')::numeric, ip.storage_width_requirement),
           tax_manuf_equivalent_db       = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_ip AND d.colonne = 'tax_manuf_equivalent_db' AND d.variante = 'STANDARD'), ip.tax_manuf_equivalent_db),
           zero_cost_flag_db             = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_ip AND d.colonne = 'zero_cost_flag_db' AND d.variante = 'STANDARD'), ip.zero_cost_flag_db),
           shortage_flag_db              = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_ip AND d.colonne = 'shortage_flag_db' AND d.variante = 'STANDARD'), ip.shortage_flag_db),
           -- 0 pour l'unite PCS, 3 pour toute autre unite (60/60 en UAT)
           qty_calc_rounding = COALESCE(CASE WHEN ip.unit_meas = 'PCS'
                                             THEN (SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_ip AND d.colonne = 'qty_calc_rounding' AND d.variante = 'STANDARD')
                                             ELSE (SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_ip AND d.colonne = 'qty_calc_rounding' AND d.variante = 'HORS_PCS') END::numeric,
                                        ip.qty_calc_rounding),
           -- Famille : celle du fichier finance, sinon celle de la categorie SAP (MAG pour ERSA / HIBE)
           part_product_family = COALESCE(ip.part_product_family,
                                          (SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_ip AND d.colonne = 'part_product_family' AND d.variante = t.mtart))
      FROM tmp_profil_uat t
     WHERE ip.part_no = t.part_no;
    r_regle := 'Constantes, arrondi selon unite, famille selon categorie'; r_table := 'inventory_part';
    GET DIAGNOSTICS r_lignes = ROW_COUNT; RETURN NEXT;

    -- Objets serie NLAG : rupture Y (12/12 en UAT)
    UPDATE clean_data.inventory_part ip
       SET shortage_flag_db = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_ip AND d.colonne = 'shortage_flag_db' AND d.variante = 'OBJET_SERIE_NLAG'), ip.shortage_flag_db)
      FROM tmp_profil_uat t
     WHERE ip.part_no = t.part_no AND t.serie AND t.mtart = 'NLAG';
    r_regle := 'Objets serie NLAG : rupture'; r_table := 'inventory_part';
    GET DIAGNOSTICS r_lignes = ROW_COUNT; RETURN NEXT;

    -- Exceptions par article : variante = n° article dans l'ecran Valeurs par defaut
    UPDATE clean_data.inventory_part ip
       SET inventory_valuation_method_db = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_ip AND d.colonne = 'inventory_valuation_method_db' AND d.variante = ip.part_no), ip.inventory_valuation_method_db),
           negative_on_hand_db           = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_ip AND d.colonne = 'negative_on_hand_db' AND d.variante = ip.part_no), ip.negative_on_hand_db),
           part_cost_group_id            = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_ip AND d.colonne = 'part_cost_group_id' AND d.variante = ip.part_no), ip.part_cost_group_id)
     WHERE ip.part_no IN (SELECT d.variante FROM tmp_defaut_uat d WHERE d.table_cible = c_ip);
    r_regle := 'Exceptions par article'; r_table := 'inventory_part';
    GET DIAGNOSTICS r_lignes = ROW_COUNT; RETURN NEXT;

    -- --------------------------------------------------------------- Purchase Part
    UPDATE clean_data.purchase_part pp
       SET buyer_code       = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_pp AND d.colonne = 'buyer_code' AND d.variante = 'STANDARD'), pp.buyer_code),
           over_delivery_db = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_pp AND d.colonne = 'over_delivery_db' AND d.variante = 'STANDARD'), pp.over_delivery_db),
           std_name_id      = COALESCE((SELECT d.valeur FROM tmp_defaut_uat d WHERE d.table_cible = c_pp AND d.colonne = 'std_name_id' AND d.variante = 'STANDARD'), pp.std_name_id)
      FROM tmp_profil_uat t
     WHERE pp.part_no = t.part_no;
    r_regle := 'Constantes'; r_table := 'purchase_part';
    GET DIAGNOSTICS r_lignes = ROW_COUNT; RETURN NEXT;

    -- Groupe d'achat : celui du fichier finance, sinon son groupe comptable (en UAT,
    -- groupe d'achat = groupe comptable). IBAU : vide.
    UPDATE clean_data.purchase_part pp
       SET stat_grp = SUBSTRING(TRIM(val.donnees ->> 'Groupe comptable'), 1, 6)
      FROM clean_data.article_perimetre_validation val, tmp_profil_uat t
     WHERE pp.stat_grp IS NULL
       AND val.numero_article = pp.part_no
       AND NULLIF(TRIM(val.donnees ->> 'Groupe comptable'), '') IS NOT NULL
       AND t.part_no = pp.part_no
       AND t.mtart IS DISTINCT FROM 'IBAU';
    r_regle := 'Groupe d''achat vide : groupe comptable de l''article'; r_table := 'purchase_part';
    GET DIAGNOSTICS r_lignes = ROW_COUNT; RETURN NEXT;

    RETURN;
END;
$function$;

COMMENT ON FUNCTION clean_data.aligner_articles_uat() IS
'Aligne part_catalog, inventory_part et purchase_part des articles de article_perimetre sur la matrice UAT (valeurs dans etl_default_values, migration 138). Regles dans sql/inventory/aligner_articles_uat.sql.';
