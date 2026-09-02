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
        -- Source unifiee : fichier + clients PHL absents du fichier.
        -- customer_id et address_id sont deja calcules par la vue.
        SELECT *
        FROM clean_data.v_customer_source
        WHERE customer_id IS NOT NULL
    )
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
    SELECT DISTINCT ON (fc.bukrs, fc.customer_id)
        public.get_default_value('clean_data.cus_ident_invoice_info', 'company') as company,
        fc.customer_id as identity,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'party_type_db') as party_type_db,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'invoice_fee') as invoice_fee,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'expire_date')::date as expire_date,
        knb1.HBKID as national_bank_code,
        knb1.TOGRU as group_id,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'def_authorizer') as def_authorizer,
        -- Terme de règlement repris du fichier file_customer (terme_reglement)
        NULLIF(TRIM(fc.terme_reglement), '') as pay_term_id,
        -- Code TVA IFS repris du fichier file_customer (code_tva_ifs)
        NULLIF(TRIM(fc.code_tva_ifs), '') as def_vat_code,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'rounding_tax_code') as rounding_tax_code,
        COALESCE(knvv.WAERS, 'EUR') as def_currency,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'paym_dev_days')::numeric as paym_dev_days,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'identity_type_db', 'CUSTOMERFILE') as identity_type_db,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'def_preliminary_code') as def_preliminary_code,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'automatic_invoice') as automatic_invoice,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'percent_tolerance')::numeric as percent_tolerance,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'amount_tolerance')::numeric as amount_tolerance,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'ncf_reference_check') as ncf_reference_check,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'tax_exempt') as tax_exempt,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'tax_exempt_valid_from')::date as tax_exempt_valid_from,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'tax_exempt_valid_to')::date as tax_exempt_valid_to,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'second_tin') as second_tin,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'report_and_withhold_db', 'CUSTOMERFILE') as report_and_withhold_db,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'numeration_group') as numeration_group,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'tax_book_id') as tax_book_id,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'tax_book_type')::numeric as tax_book_type,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'tax_structure_id') as tax_structure_id,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'print_tax_code_text') as print_tax_code_text,
        public.get_default_value('clean_data.cus_ident_invoice_info', 'no_invoice_copies', 'CUSTOMERFILE')::numeric as no_invoice_copies
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
$procedure$
