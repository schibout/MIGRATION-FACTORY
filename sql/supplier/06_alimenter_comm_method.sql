CREATE OR REPLACE FUNCTION clean_data.alimenter_comm_method()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_start_time TIMESTAMP;
    v_records_inserted INTEGER := 0;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    RAISE NOTICE 'Début alimentation comm_method - %', v_start_time;
    
    -- TRUNCATE de la table pour repartir à zéro
    TRUNCATE TABLE clean_data.comm_method;
    RAISE NOTICE 'Table comm_method vidée';
    
    -- Insérer les méthodes de communication depuis la table ifs_fournisseurs
    INSERT INTO clean_data.comm_method (
        party_type_db,
        identity,
        value,
        method_id_db,
        party_type,
        description,
        valid_from,
        valid_to,
        method_default,
        address_default,
        name,
        method_id,
        address_id,
        supplier_id,
        created_timestamp,
        updated_timestamp,
        created_by,
        updated_by,
        is_deleted
    )
    -- TÉLÉPHONE (Phone) - depuis raw_data.adr2
    SELECT 
        'SUPPLIER' as party_type_db,
        f.numero_compte_fournisseur as identity,
        adr2.tel_number as value,
        'PHONE' as method_id_db,
        'Supplier' as party_type,
        CASE 
            WHEN adr2.flgdefault = 'X' THEN 'Téléphone principal du fournisseur'
            ELSE 'Téléphone du fournisseur'
        END as description,
        CURRENT_DATE as valid_from,
        DATE '2099-12-31' as valid_to,
        CASE WHEN adr2.flgdefault = 'X' THEN 'TRUE' ELSE 'FALSE' END as method_default,
        'FALSE' as address_default,
        f.nom_1 as name,
        'Phone' as method_id,
        f.address_id as address_id,
        f.numero_compte_fournisseur as supplier_id,
        COALESCE(f.date_creation_sap::TIMESTAMP, CURRENT_TIMESTAMP) as created_timestamp,
        CURRENT_TIMESTAMP as updated_timestamp,
        'etl_supplier_base' as created_by,
        'etl_supplier_base' as updated_by,
        FALSE as is_deleted
    FROM clean_data.ifs_fournisseurs f
    INNER JOIN raw_data.lfa1 l ON f.numero_compte_fournisseur = l.lifnr
    INNER JOIN raw_data.adrc adrc ON l.adrnr = adrc.addrnumber
    INNER JOIN raw_data.adr2 adr2 ON adrc.addrnumber = adr2.addrnumber
    WHERE adr2.tel_number IS NOT NULL 
    AND adr2.tel_number != ''
    UNION ALL
    -- FAX (Fax) - depuis raw_data.adr3
    SELECT 
        'SUPPLIER' as party_type_db,
        f.numero_compte_fournisseur as identity,
        adr3.fax_number as value,
        'FAX' as method_id_db,
        'Supplier' as party_type,
        CASE 
            WHEN adr3.flgdefault = 'X' THEN 'Numéro de télécopie principal du fournisseur'
            ELSE 'Numéro de télécopie du fournisseur'
        END as description,
        CURRENT_DATE as valid_from,
        DATE '2099-12-31' as valid_to,
        CASE WHEN adr3.flgdefault = 'X' THEN 'TRUE' ELSE 'FALSE' END as method_default,
        'FALSE' as address_default,
        f.nom_1 as name,
        'Fax' as method_id,
        f.address_id as address_id,
        f.numero_compte_fournisseur as supplier_id,
        COALESCE(f.date_creation_sap::TIMESTAMP, CURRENT_TIMESTAMP) as created_timestamp,
        CURRENT_TIMESTAMP as updated_timestamp,
        'etl_supplier_base' as created_by,
        'etl_supplier_base' as updated_by,
        FALSE as is_deleted
    FROM clean_data.ifs_fournisseurs f
    INNER JOIN raw_data.lfa1 l ON f.numero_compte_fournisseur = l.lifnr
    INNER JOIN raw_data.adrc adrc ON l.adrnr = adrc.addrnumber
    INNER JOIN raw_data.adr3 adr3 ON adrc.addrnumber = adr3.addrnumber
    WHERE adr3.fax_number IS NOT NULL 
    AND adr3.fax_number != ''
    UNION ALL
    -- EMAIL (E-Mail) - depuis raw_data.adr6
    SELECT 
        'SUPPLIER' as party_type_db,
        f.numero_compte_fournisseur as identity,
        adr6.smtp_addr as value,
        'E_MAIL' as method_id_db,
        'Supplier' as party_type,
        CASE 
            WHEN adr6.flgdefault = 'X' THEN 'Adresse électronique principale du fournisseur'
            ELSE 'Adresse électronique du fournisseur'
        END as description,
        CURRENT_DATE as valid_from,
        DATE '2099-12-31' as valid_to,
        CASE WHEN adr6.flgdefault = 'X' THEN 'TRUE' ELSE 'FALSE' END as method_default,
        CASE WHEN adr6.flgdefault = 'X' THEN 'TRUE' ELSE 'FALSE' END as address_default,
        f.nom_1 as name,
        'E-Mail' as method_id,
        f.address_id as address_id,
        f.numero_compte_fournisseur as supplier_id,
        COALESCE(f.date_creation_sap::TIMESTAMP, CURRENT_TIMESTAMP) as created_timestamp,
        CURRENT_TIMESTAMP as updated_timestamp,
        'etl_supplier_base' as created_by,
        'etl_supplier_base' as updated_by,
        FALSE as is_deleted
    FROM clean_data.ifs_fournisseurs f
    INNER JOIN raw_data.lfa1 l ON f.numero_compte_fournisseur = l.lifnr
    INNER JOIN raw_data.adrc adrc ON l.adrnr = adrc.addrnumber
    INNER JOIN raw_data.adr6 adr6 ON adrc.addrnumber = adr6.addrnumber
    WHERE adr6.smtp_addr IS NOT NULL 
    AND adr6.smtp_addr != ''
    AND adr6.smtp_addr ILIKE '%@%';
    
    GET DIAGNOSTICS v_records_inserted = ROW_COUNT;
    
    -- Statistiques finales
    RAISE NOTICE '=== ALIMENTATION COMM_METHOD TERMINÉE ===';
    RAISE NOTICE 'Durée: % secondes', EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time));
    RAISE NOTICE 'Enregistrements insérés: %', v_records_inserted;
    
    -- Statistiques détaillées par type de communication
    RAISE NOTICE '=== STATISTIQUES PAR TYPE DE COMMUNICATION ===';
    RAISE NOTICE 'PHONE (Phone): %', 
                 (SELECT COUNT(*) FROM clean_data.comm_method WHERE method_id_db = 'PHONE');
    RAISE NOTICE 'FAX (Fax): %', 
                 (SELECT COUNT(*) FROM clean_data.comm_method WHERE method_id_db = 'FAX');
    RAISE NOTICE 'E_MAIL (E-Mail): %', 
                 (SELECT COUNT(*) FROM clean_data.comm_method WHERE method_id_db = 'E_MAIL');
    
    -- Statistiques qualité
    RAISE NOTICE '=== STATISTIQUES QUALITÉ ===';
    RAISE NOTICE 'Fournisseurs avec au moins un téléphone: %', 
                 (SELECT COUNT(DISTINCT supplier_id) FROM clean_data.comm_method WHERE method_id_db = 'PHONE');
    RAISE NOTICE 'Fournisseurs avec fax: %', 
                 (SELECT COUNT(DISTINCT supplier_id) FROM clean_data.comm_method WHERE method_id_db = 'FAX');
    RAISE NOTICE 'Fournisseurs avec email: %', 
                 (SELECT COUNT(DISTINCT supplier_id) FROM clean_data.comm_method WHERE method_id_db = 'E_MAIL');
    RAISE NOTICE 'Total fournisseurs avec moyens de communication: %', 
                 (SELECT COUNT(DISTINCT supplier_id) FROM clean_data.comm_method);
    RETURN v_records_inserted;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur dans alimenter_comm_method: %', SQLERRM;
END;
$function$
;
