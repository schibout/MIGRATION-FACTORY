CREATE OR REPLACE PROCEDURE clean_data.sp_update_customer_id_cascade(
    p_old_customer_id VARCHAR,
    p_new_customer_id VARCHAR
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_updated_count INTEGER := 0;
    v_total_updated INTEGER := 0;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début mise à jour customer_id: % → % - %',
        p_old_customer_id, p_new_customer_id, TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');

    -- Vérifier que l'ancien customer_id existe
    IF NOT EXISTS (SELECT 1 FROM clean_data.customer_info WHERE customer_id = p_old_customer_id) THEN
        RAISE EXCEPTION 'Customer_id % n''existe pas dans customer_info', p_old_customer_id;
    END IF;

    -- Vérifier que le nouveau customer_id n'existe pas déjà
    IF EXISTS (SELECT 1 FROM clean_data.customer_info WHERE customer_id = p_new_customer_id) THEN
        RAISE EXCEPTION 'Customer_id % existe déjà dans customer_info', p_new_customer_id;
    END IF;

    -- =========================================================
    -- PALIER 1 : tables 1 à 10
    -- =========================================================
    RAISE NOTICE '--- Palier 1/2 (tables 1-10) ---';

    -- 1. customer_info (table principale)
    UPDATE clean_data.customer_info
    SET customer_id = p_new_customer_id,
        updated_at = NOW()
    WHERE customer_id = p_old_customer_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ customer_info: % lignes mises à jour', v_updated_count;

    -- 2. customer_info_cfv
    UPDATE clean_data.customer_info_cfv
    SET customer_id = p_new_customer_id,
        updated_at = NOW()
    WHERE customer_id = p_old_customer_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ customer_info_cfv: % lignes mises à jour', v_updated_count;

    -- 3. customer_info_address
    UPDATE clean_data.customer_info_address
    SET customer_id = p_new_customer_id
    WHERE customer_id = p_old_customer_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ customer_info_address: % lignes mises à jour', v_updated_count;

    -- 4. customer_info_address_type
    UPDATE clean_data.customer_info_address_type
    SET customer_id = p_new_customer_id
    WHERE customer_id = p_old_customer_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ customer_info_address_type: % lignes mises à jour', v_updated_count;

    -- 5. customer_info_contact
    UPDATE clean_data.customer_info_contact
    SET customer_id = p_new_customer_id
    WHERE customer_id = p_old_customer_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ customer_info_contact: % lignes mises à jour', v_updated_count;

    -- 6. comm_method
    UPDATE clean_data.comm_method
    SET customer_id = p_new_customer_id
    WHERE customer_id = p_old_customer_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ comm_method: % lignes mises à jour', v_updated_count;

    -- 7. cus_comm_method (identity = customer_id)
    UPDATE clean_data.cus_comm_method
    SET identity = p_new_customer_id
    WHERE identity = p_old_customer_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ cus_comm_method: % lignes mises à jour', v_updated_count;

    -- 8. cus_ident_invoice_info (identity = customer_id)
    UPDATE clean_data.cus_ident_invoice_info
    SET identity = p_new_customer_id
    WHERE identity = p_old_customer_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ cus_ident_invoice_info: % lignes mises à jour', v_updated_count;

    -- 9. cus_identity_pay_info (identity = customer_id)
    UPDATE clean_data.cus_identity_pay_info
    SET identity = p_new_customer_id
    WHERE identity = p_old_customer_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ cus_identity_pay_info: % lignes mises à jour', v_updated_count;

    -- 10. customer_credit_info (identity = customer_id)
    UPDATE clean_data.customer_credit_info
    SET identity = p_new_customer_id
    WHERE identity = p_old_customer_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ customer_credit_info: % lignes mises à jour', v_updated_count;

    COMMIT;
    RAISE NOTICE '✔ Palier 1/2 committé';

    -- =========================================================
    -- PALIER 2 : tables 11 à 20
    -- =========================================================
    RAISE NOTICE '--- Palier 2/2 (tables 11-20) ---';

    -- 11. customer_addr_tax_number
    UPDATE clean_data.customer_addr_tax_number
    SET customer_id = p_new_customer_id
    WHERE customer_id = p_old_customer_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ customer_addr_tax_number: % lignes mises à jour', v_updated_count;

    -- 12. customer_del_tax_exempt
    UPDATE clean_data.customer_del_tax_exempt
    SET customer_id = p_new_customer_id
    WHERE customer_id = p_old_customer_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ customer_del_tax_exempt: % lignes mises à jour', v_updated_count;

    -- 13. customer_delivery_fee_code
    UPDATE clean_data.customer_delivery_fee_code
    SET customer_id = p_new_customer_id
    WHERE customer_id = p_old_customer_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ customer_delivery_fee_code: % lignes mises à jour', v_updated_count;

    -- 14. customer_delivery_tax_info
    UPDATE clean_data.customer_delivery_tax_info
    SET customer_id = p_new_customer_id
    WHERE customer_id = p_old_customer_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ customer_delivery_tax_info: % lignes mises à jour', v_updated_count;

    -- 15. customer_document_tax_info
    UPDATE clean_data.customer_document_tax_info
    SET customer_id = p_new_customer_id
    WHERE customer_id = p_old_customer_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ customer_document_tax_info: % lignes mises à jour', v_updated_count;

    -- 16. customer_tax_free_tax_code
    UPDATE clean_data.customer_tax_free_tax_code
    SET customer_id = p_new_customer_id
    WHERE customer_id = p_old_customer_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ customer_tax_free_tax_code: % lignes mises à jour', v_updated_count;

    -- 17. customer_tax_info
    UPDATE clean_data.customer_tax_info
    SET customer_id = p_new_customer_id
    WHERE customer_id = p_old_customer_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ customer_tax_info: % lignes mises à jour', v_updated_count;

    -- 18. identity_invoice_info
    UPDATE clean_data.identity_invoice_info
    SET customer_id = p_new_customer_id
    WHERE customer_id = p_old_customer_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ identity_invoice_info: % lignes mises à jour', v_updated_count;

    -- 19. identity_pay_info
    UPDATE clean_data.identity_pay_info
    SET customer_id = p_new_customer_id
    WHERE customer_id = p_old_customer_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ identity_pay_info: % lignes mises à jour', v_updated_count;

    -- 20. project_base
    UPDATE clean_data.project_base
    SET customer_id = p_new_customer_id
    WHERE customer_id = p_old_customer_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ project_base: % lignes mises à jour', v_updated_count;

    COMMIT;
    RAISE NOTICE '✔ Palier 2/2 committé';

    v_end_time := NOW();
    RAISE NOTICE '✅ Mise à jour terminée - %: % lignes au total mises à jour dans 20 tables',
        TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_total_updated;
    RAISE NOTICE 'Durée d''exécution: % secondes',
        EXTRACT(EPOCH FROM (v_end_time - v_start_time));

EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION '❌ Erreur lors de la mise à jour customer_id - %: %',
            TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$;
