CREATE OR REPLACE PROCEDURE clean_data.sp_insert_cus_payment_address_from_sap()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion adresses paiement clients SAP - % - Basé sur ifs_customer', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.cus_payment_address;
    RAISE NOTICE 'Table cus_payment_address vidée';
    
    -- Insertion directe après TRUNCATE
    INSERT INTO clean_data.cus_payment_address (
        company,
        identity,
        party_type,
        party_type_db,
        way_id,
        address_id,
        description,
        default_address,
        account,
        bic_code,
        blocked_for_use,
        bank_account_validated,
        bank_account_validated_db,
        bank_account_valid_date
    )
    SELECT DISTINCT ON (ifs.customer_number, COALESCE(ifs.payment_methods, knb1.ZWELS, 'TRANSFER'), COALESCE(ifs.numero_adresse, k.ADRNR))
        public.get_default_value('clean_data.cus_payment_address', 'company', 'TRIMET') as company,
        ifs.customer_number as identity,
        public.get_default_value('clean_data.cus_payment_address', 'party_type', 'Customer') as party_type,
        public.get_default_value('clean_data.cus_payment_address', 'party_type_db', 'CUSTOMER') as party_type_db,
        public.get_default_value('clean_data.cus_payment_address', 'way_id', 'SEPA') as way_id,
        COALESCE(ifs.numero_adresse, k.ADRNR) as address_id,
        CONCAT_WS(' - ', COALESCE(k.NAME1, ifs.name_1), COALESCE(k.ORT01, ifs.city)) as description,
        CASE
            WHEN ROW_NUMBER() OVER (
                PARTITION BY ifs.customer_number
                ORDER BY
                    CASE WHEN COALESCE(ifs.numero_adresse, k.ADRNR) IN ('01', '1') THEN 0 ELSE 1 END,
                    CASE WHEN COALESCE(ifs.numero_adresse, k.ADRNR) = '1' THEN '01' ELSE COALESCE(ifs.numero_adresse, k.ADRNR) END,
                    COALESCE(ifs.numero_adresse, k.ADRNR)
            ) = 1 THEN 'TRUE'
            ELSE 'FALSE'
        END as default_address,
        -- Calcul de l'IBAN depuis les données bancaires
        clean_data.fn_calculate_iban(
            COALESCE(knbk.BANKS, ifs.country), 
            COALESCE(knbk.BANKL, ''), 
            '', 
            COALESCE(knbk.BANKN, '')
        ) as account,
        public.get_default_value('clean_data.cus_payment_address', 'bic_code', NULL) as bic_code,
        public.get_default_value('clean_data.cus_payment_address', 'blocked_for_use', 'FALSE') as blocked_for_use,
        public.get_default_value('clean_data.cus_payment_address', 'bank_account_validated', NULL) as bank_account_validated,
        public.get_default_value('clean_data.cus_payment_address', 'bank_account_validated_db', 'NOT VALIDATED', 'CUSTOMER') as bank_account_validated_db,
        public.get_default_value('clean_data.cus_payment_address', 'bank_account_valid_date', NULL)::date as bank_account_valid_date
    FROM clean_data.ifs_customer ifs
    LEFT JOIN raw_data.KNA1 k 
        ON ifs.customer_number = k.KUNNR
        AND ifs.numero_adresse = k.ADRNR
        AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.KNB1 knb1 
        ON ifs.customer_number = knb1.KUNNR
        AND (knb1.LOEVM IS NULL OR knb1.LOEVM = '')
    LEFT JOIN raw_data.KNBK knbk
        ON ifs.customer_number = knbk.KUNNR
    WHERE COALESCE(ifs.numero_adresse, k.ADRNR) IS NOT NULL
    ORDER BY ifs.customer_number, COALESCE(ifs.payment_methods, knb1.ZWELS, 'TRANSFER'), COALESCE(ifs.numero_adresse, k.ADRNR);
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    
    v_end_time := NOW();
    RAISE NOTICE 'INSERT adresses paiement terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT adresses paiement - %: %', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
