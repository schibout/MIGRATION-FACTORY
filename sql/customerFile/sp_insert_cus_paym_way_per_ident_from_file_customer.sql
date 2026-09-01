CREATE OR REPLACE PROCEDURE clean_data.sp_insert_cus_paym_way_per_ident_from_file_customer()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion moyens de paiement par identité clients SAP - % - Basé sur file_customer', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    TRUNCATE TABLE clean_data.cus_paym_way_per_ident;
    RAISE NOTICE 'Table cus_paym_way_per_ident vidée';
    WITH fc AS (
        -- Source unifiee : fichier + clients PHL absents du fichier.
        -- customer_id et address_id sont deja calcules par la vue.
        SELECT *
        FROM clean_data.v_customer_source
        WHERE customer_id IS NOT NULL
    )
    INSERT INTO clean_data.cus_paym_way_per_ident (
        company,
        identity,
        party_type_db,
        way_id,
        default_payment_way
    )
    SELECT DISTINCT
        public.get_default_value('clean_data.cus_paym_way_per_ident', 'company', 'TRIMET') as company,
        fc.customer_id as identity,
        public.get_default_value('clean_data.cus_paym_way_per_ident', 'party_type_db', 'CUSTOMER') as party_type_db,
        public.get_default_value('clean_data.cus_paym_way_per_ident', 'way_id', 'SEPA') as way_id,
        public.get_default_value('clean_data.cus_paym_way_per_ident', 'default_payment_way', 'TRUE') as default_payment_way
    FROM fc
    LEFT JOIN raw_data.knb1
        ON fc.kunnr = knb1.KUNNR
        AND fc.bukrs = knb1.BUKRS
        AND (knb1.LOEVM IS NULL OR knb1.LOEVM = '')
    WHERE COALESCE(NULLIF(TRIM(fc.payment_methods),''), knb1.ZWELS) IS NOT NULL
    AND COALESCE(NULLIF(TRIM(fc.payment_methods),''), knb1.ZWELS) != ''
    -- Filtre de cohérence : n'inclure que les clients chargés dans cus_identity_pay_info
    -- évite ORA-20110 IdentityPayInfo.IDENTITYPAYEXIST
    AND fc.customer_id IN (
        SELECT identity FROM clean_data.cus_identity_pay_info WHERE company = 'TRIMET'
    );
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
