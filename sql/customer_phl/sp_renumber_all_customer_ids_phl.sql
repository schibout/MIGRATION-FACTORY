CREATE OR REPLACE PROCEDURE clean_data.sp_renumber_all_customer_ids_phl(IN p_starting_id integer DEFAULT 700000)
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_old_customer_id VARCHAR;
    v_new_customer_id VARCHAR;
    v_counter INTEGER := 0;
    v_total_updated INTEGER := 0;
    v_customer_count INTEGER := 0;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Début renumérotation customer_id PHL - %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    RAISE NOTICE 'ID de départ: %', p_starting_id;
    RAISE NOTICE '========================================';
    
    -- Compter le nombre de clients PHL à traiter
    SELECT COUNT(*) INTO v_customer_count
    FROM clean_data.customer_info;
    
    RAISE NOTICE 'Nombre de clients PHL à renuméroter: %', v_customer_count;
    
    -- Créer une table temporaire pour stocker le mapping des anciens et nouveaux IDs
    CREATE TEMP TABLE IF NOT EXISTS temp_customer_id_mapping_phl (
        old_customer_id VARCHAR(50),
        new_customer_id VARCHAR(50),
        row_num INTEGER
    );
    
    TRUNCATE TABLE temp_customer_id_mapping_phl;
    
    -- Remplir la table temporaire avec les anciens IDs et les nouveaux IDs séquentiels
    INSERT INTO temp_customer_id_mapping_phl (old_customer_id, new_customer_id, row_num)
    SELECT 
        customer_id,
        (p_starting_id + (ROW_NUMBER() OVER (ORDER BY customer_id) - 1) * 10)::VARCHAR,
        ROW_NUMBER() OVER (ORDER BY customer_id)
    FROM clean_data.customer_info
    ORDER BY customer_id;
    
    RAISE NOTICE 'Table temporaire de mapping créée avec % enregistrements', 
        (SELECT COUNT(*) FROM temp_customer_id_mapping_phl);
    
    -- Désactiver temporairement les triggers pour améliorer les performances
    ALTER TABLE clean_data.customer_info DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_info_address DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_info_address_type DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.cus_comm_method DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.cus_ident_invoice_info DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.cus_identity_pay_info DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_credit_info DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_tax_info DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_delivery_tax_info DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_delivery_fee_code DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_document_tax_info DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_tax_free_tax_code DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_addr_tax_number DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_del_tax_exempt DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.cust_ord_customer DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.cust_ord_customer_address DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.cus_paym_way_per_ident DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.cus_payment_address DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.payment_way_per_identity DISABLE TRIGGER ALL;
    
    RAISE NOTICE 'Mise à jour des tables en cascade...';
    
    -- 1. Mettre à jour customer_info (customer_id + legacy as400 avec old_customer_id)
    UPDATE clean_data.customer_info ci
    SET customer_id = m.new_customer_id,
        cf$_legacy_customer_as400_mn = m.old_customer_id
    FROM temp_customer_id_mapping_phl m
    WHERE ci.customer_id = m.old_customer_id;
    GET DIAGNOSTICS v_total_updated = ROW_COUNT;
    v_counter := v_counter + v_total_updated;
    RAISE NOTICE '  ✓ customer_info: % lignes mises à jour (customer_id + legacy as400)', v_total_updated;
    
    -- 2. Mettre à jour customer_info_address
    UPDATE clean_data.customer_info_address cia
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping_phl m
    WHERE cia.customer_id = m.old_customer_id;
    GET DIAGNOSTICS v_total_updated = ROW_COUNT;
    RAISE NOTICE '  ✓ customer_info_address: % lignes mises à jour', v_total_updated;
    
    -- 3. Mettre à jour customer_info_cfv (si elle existe)
    IF EXISTS (SELECT 1 FROM information_schema.tables 
               WHERE table_schema = 'clean_data' AND table_name = 'customer_info_cfv') THEN
        UPDATE clean_data.customer_info_cfv cicfv
        SET customer_id = m.new_customer_id
        FROM temp_customer_id_mapping_phl m
        WHERE cicfv.customer_id = m.old_customer_id;
        GET DIAGNOSTICS v_total_updated = ROW_COUNT;
        RAISE NOTICE '  ✓ customer_info_cfv: % lignes mises à jour', v_total_updated;
    END IF;
    
    -- 4. Mettre à jour cus_comm_method (identity = customer_id)
    UPDATE clean_data.cus_comm_method ccm
    SET identity = m.new_customer_id
    FROM temp_customer_id_mapping_phl m
    WHERE ccm.identity = m.old_customer_id;
    GET DIAGNOSTICS v_total_updated = ROW_COUNT;
    RAISE NOTICE '  ✓ cus_comm_method: % lignes mises à jour', v_total_updated;
    
    -- 5. Mettre à jour cus_ident_invoice_info (identity = customer_id)
    UPDATE clean_data.cus_ident_invoice_info ciii
    SET identity = m.new_customer_id
    FROM temp_customer_id_mapping_phl m
    WHERE ciii.identity = m.old_customer_id;
    GET DIAGNOSTICS v_total_updated = ROW_COUNT;
    RAISE NOTICE '  ✓ cus_ident_invoice_info: % lignes mises à jour', v_total_updated;
    
    -- 6. Mettre à jour cus_identity_pay_info (identity = customer_id)
    UPDATE clean_data.cus_identity_pay_info cipi
    SET identity = m.new_customer_id
    FROM temp_customer_id_mapping_phl m
    WHERE cipi.identity = m.old_customer_id;
    GET DIAGNOSTICS v_total_updated = ROW_COUNT;
    RAISE NOTICE '  ✓ cus_identity_pay_info: % lignes mises à jour', v_total_updated;
    
    -- 7. Mettre à jour customer_credit_info (identity = customer_id)
    UPDATE clean_data.customer_credit_info cci
    SET identity = m.new_customer_id
    FROM temp_customer_id_mapping_phl m
    WHERE cci.identity = m.old_customer_id;
    GET DIAGNOSTICS v_total_updated = ROW_COUNT;
    RAISE NOTICE '  ✓ customer_credit_info: % lignes mises à jour', v_total_updated;
    
    -- 8. Mettre à jour customer_delivery_tax_info (customer_id)
    UPDATE clean_data.customer_delivery_tax_info cdti
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping_phl m
    WHERE cdti.customer_id = m.old_customer_id;
    GET DIAGNOSTICS v_total_updated = ROW_COUNT;
    RAISE NOTICE '  ✓ customer_delivery_tax_info: % lignes mises à jour', v_total_updated;
    
    -- 9. Mettre à jour customer_info_address_type (customer_id)
    UPDATE clean_data.customer_info_address_type ciat
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping_phl m
    WHERE ciat.customer_id = m.old_customer_id;
    GET DIAGNOSTICS v_total_updated = ROW_COUNT;
    RAISE NOTICE '  ✓ customer_info_address_type: % lignes mises à jour', v_total_updated;
    
    -- 10. Mettre à jour customer_tax_info (customer_id)
    UPDATE clean_data.customer_tax_info cti
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping_phl m
    WHERE cti.customer_id = m.old_customer_id;
    GET DIAGNOSTICS v_total_updated = ROW_COUNT;
    RAISE NOTICE '  ✓ customer_tax_info: % lignes mises à jour', v_total_updated;
    
    -- 11. Mettre à jour customer_delivery_fee_code (customer_id)
    UPDATE clean_data.customer_delivery_fee_code cdfc
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping_phl m
    WHERE cdfc.customer_id = m.old_customer_id;
    GET DIAGNOSTICS v_total_updated = ROW_COUNT;
    RAISE NOTICE '  ✓ customer_delivery_fee_code: % lignes mises à jour', v_total_updated;
    
    -- 12. Mettre à jour customer_document_tax_info (customer_id)
    UPDATE clean_data.customer_document_tax_info cdti
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping_phl m
    WHERE cdti.customer_id = m.old_customer_id;
    GET DIAGNOSTICS v_total_updated = ROW_COUNT;
    RAISE NOTICE '  ✓ customer_document_tax_info: % lignes mises à jour', v_total_updated;
    
    -- 13. Mettre à jour customer_tax_free_tax_code (customer_id)
    UPDATE clean_data.customer_tax_free_tax_code ctftc
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping_phl m
    WHERE ctftc.customer_id = m.old_customer_id;
    GET DIAGNOSTICS v_total_updated = ROW_COUNT;
    RAISE NOTICE '  ✓ customer_tax_free_tax_code: % lignes mises à jour', v_total_updated;
    
    -- 14. Mettre à jour customer_addr_tax_number (customer_id)
    UPDATE clean_data.customer_addr_tax_number catn
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping_phl m
    WHERE catn.customer_id = m.old_customer_id;
    GET DIAGNOSTICS v_total_updated = ROW_COUNT;
    RAISE NOTICE '  ✓ customer_addr_tax_number: % lignes mises à jour', v_total_updated;
    
    -- 15. Mettre à jour customer_del_tax_exempt (customer_id)
    UPDATE clean_data.customer_del_tax_exempt cdte
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping_phl m
    WHERE cdte.customer_id = m.old_customer_id;
    GET DIAGNOSTICS v_total_updated = ROW_COUNT;
    RAISE NOTICE '  ✓ customer_del_tax_exempt: % lignes mises à jour', v_total_updated;
    
    -- 16. Mettre à jour cust_ord_customer (customer_no et customer_no_pay)
    UPDATE clean_data.cust_ord_customer coc
    SET customer_no = m.new_customer_id,
        customer_no_pay = m.new_customer_id
    FROM temp_customer_id_mapping_phl m
    WHERE coc.customer_no = m.old_customer_id;
    GET DIAGNOSTICS v_total_updated = ROW_COUNT;
    RAISE NOTICE '  ✓ cust_ord_customer: % lignes mises à jour', v_total_updated;
    
    -- 17. Mettre à jour cust_ord_customer_address (customer_no)
    UPDATE clean_data.cust_ord_customer_address coca
    SET customer_no = m.new_customer_id
    FROM temp_customer_id_mapping_phl m
    WHERE coca.customer_no = m.old_customer_id;
    GET DIAGNOSTICS v_total_updated = ROW_COUNT;
    RAISE NOTICE '  ✓ cust_ord_customer_address: % lignes mises à jour', v_total_updated;
    
    -- 18. Mettre à jour cus_paym_way_per_ident (identity = customer_id)
    UPDATE clean_data.cus_paym_way_per_ident cpwpi
    SET identity = m.new_customer_id
    FROM temp_customer_id_mapping_phl m
    WHERE cpwpi.identity = m.old_customer_id;
    GET DIAGNOSTICS v_total_updated = ROW_COUNT;
    RAISE NOTICE '  ✓ cus_paym_way_per_ident: % lignes mises à jour', v_total_updated;
    
    -- 19. Mettre à jour cus_payment_address (identity = customer_id)
    UPDATE clean_data.cus_payment_address cpa
    SET identity = m.new_customer_id
    FROM temp_customer_id_mapping_phl m
    WHERE cpa.identity = m.old_customer_id;
    GET DIAGNOSTICS v_total_updated = ROW_COUNT;
    RAISE NOTICE '  ✓ cus_payment_address: % lignes mises à jour', v_total_updated;
    
    -- 20. Mettre à jour payment_way_per_identity (identity = customer_id)
    UPDATE clean_data.payment_way_per_identity pwpi
    SET identity = m.new_customer_id
    FROM temp_customer_id_mapping_phl m
    WHERE pwpi.identity = m.old_customer_id;
    GET DIAGNOSTICS v_total_updated = ROW_COUNT;
    RAISE NOTICE '  ✓ payment_way_per_identity: % lignes mises à jour', v_total_updated;
    
    -- Réactiver les triggers
    ALTER TABLE clean_data.customer_info ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_info_address ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_info_address_type ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.cus_comm_method ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.cus_ident_invoice_info ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.cus_identity_pay_info ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_credit_info ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_tax_info ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_delivery_tax_info ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_delivery_fee_code ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_document_tax_info ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_tax_free_tax_code ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_addr_tax_number ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_del_tax_exempt ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.cust_ord_customer ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.cust_ord_customer_address ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.cus_paym_way_per_ident ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.cus_payment_address ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.payment_way_per_identity ENABLE TRIGGER ALL;
    
    -- Statistiques finales
    v_end_time := NOW();
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Renumérotation customer_id PHL terminée - %', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS');
    RAISE NOTICE 'Nombre de clients renumérotés: %', v_counter;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    RAISE NOTICE 'ID de départ utilisé: %', p_starting_id;
    RAISE NOTICE 'ID final: %', (p_starting_id + (v_counter - 1) * 10);
    RAISE NOTICE '========================================';
    
    -- Nettoyer la table temporaire
    DROP TABLE IF EXISTS temp_customer_id_mapping_phl;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Réactiver les triggers en cas d'erreur
        ALTER TABLE clean_data.customer_info ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.customer_info_address ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.customer_info_address_type ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.cus_comm_method ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.cus_ident_invoice_info ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.cus_identity_pay_info ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.customer_credit_info ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.customer_tax_info ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.customer_delivery_tax_info ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.customer_delivery_fee_code ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.customer_document_tax_info ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.customer_tax_free_tax_code ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.customer_addr_tax_number ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.customer_del_tax_exempt ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.cust_ord_customer ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.cust_ord_customer_address ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.cus_paym_way_per_ident ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.cus_payment_address ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.payment_way_per_identity ENABLE TRIGGER ALL;
        
        v_end_time := NOW();
        RAISE EXCEPTION '❌ Erreur lors de la renumérotation customer_id PHL - %: %', 
            TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
