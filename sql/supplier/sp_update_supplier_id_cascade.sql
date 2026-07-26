CREATE OR REPLACE PROCEDURE clean_data.sp_update_supplier_id_cascade(
    p_old_supplier_id VARCHAR,
    p_new_supplier_id VARCHAR
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
    RAISE NOTICE 'Début mise à jour supplier_id: % → % - %', 
        p_old_supplier_id, p_new_supplier_id, TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    
    -- Vérifier que l'ancien supplier_id existe dans supplier_info_general
    IF NOT EXISTS (SELECT 1 FROM clean_data.supplier_info_general WHERE supplier_id = p_old_supplier_id) THEN
        RAISE EXCEPTION 'Supplier_id % n''existe pas dans supplier_info_general', p_old_supplier_id;
    END IF;
    
    -- Vérifier que le nouveau supplier_id n'existe pas déjà
    IF EXISTS (SELECT 1 FROM clean_data.supplier_info_general WHERE supplier_id = p_new_supplier_id) THEN
        RAISE EXCEPTION 'Supplier_id % existe déjà dans supplier_info_general', p_new_supplier_id;
    END IF;
    
    -- 1. Mettre à jour supplier_info_general (table principale)
    -- IMPORTANT: Copier l'ancien supplier_id dans supplier_legacy_sap_id pour garder la trace du numéro SAP d'origine
    UPDATE clean_data.supplier_info_general 
    SET supplier_id = p_new_supplier_id,
        supplier_legacy_sap_id = p_old_supplier_id,  -- Copie toujours l'ancien numéro SAP
        updated_timestamp = NOW()
    WHERE supplier_id = p_old_supplier_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ supplier_info_general: % lignes mises à jour', v_updated_count;
    
    -- 2. Mettre à jour supplier (vendor_no)
    UPDATE clean_data.supplier 
    SET vendor_no = p_new_supplier_id,
        updated_timestamp = NOW()
    WHERE vendor_no = p_old_supplier_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ supplier: % lignes mises à jour', v_updated_count;
    
    -- 3. Mettre à jour supplier_info_address
    UPDATE clean_data.supplier_info_address 
    SET supplier_id = p_new_supplier_id
    WHERE supplier_id = p_old_supplier_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ supplier_info_address: % lignes mises à jour', v_updated_count;
    
    -- 4. Mettre à jour supplier_address (vendor_no correspond au supplier_id)
    BEGIN
        UPDATE clean_data.supplier_address 
        SET vendor_no = p_new_supplier_id
        WHERE vendor_no = p_old_supplier_id;
        GET DIAGNOSTICS v_updated_count = ROW_COUNT;
        v_total_updated := v_total_updated + v_updated_count;
        RAISE NOTICE '  ✓ supplier_address: % lignes mises à jour', v_updated_count;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE '  ⚠ supplier_address: table non trouvée (ignorée)';
    END;
    
    -- 5. Mettre à jour supplier_info_address_type
    UPDATE clean_data.supplier_info_address_type 
    SET supplier_id = p_new_supplier_id
    WHERE supplier_id = p_old_supplier_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ supplier_info_address_type: % lignes mises à jour', v_updated_count;
    
    -- 6. Mettre à jour comm_method (supplier_id)
    UPDATE clean_data.comm_method 
    SET supplier_id = p_new_supplier_id
    WHERE supplier_id = p_old_supplier_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ comm_method (supplier_id): % lignes mises à jour', v_updated_count;
    
    -- 7. Mettre à jour comm_method (identity pour SUPPLIER)
    UPDATE clean_data.comm_method 
    SET identity = p_new_supplier_id
    WHERE identity = p_old_supplier_id
      AND party_type_db = 'SUPPLIER';
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ comm_method (identity): % lignes mises à jour', v_updated_count;
    
    -- 8. Mettre à jour identity_invoice_info (identity pour SUPPLIER)
    UPDATE clean_data.identity_invoice_info 
    SET identity = p_new_supplier_id
    WHERE identity = p_old_supplier_id
      AND party_type_db = 'SUPPLIER';
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ identity_invoice_info: % lignes mises à jour', v_updated_count;
    
    -- 9. Mettre à jour identity_pay_info (identity pour SUPPLIER)
    UPDATE clean_data.identity_pay_info 
    SET identity = p_new_supplier_id,
        supplier_id = p_new_supplier_id
    WHERE identity = p_old_supplier_id
      AND party_type_db = 'SUPPLIER';
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ identity_pay_info: % lignes mises à jour', v_updated_count;
    
    -- 10. Mettre à jour supplier_document_tax_info
    UPDATE clean_data.supplier_document_tax_info 
    SET supplier_id = p_new_supplier_id
    WHERE supplier_id = p_old_supplier_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ supplier_document_tax_info: % lignes mises à jour', v_updated_count;
    
    -- 11. Mettre à jour supplier_tax_info
    UPDATE clean_data.supplier_tax_info 
    SET supplier_id = p_new_supplier_id
    WHERE supplier_id = p_old_supplier_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ supplier_tax_info: % lignes mises à jour', v_updated_count;
    
    -- 12. Mettre à jour supplier_delivery_tax_code (si existe)
    BEGIN
        UPDATE clean_data.supplier_delivery_tax_code 
        SET supplier_id = p_new_supplier_id
        WHERE supplier_id = p_old_supplier_id;
        GET DIAGNOSTICS v_updated_count = ROW_COUNT;
        v_total_updated := v_total_updated + v_updated_count;
        RAISE NOTICE '  ✓ supplier_delivery_tax_code: % lignes mises à jour', v_updated_count;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE '  ⚠ supplier_delivery_tax_code: table non trouvée (ignorée)';
    END;
    
    -- 13. Mettre à jour payment_address (identity pour SUPPLIER)
    BEGIN
        UPDATE clean_data.payment_address 
        SET identity = p_new_supplier_id
        WHERE identity = p_old_supplier_id
          AND party_type_db = 'SUPPLIER';
        GET DIAGNOSTICS v_updated_count = ROW_COUNT;
        v_total_updated := v_total_updated + v_updated_count;
        RAISE NOTICE '  ✓ payment_address: % lignes mises à jour', v_updated_count;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE '  ⚠ payment_address: table non trouvée (ignorée)';
    END;
    
    -- 14. Mettre à jour payment_way_per_identity (identity pour SUPPLIER)
    BEGIN
        UPDATE clean_data.payment_way_per_identity 
        SET identity = p_new_supplier_id
        WHERE identity = p_old_supplier_id
          AND party_type_db = 'SUPPLIER';
        GET DIAGNOSTICS v_updated_count = ROW_COUNT;
        v_total_updated := v_total_updated + v_updated_count;
        RAISE NOTICE '  ✓ payment_way_per_identity: % lignes mises à jour', v_updated_count;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE '  ⚠ payment_way_per_identity: table non trouvée (ignorée)';
    END;
    
    -- 15. Mettre à jour supplier_info_our_id
    UPDATE clean_data.supplier_info_our_id 
    SET supplier_id = p_new_supplier_id,
        our_id = REPLACE(our_id, p_old_supplier_id, p_new_supplier_id)
    WHERE supplier_id = p_old_supplier_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '  ✓ supplier_info_our_id: % lignes mises à jour', v_updated_count;
    
    -- 16. ifs_fournisseurs - NE PAS METTRE À JOUR (table source, conserve les IDs SAP originaux)
    -- BEGIN
    --     UPDATE clean_data.ifs_fournisseurs 
    --     SET numero_compte_fournisseur = p_new_supplier_id
    --     WHERE numero_compte_fournisseur = p_old_supplier_id;
    --     GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    --     v_total_updated := v_total_updated + v_updated_count;
    --     RAISE NOTICE '  ✓ ifs_fournisseurs: % lignes mises à jour', v_updated_count;
    -- EXCEPTION WHEN undefined_table THEN
    --     RAISE NOTICE '  ⚠ ifs_fournisseurs: table non trouvée (ignorée)';
    -- END;
    
    v_end_time := NOW();
    RAISE NOTICE '✅ Mise à jour terminée - %: % lignes au total mises à jour', 
        TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_total_updated;
    RAISE NOTICE 'Durée d''exécution: % secondes', 
        EXTRACT(EPOCH FROM (v_end_time - v_start_time));
        
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION '❌ Erreur lors de la mise à jour supplier_id - %: %', 
            TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$;

-- ============================================================================
-- Procédure pour mettre à jour TOUS les supplier_id avec une séquence à partir de 600000
-- ============================================================================
CREATE OR REPLACE PROCEDURE clean_data.sp_renumber_all_suppliers()
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_sequence_start INTEGER := 600000;
    v_current_sequence INTEGER;
    v_supplier_record RECORD;
    v_processed_count INTEGER := 0;
    v_error_count INTEGER := 0;
    v_new_supplier_id VARCHAR;
BEGIN
    v_start_time := NOW();
    v_current_sequence := v_sequence_start;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'DÉBUT RENUMÉROTATION FOURNISSEURS';
    RAISE NOTICE 'Séquence de départ: %', v_sequence_start;
    RAISE NOTICE 'Date: %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    RAISE NOTICE '========================================';
    
    -- Parcourir tous les fournisseurs existants
    FOR v_supplier_record IN 
        SELECT supplier_id 
        FROM clean_data.supplier_info_general 
        WHERE is_deleted = FALSE
        ORDER BY supplier_id
    LOOP
        v_new_supplier_id := v_current_sequence::VARCHAR;
        
        BEGIN
            -- Appeler la procédure de mise à jour en cascade
            CALL clean_data.sp_update_supplier_id_cascade(
                v_supplier_record.supplier_id, 
                v_new_supplier_id
            );
            
            v_processed_count := v_processed_count + 1;
            v_current_sequence := v_current_sequence + 1;
            
            -- Log de progression tous les 100 fournisseurs
            IF v_processed_count % 100 = 0 THEN
                RAISE NOTICE 'Progression: % fournisseurs traités...', v_processed_count;
            END IF;
            
        EXCEPTION WHEN OTHERS THEN
            v_error_count := v_error_count + 1;
            RAISE WARNING 'Erreur pour supplier_id %: %', v_supplier_record.supplier_id, SQLERRM;
            -- Continuer avec le fournisseur suivant
            v_current_sequence := v_current_sequence + 1;
        END;
    END LOOP;
    
    v_end_time := NOW();
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'RENUMÉROTATION TERMINÉE';
    RAISE NOTICE 'Fournisseurs traités: %', v_processed_count;
    RAISE NOTICE 'Erreurs: %', v_error_count;
    RAISE NOTICE 'Plage d''IDs: % à %', v_sequence_start, v_current_sequence - 1;
    RAISE NOTICE 'Durée: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    RAISE NOTICE '========================================';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION '❌ Erreur fatale lors de la renumérotation: %', SQLERRM;
END;
$procedure$;

-- ============================================================================
-- Script pour ajouter/modifier la colonne SUPPLIER_LEGACY_SAP_ID si elle n'existe pas
-- ============================================================================
DO $$
BEGIN
    -- Ajouter la colonne SUPPLIER_LEGACY_SAP_ID à supplier_info_general si elle n'existe pas
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'clean_data' 
          AND table_name = 'supplier_info_general' 
          AND column_name = 'supplier_legacy_sap_id'
    ) THEN
        ALTER TABLE clean_data.supplier_info_general 
        ADD COLUMN supplier_legacy_sap_id VARCHAR(100);
        
        COMMENT ON COLUMN clean_data.supplier_info_general.supplier_legacy_sap_id IS 
            'Ancien identifiant SAP du fournisseur avant renumérotation';
        
        RAISE NOTICE 'Colonne SUPPLIER_LEGACY_SAP_ID ajoutée à supplier_info_general (VARCHAR(100))';
    ELSE
        -- Modifier le type si la colonne existe déjà avec une taille différente
        ALTER TABLE clean_data.supplier_info_general 
        ALTER COLUMN supplier_legacy_sap_id TYPE VARCHAR(100);
        
        COMMENT ON COLUMN clean_data.supplier_info_general.supplier_legacy_sap_id IS 
            'Ancien identifiant SAP du fournisseur avant renumérotation';
        
        RAISE NOTICE 'Type de colonne SUPPLIER_LEGACY_SAP_ID modifié à VARCHAR(100)';
    END IF;
END $$;

-- Commentaires sur les procédures
COMMENT ON PROCEDURE clean_data.sp_update_supplier_id_cascade(VARCHAR, VARCHAR) IS 
'Procédure pour mettre à jour un supplier_id en cascade dans toutes les tables liées. 
Sauvegarde l''ancien ID dans la colonne SUPPLIER_LEGACY_SAP_ID.';

COMMENT ON PROCEDURE clean_data.sp_renumber_all_suppliers() IS 
'Procédure pour renuméroter tous les fournisseurs avec une séquence commençant à 600000.
Utilise sp_update_supplier_id_cascade pour chaque fournisseur.';

