-- Procédure pour insérer les types d'adresses clients depuis les données SAP
-- Utilise clean_data.ifs_customer comme table maître
-- Insère les 3 types (DELIVERY, INVOICE, DOCUMENT) avec une seule adresse par défaut par type et par client

CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_address_type_from_sap()
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_delivery_count INTEGER := 0;
    v_invoice_count INTEGER := 0;
    v_document_count INTEGER := 0;
BEGIN
    
    RAISE NOTICE 'Début insertion types d''adresse clients SAP - Basé sur ifs_customer';
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.customer_info_address_type;
    RAISE NOTICE 'Table customer_info_address_type vidée';
    
    -- Insertion des 3 types d'adresses avec une seule adresse par défaut par type et par client
    -- Utilisation d'une CTE pour générer les 3 types pour chaque adresse
    WITH address_types AS (
        SELECT DISTINCT
            ifs.customer_number as customer_id,
            COALESCE(ifs.numero_adresse, k.ADRNR) as address_id,
            ifs.customer_number as party,
            CASE 
                WHEN ifs.company_code IS NOT NULL THEN 'TRUE'
                ELSE 'FALSE'
            END as default_domain
        FROM clean_data.ifs_customer ifs
        LEFT JOIN raw_data.KNA1 k 
            ON ifs.customer_number = k.KUNNR
            AND ifs.numero_adresse = k.ADRNR
            AND (k.LOEVM IS NULL OR k.LOEVM = '')
        WHERE COALESCE(ifs.numero_adresse, k.ADRNR) IS NOT NULL
    ),
    all_address_types AS (
        SELECT 
            customer_id,
            address_id,
            party,
            default_domain,
            address_type_code,
            address_type_code_db
        FROM address_types
        CROSS JOIN (
            SELECT 'Delivery' as address_type_code, 'DELIVERY' as address_type_code_db
            UNION ALL
            SELECT 'Invoice' as address_type_code, 'INVOICE' as address_type_code_db
            UNION ALL
            SELECT 'Document' as address_type_code, 'DOCUMENT' as address_type_code_db
        ) types
    )
    INSERT INTO clean_data.customer_info_address_type (
        customer_id,
        address_id,
        address_type_code,
        address_type_code_db,
        party,
        def_address,
        default_domain
    )
    SELECT 
        customer_id,
        address_id,
        address_type_code,
        address_type_code_db,
        party,
        CASE 
            WHEN ROW_NUMBER() OVER (
                PARTITION BY customer_id, address_type_code_db 
                ORDER BY address_id
            ) = 1 
            THEN 'TRUE'
            ELSE 'FALSE'
        END as def_address,
        default_domain
    FROM all_address_types
    ORDER BY customer_id, address_type_code_db, address_id;
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    
    -- Compter par type pour les statistiques
    SELECT COUNT(*) INTO v_delivery_count
    FROM clean_data.customer_info_address_type
    WHERE address_type_code_db = 'DELIVERY' AND def_address = 'TRUE';
    
    SELECT COUNT(*) INTO v_invoice_count
    FROM clean_data.customer_info_address_type
    WHERE address_type_code_db = 'INVOICE' AND def_address = 'TRUE';
    
    SELECT COUNT(*) INTO v_document_count
    FROM clean_data.customer_info_address_type
    WHERE address_type_code_db = 'DOCUMENT' AND def_address = 'TRUE';
    
    RAISE NOTICE 'INSERT types d''adresse terminé: % enregistrements traités', v_processed_count;
    RAISE NOTICE '  ✓ DELIVERY: % adresses par défaut', v_delivery_count;
    RAISE NOTICE '  ✓ INVOICE: % adresses par défaut', v_invoice_count;
    RAISE NOTICE '  ✓ DOCUMENT: % adresses par défaut', v_document_count;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur lors de l''INSERT types d''adresse: %', SQLERRM;
END;
$procedure$;
