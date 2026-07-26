-- Généré le 2026-07-09T22:37:54 depuis ifs_fields_catalog.csv / MAINT_MATERIAL_REQ_LINE
CREATE SCHEMA IF NOT EXISTS clean_data;
CREATE TABLE IF NOT EXISTS clean_data.maint_material_req_line (
    maint_material_order_no numeric,
    line_item_no numeric,
    part_no varchar(25),
    spare_contract varchar(5),
    date_required timestamp without time zone,
    plan_qty numeric,
    qty numeric,
    qty_short numeric,
    qty_assigned numeric,
    qty_returned numeric,
    catalog_contract varchar(5),
    catalog_no varchar(25),
    price_list_no varchar(10),
    list_price numeric,
    list_price_curr numeric,
    sale_unit_price numeric,
    sale_unit_price_curr numeric,
    discount numeric,
    qty_to_invoice numeric,
    cost numeric,
    wo_no numeric,
    plan_line_no numeric,
    task_plan_line_seq numeric,
    serial_no varchar(50),
    condition_code varchar(10),
    part_ownership varchar(4000),
    part_ownership_db varchar(20),
    owner varchar(20),
    supply_code varchar(4000),
    supply_code_db varchar(20),
    job_id numeric,
    is_closed numeric,
    pegged_qty numeric,
    repair_part_flag varchar(5),
    manual_line varchar(5),
    rwo_equip_object_seq numeric,
    rwo_mch_contract varchar(5),
    rwo_mch_code varchar(4000),
    rwo_contract varchar(5),
    rwo_org_code varchar(8),
    rwo_lot_batch_no varchar(20),
    rwo_err_descr varchar(60),
    rwo_copy_prepost varchar(4000),
    rwo_copy_prepost_db varchar(20),
    price_source_db varchar(4000),
    price_source_id varchar(10),
    generated varchar(5),
    markup numeric,
    rental varchar(4000),
    rental_db varchar(5),
    rental_task_res_seq numeric,
    price_effective_date timestamp without time zone,
    quotation_no varchar(12),
    quotation_rev numeric,
    wo_quo_no numeric,
    quo_spare_seq numeric,
    change_reason varchar(40),
    changes_line_item_no numeric,
    qty_changed numeric,
    task_seq numeric,
    quo_task_seq numeric,
    tool_fac_row_no numeric,
    place_in_facility_db varchar(20),
    swap_part_db varchar(20),
    serial_in varchar(100),
    serial_in_contract varchar(5),
    vendor_no varchar(20),
    supply_source_ref1 varchar(50),
    supply_source_ref2 varchar(50),
    supply_source_ref3 varchar(50),
    supply_source_ref4 varchar(50),
    supply_source_ref_state varchar(4000),
    supply_source_ref_type varchar(4000),
    supply_source_ref_type_db varchar(20),
    delivery varchar(4000),
    delivery_db varchar(20),
    part_type varchar(4000),
    part_type_db varchar(20),
    mobile_created varchar(4000),
    mobile_created_db varchar(20),
    objid varchar(10),
    objversion varchar(2000),
    cf_alt_on_hand_qty numeric,
    cf_ecartqtedispo numeric,
    cf_on_supply_qty numeric,
    no_part_description varchar(2000),
    buy_unit_meas varchar(10),
    pickup_task_id numeric,
    consumed_qty numeric,
    fbuy_unit_price numeric,
    external_id varchar(500),
    sender_type varchar(4000),
    sender_type_db varchar(20),
    sender_id varchar(50),
    supply_site varchar(5),
    mobile_warranty varchar(4000),
    mobile_warranty_db varchar(20),
    purchase_method varchar(4000),
    purchase_method_db varchar(20),
    service_type varchar(20),
    note varchar(2000)
);
COMMENT ON TABLE clean_data.maint_material_req_line IS 'IFS MAINT_MATERIAL_REQ_LINE - lignes de besoin matière maintenance alimentées depuis SAP RESB';
COMMENT ON COLUMN clean_data.maint_material_req_line.maint_material_order_no IS 'N° bon de sortie maint. - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.line_item_no IS 'N° ligne cde - No ligne materiel de la tâche (1,2,3…)';
COMMENT ON COLUMN clean_data.maint_material_req_line.part_no IS 'N° Article - code article';
COMMENT ON COLUMN clean_data.maint_material_req_line.spare_contract IS 'Site - SJM ou CAST';
COMMENT ON COLUMN clean_data.maint_material_req_line.date_required IS 'Date Demandée - DD/MM/YYYY hh:mm';
COMMENT ON COLUMN clean_data.maint_material_req_line.plan_qty IS 'Qté prévue - Qté demandée';
COMMENT ON COLUMN clean_data.maint_material_req_line.qty IS 'Quantité - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.qty_short IS '!>Qty Short - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.qty_assigned IS 'Qté réservée - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.qty_returned IS 'Quantité sortie annulée - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.catalog_contract IS 'Site article commercial - SJM ou CAST';
COMMENT ON COLUMN clean_data.maint_material_req_line.catalog_no IS 'N° art commercial - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.price_list_no IS 'N° tarif - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.list_price IS 'Liste des prix - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.list_price_curr IS 'Prix vente unitaire/dev. - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.sale_unit_price IS 'Prix vte/unité - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.sale_unit_price_curr IS '!>Sale Unit Price Curr - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.discount IS 'Remise % - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.qty_to_invoice IS 'Qté à facturer - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.cost IS 'Coût - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.wo_no IS 'N° BT - = No BT de JT_TASK';
COMMENT ON COLUMN clean_data.maint_material_req_line.plan_line_no IS 'N° ligne planif - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.task_plan_line_seq IS 'Séq ligne plan tâche - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.serial_no IS 'N° série - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.condition_code IS 'Code condition - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.part_ownership IS 'Propriété - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.part_ownership_db IS 'Propriété - COMPANY OWNED';
COMMENT ON COLUMN clean_data.maint_material_req_line.owner IS 'Propriétaire - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.supply_code IS 'Code approv. - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.supply_code_db IS 'Code approv. - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.job_id IS 'ID tâche - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.is_closed IS 'Fermé - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.pegged_qty IS 'Qté liée - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.repair_part_flag IS 'Article réparation - "FALSE"';
COMMENT ON COLUMN clean_data.maint_material_req_line.manual_line IS '!>Manual Line - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.rwo_equip_object_seq IS 'Séq objet équip. RWO - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.rwo_mch_contract IS 'Site objet du BT de réparation - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.rwo_mch_code IS 'ID objet du BT réparation - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.rwo_contract IS 'Site org. maint. pour BT réparation - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.rwo_org_code IS 'Org. maint. pour BT réparation - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.rwo_lot_batch_no IS 'N° de lot pour BT répar. - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.rwo_err_descr IS 'Directive du BT réparation - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.rwo_copy_prepost IS 'Copier pré-imputations vers BT réparation - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.rwo_copy_prepost_db IS 'Copier pré-imputations vers BT réparation - "FALSE"';
COMMENT ON COLUMN clean_data.maint_material_req_line.price_source_db IS '!>Price Source Db - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.price_source_id IS 'ID origine prix - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.generated IS '!>Generated - "FALSE"';
COMMENT ON COLUMN clean_data.maint_material_req_line.markup IS 'Majoration - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.rental IS 'Location - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.rental_db IS '!>Rental - "FALSE"';
COMMENT ON COLUMN clean_data.maint_material_req_line.rental_task_res_seq IS 'Séq ress tâche location - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.price_effective_date IS 'Date d''effet du prix - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.quotation_no IS 'N° d''offre - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.quotation_rev IS 'Rév. devis - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.wo_quo_no IS 'N° devis BT - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.quo_spare_seq IS '!>Quo Spare Seq - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.change_reason IS 'Modifier motif - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.changes_line_item_no IS 'N° ligne modifications - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.qty_changed IS 'Qté modifiée - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.task_seq IS 'N° tâche - = N° tâche table JT_TASK';
COMMENT ON COLUMN clean_data.maint_material_req_line.quo_task_seq IS 'Séq. tâche devis - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.tool_fac_row_no IS 'N° ligne outil/inst. - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.place_in_facility_db IS 'Placer dans l''installation/Atelier de réparation - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.swap_part_db IS 'Article de remplacement - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.serial_in IS 'Objet supérieur - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.serial_in_contract IS 'Site objet supérieur - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.vendor_no IS 'Fournisseur - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.supply_source_ref1 IS 'Réf1 source approv. - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.supply_source_ref2 IS 'Réf2 source approv. - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.supply_source_ref3 IS 'Réf3 source approv. - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.supply_source_ref4 IS 'Réf4 source approv. - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.supply_source_ref_state IS 'Etat réf source d''approvisionnement - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.supply_source_ref_type IS 'Type réf source approv. - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.supply_source_ref_type_db IS 'Type réf source approv. - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.delivery IS 'Livraison - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.delivery_db IS 'Livraison - "NORMAL"';
COMMENT ON COLUMN clean_data.maint_material_req_line.part_type IS 'Type article - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.part_type_db IS 'Type article - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.mobile_created IS 'Créé à partir de Mobile - ne pas renseigner';
COMMENT ON COLUMN clean_data.maint_material_req_line.mobile_created_db IS 'Créé à partir de Mobile - "FALSE"';
COMMENT ON COLUMN clean_data.maint_material_req_line.objid IS '0 - 0';
COMMENT ON COLUMN clean_data.maint_material_req_line.objversion IS '0 - 0';
COMMENT ON COLUMN clean_data.maint_material_req_line.cf_alt_on_hand_qty IS 'Alt On Hand Qty';
COMMENT ON COLUMN clean_data.maint_material_req_line.cf_ecartqtedispo IS 'Calcul Ecart Qté';
COMMENT ON COLUMN clean_data.maint_material_req_line.cf_on_supply_qty IS 'On Supply Qty';
COMMENT ON COLUMN clean_data.maint_material_req_line.no_part_description IS 'No Part Description';
COMMENT ON COLUMN clean_data.maint_material_req_line.buy_unit_meas IS 'Buy Unit Meas';
COMMENT ON COLUMN clean_data.maint_material_req_line.pickup_task_id IS 'Pickup Task ID';
COMMENT ON COLUMN clean_data.maint_material_req_line.consumed_qty IS 'Consumed Qty';
COMMENT ON COLUMN clean_data.maint_material_req_line.fbuy_unit_price IS 'Fbuy Unit Price';
COMMENT ON COLUMN clean_data.maint_material_req_line.external_id IS 'External ID';
COMMENT ON COLUMN clean_data.maint_material_req_line.sender_type IS 'Sender Type';
COMMENT ON COLUMN clean_data.maint_material_req_line.sender_type_db IS 'Sender Type';
COMMENT ON COLUMN clean_data.maint_material_req_line.sender_id IS 'Sender ID';
COMMENT ON COLUMN clean_data.maint_material_req_line.supply_site IS 'Supply Site';
COMMENT ON COLUMN clean_data.maint_material_req_line.mobile_warranty IS 'Mobile Warranty Part';
COMMENT ON COLUMN clean_data.maint_material_req_line.mobile_warranty_db IS 'Mobile Warranty Part';
COMMENT ON COLUMN clean_data.maint_material_req_line.purchase_method IS 'Purchase Method';
COMMENT ON COLUMN clean_data.maint_material_req_line.purchase_method_db IS 'Purchase Method';
COMMENT ON COLUMN clean_data.maint_material_req_line.service_type IS 'Service Type';
COMMENT ON COLUMN clean_data.maint_material_req_line.note IS 'Note';

CREATE OR REPLACE FUNCTION clean_data.alimenter_maint_material_req_line() RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
    v_nb integer := 0;
    v_debut timestamp := clock_timestamp();
    v_fin timestamp;
BEGIN
    INSERT INTO clean_data.maint_material_req_line (
        maint_material_order_no,
        line_item_no,
        part_no,
        spare_contract,
        date_required,
        plan_qty,
        qty,
        qty_short,
        qty_assigned,
        qty_returned,
        catalog_contract,
        catalog_no,
        price_list_no,
        list_price,
        list_price_curr,
        sale_unit_price,
        sale_unit_price_curr,
        discount,
        qty_to_invoice,
        cost,
        wo_no,
        plan_line_no,
        task_plan_line_seq,
        serial_no,
        condition_code,
        part_ownership,
        part_ownership_db,
        owner,
        supply_code,
        supply_code_db,
        job_id,
        is_closed,
        pegged_qty,
        repair_part_flag,
        manual_line,
        rwo_equip_object_seq,
        rwo_mch_contract,
        rwo_mch_code,
        rwo_contract,
        rwo_org_code,
        rwo_lot_batch_no,
        rwo_err_descr,
        rwo_copy_prepost,
        rwo_copy_prepost_db,
        price_source_db,
        price_source_id,
        generated,
        markup,
        rental,
        rental_db,
        rental_task_res_seq,
        price_effective_date,
        quotation_no,
        quotation_rev,
        wo_quo_no,
        quo_spare_seq,
        change_reason,
        changes_line_item_no,
        qty_changed,
        task_seq,
        quo_task_seq,
        tool_fac_row_no,
        place_in_facility_db,
        swap_part_db,
        serial_in,
        serial_in_contract,
        vendor_no,
        supply_source_ref1,
        supply_source_ref2,
        supply_source_ref3,
        supply_source_ref4,
        supply_source_ref_state,
        supply_source_ref_type,
        supply_source_ref_type_db,
        delivery,
        delivery_db,
        part_type,
        part_type_db,
        mobile_created,
        mobile_created_db,
        objid,
        objversion,
        cf_alt_on_hand_qty,
        cf_ecartqtedispo,
        cf_on_supply_qty,
        no_part_description,
        buy_unit_meas,
        pickup_task_id,
        consumed_qty,
        fbuy_unit_price,
        external_id,
        sender_type,
        sender_type_db,
        sender_id,
        supply_site,
        mobile_warranty,
        mobile_warranty_db,
        purchase_method,
        purchase_method_db,
        service_type,
        note

    )
    SELECT DISTINCT ON (r.mandt, r.rsnum, r.rspos)
        CASE WHEN trim(r.rsnum) ~ '^[0-9]+$' THEN trim(r.rsnum)::numeric END AS maint_material_order_no,
        CASE WHEN trim(r.rspos) ~ '^[0-9]+$' THEN trim(r.rspos)::numeric END AS line_item_no,
        substring(trim(ltrim(r.matnr,'0')),1,25) AS part_no,
        CASE WHEN trim(r.werks)='9200' THEN 'SJ' WHEN trim(r.werks)='9000' THEN 'CS' ELSE substring(nullif(trim(r.werks),''),1,5) END AS spare_contract,
        CASE WHEN trim(coalesce(r.bdter,'')) ~ '^[0-9]{8}$' AND trim(r.bdter)<>'00000000' THEN to_timestamp(trim(r.bdter),'YYYYMMDD')::timestamp END AS date_required,
        -- bdmng est deja de type numeric dans raw_data.resb (contrairement aux autres tables raw_data)
        r.bdmng AS plan_qty,
        NULL AS qty,
        NULL AS qty_short,
        NULL AS qty_assigned,
        NULL AS qty_returned,
        CASE WHEN trim(r.werks)='9200' THEN 'SJ' WHEN trim(r.werks)='9000' THEN 'CS' ELSE substring(nullif(trim(r.werks),''),1,5) END AS catalog_contract,
        NULL AS catalog_no,
        NULL AS price_list_no,
        NULL AS list_price,
        NULL AS list_price_curr,
        NULL AS sale_unit_price,
        NULL AS sale_unit_price_curr,
        NULL AS discount,
        NULL AS qty_to_invoice,
        -- enwrt est deja de type numeric dans raw_data.resb
        r.enwrt AS cost,
        CASE WHEN trim(coalesce(r.aufnr,'')) ~ '^[0-9]+$' THEN trim(r.aufnr)::numeric END AS wo_no,
        CASE WHEN trim(r.rspos) ~ '^[0-9]+$' THEN trim(r.rspos)::numeric END AS plan_line_no,
        NULL AS task_plan_line_seq,
        substring(nullif(trim(r.sernr),''),1,50) AS serial_no,
        NULL AS condition_code,
        NULL AS part_ownership,
        'COMPANY OWNED' AS part_ownership_db,
        NULL AS owner,
        NULL AS supply_code,
        'INVENT_ORDER' AS supply_code_db,
        NULL AS job_id,
        NULL AS is_closed,
        NULL AS pegged_qty,
        NULL AS repair_part_flag,
        NULL AS manual_line,
        NULL AS rwo_equip_object_seq,
        NULL AS rwo_mch_contract,
        NULL AS rwo_mch_code,
        NULL AS rwo_contract,
        NULL AS rwo_org_code,
        NULL AS rwo_lot_batch_no,
        NULL AS rwo_err_descr,
        NULL AS rwo_copy_prepost,
        NULL AS rwo_copy_prepost_db,
        NULL AS price_source_db,
        NULL AS price_source_id,
        NULL AS generated,
        NULL AS markup,
        NULL AS rental,
        NULL AS rental_db,
        NULL AS rental_task_res_seq,
        NULL AS price_effective_date,
        NULL AS quotation_no,
        NULL AS quotation_rev,
        NULL AS wo_quo_no,
        NULL AS quo_spare_seq,
        NULL AS change_reason,
        NULL AS changes_line_item_no,
        NULL AS qty_changed,
        CASE WHEN trim(coalesce(r.aufpl,'')) ~ '^[0-9]+$' AND trim(coalesce(r.aplzl,'')) ~ '^[0-9]+$' THEN trim(r.aufpl)::numeric * 100000000 + trim(r.aplzl)::numeric END AS task_seq,
        NULL AS quo_task_seq,
        NULL AS tool_fac_row_no,
        NULL AS place_in_facility_db,
        NULL AS swap_part_db,
        NULL AS serial_in,
        NULL AS serial_in_contract,
        substring(nullif(trim(r.lifnr),''),1,20) AS vendor_no,
        NULL AS supply_source_ref1,
        NULL AS supply_source_ref2,
        NULL AS supply_source_ref3,
        NULL AS supply_source_ref4,
        NULL AS supply_source_ref_state,
        NULL AS supply_source_ref_type,
        NULL AS supply_source_ref_type_db,
        NULL AS delivery,
        NULL AS delivery_db,
        NULL AS part_type,
        NULL AS part_type_db,
        NULL AS mobile_created,
        NULL AS mobile_created_db,
        substring(md5('RESB_'||coalesce(trim(r.mandt),'')||'_'||coalesce(trim(r.rsnum),'')||'_'||coalesce(trim(r.rspos),'')),1,10) AS objid,
        '1' AS objversion,
        NULL AS cf_alt_on_hand_qty,
        NULL AS cf_ecartqtedispo,
        NULL AS cf_on_supply_qty,
        NULL AS no_part_description,
        NULL AS buy_unit_meas,
        NULL AS pickup_task_id,
        NULL AS consumed_qty,
        NULL AS fbuy_unit_price,
        NULL AS external_id,
        NULL AS sender_type,
        NULL AS sender_type_db,
        NULL AS sender_id,
        CASE WHEN trim(r.werks)='9200' THEN 'SJ' WHEN trim(r.werks)='9000' THEN 'CS' ELSE substring(nullif(trim(r.werks),''),1,5) END AS supply_site,
        NULL AS mobile_warranty,
        NULL AS mobile_warranty_db,
        NULL AS purchase_method,
        NULL AS purchase_method_db,
        NULL AS service_type,
        substring(nullif(trim(r.sgtxt),''),1,2000) AS note

    FROM raw_data.resb r
    LEFT JOIN raw_data.aufk a ON a.mandt = r.mandt AND a.aufnr = r.aufnr
    LEFT JOIN raw_data.afko k ON k.mandt = r.mandt AND trim(k.aufnr) = trim(r.aufnr)
    WHERE nullif(trim(coalesce(r.matnr,'')), '') IS NOT NULL
      AND (r.xloek IS NULL OR trim(r.xloek) = '')
      AND (r.kzear IS NULL OR trim(r.kzear) = '')
      -- Ne reprendre QUE les donnees de 2026 : ordre dont la date de debut de base
      -- (AFKO.GSTRP, format SAP texte YYYYMMDD) tombe sur l'annee 2026.
      AND trim(k.gstrp) ~ '^[0-9]{8}$'
      AND left(trim(k.gstrp), 4) = '2026'
      AND NOT EXISTS (
          SELECT 1 FROM clean_data.maint_material_req_line c
          WHERE c.maint_material_order_no = CASE WHEN trim(r.rsnum) ~ '^[0-9]+$' THEN trim(r.rsnum)::numeric END
            AND c.line_item_no = CASE WHEN trim(r.rspos) ~ '^[0-9]+$' THEN trim(r.rspos)::numeric END
      )
    -- resb n'a pas de colonne updated_at : on departage par extraction_date
    ORDER BY r.mandt, r.rsnum, r.rspos, r.extraction_date DESC NULLS LAST;

    GET DIAGNOSTICS v_nb = ROW_COUNT;
    v_fin := clock_timestamp();

    INSERT INTO clean_data.etl_log (procedure_name, mode, start_ts, end_ts, status, nb_inserted, nb_updated, nb_deleted, nb_rejected, message)
    VALUES ('clean_data.alimenter_maint_material_req_line', 'DELTA', v_debut, v_fin, 'SUCCESS', v_nb, 0, 0, 0,
            'Alimentation MAINT_MATERIAL_REQ_LINE depuis raw_data.resb (SAP réservations/composants d''ordre)');

    RAISE NOTICE '[%] alimenter_maint_material_req_line : % lignes en %', clock_timestamp(), v_nb, v_fin - v_debut;
EXCEPTION WHEN OTHERS THEN
    v_fin := clock_timestamp();
    BEGIN
        INSERT INTO clean_data.etl_log (procedure_name, mode, start_ts, end_ts, status, nb_inserted, nb_updated, nb_deleted, nb_rejected, message)
        VALUES ('clean_data.alimenter_maint_material_req_line', 'DELTA', v_debut, v_fin, 'ERROR', v_nb, 0, 0, 0, SQLSTATE || ' - ' || SQLERRM);
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RAISE NOTICE 'ERREUR alimenter_maint_material_req_line : % (%)', SQLERRM, SQLSTATE;
    RAISE;
END $$;
