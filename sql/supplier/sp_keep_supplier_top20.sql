CREATE OR REPLACE PROCEDURE clean_data.sp_keep_supplier_top20(
    p_sample_size INTEGER DEFAULT 20
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_start_time TIMESTAMP;
    v_total_suppliers INTEGER;
    v_deleted_count INTEGER := 0;
    v_table_deleted INTEGER;
BEGIN
    v_start_time := NOW();
    
    SELECT COUNT(*) INTO v_total_suppliers FROM clean_data.supplier_info_general;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'ÉCHANTILLONNAGE TOP % FOURNISSEURS', p_sample_size;
    RAISE NOTICE 'Total actuel: %', v_total_suppliers;
    RAISE NOTICE '========================================';
    
    IF v_total_suppliers <= p_sample_size THEN
        RAISE NOTICE 'Aucune suppression nécessaire (% <= %)', v_total_suppliers, p_sample_size;
        RETURN;
    END IF;
    
    DROP TABLE IF EXISTS _temp_top_suppliers;
    CREATE TEMP TABLE _temp_top_suppliers AS
    SELECT supplier_id 
    FROM clean_data.supplier_info_general 
    ORDER BY supplier_id
    LIMIT p_sample_size;
    
    RAISE NOTICE 'Fournisseurs sélectionnés: %', (SELECT COUNT(*) FROM _temp_top_suppliers);
    RAISE NOTICE 'IDs: %', (SELECT string_agg(supplier_id, ', ' ORDER BY supplier_id) FROM _temp_top_suppliers);

    -- 1. payment_way_per_identity
    BEGIN
        DELETE FROM clean_data.payment_way_per_identity 
        WHERE party_type_db = 'SUPPLIER' 
          AND identity NOT IN (SELECT supplier_id FROM _temp_top_suppliers);
        GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
        v_deleted_count := v_deleted_count + v_table_deleted;
        RAISE NOTICE '  ✓ payment_way_per_identity: % supprimées', v_table_deleted;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE '  ⚠ payment_way_per_identity: table absente';
    END;

    -- 2. payment_address
    BEGIN
        DELETE FROM clean_data.payment_address 
        WHERE party_type_db = 'SUPPLIER' 
          AND identity NOT IN (SELECT supplier_id FROM _temp_top_suppliers);
        GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
        v_deleted_count := v_deleted_count + v_table_deleted;
        RAISE NOTICE '  ✓ payment_address: % supprimées', v_table_deleted;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE '  ⚠ payment_address: table absente';
    END;

    -- 3. supplier_delivery_tax_code
    BEGIN
        DELETE FROM clean_data.supplier_delivery_tax_code 
        WHERE supplier_id NOT IN (SELECT supplier_id FROM _temp_top_suppliers);
        GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
        v_deleted_count := v_deleted_count + v_table_deleted;
        RAISE NOTICE '  ✓ supplier_delivery_tax_code: % supprimées', v_table_deleted;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE '  ⚠ supplier_delivery_tax_code: table absente';
    END;

    -- 4. supplier_tax_info
    BEGIN
        DELETE FROM clean_data.supplier_tax_info 
        WHERE supplier_id NOT IN (SELECT supplier_id FROM _temp_top_suppliers);
        GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
        v_deleted_count := v_deleted_count + v_table_deleted;
        RAISE NOTICE '  ✓ supplier_tax_info: % supprimées', v_table_deleted;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE '  ⚠ supplier_tax_info: table absente';
    END;

    -- 5. supplier_document_tax_info
    BEGIN
        DELETE FROM clean_data.supplier_document_tax_info 
        WHERE supplier_id NOT IN (SELECT supplier_id FROM _temp_top_suppliers);
        GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
        v_deleted_count := v_deleted_count + v_table_deleted;
        RAISE NOTICE '  ✓ supplier_document_tax_info: % supprimées', v_table_deleted;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE '  ⚠ supplier_document_tax_info: table absente';
    END;

    -- 6. identity_pay_info
    BEGIN
        DELETE FROM clean_data.identity_pay_info 
        WHERE party_type_db = 'SUPPLIER' 
          AND identity NOT IN (SELECT supplier_id FROM _temp_top_suppliers);
        GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
        v_deleted_count := v_deleted_count + v_table_deleted;
        RAISE NOTICE '  ✓ identity_pay_info: % supprimées', v_table_deleted;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE '  ⚠ identity_pay_info: table absente';
    END;

    -- 7. identity_invoice_info
    BEGIN
        DELETE FROM clean_data.identity_invoice_info 
        WHERE party_type_db = 'SUPPLIER' 
          AND identity NOT IN (SELECT supplier_id FROM _temp_top_suppliers);
        GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
        v_deleted_count := v_deleted_count + v_table_deleted;
        RAISE NOTICE '  ✓ identity_invoice_info: % supprimées', v_table_deleted;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE '  ⚠ identity_invoice_info: table absente';
    END;

    -- 8. comm_method
    BEGIN
        DELETE FROM clean_data.comm_method 
        WHERE party_type_db = 'SUPPLIER' 
          AND identity NOT IN (SELECT supplier_id FROM _temp_top_suppliers);
        GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
        v_deleted_count := v_deleted_count + v_table_deleted;
        RAISE NOTICE '  ✓ comm_method: % supprimées', v_table_deleted;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE '  ⚠ comm_method: table absente';
    END;

    -- 9. supplier_info_address_type
    BEGIN
        DELETE FROM clean_data.supplier_info_address_type 
        WHERE supplier_id NOT IN (SELECT supplier_id FROM _temp_top_suppliers);
        GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
        v_deleted_count := v_deleted_count + v_table_deleted;
        RAISE NOTICE '  ✓ supplier_info_address_type: % supprimées', v_table_deleted;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE '  ⚠ supplier_info_address_type: table absente';
    END;

    -- 10. supplier_address
    BEGIN
        DELETE FROM clean_data.supplier_address 
        WHERE vendor_no NOT IN (SELECT supplier_id FROM _temp_top_suppliers);
        GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
        v_deleted_count := v_deleted_count + v_table_deleted;
        RAISE NOTICE '  ✓ supplier_address: % supprimées', v_table_deleted;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE '  ⚠ supplier_address: table absente';
    END;

    -- 11. supplier_info_address
    BEGIN
        DELETE FROM clean_data.supplier_info_address 
        WHERE supplier_id NOT IN (SELECT supplier_id FROM _temp_top_suppliers);
        GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
        v_deleted_count := v_deleted_count + v_table_deleted;
        RAISE NOTICE '  ✓ supplier_info_address: % supprimées', v_table_deleted;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE '  ⚠ supplier_info_address: table absente';
    END;

    -- 12. supplier
    BEGIN
        DELETE FROM clean_data.supplier 
        WHERE vendor_no NOT IN (SELECT supplier_id FROM _temp_top_suppliers);
        GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
        v_deleted_count := v_deleted_count + v_table_deleted;
        RAISE NOTICE '  ✓ supplier: % supprimées', v_table_deleted;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE '  ⚠ supplier: table absente';
    END;

    -- 13. supplier_info_our_id
    BEGIN
        DELETE FROM clean_data.supplier_info_our_id 
        WHERE supplier_id NOT IN (SELECT supplier_id FROM _temp_top_suppliers);
        GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
        v_deleted_count := v_deleted_count + v_table_deleted;
        RAISE NOTICE '  ✓ supplier_info_our_id: % supprimées', v_table_deleted;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE '  ⚠ supplier_info_our_id: table absente';
    END;

    -- 14. supplier_info_general (table principale - en dernier)
    DELETE FROM clean_data.supplier_info_general 
    WHERE supplier_id NOT IN (SELECT supplier_id FROM _temp_top_suppliers);
    GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
    v_deleted_count := v_deleted_count + v_table_deleted;
    RAISE NOTICE '  ✓ supplier_info_general: % supprimées', v_table_deleted;

    -- 15. ifs_fournisseurs
    BEGIN
        DELETE FROM clean_data.ifs_fournisseurs 
        WHERE numero_compte_fournisseur NOT IN (SELECT supplier_id FROM _temp_top_suppliers);
        GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
        v_deleted_count := v_deleted_count + v_table_deleted;
        RAISE NOTICE '  ✓ ifs_fournisseurs: % supprimées', v_table_deleted;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE '  ⚠ ifs_fournisseurs: table absente';
    END;

    DROP TABLE IF EXISTS _temp_top_suppliers;

    RAISE NOTICE '========================================';
    RAISE NOTICE 'TERMINÉ';
    RAISE NOTICE 'Fournisseurs restants: %', (SELECT COUNT(*) FROM clean_data.supplier_info_general);
    RAISE NOTICE 'Total lignes supprimées: %', v_deleted_count;
    RAISE NOTICE 'Durée: % sec', EXTRACT(EPOCH FROM (NOW() - v_start_time));
    RAISE NOTICE '========================================';

EXCEPTION
    WHEN OTHERS THEN
        DROP TABLE IF EXISTS _temp_top_suppliers;
        RAISE EXCEPTION '❌ Erreur: %', SQLERRM;
END;
$procedure$;
