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
    
    -- Adresse propre du fournisseur (fonction_partenaire NULL) : les 4 types,
    -- adresse par defaut. Adresse partenaire SAP (script 04, wyt3) : le seul
    -- type de sa fonction, jamais par defaut (IFS n'admet qu'une adresse par
    -- defaut par type) :
    --   RS auteur facture -> INVOICE + PAY ; BA adresse commande -> INVOICE
    --   VA adresse contrat -> VISIT        ; SP transporteur     -> DELIVERY
    INSERT INTO clean_data.supplier_info_address_type (
        supplier_id, address_id, address_type_code, address_type_code_db,
        party, def_address, default_domain, address_type_id,
        created_timestamp, updated_timestamp, created_by, updated_by,
        is_deleted, invoice, visit, pay
    )
    SELECT
        sia.supplier_id,
        sia.address_id,
        public.get_default_value('clean_data.supplier_info_address_type', 'address_type_code', t.type_adresse),
        public.get_default_value('clean_data.supplier_info_address_type', 'address_type_code_db', t.type_adresse),
        public.get_default_value('clean_data.supplier_info_address_type', 'party', t.type_adresse),
        CASE WHEN sia.fonction_partenaire IS NULL
             THEN public.get_default_value('clean_data.supplier_info_address_type', 'def_address', t.type_adresse)
             ELSE 'FALSE' END,
        public.get_default_value('clean_data.supplier_info_address_type', 'default_domain', t.type_adresse),
        sia.supplier_id || '_' || sia.address_id || '_' || LEFT(t.type_adresse, 1),
        NOW(), NOW(), 'etl_supplier_base', 'etl_supplier_base', FALSE,
        public.get_default_value('clean_data.supplier_info_address_type', 'invoice', t.type_adresse),
        public.get_default_value('clean_data.supplier_info_address_type', 'visit', t.type_adresse),
        public.get_default_value('clean_data.supplier_info_address_type', 'pay', t.type_adresse)
    FROM clean_data.supplier_info_address sia
    JOIN (VALUES (NULL, 'DELIVERY'), (NULL, 'INVOICE'), (NULL, 'VISIT'), (NULL, 'PAY'),
                 ('RS', 'INVOICE'), ('RS', 'PAY'), ('BA', 'INVOICE'),
                 ('VA', 'VISIT'), ('SP', 'DELIVERY')) t(fonction, type_adresse)
      ON t.fonction IS NOT DISTINCT FROM sia.fonction_partenaire
    WHERE COALESCE(sia.is_deleted, FALSE) = FALSE;

    SELECT COUNT(*) FILTER (WHERE address_type_code_db = 'DELIVERY'),
           COUNT(*) FILTER (WHERE address_type_code_db = 'INVOICE'),
           COUNT(*) FILTER (WHERE address_type_code_db = 'VISIT'),
           COUNT(*) FILTER (WHERE address_type_code_db = 'PAY')
      INTO count_delivery, count_invoice, count_visit, count_pay
      FROM clean_data.supplier_info_address_type;

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
