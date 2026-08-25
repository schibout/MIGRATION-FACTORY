CREATE OR REPLACE PROCEDURE clean_data.sp_insert_cus_ident_invoice_info_from_client_phl()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion infos facturation clients PHL - %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.cus_ident_invoice_info;
    RAISE NOTICE 'Table cus_ident_invoice_info vidée';
    
    -- Insertion des données PHL
    INSERT INTO clean_data.cus_ident_invoice_info (
        company,
        identity,
        party_type_db,
        invoice_fee,
        expire_date,
        national_bank_code,
        group_id,
        def_authorizer,
        pay_term_id,
        def_vat_code,
        rounding_tax_code,
        def_currency,
        paym_dev_days,
        identity_type_db,
        def_preliminary_code,
        automatic_invoice,
        percent_tolerance,
        amount_tolerance,
        ncf_reference_check,
        tax_exempt,
        tax_exempt_valid_from,
        tax_exempt_valid_to,
        second_tin,
        report_and_withhold_db,
        numeration_group,
        tax_book_id,
        tax_book_type,
        tax_structure_id,
        print_tax_code_text,
        no_invoice_copies
    )
    SELECT DISTINCT ON (cp.customer_id)
        'TRIMET' as company,
        cp.customer_id as identity,
        'CUSTOMER' as party_type_db,
        'FALSE' as invoice_fee,
        NULL as expire_date,
        NULL as national_bank_code,
        '0' as group_id,
        NULL as def_authorizer,
        '30NETS' as pay_term_id,
        NULL as def_vat_code,
        NULL as rounding_tax_code,
        'EUR' as def_currency,
        NULL as paym_dev_days,
        'EXTERN' as identity_type_db,
        NULL as def_preliminary_code,
        'N' as automatic_invoice,
        NULL as percent_tolerance,
        NULL as amount_tolerance,
        'FALSE' as ncf_reference_check,
        'FALSE' as tax_exempt,
        NULL as tax_exempt_valid_from,
        NULL as tax_exempt_valid_to,
        'FALSE' as second_tin,
        NULL as report_and_withhold_db,
        NULL as numeration_group,
        NULL as tax_book_id,
        NULL as tax_book_type,
        'DEFAULT' as tax_structure_id,
        'FALSE' as print_tax_code_text,
        0 as no_invoice_copies
    FROM raw_data.client_phl cp
    WHERE cp.customer_id IS NOT NULL
    ORDER BY cp.customer_id;
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();
    
    RAISE NOTICE 'INSERT infos facturation terminé - %: % enregistrements insérés', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT infos facturation depuis client_phl - %: %', 
            TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
