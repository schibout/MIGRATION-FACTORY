CREATE OR REPLACE PROCEDURE clean_data.sp_insert_cus_paym_way_per_ident_from_sap()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion moyens de paiement par identité clients SAP - %', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    TRUNCATE TABLE clean_data.cus_paym_way_per_ident;
    RAISE NOTICE 'Table cus_paym_way_per_ident vidée';
    INSERT INTO clean_data.cus_paym_way_per_ident (
        company,
        identity,
        party_type,
        party_type_db,
        way_id,
        default_payment_way
    )
    SELECT DISTINCT
        public.get_default_value('clean_data.cus_paym_way_per_ident', 'company', 'TRIMET') as company,
        ifs.customer_number as identity,
        public.get_default_value('clean_data.cus_paym_way_per_ident', 'party_type', 'Customer') as party_type,
        public.get_default_value('clean_data.cus_paym_way_per_ident', 'party_type_db', 'CUSTOMER') as party_type_db,
        public.get_default_value('clean_data.cus_paym_way_per_ident', 'way_id', 'SEPA') as way_id,
        public.get_default_value('clean_data.cus_paym_way_per_ident', 'default_payment_way', 'TRUE') as default_payment_way
    FROM clean_data.ifs_customer ifs
    LEFT JOIN raw_data.knb1 
        ON ifs.customer_number = knb1.KUNNR
        AND ifs.company_code = knb1.BUKRS
        AND (knb1.LOEVM IS NULL OR knb1.LOEVM = '')
    WHERE COALESCE(ifs.payment_methods, knb1.ZWELS) IS NOT NULL
    AND COALESCE(ifs.payment_methods, knb1.ZWELS) != '';
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();
    RAISE NOTICE 'INSERT moyens de paiement terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT moyens de paiement - %: %', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
