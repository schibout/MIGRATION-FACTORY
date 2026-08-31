CREATE OR REPLACE PROCEDURE clean_data.sp_insert_cus_ident_invoice_info_from_sap()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion infos facturation clients SAP - % - Basé sur ifs_customer', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    TRUNCATE TABLE clean_data.cus_ident_invoice_info;
    RAISE NOTICE 'Table cus_ident_invoice_info vidée';
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
    SELECT DISTINCT ON (ifs.company_code, ifs.customer_number)
        public.get_default_value('clean_data.cus_ident_invoice_info', 'company', 'TRIMET') as company,
        ifs.customer_number as identity,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'party_type', 'Customer') as party_type,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'party_type_db', 'CUSTOMER') as party_type_db,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'invoice_fee', 'FALSE') as invoice_fee,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'expire_date', NULL)::date as expire_date,
        knb1.HBKID as national_bank_code,
        knb1.TOGRU as group_id,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'def_authorizer', NULL) as def_authorizer,
        COALESCE(knb1.ZTERM, 'NET30') as pay_term_id,
        COALESCE(ifs.vat_number, k.STCEG) as def_vat_code,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'rounding_tax_code', NULL) as rounding_tax_code,
        COALESCE(knvv.WAERS, 'EUR') as def_currency,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'paym_dev_days', NULL)::numeric as paym_dev_days,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'identity_type', 'Customer', 'CUSTOMER') as identity_type,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'identity_type_db', 'CUSTOMER', 'CUSTOMER') as identity_type_db,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'def_preliminary_code', NULL) as def_preliminary_code,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'automatic_invoice', 'N') as automatic_invoice,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'percent_tolerance', NULL)::numeric as percent_tolerance,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'amount_tolerance', NULL)::numeric as amount_tolerance,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'ncf_reference_check', 'FALSE') as ncf_reference_check,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'tax_exempt', 'FALSE') as tax_exempt,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'tax_exempt_valid_from', NULL)::date as tax_exempt_valid_from,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'tax_exempt_valid_to', NULL)::date as tax_exempt_valid_to,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'second_tin', 'FALSE') as second_tin,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'report_and_withhold', 'No Report', 'CUSTOMER') as report_and_withhold,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'report_and_withhold_db', 'NO_REPORT', 'CUSTOMER') as report_and_withhold_db,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'numeration_group', NULL) as numeration_group,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'tax_book_id', NULL) as tax_book_id,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'tax_book_type', NULL)::numeric as tax_book_type,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'tax_structure_id', 'DEFAULT') as tax_structure_id,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'print_tax_code_text', 'FALSE') as print_tax_code_text,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'no_invoice_copies', '1', 'CUSTOMER')::numeric as no_invoice_copies
    FROM clean_data.ifs_customer ifs
    LEFT JOIN raw_data.kna1 k 
        ON ifs.customer_number = k.KUNNR
        AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.knb1 
        ON ifs.customer_number = knb1.KUNNR
        AND ifs.company_code = knb1.BUKRS
        AND (knb1.LOEVM IS NULL OR knb1.LOEVM = '')
    LEFT JOIN raw_data.knvv 
        ON ifs.customer_number = knvv.KUNNR
    ORDER BY ifs.company_code, ifs.customer_number;
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();
    RAISE NOTICE 'INSERT infos facturation terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT infos facturation - %: %', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
