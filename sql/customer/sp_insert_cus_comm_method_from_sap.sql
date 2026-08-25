CREATE OR REPLACE PROCEDURE clean_data.sp_insert_cus_comm_method_from_sap()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion méthodes communication clients SAP - % - Version améliorée avec ADR2/ADR3/ADR6', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    TRUNCATE TABLE clean_data.cus_comm_method;
    RAISE NOTICE 'Table cus_comm_method vidée';
    INSERT INTO clean_data.cus_comm_method (
        party_type,
        party_type_db,
        identity,
        comm_id,
        value,
        method_id,
        description,
        valid_from,
        valid_to,
        method_default,
        address_default,
        name,
        method_id_db,
        address_id
    )
    SELECT 
        NULL AS party_type,
        'CUSTOMER' AS party_type_db,
        ifs.customer_number AS identity,
        ROW_NUMBER() OVER (ORDER BY ifs.customer_number) AS comm_id,
        COALESCE(adr2.telnr_long, adr2.tel_number, k.TELF1, ifs.telephone) AS value,
        'Phone' AS method_id,
        'Téléphone principal' AS description,
        ifs.created_on AS valid_from,
        NULL::DATE AS valid_to,
        'TRUE' AS method_default,
        'TRUE' AS address_default,
        COALESCE(k.NAME1, ifs.name_1) AS name,
        'PHONE' AS method_id_db,
        COALESCE(ifs.numero_adresse, k.ADRNR) AS address_id
    FROM clean_data.ifs_customer ifs
    LEFT JOIN raw_data.kna1 k ON ifs.customer_number = k.KUNNR AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.adr2 ON LPAD(TRIM(k.ADRNR), 10, '0') = LPAD(TRIM(adr2.addrnumber), 10, '0') AND adr2.flgdefault = 'X'
    WHERE COALESCE(adr2.telnr_long, adr2.tel_number, k.TELF1, ifs.telephone) IS NOT NULL 
    AND COALESCE(adr2.telnr_long, adr2.tel_number, k.TELF1, ifs.telephone) != ''
    UNION ALL
    SELECT 
        NULL AS party_type,
        'CUSTOMER' AS party_type_db,
        ifs.customer_number AS identity,
        ROW_NUMBER() OVER (ORDER BY ifs.customer_number) AS comm_id,
        COALESCE(adr2.telnr_long, adr2.tel_number, k.TELF2, ifs.telephone_2) AS value,
        'Phone' AS method_id,
        'Téléphone secondaire' AS description,
        ifs.created_on AS valid_from,
        NULL::DATE AS valid_to,
        'FALSE' AS method_default,
        'FALSE' AS address_default,
        COALESCE(k.NAME1, ifs.name_1) AS name,
        'PHONE' AS method_id_db,
        COALESCE(ifs.numero_adresse, k.ADRNR) AS address_id
    FROM clean_data.ifs_customer ifs
    LEFT JOIN raw_data.kna1 k ON ifs.customer_number = k.KUNNR AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.adr2 ON LPAD(TRIM(k.ADRNR), 10, '0') = LPAD(TRIM(adr2.addrnumber), 10, '0') AND (adr2.flgdefault != 'X' OR adr2.flgdefault IS NULL)
    WHERE COALESCE(adr2.telnr_long, adr2.tel_number, k.TELF2, ifs.telephone_2) IS NOT NULL 
    AND COALESCE(adr2.telnr_long, adr2.tel_number, k.TELF2, ifs.telephone_2) != ''
    AND COALESCE(adr2.telnr_long, adr2.tel_number, k.TELF2, ifs.telephone_2) != COALESCE(k.TELF1, ifs.telephone)
    UNION ALL
    SELECT 
        NULL AS party_type,
        'CUSTOMER' AS party_type_db,
        ifs.customer_number AS identity,
        ROW_NUMBER() OVER (ORDER BY ifs.customer_number) AS comm_id,
        COALESCE(adr3.faxnr_long, adr3.fax_number, k.TELFX, ifs.fax) AS value,
        'Fax' AS method_id,
        'Fax' AS description,
        ifs.created_on AS valid_from,
        NULL::DATE AS valid_to,
        'FALSE' AS method_default,
        'FALSE' AS address_default,
        COALESCE(k.NAME1, ifs.name_1) AS name,
        'FAX' AS method_id_db,
        COALESCE(ifs.numero_adresse, k.ADRNR) AS address_id
    FROM clean_data.ifs_customer ifs
    LEFT JOIN raw_data.kna1 k ON ifs.customer_number = k.KUNNR AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.adr3 ON LPAD(TRIM(k.ADRNR), 10, '0') = LPAD(TRIM(adr3.addrnumber), 10, '0') AND adr3.flgdefault = 'X'
    WHERE COALESCE(adr3.faxnr_long, adr3.fax_number, k.TELFX, ifs.fax) IS NOT NULL 
    AND COALESCE(adr3.faxnr_long, adr3.fax_number, k.TELFX, ifs.fax) != ''
    UNION ALL
    SELECT 
        NULL AS party_type,
        'CUSTOMER' AS party_type_db,
        ifs.customer_number AS identity,
        ROW_NUMBER() OVER (ORDER BY ifs.customer_number) AS comm_id,
        adr6.smtp_addr AS value,
        'E-Mail' AS method_id,
        'Email principal' AS description,
        ifs.created_on AS valid_from,
        NULL::DATE AS valid_to,
        'TRUE' AS method_default,
        'TRUE' AS address_default,
        COALESCE(k.NAME1, ifs.name_1) AS name,
        'E_MAIL' AS method_id_db,
        COALESCE(ifs.numero_adresse, k.ADRNR) AS address_id
    FROM clean_data.ifs_customer ifs
    LEFT JOIN raw_data.kna1 k ON ifs.customer_number = k.KUNNR AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.adr6 ON LPAD(TRIM(k.ADRNR), 10, '0') = LPAD(TRIM(adr6.addrnumber), 10, '0') AND adr6.flgdefault = 'X'
    WHERE adr6.smtp_addr IS NOT NULL AND adr6.smtp_addr != ''
    UNION ALL
    SELECT 
        NULL AS party_type,
        'CUSTOMER' AS party_type_db,
        ifs.customer_number AS identity,
        ROW_NUMBER() OVER (ORDER BY ifs.customer_number) AS comm_id,
        COALESCE(k.TELX1, ifs.telex) AS value,
        'Telex' AS method_id,
        'Telex' AS description,
        ifs.created_on AS valid_from,
        NULL::DATE AS valid_to,
        'FALSE' AS method_default,
        'FALSE' AS address_default,
        COALESCE(k.NAME1, ifs.name_1) AS name,
        'TELEX' AS method_id_db,
        COALESCE(ifs.numero_adresse, k.ADRNR) AS address_id
    FROM clean_data.ifs_customer ifs
    LEFT JOIN raw_data.kna1 k ON ifs.customer_number = k.KUNNR AND (k.LOEVM IS NULL OR k.LOEVM = '')
    WHERE COALESCE(k.TELX1, ifs.telex) IS NOT NULL AND COALESCE(k.TELX1, ifs.telex) != ''
    UNION ALL
    SELECT 
        NULL AS party_type,
        'CUSTOMER' AS party_type_db,
        ifs.customer_number AS identity,
        ROW_NUMBER() OVER (ORDER BY ifs.customer_number) AS comm_id,
        COALESCE(k.TELTX, ifs.teletex) AS value,
        'Teletex' AS method_id,
        'Teletex' AS description,
        ifs.created_on AS valid_from,
        NULL::DATE AS valid_to,
        'FALSE' AS method_default,
        'FALSE' AS address_default,
        COALESCE(k.NAME1, ifs.name_1) AS name,
        'TELETEX' AS method_id_db,
        COALESCE(ifs.numero_adresse, k.ADRNR) AS address_id
    FROM clean_data.ifs_customer ifs
    LEFT JOIN raw_data.kna1 k ON ifs.customer_number = k.KUNNR AND (k.LOEVM IS NULL OR k.LOEVM = '')
    WHERE COALESCE(k.TELTX, ifs.teletex) IS NOT NULL AND COALESCE(k.TELTX, ifs.teletex) != ''
    UNION ALL
    SELECT 
        NULL AS party_type,
        'CUSTOMER' AS party_type_db,
        ifs.customer_number AS identity,
        ROW_NUMBER() OVER (ORDER BY ifs.customer_number) AS comm_id,
        adrc.tel_number AS value,
        'Phone' AS method_id,
        'Téléphone (adresse)' AS description,
        ifs.created_on AS valid_from,
        NULL::DATE AS valid_to,
        'FALSE' AS method_default,
        'FALSE' AS address_default,
        COALESCE(k.NAME1, ifs.name_1) AS name,
        'PHONE' AS method_id_db,
        COALESCE(ifs.numero_adresse, k.ADRNR) AS address_id
    FROM clean_data.ifs_customer ifs
    LEFT JOIN raw_data.kna1 k ON ifs.customer_number = k.KUNNR AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.adrc ON TRIM(k.ADRNR) = TRIM(adrc.addrnumber)
    WHERE adrc.tel_number IS NOT NULL 
    AND adrc.tel_number != ''
    AND adrc.tel_number NOT IN (COALESCE(k.TELF1, ''), COALESCE(k.TELF2, ''))
    UNION ALL
    SELECT 
        NULL AS party_type,
        'CUSTOMER' AS party_type_db,
        ifs.customer_number AS identity,
        ROW_NUMBER() OVER (ORDER BY ifs.customer_number) AS comm_id,
        adrc.fax_number AS value,
        'Fax' AS method_id,
        'Fax (adresse)' AS description,
        ifs.created_on AS valid_from,
        NULL::DATE AS valid_to,
        'FALSE' AS method_default,
        'FALSE' AS address_default,
        COALESCE(k.NAME1, ifs.name_1) AS name,
        'FAX' AS method_id_db,
        COALESCE(ifs.numero_adresse, k.ADRNR) AS address_id
    FROM clean_data.ifs_customer ifs
    LEFT JOIN raw_data.kna1 k ON ifs.customer_number = k.KUNNR AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.adrc ON TRIM(k.ADRNR) = TRIM(adrc.addrnumber)
    WHERE adrc.fax_number IS NOT NULL 
    AND adrc.fax_number != ''
    AND adrc.fax_number != COALESCE(k.TELFX, '');
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();
    RAISE NOTICE 'INSERT méthodes communication terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT méthodes communication - %: %', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
