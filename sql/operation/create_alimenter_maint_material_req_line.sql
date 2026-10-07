CREATE OR REPLACE FUNCTION clean_data.alimenter_maint_material_req_line() RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
    v_nb integer := 0;
    v_debut timestamp := clock_timestamp();
    v_fin timestamp;
BEGIN
    -- Rechargement complet a chaque lancement du module, comme jt_task et
    -- jt_task_resource (2026-09-19, demande explicite) : la table etait
    -- incrementale et gardait les lignes des chargements precedents.
    TRUNCATE TABLE clean_data.maint_material_req_line;

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
        public.get_default_value('clean_data.maint_material_req_line', 'qty')::numeric AS qty,
        public.get_default_value('clean_data.maint_material_req_line', 'qty_short')::numeric AS qty_short,
        public.get_default_value('clean_data.maint_material_req_line', 'qty_assigned')::numeric AS qty_assigned,
        public.get_default_value('clean_data.maint_material_req_line', 'qty_returned')::numeric AS qty_returned,
        CASE WHEN trim(r.werks)='9200' THEN 'SJ' WHEN trim(r.werks)='9000' THEN 'CS' ELSE substring(nullif(trim(r.werks),''),1,5) END AS catalog_contract,
        public.get_default_value('clean_data.maint_material_req_line', 'catalog_no') AS catalog_no,
        public.get_default_value('clean_data.maint_material_req_line', 'price_list_no') AS price_list_no,
        public.get_default_value('clean_data.maint_material_req_line', 'list_price')::numeric AS list_price,
        public.get_default_value('clean_data.maint_material_req_line', 'list_price_curr')::numeric AS list_price_curr,
        public.get_default_value('clean_data.maint_material_req_line', 'sale_unit_price')::numeric AS sale_unit_price,
        public.get_default_value('clean_data.maint_material_req_line', 'sale_unit_price_curr')::numeric AS sale_unit_price_curr,
        public.get_default_value('clean_data.maint_material_req_line', 'discount')::numeric AS discount,
        public.get_default_value('clean_data.maint_material_req_line', 'qty_to_invoice')::numeric AS qty_to_invoice,
        -- enwrt est deja de type numeric dans raw_data.resb
        r.enwrt AS cost,
        CASE WHEN trim(coalesce(r.aufnr,'')) ~ '^[0-9]+$' THEN trim(r.aufnr)::numeric END AS wo_no,
        CASE WHEN trim(r.rspos) ~ '^[0-9]+$' THEN trim(r.rspos)::numeric END AS plan_line_no,
        public.get_default_value('clean_data.maint_material_req_line', 'task_plan_line_seq')::numeric AS task_plan_line_seq,
        substring(nullif(trim(r.sernr),''),1,50) AS serial_no,
        public.get_default_value('clean_data.maint_material_req_line', 'condition_code') AS condition_code,
        public.get_default_value('clean_data.maint_material_req_line', 'part_ownership') AS part_ownership,
        public.get_default_value('clean_data.maint_material_req_line', 'part_ownership_db') AS part_ownership_db,
        public.get_default_value('clean_data.maint_material_req_line', 'owner') AS owner,
        public.get_default_value('clean_data.maint_material_req_line', 'supply_code') AS supply_code,
        public.get_default_value('clean_data.maint_material_req_line', 'supply_code_db') AS supply_code_db,
        public.get_default_value('clean_data.maint_material_req_line', 'job_id')::numeric AS job_id,
        public.get_default_value('clean_data.maint_material_req_line', 'is_closed')::numeric AS is_closed,
        public.get_default_value('clean_data.maint_material_req_line', 'pegged_qty')::numeric AS pegged_qty,
        public.get_default_value('clean_data.maint_material_req_line', 'repair_part_flag') AS repair_part_flag,
        public.get_default_value('clean_data.maint_material_req_line', 'manual_line') AS manual_line,
        public.get_default_value('clean_data.maint_material_req_line', 'rwo_equip_object_seq')::numeric AS rwo_equip_object_seq,
        public.get_default_value('clean_data.maint_material_req_line', 'rwo_mch_contract') AS rwo_mch_contract,
        public.get_default_value('clean_data.maint_material_req_line', 'rwo_mch_code') AS rwo_mch_code,
        public.get_default_value('clean_data.maint_material_req_line', 'rwo_contract') AS rwo_contract,
        public.get_default_value('clean_data.maint_material_req_line', 'rwo_org_code') AS rwo_org_code,
        public.get_default_value('clean_data.maint_material_req_line', 'rwo_lot_batch_no') AS rwo_lot_batch_no,
        public.get_default_value('clean_data.maint_material_req_line', 'rwo_err_descr') AS rwo_err_descr,
        public.get_default_value('clean_data.maint_material_req_line', 'rwo_copy_prepost') AS rwo_copy_prepost,
        public.get_default_value('clean_data.maint_material_req_line', 'rwo_copy_prepost_db') AS rwo_copy_prepost_db,
        public.get_default_value('clean_data.maint_material_req_line', 'price_source_db') AS price_source_db,
        public.get_default_value('clean_data.maint_material_req_line', 'price_source_id') AS price_source_id,
        public.get_default_value('clean_data.maint_material_req_line', 'generated') AS generated,
        public.get_default_value('clean_data.maint_material_req_line', 'markup')::numeric AS markup,
        public.get_default_value('clean_data.maint_material_req_line', 'rental') AS rental,
        public.get_default_value('clean_data.maint_material_req_line', 'rental_db') AS rental_db,
        public.get_default_value('clean_data.maint_material_req_line', 'rental_task_res_seq')::numeric AS rental_task_res_seq,
        public.get_default_value('clean_data.maint_material_req_line', 'price_effective_date')::timestamp AS price_effective_date,
        public.get_default_value('clean_data.maint_material_req_line', 'quotation_no') AS quotation_no,
        public.get_default_value('clean_data.maint_material_req_line', 'quotation_rev')::numeric AS quotation_rev,
        public.get_default_value('clean_data.maint_material_req_line', 'wo_quo_no')::numeric AS wo_quo_no,
        public.get_default_value('clean_data.maint_material_req_line', 'quo_spare_seq')::numeric AS quo_spare_seq,
        public.get_default_value('clean_data.maint_material_req_line', 'change_reason') AS change_reason,
        public.get_default_value('clean_data.maint_material_req_line', 'changes_line_item_no')::numeric AS changes_line_item_no,
        public.get_default_value('clean_data.maint_material_req_line', 'qty_changed')::numeric AS qty_changed,
        CASE WHEN trim(coalesce(r.aufpl,'')) ~ '^[0-9]+$' AND trim(coalesce(r.aplzl,'')) ~ '^[0-9]+$' THEN trim(r.aufpl)::numeric * 100000000 + trim(r.aplzl)::numeric END AS task_seq,
        public.get_default_value('clean_data.maint_material_req_line', 'quo_task_seq')::numeric AS quo_task_seq,
        public.get_default_value('clean_data.maint_material_req_line', 'tool_fac_row_no')::numeric AS tool_fac_row_no,
        public.get_default_value('clean_data.maint_material_req_line', 'place_in_facility_db') AS place_in_facility_db,
        public.get_default_value('clean_data.maint_material_req_line', 'swap_part_db') AS swap_part_db,
        public.get_default_value('clean_data.maint_material_req_line', 'serial_in') AS serial_in,
        public.get_default_value('clean_data.maint_material_req_line', 'serial_in_contract') AS serial_in_contract,
        -- VENDOR_NO : numero de compte IFS du fournisseur (600xxx) repris du
        -- fichier de selection, et non le LIFNR SAP brut (la table supplier est
        -- renumerotee). NULL si le fournisseur est inconnu du fichier.
        public.get_vendor_no_ifs(r.lifnr) AS vendor_no,
        public.get_default_value('clean_data.maint_material_req_line', 'supply_source_ref1') AS supply_source_ref1,
        public.get_default_value('clean_data.maint_material_req_line', 'supply_source_ref2') AS supply_source_ref2,
        public.get_default_value('clean_data.maint_material_req_line', 'supply_source_ref3') AS supply_source_ref3,
        public.get_default_value('clean_data.maint_material_req_line', 'supply_source_ref4') AS supply_source_ref4,
        public.get_default_value('clean_data.maint_material_req_line', 'supply_source_ref_state') AS supply_source_ref_state,
        public.get_default_value('clean_data.maint_material_req_line', 'supply_source_ref_type') AS supply_source_ref_type,
        public.get_default_value('clean_data.maint_material_req_line', 'supply_source_ref_type_db') AS supply_source_ref_type_db,
        public.get_default_value('clean_data.maint_material_req_line', 'delivery') AS delivery,
        public.get_default_value('clean_data.maint_material_req_line', 'delivery_db') AS delivery_db,
        public.get_default_value('clean_data.maint_material_req_line', 'part_type') AS part_type,
        public.get_default_value('clean_data.maint_material_req_line', 'part_type_db') AS part_type_db,
        public.get_default_value('clean_data.maint_material_req_line', 'mobile_created') AS mobile_created,
        public.get_default_value('clean_data.maint_material_req_line', 'mobile_created_db') AS mobile_created_db,
        substring(md5('RESB_'||coalesce(trim(r.mandt),'')||'_'||coalesce(trim(r.rsnum),'')||'_'||coalesce(trim(r.rspos),'')),1,10) AS objid,
        public.get_default_value('clean_data.maint_material_req_line', 'objversion') AS objversion,
        public.get_default_value('clean_data.maint_material_req_line', 'cf_alt_on_hand_qty')::numeric AS cf_alt_on_hand_qty,
        public.get_default_value('clean_data.maint_material_req_line', 'cf_ecartqtedispo')::numeric AS cf_ecartqtedispo,
        public.get_default_value('clean_data.maint_material_req_line', 'cf_on_supply_qty')::numeric AS cf_on_supply_qty,
        public.get_default_value('clean_data.maint_material_req_line', 'no_part_description') AS no_part_description,
        public.get_default_value('clean_data.maint_material_req_line', 'buy_unit_meas') AS buy_unit_meas,
        public.get_default_value('clean_data.maint_material_req_line', 'pickup_task_id')::numeric AS pickup_task_id,
        public.get_default_value('clean_data.maint_material_req_line', 'consumed_qty')::numeric AS consumed_qty,
        public.get_default_value('clean_data.maint_material_req_line', 'fbuy_unit_price')::numeric AS fbuy_unit_price,
        public.get_default_value('clean_data.maint_material_req_line', 'external_id') AS external_id,
        public.get_default_value('clean_data.maint_material_req_line', 'sender_type') AS sender_type,
        public.get_default_value('clean_data.maint_material_req_line', 'sender_type_db') AS sender_type_db,
        public.get_default_value('clean_data.maint_material_req_line', 'sender_id') AS sender_id,
        CASE WHEN trim(r.werks)='9200' THEN 'SJ' WHEN trim(r.werks)='9000' THEN 'CS' ELSE substring(nullif(trim(r.werks),''),1,5) END AS supply_site,
        public.get_default_value('clean_data.maint_material_req_line', 'mobile_warranty') AS mobile_warranty,
        public.get_default_value('clean_data.maint_material_req_line', 'mobile_warranty_db') AS mobile_warranty_db,
        public.get_default_value('clean_data.maint_material_req_line', 'purchase_method') AS purchase_method,
        public.get_default_value('clean_data.maint_material_req_line', 'purchase_method_db') AS purchase_method_db,
        public.get_default_value('clean_data.maint_material_req_line', 'service_type') AS service_type,
        COALESCE(public.get_default_value('clean_data.maint_material_req_line', 'note'), 'Déjà sortie SAP') AS note

    FROM raw_data.resb r
    LEFT JOIN raw_data.aufk a ON a.mandt = r.mandt AND a.aufnr = r.aufnr
    WHERE nullif(trim(coalesce(r.matnr,'')), '') IS NOT NULL
      AND (r.xloek IS NULL OR trim(r.xloek) = '')
      -- Composants de type article uniquement (RESB.POSTP = 'L', article
      -- stocke), comme l'onglet Composants de l'ecran Operations ; les postes
      -- non stockes (N), texte (T) et autres sont ecartes. Le filtre sur la
      -- sortie finale (KZEAR = 'X') est retire (2026-10-07, demande explicite) :
      -- il ne gardait que ~7 % des composants (473 lignes au lieu de ~5 900).
      AND r.postp = 'L'
      -- Operations chargees dans jt_task uniquement (2026-10-07, demande
      -- explicite), comme jt_task_resource : une ligne de materiel sans tache
      -- IFS n'a pas de rattachement. jt_task est chargee avant (alimenter_all_operation).
      -- Son perimetre (v_sap_ordre_repris : en-tete AFKO, statut REL non clos)
      -- remplace les anciens filtres AFKO / v_sap_ordre_clos, retires : avec
      -- jt_task fraichement rechargee (stats perimees) l'anti-jointure sur
      -- v_sap_ordre_clos passait en boucle imbriquee (> 9 min).
      AND trim(r.aufpl) ~ '^[0-9]+$' AND trim(r.aplzl) ~ '^[0-9]+$'
      AND EXISTS (
          SELECT 1 FROM clean_data.jt_task t
          WHERE t.task_seq = trim(r.aufpl)::numeric * 100000000 + trim(r.aplzl)::numeric
      )
    -- resb n'a pas de colonne updated_at : on departage par extraction_date
    ORDER BY r.mandt, r.rsnum, r.rspos, r.extraction_date DESC NULLS LAST;

    GET DIAGNOSTICS v_nb = ROW_COUNT;
    v_fin := clock_timestamp();

    INSERT INTO clean_data.etl_log (procedure_name, mode, start_ts, end_ts, status, nb_inserted, nb_updated, nb_deleted, nb_rejected, message)
    VALUES ('clean_data.alimenter_maint_material_req_line', 'FULL', v_debut, v_fin, 'SUCCESS', v_nb, 0, 0, 0,
            'Alimentation MAINT_MATERIAL_REQ_LINE depuis raw_data.resb (SAP réservations/composants d''ordre)');

    RAISE NOTICE '[%] alimenter_maint_material_req_line : % lignes en %', clock_timestamp(), v_nb, v_fin - v_debut;
EXCEPTION WHEN OTHERS THEN
    v_fin := clock_timestamp();
    BEGIN
        INSERT INTO clean_data.etl_log (procedure_name, mode, start_ts, end_ts, status, nb_inserted, nb_updated, nb_deleted, nb_rejected, message)
        VALUES ('clean_data.alimenter_maint_material_req_line', 'FULL', v_debut, v_fin, 'ERROR', v_nb, 0, 0, 0, SQLSTATE || ' - ' || SQLERRM);
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RAISE NOTICE 'ERREUR alimenter_maint_material_req_line : % (%)', SQLERRM, SQLSTATE;
    RAISE;
END $$;
