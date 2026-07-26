CREATE OR REPLACE PROCEDURE clean_data.sp_insert_cus_ident_invoice_info_from_file_customer()
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion infos facturation clients SAP - % - Basé sur file_customer', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    TRUNCATE TABLE clean_data.cus_ident_invoice_info;
    RAISE NOTICE 'Table cus_ident_invoice_info vidée';
    WITH fc AS (
        SELECT f.*,
            COALESCE(NULLIF(TRIM(f.nouveau_compte_ifs),''), NULLIF(TRIM(f.num_corrige),''), TRIM(f.kunnr)) AS customer_id,
            COALESCE(NULLIF(split_part(TRIM(f.numero_adresse), '.', 1), ''), '1') AS address_id
        FROM raw_data.file_customer f
        WHERE COALESCE(NULLIF(TRIM(f.nouveau_compte_ifs),''), NULLIF(TRIM(f.num_corrige),''), TRIM(f.kunnr)) IS NOT NULL
    )
    INSERT INTO clean_data.cus_ident_invoice_info (
        company,
        identity,
        party_type,
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
        identity_type,
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
        report_and_withhold,
        report_and_withhold_db,
        numeration_group,
        tax_book_id,
        tax_book_type,
        tax_structure_id,
        print_tax_code_text,
        no_invoice_copies
    )
    SELECT DISTINCT ON (fc.bukrs, fc.customer_id)
        'TRIMET' as company,
        fc.customer_id as identity,
        'Customer' as party_type,
        'CUSTOMER' as party_type_db,
        'FALSE' as invoice_fee,
        NULL as expire_date,
        knb1.HBKID as national_bank_code,
        knb1.TOGRU as group_id,
        NULL as def_authorizer,
        -- Terme de règlement repris du fichier file_customer (terme_reglement)
        NULLIF(TRIM(fc.terme_reglement), '') as pay_term_id,
        -- Code TVA IFS repris du fichier file_customer (code_tva_ifs)
        NULLIF(TRIM(fc.code_tva_ifs), '') as def_vat_code,
        NULL as rounding_tax_code,
        COALESCE(knvv.WAERS, 'EUR') as def_currency,
        NULL as paym_dev_days,
        -- 'CUSTOMER' n'existe pas comme IdentityType dans IFS → valeur valide 'EXTERN'
        'External' as identity_type,
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
        'Blocked' as report_and_withhold,
        'BLOCKED' as report_and_withhold_db,
        NULL as numeration_group,
        NULL as tax_book_id,
        NULL as tax_book_type,
        'DEFAULT' as tax_structure_id,
        'FALSE' as print_tax_code_text,
        1 as no_invoice_copies
    FROM fc
    LEFT JOIN raw_data.kna1 k
        ON fc.kunnr = k.KUNNR
        AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.knb1
        ON fc.kunnr = knb1.KUNNR
        AND fc.bukrs = knb1.BUKRS
        AND (knb1.LOEVM IS NULL OR knb1.LOEVM = '')
    LEFT JOIN raw_data.knvv
        ON fc.kunnr = knvv.KUNNR
    ORDER BY fc.bukrs, fc.customer_id;
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();
    RAISE NOTICE 'INSERT infos facturation terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT infos facturation - %: %', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$;
