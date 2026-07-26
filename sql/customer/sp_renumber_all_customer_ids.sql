-- Procédure pour renuméroter tous les customer_id en cascade
-- Commence à partir de 700000 et incrémente de 10 pour chaque client (700000, 700010, 700020…)
-- Met à jour toutes les tables liées automatiquement

CREATE OR REPLACE PROCEDURE clean_data.sp_renumber_all_customer_ids(
    p_start_id INTEGER DEFAULT 700000
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_customer_record RECORD;
    v_new_id INTEGER;
    v_total_customers INTEGER := 0;
    v_total_rows_updated INTEGER := 0;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Début renumérotation des customer_id';
    RAISE NOTICE 'ID de départ: %', p_start_id;
    RAISE NOTICE 'Heure de début: %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    RAISE NOTICE '========================================';
    
    -- Initialiser le compteur
    v_new_id := p_start_id;
    
    -- Créer une table temporaire pour mapper les anciens et nouveaux IDs
    CREATE TEMP TABLE IF NOT EXISTS temp_customer_id_mapping (
        old_customer_id VARCHAR,
        new_customer_id VARCHAR,
        PRIMARY KEY (old_customer_id)
    );
    
    -- Vider la table temporaire si elle existe déjà
    TRUNCATE TABLE temp_customer_id_mapping;
    
    -- Générer le mapping pour tous les clients
    -- Séquence 750000+ pour les clients avec compte_collectif (NOT NULL)
    -- Séquence 700000+ pour les clients sans compte_collectif (NULL)
    RAISE NOTICE 'Génération du mapping des IDs...';
    INSERT INTO temp_customer_id_mapping (old_customer_id, new_customer_id)
    SELECT DISTINCT ON (customer_id)
        customer_id,
        new_customer_id
    FROM (
        SELECT 
            ci.customer_id,
            CASE
                WHEN cts.compte_collectif IS NOT NULL THEN
                    (750000 + (ROW_NUMBER() OVER (PARTITION BY CASE WHEN cts.compte_collectif IS NOT NULL THEN 1 ELSE 0 END ORDER BY ci.customer_id) - 1) * 10)::TEXT
                ELSE
                    (700000 + (ROW_NUMBER() OVER (PARTITION BY CASE WHEN cts.compte_collectif IS NOT NULL THEN 1 ELSE 0 END ORDER BY ci.customer_id) - 1) * 10)::TEXT
            END as new_customer_id
        FROM clean_data.customer_info ci
        LEFT JOIN raw_data.clienttosave cts ON ci.customer_id = cts.numero_client
    ) sub
    ORDER BY customer_id;
    
    -- Compter le nombre de clients
    SELECT COUNT(*) INTO v_total_customers FROM temp_customer_id_mapping;
    RAISE NOTICE 'Nombre de clients à renuméroter: %', v_total_customers;
    RAISE NOTICE '';
    
    -- Désactiver temporairement les triggers et contraintes
    RAISE NOTICE 'Désactivation temporaire des triggers...';
    ALTER TABLE clean_data.customer_info DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_info_cfv DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_info_address DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_info_address_type DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_info_contact DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.comm_method DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.cus_comm_method DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.cus_ident_invoice_info DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.cus_identity_pay_info DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_credit_info DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_addr_tax_number DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_del_tax_exempt DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_delivery_fee_code DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_delivery_tax_info DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_document_tax_info DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_tax_free_tax_code DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_tax_info DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.identity_invoice_info DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.identity_pay_info DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.project_base DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.cust_ord_customer DISABLE TRIGGER ALL;
    ALTER TABLE clean_data.cust_ord_customer_address DISABLE TRIGGER ALL;
    
    -- Mettre à jour toutes les tables en une seule transaction
    RAISE NOTICE 'Mise à jour des tables...';
    
    -- 1. customer_info
    UPDATE clean_data.customer_info ci
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping m
    WHERE ci.customer_id = m.old_customer_id;
    RAISE NOTICE '  ✓ customer_info mis à jour';
    
    -- 2. customer_info_cfv
    UPDATE clean_data.customer_info_cfv ci
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping m
    WHERE ci.customer_id = m.old_customer_id;
    RAISE NOTICE '  ✓ customer_info_cfv mis à jour';
    
    -- 3. customer_info_address
    UPDATE clean_data.customer_info_address cia
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping m
    WHERE cia.customer_id = m.old_customer_id;
    RAISE NOTICE '  ✓ customer_info_address mis à jour';
    
    -- 4. customer_info_address_type
    UPDATE clean_data.customer_info_address_type ciat
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping m
    WHERE ciat.customer_id = m.old_customer_id;
    RAISE NOTICE '  ✓ customer_info_address_type mis à jour';
    
    -- 5. customer_info_contact
    UPDATE clean_data.customer_info_contact cic
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping m
    WHERE cic.customer_id = m.old_customer_id;
    RAISE NOTICE '  ✓ customer_info_contact mis à jour';
    
    -- 6. comm_method
    UPDATE clean_data.comm_method cm
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping m
    WHERE cm.customer_id = m.old_customer_id;
    RAISE NOTICE '  ✓ comm_method mis à jour';
    
    -- 6b. cus_comm_method (identity = customer_id)
    UPDATE clean_data.cus_comm_method ccm
    SET identity = m.new_customer_id
    FROM temp_customer_id_mapping m
    WHERE ccm.identity = m.old_customer_id;
    RAISE NOTICE '  ✓ cus_comm_method mis à jour';
    
    -- 6c. cus_ident_invoice_info (identity = customer_id)
    UPDATE clean_data.cus_ident_invoice_info ciii
    SET identity = m.new_customer_id
    FROM temp_customer_id_mapping m
    WHERE ciii.identity = m.old_customer_id;
    RAISE NOTICE '  ✓ cus_ident_invoice_info mis à jour';
    
    -- 6d. cus_identity_pay_info (identity = customer_id)
    UPDATE clean_data.cus_identity_pay_info cipi
    SET identity = m.new_customer_id
    FROM temp_customer_id_mapping m
    WHERE cipi.identity = m.old_customer_id;
    RAISE NOTICE '  ✓ cus_identity_pay_info mis à jour';
    
    -- 6e. customer_credit_info (identity = customer_id)
    UPDATE clean_data.customer_credit_info cci
    SET identity = m.new_customer_id
    FROM temp_customer_id_mapping m
    WHERE cci.identity = m.old_customer_id;
    RAISE NOTICE '  ✓ customer_credit_info mis à jour';
    
    -- 7. customer_addr_tax_number
    UPDATE clean_data.customer_addr_tax_number catn
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping m
    WHERE catn.customer_id = m.old_customer_id;
    RAISE NOTICE '  ✓ customer_addr_tax_number mis à jour';
    
    -- 8. customer_del_tax_exempt
    UPDATE clean_data.customer_del_tax_exempt cdte
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping m
    WHERE cdte.customer_id = m.old_customer_id;
    RAISE NOTICE '  ✓ customer_del_tax_exempt mis à jour';
    
    -- 9. customer_delivery_fee_code
    UPDATE clean_data.customer_delivery_fee_code cdfc
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping m
    WHERE cdfc.customer_id = m.old_customer_id;
    RAISE NOTICE '  ✓ customer_delivery_fee_code mis à jour';
    
    -- 10. customer_delivery_tax_info
    UPDATE clean_data.customer_delivery_tax_info cdti
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping m
    WHERE cdti.customer_id = m.old_customer_id;
    RAISE NOTICE '  ✓ customer_delivery_tax_info mis à jour';
    
    -- 11. customer_document_tax_info
    UPDATE clean_data.customer_document_tax_info cdti
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping m
    WHERE cdti.customer_id = m.old_customer_id;
    RAISE NOTICE '  ✓ customer_document_tax_info mis à jour';
    
    -- 12. customer_tax_free_tax_code
    UPDATE clean_data.customer_tax_free_tax_code ctftc
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping m
    WHERE ctftc.customer_id = m.old_customer_id;
    RAISE NOTICE '  ✓ customer_tax_free_tax_code mis à jour';
    
    -- 13. customer_tax_info
    UPDATE clean_data.customer_tax_info cti
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping m
    WHERE cti.customer_id = m.old_customer_id;
    RAISE NOTICE '  ✓ customer_tax_info mis à jour';
    
    -- 14. identity_invoice_info
    UPDATE clean_data.identity_invoice_info iii
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping m
    WHERE iii.customer_id = m.old_customer_id;
    RAISE NOTICE '  ✓ identity_invoice_info mis à jour';
    
    -- 15. identity_pay_info
    UPDATE clean_data.identity_pay_info ipi
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping m
    WHERE ipi.customer_id = m.old_customer_id;
    RAISE NOTICE '  ✓ identity_pay_info mis à jour';
    
    -- 16. project_base
    UPDATE clean_data.project_base pb
    SET customer_id = m.new_customer_id
    FROM temp_customer_id_mapping m
    WHERE pb.customer_id = m.old_customer_id;
    RAISE NOTICE '  ✓ project_base mis à jour';
    
    -- 17. cust_ord_customer
    UPDATE clean_data.cust_ord_customer coc
    SET customer_no = m.new_customer_id,
        customer_no_pay = m.new_customer_id
    FROM temp_customer_id_mapping m
    WHERE coc.customer_no = m.old_customer_id;
    RAISE NOTICE '  ✓ cust_ord_customer mis à jour';
    
    -- 18. cust_ord_customer_address
    UPDATE clean_data.cust_ord_customer_address coca
    SET customer_no = m.new_customer_id
    FROM temp_customer_id_mapping m
    WHERE coca.customer_no = m.old_customer_id;
    RAISE NOTICE '  ✓ cust_ord_customer_address mis à jour';
    
    -- Réactiver les triggers
    RAISE NOTICE 'Réactivation des triggers...';
    ALTER TABLE clean_data.customer_info ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_info_cfv ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_info_address ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_info_address_type ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_info_contact ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.comm_method ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.cus_comm_method ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.cus_ident_invoice_info ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.cus_identity_pay_info ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_credit_info ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_addr_tax_number ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_del_tax_exempt ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_delivery_fee_code ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_delivery_tax_info ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_document_tax_info ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_tax_free_tax_code ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.customer_tax_info ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.identity_invoice_info ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.identity_pay_info ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.project_base ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.cust_ord_customer ENABLE TRIGGER ALL;
    ALTER TABLE clean_data.cust_ord_customer_address ENABLE TRIGGER ALL;
    
    v_end_time := NOW();
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Renumérotation terminée avec succès';
    RAISE NOTICE 'Nombre de clients traités: %', v_total_customers;
    RAISE NOTICE 'Plage IDs avec compte collectif: 750000, 750010, 750020…';
    RAISE NOTICE 'Plage IDs sans compte collectif: 700000, 700010, 700020…';
    RAISE NOTICE 'Heure de fin: %', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS');
    RAISE NOTICE 'Durée d''exécution: % secondes', 
        EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    RAISE NOTICE '========================================';
    
    -- Nettoyer la table temporaire
    DROP TABLE IF EXISTS temp_customer_id_mapping;
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        -- Réactiver les triggers en cas d'erreur
        ALTER TABLE clean_data.customer_info ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.customer_info_cfv ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.customer_info_address ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.customer_info_address_type ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.customer_info_contact ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.comm_method ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.cus_comm_method ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.cus_ident_invoice_info ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.cus_identity_pay_info ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.customer_credit_info ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.customer_addr_tax_number ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.customer_del_tax_exempt ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.customer_delivery_fee_code ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.customer_delivery_tax_info ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.customer_document_tax_info ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.customer_tax_free_tax_code ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.customer_tax_info ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.identity_invoice_info ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.identity_pay_info ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.project_base ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.cust_ord_customer ENABLE TRIGGER ALL;
        ALTER TABLE clean_data.cust_ord_customer_address ENABLE TRIGGER ALL;
        DROP TABLE IF EXISTS temp_customer_id_mapping;
        RAISE EXCEPTION '❌ Erreur lors de la renumérotation - %: %', 
            TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$;

-- Commentaire sur la procédure
COMMENT ON PROCEDURE clean_data.sp_renumber_all_customer_ids(INTEGER) IS 
'Renumérotation complète de tous les customer_id en cascade dans toutes les tables liées.
Par défaut commence à 700000 et incrémente de 10 pour chaque client (700000, 700010, 700020…).
Exemple d''utilisation: CALL clean_data.sp_renumber_all_customer_ids(700000);';

