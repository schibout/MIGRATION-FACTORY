-- L'ancienne signature sans parametre doit disparaitre, sinon PostgreSQL cree une
-- surcharge et les appels sans argument deviennent ambigus.
DROP FUNCTION IF EXISTS clean_data.alimenter_purchase_part_cmp();
CREATE OR REPLACE FUNCTION clean_data.alimenter_purchase_part_cmp(p_contract text DEFAULT 'SJ')
 RETURNS void
 LANGUAGE plpgsql
AS $function$
-- Table directrice : raw_data.composant_sj_cs, filtree sur site = p_contract.
-- purchase_part = articles ACHETES : le tri se fait sur type_article ("Achete"),
-- et non sur un statut de production comme pour les articles PHL.
--
-- Valeurs par defaut : gabarit metier valeurParDefaut/purchase_part.csv, seede en
-- variante COMPOSANT (migration 060) et ajustable via /configuration/valeurs-defaut.
-- Les lignes SJ et CS du gabarit sont identiques : pas de variante par site.
--
-- Colonnes laissees vides par le gabarit : elles ne sont pas dans l'INSERT
-- (eng_attribute, qc_code, stat_grp, note_text, qc_date, over_delivery*, buyer_code,
-- process_type, technical_coordinator_id, statistical_code*, quality_system_level_id,
-- les modeles d'approbation, acquisition_origin, acquisition_reason_id, nbs_code).
-- NOTE_ID est un identifiant genere par IFS : non alimente. OWN_PRODUCTION et
-- PART_CATALOG_DESCRIPTION du gabarit n'existent pas dans clean_data.purchase_part.
DECLARE
    v_count_inserted INTEGER := 0;
    v_count_updated INTEGER := 0;
    v_count_vides INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL;
BEGIN
    IF p_contract NOT IN ('SJ', 'CS') THEN
        RAISE EXCEPTION 'Site invalide: % (attendu: SJ ou CS)', p_contract;
    END IF;
    v_start_time := CURRENT_TIMESTAMP;
    RAISE NOTICE 'Debut de l''alimentation PURCHASE_PART (composants, site %) - %', p_contract, v_start_time;
    INSERT INTO clean_data.purchase_part (
        contract, part_no, description, default_buy_unit_meas, date_cre, acquisition_type,
        acquisition_type_db, action_authorized, action_authorized_db, action_non_authorized,
        action_non_authorized_db, close_code, close_code_db, close_tolerance, company,
        dop_pegged_po_update_flag, dop_pegged_po_update_flag_db, external_resource, external_resource_db,
        inventory_flag, inventory_flag_db, package_part_flag, package_part_flag_db, qualified_manufacturer,
        qualified_manufacturer_db, qualified_supplier, qualified_supplier_db, standard_pack_size,
        std_name_description, std_name_id, taxable, taxable_db
    )
    SELECT DISTINCT ON (TRIM(cmp.code_produit))
        -- site passe en parametre
        p_contract as contract,
        -- code_produit = cle des composants
        SUBSTRING(TRIM(cmp.code_produit), 1, 25) as part_no,
        SUBSTRING(TRIM(COALESCE(NULLIF(TRIM(cmp.libelle_produit), ''), cmp.code_produit)), 1, 200) as description,
        -- unite via transcodification UOM (KG -> kg)
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(TRIM(cmp.unite), '')),
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(cmp.unite)), '')),
            NULLIF(TRIM(cmp.unite), ''),
            'PCE'
        ), 1, 10) as default_buy_unit_meas,
        CURRENT_DATE as date_cre,
        public.get_default_value('clean_data.purchase_part', 'acquisition_type', 'COMPOSANT') as acquisition_type,
        public.get_default_value('clean_data.purchase_part', 'acquisition_type_db', 'COMPOSANT') as acquisition_type_db,
        public.get_default_value('clean_data.purchase_part', 'action_authorized', 'COMPOSANT') as action_authorized,
        public.get_default_value('clean_data.purchase_part', 'action_authorized_db', 'COMPOSANT') as action_authorized_db,
        public.get_default_value('clean_data.purchase_part', 'action_non_authorized', 'COMPOSANT') as action_non_authorized,
        public.get_default_value('clean_data.purchase_part', 'action_non_authorized_db', 'COMPOSANT') as action_non_authorized_db,
        public.get_default_value('clean_data.purchase_part', 'close_code', 'COMPOSANT') as close_code,
        public.get_default_value('clean_data.purchase_part', 'close_code_db', 'COMPOSANT') as close_code_db,
        public.get_default_value('clean_data.purchase_part', 'close_tolerance', 'COMPOSANT')::numeric as close_tolerance,
        public.get_default_value('clean_data.purchase_part', 'company', 'COMPOSANT') as company,
        public.get_default_value('clean_data.purchase_part', 'dop_pegged_po_update_flag', 'COMPOSANT') as dop_pegged_po_update_flag,
        public.get_default_value('clean_data.purchase_part', 'dop_pegged_po_update_flag_db', 'COMPOSANT') as dop_pegged_po_update_flag_db,
        public.get_default_value('clean_data.purchase_part', 'external_resource', 'COMPOSANT') as external_resource,
        public.get_default_value('clean_data.purchase_part', 'external_resource_db', 'COMPOSANT') as external_resource_db,
        public.get_default_value('clean_data.purchase_part', 'inventory_flag', 'COMPOSANT') as inventory_flag,
        public.get_default_value('clean_data.purchase_part', 'inventory_flag_db', 'COMPOSANT') as inventory_flag_db,
        public.get_default_value('clean_data.purchase_part', 'package_part_flag', 'COMPOSANT') as package_part_flag,
        public.get_default_value('clean_data.purchase_part', 'package_part_flag_db', 'COMPOSANT') as package_part_flag_db,
        public.get_default_value('clean_data.purchase_part', 'qualified_manufacturer', 'COMPOSANT') as qualified_manufacturer,
        public.get_default_value('clean_data.purchase_part', 'qualified_manufacturer_db', 'COMPOSANT') as qualified_manufacturer_db,
        public.get_default_value('clean_data.purchase_part', 'qualified_supplier', 'COMPOSANT') as qualified_supplier,
        public.get_default_value('clean_data.purchase_part', 'qualified_supplier_db', 'COMPOSANT') as qualified_supplier_db,
        public.get_default_value('clean_data.purchase_part', 'standard_pack_size', 'COMPOSANT')::numeric as standard_pack_size,
        public.get_default_value('clean_data.purchase_part', 'std_name_description', 'COMPOSANT') as std_name_description,
        public.get_default_value('clean_data.purchase_part', 'std_name_id', 'COMPOSANT') as std_name_id,
        public.get_default_value('clean_data.purchase_part', 'taxable', 'COMPOSANT') as taxable,
        public.get_default_value('clean_data.purchase_part', 'taxable_db', 'COMPOSANT') as taxable_db
    FROM raw_data.composant_sj_cs cmp
    WHERE cmp.code_produit IS NOT NULL
      AND TRIM(cmp.code_produit) != ''
      -- Seules les lignes du site charge
      AND UPPER(TRIM(COALESCE(cmp.site, ''))) = p_contract
      -- Articles achetes uniquement
      AND UPPER(TRIM(COALESCE(cmp.type_article, ''))) LIKE 'ACHET%'
      -- L'article doit exister dans part_catalog (table de base)
      AND EXISTS (
          SELECT 1 FROM clean_data.part_catalog pc
          WHERE pc.part_no = SUBSTRING(TRIM(cmp.code_produit), 1, 25)
      )
      -- Ne pas dupliquer une ligne (contract, part_no) deja presente
      AND NOT EXISTS (
          SELECT 1 FROM clean_data.purchase_part pp
          WHERE pp.contract = p_contract
            AND pp.part_no = SUBSTRING(TRIM(cmp.code_produit), 1, 25)
      )
    ORDER BY TRIM(cmp.code_produit);
    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;
    -- Re-execution idempotente : realignement des lignes deja presentes sur le
    -- gabarit (date_cre exclue : elle daterait de la re-execution).
    WITH src AS (
        SELECT DISTINCT ON (TRIM(cmp.code_produit))
            SUBSTRING(TRIM(cmp.code_produit), 1, 25) as part_no,
            SUBSTRING(TRIM(COALESCE(NULLIF(TRIM(cmp.libelle_produit), ''), cmp.code_produit)), 1, 200) as description,
            SUBSTRING(COALESCE(
                public.get_transcodification('UOM', NULLIF(TRIM(cmp.unite), '')),
                public.get_transcodification('UOM', NULLIF(UPPER(TRIM(cmp.unite)), '')),
                NULLIF(TRIM(cmp.unite), ''),
                'PCE'
            ), 1, 10) as default_buy_unit_meas,
            public.get_default_value('clean_data.purchase_part', 'acquisition_type', 'COMPOSANT') as acquisition_type,
            public.get_default_value('clean_data.purchase_part', 'acquisition_type_db', 'COMPOSANT') as acquisition_type_db,
            public.get_default_value('clean_data.purchase_part', 'action_authorized', 'COMPOSANT') as action_authorized,
            public.get_default_value('clean_data.purchase_part', 'action_authorized_db', 'COMPOSANT') as action_authorized_db,
            public.get_default_value('clean_data.purchase_part', 'action_non_authorized', 'COMPOSANT') as action_non_authorized,
            public.get_default_value('clean_data.purchase_part', 'action_non_authorized_db', 'COMPOSANT') as action_non_authorized_db,
            public.get_default_value('clean_data.purchase_part', 'close_code', 'COMPOSANT') as close_code,
            public.get_default_value('clean_data.purchase_part', 'close_code_db', 'COMPOSANT') as close_code_db,
            public.get_default_value('clean_data.purchase_part', 'close_tolerance', 'COMPOSANT')::numeric as close_tolerance,
            public.get_default_value('clean_data.purchase_part', 'company', 'COMPOSANT') as company,
            public.get_default_value('clean_data.purchase_part', 'dop_pegged_po_update_flag', 'COMPOSANT') as dop_pegged_po_update_flag,
            public.get_default_value('clean_data.purchase_part', 'dop_pegged_po_update_flag_db', 'COMPOSANT') as dop_pegged_po_update_flag_db,
            public.get_default_value('clean_data.purchase_part', 'external_resource', 'COMPOSANT') as external_resource,
            public.get_default_value('clean_data.purchase_part', 'external_resource_db', 'COMPOSANT') as external_resource_db,
            public.get_default_value('clean_data.purchase_part', 'inventory_flag', 'COMPOSANT') as inventory_flag,
            public.get_default_value('clean_data.purchase_part', 'inventory_flag_db', 'COMPOSANT') as inventory_flag_db,
            public.get_default_value('clean_data.purchase_part', 'package_part_flag', 'COMPOSANT') as package_part_flag,
            public.get_default_value('clean_data.purchase_part', 'package_part_flag_db', 'COMPOSANT') as package_part_flag_db,
            public.get_default_value('clean_data.purchase_part', 'qualified_manufacturer', 'COMPOSANT') as qualified_manufacturer,
            public.get_default_value('clean_data.purchase_part', 'qualified_manufacturer_db', 'COMPOSANT') as qualified_manufacturer_db,
            public.get_default_value('clean_data.purchase_part', 'qualified_supplier', 'COMPOSANT') as qualified_supplier,
            public.get_default_value('clean_data.purchase_part', 'qualified_supplier_db', 'COMPOSANT') as qualified_supplier_db,
            public.get_default_value('clean_data.purchase_part', 'standard_pack_size', 'COMPOSANT')::numeric as standard_pack_size,
            public.get_default_value('clean_data.purchase_part', 'std_name_description', 'COMPOSANT') as std_name_description,
            public.get_default_value('clean_data.purchase_part', 'std_name_id', 'COMPOSANT') as std_name_id,
            public.get_default_value('clean_data.purchase_part', 'taxable', 'COMPOSANT') as taxable,
            public.get_default_value('clean_data.purchase_part', 'taxable_db', 'COMPOSANT') as taxable_db
        FROM raw_data.composant_sj_cs cmp
        WHERE cmp.code_produit IS NOT NULL
          AND TRIM(cmp.code_produit) != ''
          AND UPPER(TRIM(COALESCE(cmp.site, ''))) = p_contract
          AND UPPER(TRIM(COALESCE(cmp.type_article, ''))) LIKE 'ACHET%'
        ORDER BY TRIM(cmp.code_produit)
    )
    UPDATE clean_data.purchase_part pp
    SET description = src.description,
        default_buy_unit_meas = src.default_buy_unit_meas,
        acquisition_type = src.acquisition_type,
        acquisition_type_db = src.acquisition_type_db,
        action_authorized = src.action_authorized,
        action_authorized_db = src.action_authorized_db,
        action_non_authorized = src.action_non_authorized,
        action_non_authorized_db = src.action_non_authorized_db,
        close_code = src.close_code,
        close_code_db = src.close_code_db,
        close_tolerance = src.close_tolerance,
        company = src.company,
        dop_pegged_po_update_flag = src.dop_pegged_po_update_flag,
        dop_pegged_po_update_flag_db = src.dop_pegged_po_update_flag_db,
        external_resource = src.external_resource,
        external_resource_db = src.external_resource_db,
        inventory_flag = src.inventory_flag,
        inventory_flag_db = src.inventory_flag_db,
        package_part_flag = src.package_part_flag,
        package_part_flag_db = src.package_part_flag_db,
        qualified_manufacturer = src.qualified_manufacturer,
        qualified_manufacturer_db = src.qualified_manufacturer_db,
        qualified_supplier = src.qualified_supplier,
        qualified_supplier_db = src.qualified_supplier_db,
        standard_pack_size = src.standard_pack_size,
        std_name_description = src.std_name_description,
        std_name_id = src.std_name_id,
        taxable = src.taxable,
        taxable_db = src.taxable_db
    FROM src
    WHERE pp.contract = p_contract
      AND pp.part_no = src.part_no
      AND (
           pp.description, pp.default_buy_unit_meas, pp.acquisition_type, pp.acquisition_type_db,
           pp.action_authorized, pp.action_authorized_db, pp.action_non_authorized,
           pp.action_non_authorized_db, pp.close_code, pp.close_code_db, pp.close_tolerance, pp.company,
           pp.dop_pegged_po_update_flag, pp.dop_pegged_po_update_flag_db, pp.external_resource,
           pp.external_resource_db, pp.inventory_flag, pp.inventory_flag_db, pp.package_part_flag,
           pp.package_part_flag_db, pp.qualified_manufacturer, pp.qualified_manufacturer_db,
           pp.qualified_supplier, pp.qualified_supplier_db, pp.standard_pack_size, pp.std_name_description,
           pp.std_name_id, pp.taxable, pp.taxable_db
          ) IS DISTINCT FROM (
           src.description, src.default_buy_unit_meas, src.acquisition_type, src.acquisition_type_db,
           src.action_authorized, src.action_authorized_db, src.action_non_authorized,
           src.action_non_authorized_db, src.close_code, src.close_code_db, src.close_tolerance, src.company,
           src.dop_pegged_po_update_flag, src.dop_pegged_po_update_flag_db, src.external_resource,
           src.external_resource_db, src.inventory_flag, src.inventory_flag_db, src.package_part_flag,
           src.package_part_flag_db, src.qualified_manufacturer, src.qualified_manufacturer_db,
           src.qualified_supplier, src.qualified_supplier_db, src.standard_pack_size,
           src.std_name_description, src.std_name_id, src.taxable, src.taxable_db
          );
    GET DIAGNOSTICS v_count_updated = ROW_COUNT;
    -- Colonnes que le gabarit laisse vides mais qu'une version precedente de la
    -- procedure (heritee du module PHL) alimentait : on les remet a NULL.
    UPDATE clean_data.purchase_part pp
    SET over_delivery_tolerance = NULL,
        over_delivery = NULL,
        over_delivery_db = NULL,
        process_type = NULL
    FROM raw_data.composant_sj_cs cmp
    WHERE pp.contract = p_contract
      AND pp.part_no = SUBSTRING(TRIM(cmp.code_produit), 1, 25)
      AND UPPER(TRIM(COALESCE(cmp.site, ''))) = p_contract
      AND (pp.over_delivery_tolerance IS NOT NULL
        OR pp.over_delivery IS NOT NULL
        OR pp.over_delivery_db IS NOT NULL
        OR pp.process_type IS NOT NULL);
    GET DIAGNOSTICS v_count_vides = ROW_COUNT;
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Alimentation PURCHASE_PART (composants) terminee avec succes';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Composants inseres: %', v_count_inserted;
    RAISE NOTICE 'Composants realignes sur le gabarit: %', v_count_updated;
    RAISE NOTICE 'Colonnes hors gabarit remises a NULL: %', v_count_vides;
    RAISE NOTICE 'Duree d''execution: %', v_duration;
    RAISE NOTICE '====================================================';
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'ERREUR lors de l''alimentation PURCHASE_PART (composants)';
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'Code d''erreur: %', SQLSTATE;
        RAISE NOTICE 'Message: %', SQLERRM;
        RAISE NOTICE 'Duree avant erreur: %', v_duration;
        RAISE NOTICE '====================================================';
        RAISE;
END;
$function$
;
