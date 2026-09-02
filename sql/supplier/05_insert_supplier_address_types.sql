CREATE OR REPLACE FUNCTION clean_data.insert_supplier_address_types()
 RETURNS TABLE(execution_status text, total_inserted integer, delivery_count integer, invoice_count integer, visit_count integer, pay_count integer, execution_time interval)
 LANGUAGE plpgsql
AS $function$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    count_delivery INTEGER := 0;
    count_invoice INTEGER := 0;
    count_visit INTEGER := 0;
    count_pay INTEGER := 0;
    total_count INTEGER := 0;
BEGIN
    start_time := clock_timestamp();
    
    RAISE NOTICE '=== DÉBUT INSERTION SUPPLIER_ADDRESS_TYPES ===';
    RAISE NOTICE 'Heure de début: %', start_time;
    
    -- Vider complètement la table destination
    TRUNCATE TABLE clean_data.supplier_info_address_type;
    RAISE NOTICE 'Table supplier_info_address_type vidée';
    
    -- Vérifier le nombre d'adresses sources
    RAISE NOTICE 'Nombre d''adresses sources (supplier_info_address): %', 
                 (SELECT COUNT(*) FROM clean_data.supplier_info_address WHERE COALESCE(is_deleted, FALSE) = FALSE);
    
    -- =====================================
    -- TYPE 1: DELIVERY 
    -- =====================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Insertion TYPE 1: DELIVERY ---';
    
    INSERT INTO clean_data.supplier_info_address_type (
        supplier_id,
        address_id,
        address_type_code,
        address_type_code_db,
        party,
        def_address,
        default_domain,
        address_type_id,
        created_timestamp,
        updated_timestamp,
        created_by,
        updated_by,
        is_deleted,
        invoice,
        visit,
        pay
    )
    SELECT 
        sia.supplier_id,
        sia.address_id,
        public.get_default_value('clean_data.supplier_info_address_type', 'address_type_code', 'DELIVERY') as address_type_code,
        public.get_default_value('clean_data.supplier_info_address_type', 'address_type_code_db', 'DELIVERY') as address_type_code_db,
        public.get_default_value('clean_data.supplier_info_address_type', 'party', 'DELIVERY') as party,
        public.get_default_value('clean_data.supplier_info_address_type', 'def_address', 'DELIVERY') as def_address,
        public.get_default_value('clean_data.supplier_info_address_type', 'default_domain', 'DELIVERY') as default_domain,
        sia.supplier_id || '_' || sia.address_id || '_D' as address_type_id,
        NOW() as created_timestamp,
        NOW() as updated_timestamp,
        'etl_supplier_base' as created_by,
        'etl_supplier_base' as updated_by,
        FALSE as is_deleted,
        public.get_default_value('clean_data.supplier_info_address_type', 'invoice', 'DELIVERY') as invoice,
        public.get_default_value('clean_data.supplier_info_address_type', 'visit', 'DELIVERY') as visit,
        public.get_default_value('clean_data.supplier_info_address_type', 'pay', 'DELIVERY') as pay
    FROM clean_data.supplier_info_address sia
    WHERE COALESCE(sia.is_deleted, FALSE) = FALSE;
    
    GET DIAGNOSTICS count_delivery = ROW_COUNT;
    RAISE NOTICE 'TYPE DELIVERY: % enregistrements insérés', count_delivery;
    
    -- =====================================
    -- TYPE 2: INVOICE (Document)
    -- =====================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Insertion TYPE 2: INVOICE (Document) ---';
    
    INSERT INTO clean_data.supplier_info_address_type (
        supplier_id,
        address_id,
        address_type_code,
        address_type_code_db,
        party,
        def_address,
        default_domain,
        address_type_id,
        created_timestamp,
        updated_timestamp,
        created_by,
        updated_by,
        is_deleted,
        invoice,
        visit,
        pay
    )
    SELECT 
        sia.supplier_id,
        sia.address_id,
        public.get_default_value('clean_data.supplier_info_address_type', 'address_type_code', 'INVOICE') as address_type_code,
        public.get_default_value('clean_data.supplier_info_address_type', 'address_type_code_db', 'INVOICE') as address_type_code_db,
        public.get_default_value('clean_data.supplier_info_address_type', 'party', 'INVOICE') as party,
        public.get_default_value('clean_data.supplier_info_address_type', 'def_address', 'INVOICE') as def_address,
        public.get_default_value('clean_data.supplier_info_address_type', 'default_domain', 'INVOICE') as default_domain,
        sia.supplier_id || '_' || sia.address_id || '_I' as address_type_id,
        NOW() as created_timestamp,
        NOW() as updated_timestamp,
        'etl_supplier_base' as created_by,
        'etl_supplier_base' as updated_by,
        FALSE as is_deleted,
        public.get_default_value('clean_data.supplier_info_address_type', 'invoice', 'INVOICE') as invoice,
        public.get_default_value('clean_data.supplier_info_address_type', 'visit', 'INVOICE') as visit,
        public.get_default_value('clean_data.supplier_info_address_type', 'pay', 'INVOICE') as pay
    FROM clean_data.supplier_info_address sia
    WHERE COALESCE(sia.is_deleted, FALSE) = FALSE;
    
    GET DIAGNOSTICS count_invoice = ROW_COUNT;
    RAISE NOTICE 'TYPE INVOICE: % enregistrements insérés', count_invoice;
    
    -- =====================================
    -- TYPE 3: VISIT
    -- =====================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Insertion TYPE 3: VISIT ---';
    
    INSERT INTO clean_data.supplier_info_address_type (
        supplier_id,
        address_id,
        address_type_code,
        address_type_code_db,
        party,
        def_address,
        default_domain,
        address_type_id,
        created_timestamp,
        updated_timestamp,
        created_by,
        updated_by,
        is_deleted,
        invoice,
        visit,
        pay
    )
    SELECT 
        sia.supplier_id,
        sia.address_id,
        public.get_default_value('clean_data.supplier_info_address_type', 'address_type_code', 'VISIT') as address_type_code,
        public.get_default_value('clean_data.supplier_info_address_type', 'address_type_code_db', 'VISIT') as address_type_code_db,
        public.get_default_value('clean_data.supplier_info_address_type', 'party', 'VISIT') as party,
        public.get_default_value('clean_data.supplier_info_address_type', 'def_address', 'VISIT') as def_address,
        public.get_default_value('clean_data.supplier_info_address_type', 'default_domain', 'VISIT') as default_domain,
        sia.supplier_id || '_' || sia.address_id || '_V' as address_type_id,
        NOW() as created_timestamp,
        NOW() as updated_timestamp,
        'etl_supplier_base' as created_by,
        'etl_supplier_base' as updated_by,
        FALSE as is_deleted,
        public.get_default_value('clean_data.supplier_info_address_type', 'invoice', 'VISIT') as invoice,
        public.get_default_value('clean_data.supplier_info_address_type', 'visit', 'VISIT') as visit,
        public.get_default_value('clean_data.supplier_info_address_type', 'pay', 'VISIT') as pay
    FROM clean_data.supplier_info_address sia
    WHERE COALESCE(sia.is_deleted, FALSE) = FALSE;
    
    GET DIAGNOSTICS count_visit = ROW_COUNT;
    RAISE NOTICE 'TYPE VISIT: % enregistrements insérés', count_visit;
    
    -- =====================================
    -- TYPE 4: PAY
    -- =====================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Insertion TYPE 4: PAY ---';
    
    INSERT INTO clean_data.supplier_info_address_type (
        supplier_id,
        address_id,
        address_type_code,
        address_type_code_db,
        party,
        def_address,
        default_domain,
        address_type_id,
        created_timestamp,
        updated_timestamp,
        created_by,
        updated_by,
        is_deleted,
        invoice,
        visit,
        pay
    )
    SELECT 
        sia.supplier_id,
        sia.address_id,
        public.get_default_value('clean_data.supplier_info_address_type', 'address_type_code', 'PAY') as address_type_code,
        public.get_default_value('clean_data.supplier_info_address_type', 'address_type_code_db', 'PAY') as address_type_code_db,
        public.get_default_value('clean_data.supplier_info_address_type', 'party', 'PAY') as party,
        public.get_default_value('clean_data.supplier_info_address_type', 'def_address', 'PAY') as def_address,
        public.get_default_value('clean_data.supplier_info_address_type', 'default_domain', 'PAY') as default_domain,
        sia.supplier_id || '_' || sia.address_id || '_P' as address_type_id,
        NOW() as created_timestamp,
        NOW() as updated_timestamp,
        'etl_supplier_base' as created_by,
        'etl_supplier_base' as updated_by,
        FALSE as is_deleted,
        public.get_default_value('clean_data.supplier_info_address_type', 'invoice', 'PAY') as invoice,
        public.get_default_value('clean_data.supplier_info_address_type', 'visit', 'PAY') as visit,
        public.get_default_value('clean_data.supplier_info_address_type', 'pay', 'PAY') as pay
    FROM clean_data.supplier_info_address sia
    WHERE COALESCE(sia.is_deleted, FALSE) = FALSE;
    
    GET DIAGNOSTICS count_pay = ROW_COUNT;
    RAISE NOTICE 'TYPE PAY: % enregistrements insérés', count_pay;
    
    end_time := clock_timestamp();
    total_count := count_delivery + count_invoice + count_visit + count_pay;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== INSERTION SUPPLIER_ADDRESS_TYPES TERMINÉE ===';
    RAISE NOTICE 'Durée totale: % secondes', EXTRACT(EPOCH FROM (end_time - start_time));
    RAISE NOTICE 'Total enregistrements insérés: %', total_count;
    RAISE NOTICE '  - DELIVERY: %', count_delivery;
    RAISE NOTICE '  - INVOICE: %', count_invoice;
    RAISE NOTICE '  - VISIT: %', count_visit;
    RAISE NOTICE '  - PAY: %', count_pay;
    
    -- Statistiques de vérification
    RAISE NOTICE '';
    RAISE NOTICE '=== STATISTIQUES DE VÉRIFICATION ===';
    RAISE NOTICE 'Total dans supplier_info_address_type: %', 
                 (SELECT COUNT(*) FROM clean_data.supplier_info_address_type);
    RAISE NOTICE 'Fournisseurs distincts: %', 
                 (SELECT COUNT(DISTINCT supplier_id) FROM clean_data.supplier_info_address_type);
    RAISE NOTICE 'Adresses distinctes: %', 
                 (SELECT COUNT(DISTINCT address_id) FROM clean_data.supplier_info_address_type);
    
    RETURN QUERY SELECT 
        '✅ INSERTION RÉUSSIE' as execution_status,
        total_count,
        count_delivery,
        count_invoice,
        count_visit,
        count_pay,
        end_time - start_time;
        
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT 
            '❌ ERREUR: ' || SQLERRM as execution_status,
            0 as total_inserted,
            0 as delivery_count,
            0 as invoice_count,
            0 as visit_count,
            0 as pay_count,
            INTERVAL '0' as execution_time;
END;
$function$
;
