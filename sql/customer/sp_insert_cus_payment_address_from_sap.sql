-- Procédure pour insérer les adresses de paiement clients depuis les données SAP
-- Utilise clean_data.ifs_customer comme table maître

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
        'TRIMET' as company,
        ifs.customer_number as identity,
        'Customer' as party_type,
        'CUSTOMER' as party_type_db,
        'SEPA' as way_id,
        COALESCE(ifs.numero_adresse, k.ADRNR) as address_id,
        CONCAT_WS(' - ', COALESCE(k.NAME1, ifs.name_1), COALESCE(k.ORT01, ifs.city)) as description,
        'TRUE' as default_address,
        -- Calcul de l'IBAN depuis les données bancaires
        clean_data.fn_calculate_iban(
            COALESCE(knbk.BANKS, ifs.country), 
            COALESCE(knbk.BANKL, ''), 
            '', 
            COALESCE(knbk.BANKN, '')
        ) as account,
        NULL as bic_code,
        'FALSE' as blocked_for_use,
        NULL as bank_account_validated,
        -- 'NOT VALIDATED' n'est pas un FndBoolean valide dans IFS → 'FALSE' (compte non validé)
        'FALSE' as bank_account_validated_db,
        NULL as bank_account_valid_date
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
    -- SEPA exige un IBAN : on exclut les enregistrements sans IBAN calculable (ORA-20110 SepaBankAddress.VALIDIBAN)
    AND clean_data.fn_calculate_iban(
            COALESCE(knbk.BANKS, ifs.country),
            COALESCE(knbk.BANKL, ''),
            '',
            COALESCE(knbk.BANKN, '')
        ) IS NOT NULL
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
$procedure$;

