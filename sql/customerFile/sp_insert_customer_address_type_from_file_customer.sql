CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_address_type_from_file_customer()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_total_inserted INTEGER := 0;
    v_inserted_count INTEGER := 0;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Début insertion types d''adresse clients depuis file_customer - %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    RAISE NOTICE '========================================';

    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.customer_info_address_type;
    RAISE NOTICE 'Table customer_info_address_type vidée';

    -- Appeler la sous-procédure pour DELIVERY
    RAISE NOTICE 'Insertion des types DELIVERY...';
    CALL clean_data.sp_insert_customer_address_type_single_file('DELIVERY', v_inserted_count);
    v_total_inserted := v_total_inserted + v_inserted_count;
    RAISE NOTICE '  ✓ DELIVERY: % enregistrements insérés (1 adresse par défaut par client)', v_inserted_count;

    -- Appeler la sous-procédure pour INVOICE
    RAISE NOTICE 'Insertion des types INVOICE...';
    CALL clean_data.sp_insert_customer_address_type_single_file('INVOICE', v_inserted_count);
    v_total_inserted := v_total_inserted + v_inserted_count;
    RAISE NOTICE '  ✓ INVOICE: % enregistrements insérés (1 adresse par défaut par client)', v_inserted_count;

    -- Appeler la sous-procédure pour DOCUMENT
    RAISE NOTICE 'Insertion des types DOCUMENT...';
    CALL clean_data.sp_insert_customer_address_type_single_file('DOCUMENT', v_inserted_count);
    v_total_inserted := v_total_inserted + v_inserted_count;
    RAISE NOTICE '  ✓ DOCUMENT: % enregistrements insérés (1 adresse par défaut par client)', v_inserted_count;

    v_end_time := NOW();
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Insertion types d''adresse terminée - %: % enregistrements au total',
        TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_total_inserted;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    RAISE NOTICE '========================================';

EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION '❌ Erreur lors de l''INSERT types d''adresse depuis file_customer - %: %',
            TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
