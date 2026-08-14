CREATE OR REPLACE PROCEDURE clean_data.sp_insert_cus_comm_method_from_file_customer()
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion méthodes communication clients depuis file_customer - % - Version améliorée avec ADR2/ADR3/ADR6', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
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
    WITH fc AS (
        -- Source unifiee : fichier + clients PHL absents du fichier.
        -- customer_id et address_id sont deja calcules par la vue.
        SELECT *
        FROM clean_data.v_customer_source
        WHERE customer_id IS NOT NULL
    )
    SELECT
        NULL AS party_type,
        'CUSTOMER' AS party_type_db,
        fc.customer_id AS identity,
        ROW_NUMBER() OVER (ORDER BY fc.customer_id) AS comm_id,
        COALESCE(NULLIF(TRIM(fc.telephone),''), adr2.telnr_long, adr2.tel_number, k.TELF1) AS value,
        'Phone' AS method_id,
        'Téléphone principal' AS description,
        CASE WHEN fc.created_on ~ '^[0-9]{8}$' THEN TO_DATE(fc.created_on, 'YYYYMMDD') ELSE NULL END AS valid_from,
        NULL::DATE AS valid_to,
        'TRUE' AS method_default,
        'TRUE' AS address_default,
        COALESCE(NULLIF(TRIM(fc.name_1),''), k.NAME1) AS name,
        'PHONE' AS method_id_db,
        fc.address_id AS address_id
    FROM fc
    LEFT JOIN raw_data.kna1 k ON fc.kunnr = k.KUNNR AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.adr2 ON LPAD(TRIM(fc.numero_adresse), 10, '0') = LPAD(TRIM(adr2.addrnumber), 10, '0') AND adr2.flgdefault = 'X'
    WHERE COALESCE(NULLIF(TRIM(fc.telephone),''), adr2.telnr_long, adr2.tel_number, k.TELF1) IS NOT NULL
    AND COALESCE(NULLIF(TRIM(fc.telephone),''), adr2.telnr_long, adr2.tel_number, k.TELF1) != ''
    UNION ALL
    SELECT
        NULL AS party_type,
        'CUSTOMER' AS party_type_db,
        fc.customer_id AS identity,
        ROW_NUMBER() OVER (ORDER BY fc.customer_id) AS comm_id,
        COALESCE(NULLIF(TRIM(fc.telephone_2),''), adr2.telnr_long, adr2.tel_number, k.TELF2) AS value,
        'Phone' AS method_id,
        'Téléphone secondaire' AS description,
        CASE WHEN fc.created_on ~ '^[0-9]{8}$' THEN TO_DATE(fc.created_on, 'YYYYMMDD') ELSE NULL END AS valid_from,
        NULL::DATE AS valid_to,
        'FALSE' AS method_default,
        'FALSE' AS address_default,
        COALESCE(NULLIF(TRIM(fc.name_1),''), k.NAME1) AS name,
        'PHONE' AS method_id_db,
        fc.address_id AS address_id
    FROM fc
    LEFT JOIN raw_data.kna1 k ON fc.kunnr = k.KUNNR AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.adr2 ON LPAD(TRIM(fc.numero_adresse), 10, '0') = LPAD(TRIM(adr2.addrnumber), 10, '0') AND (adr2.flgdefault != 'X' OR adr2.flgdefault IS NULL)
    WHERE COALESCE(NULLIF(TRIM(fc.telephone_2),''), adr2.telnr_long, adr2.tel_number, k.TELF2) IS NOT NULL
    AND COALESCE(NULLIF(TRIM(fc.telephone_2),''), adr2.telnr_long, adr2.tel_number, k.TELF2) != ''
    AND COALESCE(NULLIF(TRIM(fc.telephone_2),''), adr2.telnr_long, adr2.tel_number, k.TELF2) != COALESCE(NULLIF(TRIM(fc.telephone),''), k.TELF1)
    UNION ALL
    SELECT
        NULL AS party_type,
        'CUSTOMER' AS party_type_db,
        fc.customer_id AS identity,
        ROW_NUMBER() OVER (ORDER BY fc.customer_id) AS comm_id,
        COALESCE(NULLIF(TRIM(fc.fax),''), adr3.faxnr_long, adr3.fax_number, k.TELFX) AS value,
        'Fax' AS method_id,
        'Fax' AS description,
        CASE WHEN fc.created_on ~ '^[0-9]{8}$' THEN TO_DATE(fc.created_on, 'YYYYMMDD') ELSE NULL END AS valid_from,
        NULL::DATE AS valid_to,
        'FALSE' AS method_default,
        'FALSE' AS address_default,
        COALESCE(NULLIF(TRIM(fc.name_1),''), k.NAME1) AS name,
        'FAX' AS method_id_db,
        fc.address_id AS address_id
    FROM fc
    LEFT JOIN raw_data.kna1 k ON fc.kunnr = k.KUNNR AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.adr3 ON LPAD(TRIM(fc.numero_adresse), 10, '0') = LPAD(TRIM(adr3.addrnumber), 10, '0') AND adr3.flgdefault = 'X'
    WHERE COALESCE(NULLIF(TRIM(fc.fax),''), adr3.faxnr_long, adr3.fax_number, k.TELFX) IS NOT NULL
    AND COALESCE(NULLIF(TRIM(fc.fax),''), adr3.faxnr_long, adr3.fax_number, k.TELFX) != ''
    UNION ALL
    SELECT
        NULL AS party_type,
        'CUSTOMER' AS party_type_db,
        fc.customer_id AS identity,
        ROW_NUMBER() OVER (ORDER BY fc.customer_id) AS comm_id,
        adr6.smtp_addr AS value,
        'E-Mail' AS method_id,
        'Email principal' AS description,
        CASE WHEN fc.created_on ~ '^[0-9]{8}$' THEN TO_DATE(fc.created_on, 'YYYYMMDD') ELSE NULL END AS valid_from,
        NULL::DATE AS valid_to,
        'TRUE' AS method_default,
        'TRUE' AS address_default,
        COALESCE(NULLIF(TRIM(fc.name_1),''), k.NAME1) AS name,
        'E_MAIL' AS method_id_db,
        fc.address_id AS address_id
    FROM fc
    LEFT JOIN raw_data.kna1 k ON fc.kunnr = k.KUNNR AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.adr6 ON LPAD(TRIM(fc.numero_adresse), 10, '0') = LPAD(TRIM(adr6.addrnumber), 10, '0') AND adr6.flgdefault = 'X'
    WHERE adr6.smtp_addr IS NOT NULL AND adr6.smtp_addr != ''
    -- TELEX et TELETEX supprimés : CommMethodCode 'TELEX'/'TELETEX' n'existe pas dans IFS → ORA-20111
    UNION ALL
    SELECT
        NULL AS party_type,
        'CUSTOMER' AS party_type_db,
        fc.customer_id AS identity,
        ROW_NUMBER() OVER (ORDER BY fc.customer_id) AS comm_id,
        adrc.tel_number AS value,
        'Phone' AS method_id,
        'Téléphone (adresse)' AS description,
        CASE WHEN fc.created_on ~ '^[0-9]{8}$' THEN TO_DATE(fc.created_on, 'YYYYMMDD') ELSE NULL END AS valid_from,
        NULL::DATE AS valid_to,
        'FALSE' AS method_default,
        'FALSE' AS address_default,
        COALESCE(NULLIF(TRIM(fc.name_1),''), k.NAME1) AS name,
        'PHONE' AS method_id_db,
        fc.address_id AS address_id
    FROM fc
    LEFT JOIN raw_data.kna1 k ON fc.kunnr = k.KUNNR AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.adrc ON TRIM(fc.numero_adresse) = TRIM(adrc.addrnumber)
    WHERE adrc.tel_number IS NOT NULL
    AND adrc.tel_number != ''
    AND adrc.tel_number NOT IN (COALESCE(NULLIF(TRIM(fc.telephone),''), ''), COALESCE(NULLIF(TRIM(fc.telephone_2),''), ''), COALESCE(k.TELF1, ''), COALESCE(k.TELF2, ''))
    UNION ALL
    SELECT
        NULL AS party_type,
        'CUSTOMER' AS party_type_db,
        fc.customer_id AS identity,
        ROW_NUMBER() OVER (ORDER BY fc.customer_id) AS comm_id,
        adrc.fax_number AS value,
        'Fax' AS method_id,
        'Fax (adresse)' AS description,
        CASE WHEN fc.created_on ~ '^[0-9]{8}$' THEN TO_DATE(fc.created_on, 'YYYYMMDD') ELSE NULL END AS valid_from,
        NULL::DATE AS valid_to,
        'FALSE' AS method_default,
        'FALSE' AS address_default,
        COALESCE(NULLIF(TRIM(fc.name_1),''), k.NAME1) AS name,
        'FAX' AS method_id_db,
        fc.address_id AS address_id
    FROM fc
    LEFT JOIN raw_data.kna1 k ON fc.kunnr = k.KUNNR AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.adrc ON TRIM(fc.numero_adresse) = TRIM(adrc.addrnumber)
    WHERE adrc.fax_number IS NOT NULL
    AND adrc.fax_number != ''
    AND adrc.fax_number NOT IN (COALESCE(NULLIF(TRIM(fc.fax),''), ''), COALESCE(k.TELFX, ''));
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();
    RAISE NOTICE 'INSERT méthodes communication terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT méthodes communication depuis file_customer - %: %', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$;
