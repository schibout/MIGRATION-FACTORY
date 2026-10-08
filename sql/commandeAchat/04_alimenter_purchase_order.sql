-- ============================================================================
-- clean_data.alimenter_purchase_order : dispatch des commandes d'achat
-- (clean_data.commande_achat_ifs, une ligne par poste) vers les trois objets
-- de reprise IFS du Lot 11 :
--   clean_data.purchase_order             : une ligne par commande
--   clean_data.purchase_order_line_part   : postes avec article (PART)
--   clean_data.purchase_order_line_nopart : postes sans article (NOPART)
-- Spec : docs/Lot11_AchatAppro_CommandeAchat_V4.1 - final.xlsx ; format :
-- docs/Lot11_*_V2.csv.
-- ============================================================================
-- Ordre d'execution : module ETL Commandes d'achat (alimenter_commande_achat_ifs)
-- PUIS cette fonction. Snapshot : les trois tables sont videes a chaque appel.
--
-- Identifiants IFS (jamais l'identifiant SAP) :
--   - VENDOR_NO / INVOICING_SUPPLIER = clean_data.supplier_info_general.supplier_id
--     rapproche sur supplier_legacy_sap_id (LIFNR sans zeros de tete), comme
--     alimenter_purchase_part_supplier : suit les renumerotations faites apres
--     le chargement fournisseur. INVOICING_SUPPLIER se replie sur VENDOR_NO
--     quand le fournisseur facture est le fournisseur commande ;
--   - ADDR_NO / DOC_ADDR_NO = clean_data.supplier_info_address.address_id du
--     fournisseur IFS (une adresse par fournisseur), repli valeur par defaut ;
--   - PART_NO = clean_data.part_catalog.part_no ;
--   - PAY_TERM_ID = transcodification PAY_TERM, sinon clean_data.supplier.pay_term_id ;
--   - DELIVERY_TERMS = Incoterm SAP (3 lettres reconnues), sinon
--     clean_data.supplier_address.delivery_terms, sinon valeur par defaut ;
--     DEL_TERMS_LOCATION = reste du libelle SAP, seulement si l'Incoterm vient de SAP ;
--   - SHIP_VIA_CODE = mode_expedition, sinon supplier_address.ship_via_code,
--     sinon valeur par defaut ;
--   - PRE_ACCOUNTING_ID = transcodification COST_CENTER (SAP -> IFS, migration 105)
--     du centre de couts de l'imputation : commande_achat_ifs.centre_cout_sap
--     = ekkn.kostl, ou pour une imputation sur ordre le centre de couts
--     responsable de l'ordre (aufk.kostv). NULL si le centre n'est pas transcode,
--     et pour une imputation sur OTP (PRPS ne porte pas de centre de couts) ;
--   - PROJECT_ID = commande_achat_ifs.numero_projet (projet SharePoint de l'OTP).
--   L'en-tete prend la pre-imputation et le projet du premier poste.
-- Toutes les autres constantes : public.get_default_value('clean_data.<table>',
-- '<colonne>') (migration 104, ecran Valeurs par defaut), resolues UNE fois.
--
-- Perimetre (spec ORDER_NO) : une commande est reprise si un de ses postes a
-- une date de reception souhaitee (derniere reception SAP), sinon si elle a ete
-- creee dans les <mois_anteriorite> mois (defaut 6) precedant la date de
-- bascule (valeur par defaut purchase_order.order_date, qui est aussi
-- l'ORDER_DATE de toutes les commandes). Ses lignes suivent l'en-tete.
-- EXCLUSIONS (comptees en NOTICE, a traiter en cadrage) :
--   - commande sans VENDOR_NO, sans INVOICING_SUPPLIER ou sans PAY_TERM_ID
--     (champs obligatoires IFS, regle de la spec) -> en-tete ET lignes exclus ;
--   - poste PART dont l'article n'est pas dans clean_data.part_catalog.
-- LINE_NO = num_ligne_sap sans zeros de tete ('00010' -> '10') : LINE_NO est
-- un VARCHAR2(4) cote IFS.
-- Retour : nombre de commandes chargees.
-- ============================================================================

CREATE OR REPLACE FUNCTION clean_data.alimenter_purchase_order()
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_debut    timestamp := clock_timestamp();
    v_bascule  date := COALESCE(NULLIF(public.get_default_value('clean_data.purchase_order', 'order_date'), '')::date, CURRENT_DATE);
    v_mois     integer := COALESCE(NULLIF(public.get_default_value('clean_data.purchase_order', 'mois_anteriorite'), '')::integer, 6);
    v_candidats integer;
    v_sans_fournisseur integer;
    v_sans_facturation integer;
    v_sans_paiement integer;
    v_nb_po    integer;
    v_nb_part  integer;
    v_nb_nopart integer;
    v_part_hors_catalogue integer;
BEGIN
    RAISE NOTICE '[%] Debut dispatch purchase_order (bascule %, fenetre % mois)', clock_timestamp(), v_bascule, v_mois;

    TRUNCATE TABLE clean_data.purchase_order_line_part,
                   clean_data.purchase_order_line_nopart,
                   clean_data.purchase_order;

    -- Pre-imputation IFS, resolue une fois par valeur distincte
    DROP TABLE IF EXISTS tmp_po_pre_accounting;
    CREATE TEMP TABLE tmp_po_pre_accounting ON COMMIT DROP AS
    SELECT p.centre_cout_sap,
           public.get_transcodification('COST_CENTER', p.centre_cout_sap) AS pre_accounting_id
    FROM (SELECT DISTINCT centre_cout_sap
          FROM clean_data.commande_achat_ifs
          WHERE centre_cout_sap IS NOT NULL) p;

    -- En-tetes candidats avec leurs identifiants IFS resolus
    DROP TABLE IF EXISTS tmp_po_entete;
    CREATE TEMP TABLE tmp_po_entete ON COMMIT DROP AS
    WITH
    lig AS (
        SELECT c.*
        FROM clean_data.commande_achat_ifs c
        WHERE c.num_ligne_sap IS NOT NULL      -- repli en-tete du module : pas de poste, rien a dispatcher
    ),
    -- Donnees d'en-tete repetees sur chaque poste : celles du premier poste
    ent AS (
        SELECT DISTINCT ON (num_commande_sap) *
        FROM lig
        ORDER BY num_commande_sap, num_ligne_sap
    ),
    reception AS (
        SELECT num_commande_sap, MAX(TO_DATE(date_reception_souhaitee, 'DD/MM/YYYY')) AS date_reception
        FROM lig
        GROUP BY num_commande_sap
    ),
    fournisseur AS (
        SELECT DISTINCT ON (lifnr) lifnr, supplier_id
        FROM (SELECT LTRIM(supplier_legacy_sap_id, '0') AS lifnr, supplier_id
              FROM clean_data.supplier_info_general
              WHERE NULLIF(TRIM(supplier_legacy_sap_id), '') IS NOT NULL) s
        ORDER BY lifnr, supplier_id
    ),
    adresse_fournisseur AS (
        SELECT DISTINCT ON (supplier_id) supplier_id, address_id
        FROM clean_data.supplier_info_address
        ORDER BY supplier_id, address_id
    ),
    livraison_fournisseur AS (
        SELECT DISTINCT ON (vendor_no) vendor_no, NULLIF(TRIM(delivery_terms), '') AS delivery_terms,
               NULLIF(TRIM(ship_via_code), '') AS ship_via_code
        FROM clean_data.supplier_address
        ORDER BY vendor_no, addr_no
    ),
    paiement AS (
        SELECT condition_paiement, public.get_transcodification('PAY_TERM', condition_paiement) AS pay_term_id
        FROM (SELECT DISTINCT condition_paiement FROM ent WHERE NULLIF(TRIM(condition_paiement), '') IS NOT NULL) x
    ),
    base AS (
        SELECT e.*,
               TO_DATE(e.date_creation, 'DD/MM/YYYY') AS d_creation,
               r.date_reception,
               f1.supplier_id AS vendor_no,
               COALESCE(f2.supplier_id,
                        CASE WHEN LTRIM(e.fournisseur_facturation_sap, '0') = LTRIM(e.fournisseur_sap, '0')
                             THEN f1.supplier_id END) AS invoicing_supplier,
               -- Incoterm : 3 premieres lettres du libelle SAP si c'est un code reconnu
               CASE WHEN SUBSTRING(UPPER(TRIM(e.condition_livraison)) FROM '^([A-Z]{3})(?:\s|$)')
                         IN ('EXW','FCA','FAS','FOB','CFR','CIF','CPT','CIP','DAP','DPU','DDP','DAT','DDU')
                    THEN SUBSTRING(UPPER(TRIM(e.condition_livraison)) FROM '^([A-Z]{3})(?:\s|$)')
               END AS incoterm_sap
        FROM ent e
        JOIN reception r USING (num_commande_sap)
        LEFT JOIN fournisseur f1 ON f1.lifnr = LTRIM(e.fournisseur_sap, '0')
        LEFT JOIN fournisseur f2 ON f2.lifnr = LTRIM(e.fournisseur_facturation_sap, '0')
    )
    SELECT b.num_commande_sap,
           b.site,
           b.devise,
           b.d_creation AS date_creation,
           b.date_reception,
           b.vendor_no,
           b.invoicing_supplier,
           COALESCE(pa.pay_term_id, NULLIF(TRIM(s.pay_term_id), '')) AS pay_term_id,
           COALESCE(b.incoterm_sap, lf.delivery_terms,
                    public.get_default_value('clean_data.purchase_order', 'delivery_terms')) AS delivery_terms,
           CASE WHEN b.incoterm_sap IS NOT NULL
                THEN LEFT(NULLIF(TRIM(SUBSTR(TRIM(b.condition_livraison), 4)), ''), 100) END AS del_terms_location,
           COALESCE(NULLIF(TRIM(b.mode_expedition), ''), lf.ship_via_code,
                    public.get_default_value('clean_data.purchase_order', 'ship_via_code')) AS ship_via_code,
           af.address_id AS addr_no_fournisseur,
           pre.pre_accounting_id,
           b.numero_projet,
           b.pays_livraison
    FROM base b
    LEFT JOIN paiement pa ON pa.condition_paiement = b.condition_paiement
    LEFT JOIN clean_data.supplier s ON s.vendor_no = b.vendor_no
    LEFT JOIN livraison_fournisseur lf ON lf.vendor_no = b.vendor_no
    LEFT JOIN adresse_fournisseur af ON af.supplier_id = b.vendor_no
    LEFT JOIN tmp_po_pre_accounting pre ON pre.centre_cout_sap = b.centre_cout_sap
    WHERE b.date_reception IS NOT NULL
       OR b.d_creation >= v_bascule - make_interval(months => v_mois);

    SELECT COUNT(*),
           COUNT(*) FILTER (WHERE vendor_no IS NULL),
           COUNT(*) FILTER (WHERE invoicing_supplier IS NULL),
           COUNT(*) FILTER (WHERE pay_term_id IS NULL)
      INTO v_candidats, v_sans_fournisseur, v_sans_facturation, v_sans_paiement
    FROM tmp_po_entete;

    -- ---------------------------------------------------------------- en-tetes
    INSERT INTO clean_data.purchase_order (
            order_no,
            addr_no,
            authorize_code,
            buyer_code,
            contract,
            currency_code,
            delivery_address,
            delivery_terms,
            language_code,
            pre_accounting_id,
            project_id,
            ship_via_code,
            vendor_no,
            date_entered,
            order_code,
            order_date,
            pick_list_flag,
            pick_list_flag_db,
            communicated,
            communicated_db,
            revision,
            wanted_receipt_date,
            country_code,
            pay_term_id,
            blanket_date,
            blanket_date_db,
            schedule_agreement_order,
            schedule_agreement_order_db,
            address1,
            address2,
            address3,
            zip_code,
            city,
            county,
            addr_flag,
            addr_flag_db,
            central_order_flag,
            central_order_flag_db,
            centralized_order_site,
            centralized_order_site_db,
            consolidated_flag,
            consolidated_flag_db,
            document_address_id,
            doc_addr_no,
            invoicing_supplier,
            intrastat_exempt,
            intrastat_exempt_db,
            del_terms_location,
            project_address_flag,
            project_address_flag_db,
            authorization_rejected,
            authorization_rejected_db,
            use_price_incl_tax_db,
            tax_liability,
            pending_changes,
            pending_changes_db,
            communicated_via,
            communicated_via_db,
            adhoc_purchased,
            adhoc_purchased_db,
            use_delivery_doc_address,
            use_supplier_doc_address,
            company
    )
    WITH
        d AS (SELECT
            public.get_default_value('clean_data.purchase_order', 'addr_no') AS addr_no,
            public.get_default_value('clean_data.purchase_order', 'authorize_code') AS authorize_code,
            public.get_default_value('clean_data.purchase_order', 'buyer_code') AS buyer_code,
            public.get_default_value('clean_data.purchase_order', 'delivery_address') AS delivery_address,
            public.get_default_value('clean_data.purchase_order', 'delivery_terms') AS delivery_terms,
            public.get_default_value('clean_data.purchase_order', 'language_code') AS language_code,
            public.get_default_value('clean_data.purchase_order', 'ship_via_code') AS ship_via_code,
            public.get_default_value('clean_data.purchase_order', 'order_code') AS order_code,
            public.get_default_value('clean_data.purchase_order', 'order_date') AS order_date,
            public.get_default_value('clean_data.purchase_order', 'pick_list_flag') AS pick_list_flag,
            public.get_default_value('clean_data.purchase_order', 'pick_list_flag_db') AS pick_list_flag_db,
            public.get_default_value('clean_data.purchase_order', 'communicated') AS communicated,
            public.get_default_value('clean_data.purchase_order', 'communicated_db') AS communicated_db,
            public.get_default_value('clean_data.purchase_order', 'revision') AS revision,
            public.get_default_value('clean_data.purchase_order', 'country_code') AS country_code,
            public.get_default_value('clean_data.purchase_order', 'blanket_date') AS blanket_date,
            public.get_default_value('clean_data.purchase_order', 'blanket_date_db') AS blanket_date_db,
            public.get_default_value('clean_data.purchase_order', 'schedule_agreement_order') AS schedule_agreement_order,
            public.get_default_value('clean_data.purchase_order', 'schedule_agreement_order_db') AS schedule_agreement_order_db,
            public.get_default_value('clean_data.purchase_order', 'addr_flag') AS addr_flag,
            public.get_default_value('clean_data.purchase_order', 'addr_flag_db') AS addr_flag_db,
            public.get_default_value('clean_data.purchase_order', 'central_order_flag') AS central_order_flag,
            public.get_default_value('clean_data.purchase_order', 'central_order_flag_db') AS central_order_flag_db,
            public.get_default_value('clean_data.purchase_order', 'centralized_order_site') AS centralized_order_site,
            public.get_default_value('clean_data.purchase_order', 'centralized_order_site_db') AS centralized_order_site_db,
            public.get_default_value('clean_data.purchase_order', 'consolidated_flag') AS consolidated_flag,
            public.get_default_value('clean_data.purchase_order', 'consolidated_flag_db') AS consolidated_flag_db,
            public.get_default_value('clean_data.purchase_order', 'document_address_id') AS document_address_id,
            public.get_default_value('clean_data.purchase_order', 'doc_addr_no') AS doc_addr_no,
            public.get_default_value('clean_data.purchase_order', 'intrastat_exempt') AS intrastat_exempt,
            public.get_default_value('clean_data.purchase_order', 'intrastat_exempt_db') AS intrastat_exempt_db,
            public.get_default_value('clean_data.purchase_order', 'project_address_flag') AS project_address_flag,
            public.get_default_value('clean_data.purchase_order', 'project_address_flag_db') AS project_address_flag_db,
            public.get_default_value('clean_data.purchase_order', 'authorization_rejected') AS authorization_rejected,
            public.get_default_value('clean_data.purchase_order', 'authorization_rejected_db') AS authorization_rejected_db,
            public.get_default_value('clean_data.purchase_order', 'use_price_incl_tax_db') AS use_price_incl_tax_db,
            public.get_default_value('clean_data.purchase_order', 'tax_liability') AS tax_liability,
            public.get_default_value('clean_data.purchase_order', 'pending_changes') AS pending_changes,
            public.get_default_value('clean_data.purchase_order', 'pending_changes_db') AS pending_changes_db,
            public.get_default_value('clean_data.purchase_order', 'communicated_via') AS communicated_via,
            public.get_default_value('clean_data.purchase_order', 'communicated_via_db') AS communicated_via_db,
            public.get_default_value('clean_data.purchase_order', 'adhoc_purchased') AS adhoc_purchased,
            public.get_default_value('clean_data.purchase_order', 'adhoc_purchased_db') AS adhoc_purchased_db,
            public.get_default_value('clean_data.purchase_order', 'use_delivery_doc_address') AS use_delivery_doc_address,
            public.get_default_value('clean_data.purchase_order', 'use_supplier_doc_address') AS use_supplier_doc_address,
            public.get_default_value('clean_data.purchase_order', 'company') AS company
        ),
        -- Adresse de livraison = adresse du site (variante = site)
        a AS (SELECT site,
                     public.get_default_value('clean_data.purchase_order', 'address1', site) AS address1,
                     public.get_default_value('clean_data.purchase_order', 'address2', site) AS address2,
                     public.get_default_value('clean_data.purchase_order', 'address3', site) AS address3,
                     public.get_default_value('clean_data.purchase_order', 'zip_code', site) AS zip_code,
                     public.get_default_value('clean_data.purchase_order', 'city', site) AS city
              FROM (SELECT DISTINCT site FROM tmp_po_entete WHERE site IS NOT NULL) x)
    SELECT
            'S' || p.num_commande_sap,
            COALESCE(p.addr_no_fournisseur, d.addr_no),
            d.authorize_code,
            d.buyer_code,
            p.site,
            p.devise,
            d.delivery_address,
            p.delivery_terms,
            d.language_code,
            p.pre_accounting_id,
            p.numero_projet,
            p.ship_via_code,
            p.vendor_no,
            p.date_creation::timestamp,
            d.order_code,
            v_bascule::timestamp,
            d.pick_list_flag,
            d.pick_list_flag_db,
            d.communicated,
            d.communicated_db,
            NULLIF(d.revision, '')::numeric,
            p.date_reception::timestamp,
            d.country_code,
            p.pay_term_id,
            d.blanket_date,
            d.blanket_date_db,
            d.schedule_agreement_order,
            d.schedule_agreement_order_db,
            a.address1,
            a.address2,
            a.address3,
            a.zip_code,
            a.city,
            p.pays_livraison,
            d.addr_flag,
            d.addr_flag_db,
            d.central_order_flag,
            d.central_order_flag_db,
            d.centralized_order_site,
            d.centralized_order_site_db,
            d.consolidated_flag,
            d.consolidated_flag_db,
            d.document_address_id,
            COALESCE(p.addr_no_fournisseur, d.doc_addr_no),
            p.invoicing_supplier,
            d.intrastat_exempt,
            d.intrastat_exempt_db,
            p.del_terms_location,
            d.project_address_flag,
            d.project_address_flag_db,
            d.authorization_rejected,
            d.authorization_rejected_db,
            d.use_price_incl_tax_db,
            d.tax_liability,
            d.pending_changes,
            d.pending_changes_db,
            d.communicated_via,
            d.communicated_via_db,
            d.adhoc_purchased,
            d.adhoc_purchased_db,
            d.use_delivery_doc_address,
            d.use_supplier_doc_address,
            d.company
    FROM tmp_po_entete p
    CROSS JOIN d
    LEFT JOIN a ON a.site = p.site
    WHERE p.vendor_no IS NOT NULL
      AND p.invoicing_supplier IS NOT NULL
      AND p.pay_term_id IS NOT NULL
    ORDER BY p.num_commande_sap;

    GET DIAGNOSTICS v_nb_po = ROW_COUNT;

    -- ---------------------------------------------------------- lignes article
    SELECT COUNT(*) INTO v_part_hors_catalogue
    FROM clean_data.commande_achat_ifs l
    JOIN clean_data.purchase_order po ON po.order_no = 'S' || l.num_commande_sap
    WHERE l.type_ligne_ifs = 'PART'
      AND NOT EXISTS (SELECT 1 FROM clean_data.part_catalog pc WHERE pc.part_no = l.article_sap);

    INSERT INTO clean_data.purchase_order_line_part (
            order_no,
            line_no,
            release_no,
            additional_cost_amount,
            additional_cost_incl_tax,
            buy_qty_due,
            buy_unit_price,
            buy_unit_price_incl_tax,
            conv_factor,
            currency_rate,
            date_entered,
            description,
            fbuy_unit_price,
            fbuy_unit_price_incl_tax,
            planned_delivery_date,
            promised_delivery_date,
            close_code,
            close_code_db,
            pre_accounting_id,
            project_id,
            contract,
            buy_unit_meas,
            price_conv_factor,
            demand_code_db,
            currency_code,
            ord_conf_reminder_db,
            delivery_reminder_db,
            receive_case_db,
            purchase_payment_type_db,
            automatic_invoice_db,
            currency_type,
            addr_flag_db,
            default_addr_flag_db,
            company,
            purchase_site,
            freeze_flag,
            freeze_flag_db,
            invoicing_supplier,
            intrastat_exempt,
            intrastat_exempt_db,
            taxable,
            taxable_db,
            inventory_part,
            inventory_part_db,
            part_no,
            project_address,
            project_address_db,
            rental,
            rental_db,
            external_project_resource,
            external_project_resource_db,
            sample_percent,
            sample_qty,
            create_fa_obj,
            create_fa_obj_db,
            fa_obj_per_unit,
            fa_obj_per_unit_db,
            tax_liability,
            tax_liability_type,
            tax_liability_type_db,
            ignore_default_taxes_db,
            post_on_purchasing_comp_db,
            eng_chg_level,
            order_code,
            price_unit_meas,
            last_activity_date,
            ord_conf_rem_num,
            delivery_rem_num,
            is_exchange_part,
            part_ownership,
            part_ownership_db,
            exchange_item,
            exchange_item_db,
            qty_scrapped_supplier,
            issue_packaging_material,
            issue_packaging_material_db,
            sup_loaned_part_return
    )
    WITH d AS (SELECT
            public.get_default_value('clean_data.purchase_order_line_part', 'release_no') AS release_no,
            public.get_default_value('clean_data.purchase_order_line_part', 'additional_cost_amount') AS additional_cost_amount,
            public.get_default_value('clean_data.purchase_order_line_part', 'additional_cost_incl_tax') AS additional_cost_incl_tax,
            public.get_default_value('clean_data.purchase_order_line_part', 'conv_factor') AS conv_factor,
            public.get_default_value('clean_data.purchase_order_line_part', 'close_code') AS close_code,
            public.get_default_value('clean_data.purchase_order_line_part', 'close_code_db') AS close_code_db,
            public.get_default_value('clean_data.purchase_order_line_part', 'price_conv_factor') AS price_conv_factor,
            public.get_default_value('clean_data.purchase_order_line_part', 'demand_code_db') AS demand_code_db,
            public.get_default_value('clean_data.purchase_order_line_part', 'ord_conf_reminder_db') AS ord_conf_reminder_db,
            public.get_default_value('clean_data.purchase_order_line_part', 'delivery_reminder_db') AS delivery_reminder_db,
            public.get_default_value('clean_data.purchase_order_line_part', 'receive_case_db') AS receive_case_db,
            public.get_default_value('clean_data.purchase_order_line_part', 'purchase_payment_type_db') AS purchase_payment_type_db,
            public.get_default_value('clean_data.purchase_order_line_part', 'automatic_invoice_db') AS automatic_invoice_db,
            public.get_default_value('clean_data.purchase_order_line_part', 'currency_type') AS currency_type,
            public.get_default_value('clean_data.purchase_order_line_part', 'addr_flag_db') AS addr_flag_db,
            public.get_default_value('clean_data.purchase_order_line_part', 'default_addr_flag_db') AS default_addr_flag_db,
            public.get_default_value('clean_data.purchase_order_line_part', 'company') AS company,
            public.get_default_value('clean_data.purchase_order_line_part', 'freeze_flag') AS freeze_flag,
            public.get_default_value('clean_data.purchase_order_line_part', 'freeze_flag_db') AS freeze_flag_db,
            public.get_default_value('clean_data.purchase_order_line_part', 'intrastat_exempt') AS intrastat_exempt,
            public.get_default_value('clean_data.purchase_order_line_part', 'intrastat_exempt_db') AS intrastat_exempt_db,
            public.get_default_value('clean_data.purchase_order_line_part', 'taxable') AS taxable,
            public.get_default_value('clean_data.purchase_order_line_part', 'taxable_db') AS taxable_db,
            public.get_default_value('clean_data.purchase_order_line_part', 'inventory_part') AS inventory_part,
            public.get_default_value('clean_data.purchase_order_line_part', 'inventory_part_db') AS inventory_part_db,
            public.get_default_value('clean_data.purchase_order_line_part', 'project_address') AS project_address,
            public.get_default_value('clean_data.purchase_order_line_part', 'project_address_db') AS project_address_db,
            public.get_default_value('clean_data.purchase_order_line_part', 'rental') AS rental,
            public.get_default_value('clean_data.purchase_order_line_part', 'rental_db') AS rental_db,
            public.get_default_value('clean_data.purchase_order_line_part', 'external_project_resource') AS external_project_resource,
            public.get_default_value('clean_data.purchase_order_line_part', 'external_project_resource_db') AS external_project_resource_db,
            public.get_default_value('clean_data.purchase_order_line_part', 'sample_percent') AS sample_percent,
            public.get_default_value('clean_data.purchase_order_line_part', 'sample_qty') AS sample_qty,
            public.get_default_value('clean_data.purchase_order_line_part', 'create_fa_obj') AS create_fa_obj,
            public.get_default_value('clean_data.purchase_order_line_part', 'create_fa_obj_db') AS create_fa_obj_db,
            public.get_default_value('clean_data.purchase_order_line_part', 'fa_obj_per_unit') AS fa_obj_per_unit,
            public.get_default_value('clean_data.purchase_order_line_part', 'fa_obj_per_unit_db') AS fa_obj_per_unit_db,
            public.get_default_value('clean_data.purchase_order_line_part', 'tax_liability') AS tax_liability,
            public.get_default_value('clean_data.purchase_order_line_part', 'tax_liability_type') AS tax_liability_type,
            public.get_default_value('clean_data.purchase_order_line_part', 'tax_liability_type_db') AS tax_liability_type_db,
            public.get_default_value('clean_data.purchase_order_line_part', 'ignore_default_taxes_db') AS ignore_default_taxes_db,
            public.get_default_value('clean_data.purchase_order_line_part', 'post_on_purchasing_comp_db') AS post_on_purchasing_comp_db,
            public.get_default_value('clean_data.purchase_order_line_part', 'eng_chg_level') AS eng_chg_level,
            public.get_default_value('clean_data.purchase_order_line_part', 'order_code') AS order_code,
            public.get_default_value('clean_data.purchase_order_line_part', 'ord_conf_rem_num') AS ord_conf_rem_num,
            public.get_default_value('clean_data.purchase_order_line_part', 'delivery_rem_num') AS delivery_rem_num,
            public.get_default_value('clean_data.purchase_order_line_part', 'is_exchange_part') AS is_exchange_part,
            public.get_default_value('clean_data.purchase_order_line_part', 'part_ownership') AS part_ownership,
            public.get_default_value('clean_data.purchase_order_line_part', 'part_ownership_db') AS part_ownership_db,
            public.get_default_value('clean_data.purchase_order_line_part', 'exchange_item') AS exchange_item,
            public.get_default_value('clean_data.purchase_order_line_part', 'exchange_item_db') AS exchange_item_db,
            public.get_default_value('clean_data.purchase_order_line_part', 'qty_scrapped_supplier') AS qty_scrapped_supplier,
            public.get_default_value('clean_data.purchase_order_line_part', 'issue_packaging_material') AS issue_packaging_material,
            public.get_default_value('clean_data.purchase_order_line_part', 'issue_packaging_material_db') AS issue_packaging_material_db,
            public.get_default_value('clean_data.purchase_order_line_part', 'sup_loaned_part_return') AS sup_loaned_part_return
    )
    SELECT
            po.order_no,
            NULLIF(LTRIM(l.num_ligne_sap, '0'), ''),
            d.release_no,
            NULLIF(d.additional_cost_amount, '')::numeric,
            NULLIF(d.additional_cost_incl_tax, '')::numeric,
            l.qte_restant_livrer,
            l.prix_net_unitaire,
            l.prix_net_unitaire,
            NULLIF(d.conv_factor, '')::numeric,
            clean_data.commande_achat_to_num(l.taux_change),
            TO_DATE(l.date_creation, 'DD/MM/YYYY')::timestamp,
            l.designation,
            l.prix_net_unitaire,
            l.prix_net_unitaire,
            TO_DATE(l.date_livraison_planifiee, 'DD/MM/YYYY')::timestamp,
            TO_DATE(l.date_livraison_promise, 'DD/MM/YYYY')::timestamp,
            d.close_code,
            d.close_code_db,
            pa.pre_accounting_id,
            l.numero_projet,
            po.contract,
            l.unite_achat,
            NULLIF(d.price_conv_factor, '')::numeric,
            d.demand_code_db,
            po.currency_code,
            d.ord_conf_reminder_db,
            d.delivery_reminder_db,
            d.receive_case_db,
            d.purchase_payment_type_db,
            d.automatic_invoice_db,
            d.currency_type,
            d.addr_flag_db,
            d.default_addr_flag_db,
            d.company,
            po.contract,
            d.freeze_flag,
            d.freeze_flag_db,
            po.invoicing_supplier,
            d.intrastat_exempt,
            d.intrastat_exempt_db,
            d.taxable,
            d.taxable_db,
            d.inventory_part,
            d.inventory_part_db,
            pc.part_no,
            d.project_address,
            d.project_address_db,
            d.rental,
            d.rental_db,
            d.external_project_resource,
            d.external_project_resource_db,
            NULLIF(d.sample_percent, '')::numeric,
            NULLIF(d.sample_qty, '')::numeric,
            d.create_fa_obj,
            d.create_fa_obj_db,
            d.fa_obj_per_unit,
            d.fa_obj_per_unit_db,
            d.tax_liability,
            d.tax_liability_type,
            d.tax_liability_type_db,
            d.ignore_default_taxes_db,
            d.post_on_purchasing_comp_db,
            d.eng_chg_level,
            d.order_code,
            l.unite_achat,
            TO_DATE(l.date_creation, 'DD/MM/YYYY')::timestamp,
            NULLIF(d.ord_conf_rem_num, '')::numeric,
            NULLIF(d.delivery_rem_num, '')::numeric,
            d.is_exchange_part,
            d.part_ownership,
            d.part_ownership_db,
            d.exchange_item,
            d.exchange_item_db,
            NULLIF(d.qty_scrapped_supplier, '')::numeric,
            d.issue_packaging_material,
            d.issue_packaging_material_db,
            d.sup_loaned_part_return
    FROM clean_data.commande_achat_ifs l
    JOIN clean_data.purchase_order po ON po.order_no = 'S' || l.num_commande_sap
    JOIN clean_data.part_catalog pc ON pc.part_no = l.article_sap
    LEFT JOIN tmp_po_pre_accounting pa ON pa.centre_cout_sap = l.centre_cout_sap
    CROSS JOIN d
    WHERE l.type_ligne_ifs = 'PART'
    ORDER BY l.num_commande_sap, l.num_ligne_sap;

    GET DIAGNOSTICS v_nb_part = ROW_COUNT;

    -- ----------------------------------------------------- lignes sans article
    INSERT INTO clean_data.purchase_order_line_nopart (
            order_no,
            line_no,
            release_no,
            additional_cost_amount,
            additional_cost_incl_tax,
            buy_qty_due,
            buy_unit_price,
            buy_unit_price_incl_tax,
            conv_factor,
            currency_rate,
            date_entered,
            description,
            fbuy_unit_price,
            fbuy_unit_price_incl_tax,
            planned_delivery_date,
            promised_delivery_date,
            close_code,
            close_code_db,
            pre_accounting_id,
            project_id,
            contract,
            buy_unit_meas,
            price_conv_factor,
            demand_code_db,
            currency_code,
            ord_conf_reminder_db,
            delivery_reminder_db,
            receive_case_db,
            purchase_payment_type_db,
            automatic_invoice_db,
            currency_type,
            addr_flag_db,
            default_addr_flag_db,
            company,
            purchase_site,
            freeze_flag,
            freeze_flag_db,
            invoicing_supplier,
            intrastat_exempt,
            intrastat_exempt_db,
            taxable,
            taxable_db,
            inventory_part,
            inventory_part_db,
            project_address,
            project_address_db,
            rental,
            rental_db,
            external_project_resource,
            external_project_resource_db,
            sample_percent,
            sample_qty,
            create_fa_obj,
            create_fa_obj_db,
            fa_obj_per_unit,
            fa_obj_per_unit_db,
            tax_liability,
            tax_liability_type,
            tax_liability_type_db,
            ignore_default_taxes_db,
            post_on_purchasing_comp_db,
            close_tolerance,
            last_activity_date,
            hide_price,
            hide_price_db,
            ord_conf_rem_num,
            delivery_rem_num,
            is_exchange_part
    )
    WITH d AS (SELECT
            public.get_default_value('clean_data.purchase_order_line_nopart', 'release_no') AS release_no,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'additional_cost_amount') AS additional_cost_amount,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'additional_cost_incl_tax') AS additional_cost_incl_tax,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'conv_factor') AS conv_factor,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'close_code') AS close_code,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'close_code_db') AS close_code_db,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'price_conv_factor') AS price_conv_factor,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'demand_code_db') AS demand_code_db,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'ord_conf_reminder_db') AS ord_conf_reminder_db,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'delivery_reminder_db') AS delivery_reminder_db,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'receive_case_db') AS receive_case_db,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'purchase_payment_type_db') AS purchase_payment_type_db,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'automatic_invoice_db') AS automatic_invoice_db,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'currency_type') AS currency_type,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'addr_flag_db') AS addr_flag_db,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'default_addr_flag_db') AS default_addr_flag_db,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'company') AS company,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'freeze_flag') AS freeze_flag,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'freeze_flag_db') AS freeze_flag_db,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'intrastat_exempt') AS intrastat_exempt,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'intrastat_exempt_db') AS intrastat_exempt_db,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'taxable') AS taxable,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'taxable_db') AS taxable_db,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'inventory_part') AS inventory_part,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'inventory_part_db') AS inventory_part_db,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'project_address') AS project_address,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'project_address_db') AS project_address_db,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'rental') AS rental,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'rental_db') AS rental_db,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'external_project_resource') AS external_project_resource,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'external_project_resource_db') AS external_project_resource_db,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'sample_percent') AS sample_percent,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'sample_qty') AS sample_qty,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'create_fa_obj') AS create_fa_obj,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'create_fa_obj_db') AS create_fa_obj_db,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'fa_obj_per_unit') AS fa_obj_per_unit,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'fa_obj_per_unit_db') AS fa_obj_per_unit_db,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'tax_liability') AS tax_liability,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'tax_liability_type') AS tax_liability_type,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'tax_liability_type_db') AS tax_liability_type_db,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'ignore_default_taxes_db') AS ignore_default_taxes_db,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'post_on_purchasing_comp_db') AS post_on_purchasing_comp_db,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'close_tolerance') AS close_tolerance,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'hide_price') AS hide_price,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'hide_price_db') AS hide_price_db,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'ord_conf_rem_num') AS ord_conf_rem_num,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'delivery_rem_num') AS delivery_rem_num,
            public.get_default_value('clean_data.purchase_order_line_nopart', 'is_exchange_part') AS is_exchange_part
    )
    SELECT
            po.order_no,
            NULLIF(LTRIM(l.num_ligne_sap, '0'), ''),
            d.release_no,
            NULLIF(d.additional_cost_amount, '')::numeric,
            NULLIF(d.additional_cost_incl_tax, '')::numeric,
            l.qte_restant_livrer,
            l.prix_net_unitaire,
            l.prix_net_unitaire,
            NULLIF(d.conv_factor, '')::numeric,
            clean_data.commande_achat_to_num(l.taux_change),
            TO_DATE(l.date_creation, 'DD/MM/YYYY')::timestamp,
            l.designation,
            l.prix_net_unitaire,
            l.prix_net_unitaire,
            TO_DATE(l.date_livraison_planifiee, 'DD/MM/YYYY')::timestamp,
            TO_DATE(l.date_livraison_promise, 'DD/MM/YYYY')::timestamp,
            d.close_code,
            d.close_code_db,
            pa.pre_accounting_id,
            l.numero_projet,
            po.contract,
            l.unite_achat,
            NULLIF(d.price_conv_factor, '')::numeric,
            d.demand_code_db,
            po.currency_code,
            d.ord_conf_reminder_db,
            d.delivery_reminder_db,
            d.receive_case_db,
            d.purchase_payment_type_db,
            d.automatic_invoice_db,
            d.currency_type,
            d.addr_flag_db,
            d.default_addr_flag_db,
            d.company,
            po.contract,
            d.freeze_flag,
            d.freeze_flag_db,
            po.invoicing_supplier,
            d.intrastat_exempt,
            d.intrastat_exempt_db,
            d.taxable,
            d.taxable_db,
            d.inventory_part,
            d.inventory_part_db,
            d.project_address,
            d.project_address_db,
            d.rental,
            d.rental_db,
            d.external_project_resource,
            d.external_project_resource_db,
            NULLIF(d.sample_percent, '')::numeric,
            NULLIF(d.sample_qty, '')::numeric,
            d.create_fa_obj,
            d.create_fa_obj_db,
            d.fa_obj_per_unit,
            d.fa_obj_per_unit_db,
            d.tax_liability,
            d.tax_liability_type,
            d.tax_liability_type_db,
            d.ignore_default_taxes_db,
            d.post_on_purchasing_comp_db,
            NULLIF(d.close_tolerance, '')::numeric,
            TO_DATE(l.date_creation, 'DD/MM/YYYY')::timestamp,
            d.hide_price,
            d.hide_price_db,
            NULLIF(d.ord_conf_rem_num, '')::numeric,
            NULLIF(d.delivery_rem_num, '')::numeric,
            d.is_exchange_part
    FROM clean_data.commande_achat_ifs l
    JOIN clean_data.purchase_order po ON po.order_no = 'S' || l.num_commande_sap
    LEFT JOIN tmp_po_pre_accounting pa ON pa.centre_cout_sap = l.centre_cout_sap
    CROSS JOIN d
    WHERE COALESCE(l.type_ligne_ifs, 'NOPART') = 'NOPART'
      AND l.num_ligne_sap IS NOT NULL
    ORDER BY l.num_commande_sap, l.num_ligne_sap;

    GET DIAGNOSTICS v_nb_nopart = ROW_COUNT;

    RAISE NOTICE '[%] Commandes eligibles : %, chargees : % ; exclues : % sans fournisseur IFS, % sans fournisseur de facturation IFS, % sans condition de paiement IFS (cumulables)',
        clock_timestamp(), v_candidats, v_nb_po, v_sans_fournisseur, v_sans_facturation, v_sans_paiement;
    RAISE NOTICE '[%] Lignes PART : % (% postes exclus, article absent de part_catalog) ; lignes NOPART : % ; duree %',
        clock_timestamp(), v_nb_part, v_part_hors_catalogue, v_nb_nopart, clock_timestamp() - v_debut;

    RETURN v_nb_po;
END;
$$;

COMMENT ON FUNCTION clean_data.alimenter_purchase_order() IS
    'Dispatch clean_data.commande_achat_ifs vers purchase_order / purchase_order_line_part / purchase_order_line_nopart (reprise IFS Lot 11, TRUNCATE + INSERT). Renvoie le nombre de commandes chargees.';

-- Exemple :
--   SELECT clean_data.alimenter_commande_achat_ifs();   -- 1. extraction SAP -> table a plat
--   SELECT clean_data.alimenter_purchase_order();       -- 2. dispatch vers les 3 objets IFS
