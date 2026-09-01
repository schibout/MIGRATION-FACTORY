CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_del_tax_exempt_from_file_customer()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN

    v_start_time := NOW();
    RAISE NOTICE 'Début insertion del tax exempt clients - % - Basé sur file_customer', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');

    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.CUSTOMER_DEL_TAX_EXEMPT;
    RAISE NOTICE 'Table customer_del_tax_exempt vidée';

    -- Insertion directe après TRUNCATE
    INSERT INTO clean_data.CUSTOMER_DEL_TAX_EXEMPT (
        CUSTOMER_ID,
        ADDRESS_ID,
        COMPANY,
        SUPPLY_COUNTRY,
        TAX_EXEMPTION_CERT_NO,
        CERTIFICATION_JURISDICTION,
        CERTIFICATION_DATE,
        EXPIRATION_DATE,
        EXEMPT_CERTIFICATE_TYPE_DB,
        CERTIFICATE_AMOUNT
    )
    WITH fc AS (
        -- Source unifiee : fichier + clients PHL absents du fichier.
        -- customer_id et address_id sont deja calcules par la vue.
        SELECT *
        FROM clean_data.v_customer_source
        WHERE customer_id IS NOT NULL
    )
    SELECT DISTINCT ON (fc.customer_id, fc.address_id, public.get_transcodification('COUNTRY', COALESCE(k.LAND1, fc.country, 'FR')), COALESCE(NULLIF(TRIM(fc.vat_number),''), NULLIF(TRIM(fc.tax_number_1),''), NULLIF(TRIM(fc.tax_number_2),''), 'NO_CERT'))
        fc.customer_id as CUSTOMER_ID,
        fc.address_id as ADDRESS_ID,
        public.get_default_value('clean_data.customer_del_tax_exempt', 'company', 'TRIMET') as COMPANY,
        public.get_transcodification('COUNTRY', COALESCE(k.LAND1, fc.country, 'FR')) as SUPPLY_COUNTRY,
        SUBSTRING(COALESCE(NULLIF(TRIM(fc.vat_number),''), NULLIF(TRIM(fc.tax_number_1),''), NULLIF(TRIM(fc.tax_number_2),''), 'NO_CERT'), 1, 20) as TAX_EXEMPTION_CERT_NO,
        SUBSTRING(public.get_transcodification('COUNTRY', COALESCE(k.LAND1, fc.country, 'FR')), 1, 100) as CERTIFICATION_JURISDICTION,
        CASE WHEN fc.created_on ~ '^[0-9]{8}$'
            THEN TO_TIMESTAMP(fc.created_on, 'YYYYMMDD')
            ELSE NULL END as CERTIFICATION_DATE,
        CASE WHEN fc.created_on ~ '^[0-9]{8}$'
            THEN TO_TIMESTAMP(fc.created_on, 'YYYYMMDD') + INTERVAL '1 year'
            ELSE NULL END as EXPIRATION_DATE,
        public.get_default_value('clean_data.customer_del_tax_exempt', 'exempt_certificate_type_db', 'BLANKET CERTIFICATE') as EXEMPT_CERTIFICATE_TYPE_DB,
        public.get_default_value('clean_data.customer_del_tax_exempt', 'certificate_amount', '0')::numeric as CERTIFICATE_AMOUNT
    FROM fc  -- TABLE MAÎTRE
    LEFT JOIN raw_data.KNA1 k
        ON fc.kunnr = k.KUNNR
        AND (k.LOEVM IS NULL OR k.LOEVM = '')
    ORDER BY fc.customer_id, fc.address_id, public.get_transcodification('COUNTRY', COALESCE(k.LAND1, fc.country, 'FR')), COALESCE(NULLIF(TRIM(fc.vat_number),''), NULLIF(TRIM(fc.tax_number_1),''), NULLIF(TRIM(fc.tax_number_2),''), 'NO_CERT');

    GET DIAGNOSTICS v_processed_count = ROW_COUNT;

    v_end_time := NOW();
    RAISE NOTICE 'INSERT del tax exempt terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));

EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT del tax exempt - %: %', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
