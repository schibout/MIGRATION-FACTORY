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
        public.get_default_value('clean_data.cus_ident_invoice_info', 'company', 'TRIMET') as company,
        cp.customer_id as identity,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'party_type_db', 'CUSTOMER') as party_type_db,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'invoice_fee', 'FALSE') as invoice_fee,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'expire_date', NULL)::date as expire_date,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'national_bank_code', NULL) as national_bank_code,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'group_id', '0') as group_id,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'def_authorizer', NULL) as def_authorizer,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'pay_term_id', '30NETS') as pay_term_id,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'def_vat_code', NULL) as def_vat_code,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'rounding_tax_code', NULL) as rounding_tax_code,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'def_currency', 'EUR') as def_currency,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'paym_dev_days', NULL)::numeric as paym_dev_days,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'identity_type_db', 'EXTERN', 'CUSTOMER_PHL') as identity_type_db,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'def_preliminary_code', NULL) as def_preliminary_code,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'automatic_invoice', 'N') as automatic_invoice,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'percent_tolerance', NULL)::numeric as percent_tolerance,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'amount_tolerance', NULL)::numeric as amount_tolerance,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'ncf_reference_check', 'FALSE') as ncf_reference_check,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'tax_exempt', 'FALSE') as tax_exempt,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'tax_exempt_valid_from', NULL)::date as tax_exempt_valid_from,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'tax_exempt_valid_to', NULL)::date as tax_exempt_valid_to,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'second_tin', 'FALSE') as second_tin,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'report_and_withhold_db', NULL, 'CUSTOMER_PHL') as report_and_withhold_db,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'numeration_group', NULL) as numeration_group,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'tax_book_id', NULL) as tax_book_id,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'tax_book_type', NULL)::numeric as tax_book_type,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'tax_structure_id', 'DEFAULT') as tax_structure_id,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'print_tax_code_text', 'FALSE') as print_tax_code_text,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'no_invoice_copies', '0', 'CUSTOMER_PHL')::numeric as no_invoice_copies
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
