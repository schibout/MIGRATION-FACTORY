-- ============================================================================
-- Procédure pour garder un échantillon de N fournisseurs (défaut: 200)
-- Supprime les données des autres fournisseurs dans toutes les tables liées
-- ============================================================================
CREATE OR REPLACE PROCEDURE clean_data.sp_keep_supplier_sample(
    p_sample_size INTEGER DEFAULT 200
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_total_suppliers INTEGER;
    v_deleted_count INTEGER := 0;
    v_table_deleted INTEGER;
BEGIN
    v_start_time := NOW();
    
    -- Compter le total de fournisseurs
    SELECT COUNT(*) INTO v_total_suppliers FROM clean_data.supplier_info_general;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'ÉCHANTILLONNAGE DES FOURNISSEURS';
    RAISE NOTICE 'Total actuel: % fournisseurs', v_total_suppliers;
    RAISE NOTICE 'Échantillon à garder: % fournisseurs', p_sample_size;
    RAISE NOTICE 'Date: %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    RAISE NOTICE '========================================';
    
    IF v_total_suppliers <= p_sample_size THEN
        RAISE NOTICE 'Aucune suppression nécessaire - nombre actuel (%) <= échantillon demandé (%)', 
            v_total_suppliers, p_sample_size;
        RETURN;
    END IF;
    
    -- Créer une table temporaire avec les IDs à garder (sélection aléatoire)
    DROP TABLE IF EXISTS _temp_suppliers_to_keep;
    CREATE TEMP TABLE _temp_suppliers_to_keep AS
    SELECT supplier_id 
    FROM clean_data.supplier_info_general 
    ORDER BY RANDOM() 
    LIMIT p_sample_size;
    
    RAISE NOTICE 'Échantillon sélectionné: % fournisseurs', 
        (SELECT COUNT(*) FROM _temp_suppliers_to_keep);
    
    -- 1. Supprimer de payment_way_per_identity
    BEGIN
        DELETE FROM clean_data.payment_way_per_identity 
        WHERE party_type_db = 'SUPPLIER' 
          AND identity NOT IN (SELECT supplier_id FROM _temp_suppliers_to_keep);
        GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
        v_deleted_count := v_deleted_count + v_table_deleted;
        RAISE NOTICE '  ✓ payment_way_per_identity: % lignes supprimées', v_table_deleted;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE '  ⚠ payment_way_per_identity: table non trouvée (ignorée)';
    END;
    
    -- 2. Supprimer de payment_address
    BEGIN
        DELETE FROM clean_data.payment_address 
        WHERE party_type_db = 'SUPPLIER' 
          AND identity NOT IN (SELECT supplier_id FROM _temp_suppliers_to_keep);
        GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
        v_deleted_count := v_deleted_count + v_table_deleted;
        RAISE NOTICE '  ✓ payment_address: % lignes supprimées', v_table_deleted;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE '  ⚠ payment_address: table non trouvée (ignorée)';
    END;
    
    -- 3. Supprimer de supplier_delivery_tax_code
    BEGIN
        DELETE FROM clean_data.supplier_delivery_tax_code 
        WHERE supplier_id NOT IN (SELECT supplier_id FROM _temp_suppliers_to_keep);
        GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
        v_deleted_count := v_deleted_count + v_table_deleted;
        RAISE NOTICE '  ✓ supplier_delivery_tax_code: % lignes supprimées', v_table_deleted;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE '  ⚠ supplier_delivery_tax_code: table non trouvée (ignorée)';
    END;
    
    -- 4. Supprimer de supplier_tax_info
    DELETE FROM clean_data.supplier_tax_info 
    WHERE supplier_id NOT IN (SELECT supplier_id FROM _temp_suppliers_to_keep);
    GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
    v_deleted_count := v_deleted_count + v_table_deleted;
    RAISE NOTICE '  ✓ supplier_tax_info: % lignes supprimées', v_table_deleted;
    
    -- 5. Supprimer de supplier_document_tax_info
    DELETE FROM clean_data.supplier_document_tax_info 
    WHERE supplier_id NOT IN (SELECT supplier_id FROM _temp_suppliers_to_keep);
    GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
    v_deleted_count := v_deleted_count + v_table_deleted;
    RAISE NOTICE '  ✓ supplier_document_tax_info: % lignes supprimées', v_table_deleted;
    
    -- 6. Supprimer de identity_pay_info (SUPPLIER)
    DELETE FROM clean_data.identity_pay_info 
    WHERE party_type_db = 'SUPPLIER' 
      AND identity NOT IN (SELECT supplier_id FROM _temp_suppliers_to_keep);
    GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
    v_deleted_count := v_deleted_count + v_table_deleted;
    RAISE NOTICE '  ✓ identity_pay_info: % lignes supprimées', v_table_deleted;
    
    -- 7. Supprimer de identity_invoice_info (SUPPLIER)
    DELETE FROM clean_data.identity_invoice_info 
    WHERE party_type_db = 'SUPPLIER' 
      AND identity NOT IN (SELECT supplier_id FROM _temp_suppliers_to_keep);
    GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
    v_deleted_count := v_deleted_count + v_table_deleted;
    RAISE NOTICE '  ✓ identity_invoice_info: % lignes supprimées', v_table_deleted;
    
    -- 8. Supprimer de comm_method (SUPPLIER)
    DELETE FROM clean_data.comm_method 
    WHERE party_type_db = 'SUPPLIER' 
      AND (supplier_id NOT IN (SELECT supplier_id FROM _temp_suppliers_to_keep)
           OR identity NOT IN (SELECT supplier_id FROM _temp_suppliers_to_keep));
    GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
    v_deleted_count := v_deleted_count + v_table_deleted;
    RAISE NOTICE '  ✓ comm_method: % lignes supprimées', v_table_deleted;
    
    -- 9. Supprimer de supplier_info_address_type
    DELETE FROM clean_data.supplier_info_address_type 
    WHERE supplier_id NOT IN (SELECT supplier_id FROM _temp_suppliers_to_keep);
    GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
    v_deleted_count := v_deleted_count + v_table_deleted;
    RAISE NOTICE '  ✓ supplier_info_address_type: % lignes supprimées', v_table_deleted;
    
    -- 10. Supprimer de supplier_address
    BEGIN
        DELETE FROM clean_data.supplier_address 
        WHERE vendor_no NOT IN (SELECT supplier_id FROM _temp_suppliers_to_keep);
        GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
        v_deleted_count := v_deleted_count + v_table_deleted;
        RAISE NOTICE '  ✓ supplier_address: % lignes supprimées', v_table_deleted;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE '  ⚠ supplier_address: table non trouvée (ignorée)';
    END;
    
    -- 11. Supprimer de supplier_info_address
    DELETE FROM clean_data.supplier_info_address 
    WHERE supplier_id NOT IN (SELECT supplier_id FROM _temp_suppliers_to_keep);
    GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
    v_deleted_count := v_deleted_count + v_table_deleted;
    RAISE NOTICE '  ✓ supplier_info_address: % lignes supprimées', v_table_deleted;
    
    -- 12. Supprimer de supplier
    DELETE FROM clean_data.supplier 
    WHERE vendor_no NOT IN (SELECT supplier_id FROM _temp_suppliers_to_keep);
    GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
    v_deleted_count := v_deleted_count + v_table_deleted;
    RAISE NOTICE '  ✓ supplier: % lignes supprimées', v_table_deleted;
    
    -- 13. Supprimer de supplier_info_general (table principale - à la fin)
    DELETE FROM clean_data.supplier_info_general 
    WHERE supplier_id NOT IN (SELECT supplier_id FROM _temp_suppliers_to_keep);
    GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
    v_deleted_count := v_deleted_count + v_table_deleted;
    RAISE NOTICE '  ✓ supplier_info_general: % lignes supprimées', v_table_deleted;
    
    -- 14. Supprimer aussi de ifs_fournisseurs pour cohérence
    BEGIN
        DELETE FROM clean_data.ifs_fournisseurs 
        WHERE numero_compte_fournisseur NOT IN (SELECT supplier_id FROM _temp_suppliers_to_keep);
        GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
        v_deleted_count := v_deleted_count + v_table_deleted;
        RAISE NOTICE '  ✓ ifs_fournisseurs: % lignes supprimées', v_table_deleted;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE '  ⚠ ifs_fournisseurs: table non trouvée (ignorée)';
    END;
    
    -- 15. Supprimer de supplier_info_our_id
    BEGIN
        DELETE FROM clean_data.supplier_info_our_id 
        WHERE supplier_id NOT IN (SELECT supplier_id FROM _temp_suppliers_to_keep);
        GET DIAGNOSTICS v_table_deleted = ROW_COUNT;
        v_deleted_count := v_deleted_count + v_table_deleted;
        RAISE NOTICE '  ✓ supplier_info_our_id: % lignes supprimées', v_table_deleted;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE '  ⚠ supplier_info_our_id: table non trouvée (ignorée)';
    END;
    
    -- Nettoyer la table temporaire
    DROP TABLE IF EXISTS _temp_suppliers_to_keep;
    
    v_end_time := NOW();
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'ÉCHANTILLONNAGE TERMINÉ';
    RAISE NOTICE 'Fournisseurs restants: %', 
        (SELECT COUNT(*) FROM clean_data.supplier_info_general);
    RAISE NOTICE 'Total lignes supprimées: %', v_deleted_count;
    RAISE NOTICE 'Durée: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    RAISE NOTICE '========================================';
    
EXCEPTION
    WHEN OTHERS THEN
        DROP TABLE IF EXISTS _temp_suppliers_to_keep;
        RAISE EXCEPTION '❌ Erreur lors de l''échantillonnage: %', SQLERRM;
END;
$procedure$;

COMMENT ON PROCEDURE clean_data.sp_keep_supplier_sample(INTEGER) IS 
'Procédure pour garder un échantillon aléatoire de N fournisseurs (défaut: 200).
Supprime les données des autres fournisseurs dans toutes les tables liées.';
