CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_tax_free_tax_code_from_file_customer()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion tax free code clients - % - Basé sur file_customer', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');

    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.CUSTOMER_TAX_FREE_TAX_CODE;
    RAISE NOTICE 'Table customer_tax_free_tax_code vidée';

    -- Insertion directe après TRUNCATE
    INSERT INTO clean_data.CUSTOMER_TAX_FREE_TAX_CODE (
        CUSTOMER_ID,
        ADDRESS_ID,
        COMPANY,
        SUPPLY_COUNTRY,
        DELIVERY_TYPE,
        VAT_FREE_VAT_CODE
    )
    WITH fc AS (
        -- Source unifiee : fichier + clients PHL absents du fichier.
        -- customer_id et address_id sont deja calcules par la vue.
        SELECT *
        FROM clean_data.v_customer_source
        WHERE customer_id IS NOT NULL
    )
    -- Une ligne par client/adresse ET par type de livraison (GOODS et SERVICE)
    SELECT
        sub.customer_id as CUSTOMER_ID,
        sub.address_id as ADDRESS_ID,
        public.get_default_value('clean_data.customer_tax_free_tax_code', 'company') as COMPANY,
        sub.supply_country as SUPPLY_COUNTRY,
        dt.delivery_type as DELIVERY_TYPE,
        public.get_default_value('clean_data.customer_tax_free_tax_code', 'vat_free_vat_code', 'CUSTOMERFILE') as VAT_FREE_VAT_CODE
    FROM (
        SELECT DISTINCT ON (fc.customer_id, fc.address_id)
            fc.customer_id,
            fc.address_id,
            COALESCE(NULLIF(TRIM(fc.country),''), 'FR') as supply_country
        FROM fc  -- TABLE MAÎTRE
        ORDER BY fc.customer_id, fc.address_id
    ) sub
    CROSS JOIN (VALUES ('GOODS'), ('SERVICE')) AS dt(delivery_type)
    ORDER BY sub.customer_id, sub.address_id, dt.delivery_type;

    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    v_end_time := NOW();

    RAISE NOTICE 'INSERT tax free code terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));

EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT tax free code depuis file_customer - %: %',
            TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
