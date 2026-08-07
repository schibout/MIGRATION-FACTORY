CREATE OR REPLACE FUNCTION clean_data.insert_supplier_document_tax_info()
 RETURNS TABLE(execution_status text, total_inserted integer, execution_time interval)
 LANGUAGE plpgsql
AS $function$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    inserted_count INTEGER := 0;
BEGIN
    start_time := clock_timestamp();
    
    -- Vider complètement la table destination
    TRUNCATE TABLE clean_data.supplier_document_tax_info;
    
    -- =====================================
    -- INSERTION DES DONNÉES SUPPLIER_DOCUMENT_TAX_INFO
    -- =====================================
    INSERT INTO clean_data.supplier_document_tax_info (
        supplier_id,
        address_id,
        company,
        tax_id_type,
        vat_no,
        validated_date,
        reliability_status_db,
        declaration_date,
        last_modify_date,
        tax_office_id,
        company_addr_tax_id_type,
        company_addr_tax_id_type_db,
        created_timestamp,
        updated_timestamp,
        created_by,
        updated_by,
        is_deleted
    )
    SELECT 
        sia.supplier_id,
        sia.address_id,
        'TRIMET' as company,
        CASE 
            WHEN sia.country = 'FR' THEN 'SIRET'
            WHEN sia.country = 'DE' THEN 'TVA DE'
            WHEN sia.country ='BE' THEN 'VAT BE'
            WHEN sia.country ='NL' THEN 'VAT NL'
            WHEN sia.country ='IT' THEN 'VAT IT'
            ELSE 'OTHER'
        END as tax_id_type,
        COALESCE(ifs.tva, 'NO_VAT_' || sia.supplier_id) as vat_no,
        CURRENT_DATE as validated_date,
        'NOT_SET' as reliability_status_db,
        CURRENT_DATE as declaration_date,
        CURRENT_DATE as last_modify_date,
        '' as tax_office_id,
        '' as company_addr_tax_id_type,
        'FALSE' as company_addr_tax_id_type_db,
        COALESCE(sia.created_timestamp, NOW()) as created_timestamp,
        NOW() as updated_timestamp,
        COALESCE(sia.created_by, 'system') as created_by,
        'insert_supplier_tax_info_v1' as updated_by,
        COALESCE(sia.is_deleted, FALSE) as is_deleted
    FROM clean_data.supplier_info_address sia
    LEFT JOIN clean_data.ifs_fournisseurs ifs ON sia.supplier_id = ifs.numero_compte_fournisseur
    WHERE COALESCE(sia.is_deleted, FALSE) = FALSE;
    
    GET DIAGNOSTICS inserted_count = ROW_COUNT;
    
    end_time := clock_timestamp();
    
    RETURN QUERY SELECT 
        '✅ INSERTION RÉUSSIE - Table supplier_document_tax_info alimentée' as execution_status,
        inserted_count,
        end_time - start_time;
        
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT 
            '❌ ERREUR: ' || SQLERRM as execution_status,
            0 as total_inserted,
            INTERVAL '0' as execution_time;
END;
$function$
;
