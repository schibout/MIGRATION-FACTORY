CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_delivery_tax_info_from_file_customer()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
BEGIN

    RAISE NOTICE 'Début insertion delivery tax info clients - Basé sur file_customer';

    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.customer_delivery_tax_info;
    RAISE NOTICE 'Table customer_delivery_tax_info vidée';

    -- Insertion directe après TRUNCATE
    INSERT INTO clean_data.customer_delivery_tax_info (
        CUSTOMER_ID,
        ADDRESS_ID,
        COMPANY,
        SUPPLY_COUNTRY,
        SUPPLY_COUNTRY_DB,
        CUS_COUNTRY_CODE,
        TAX_LIABILITY,
        TAX_BOOK_ID,
        TAX_BOOK_TYPE,
        TAX_STRUCTURE_ID,
        TAX_CALC_STRUCTURE_ID
    )
    WITH fc AS (
        -- Source unifiee : fichier + clients PHL absents du fichier.
        -- customer_id et address_id sont deja calcules par la vue.
        SELECT *
        FROM clean_data.v_customer_source
        WHERE customer_id IS NOT NULL
    )
    SELECT DISTINCT ON (fc.customer_id, fc.address_id, public.get_transcodification('COUNTRY', COALESCE(k.LAND1, fc.country, 'FR')))
        fc.customer_id as CUSTOMER_ID,
        fc.address_id as ADDRESS_ID,
        'TRIMET' as COMPANY,
        NULL as SUPPLY_COUNTRY,
        public.get_transcodification('COUNTRY', COALESCE(k.LAND1, fc.country, 'FR')) as SUPPLY_COUNTRY_DB,
        public.get_transcodification('COUNTRY', COALESCE(k.LAND1, fc.country, 'FR')) as CUS_COUNTRY_CODE,
        'TAX' as TAX_LIABILITY,
        NULL as TAX_BOOK_ID,
        NULL as TAX_BOOK_TYPE,
        NULL as TAX_STRUCTURE_ID,
        NULL as TAX_CALC_STRUCTURE_ID
    FROM fc  -- TABLE MAÎTRE
    LEFT JOIN raw_data.KNA1 k
        ON fc.kunnr = k.KUNNR
        AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.T005T t_country
        ON COALESCE(k.LAND1, fc.country) = t_country.LAND1
        AND t_country.SPRAS = 'F'
    ORDER BY fc.customer_id, fc.address_id, public.get_transcodification('COUNTRY', COALESCE(k.LAND1, fc.country, 'FR'));

    GET DIAGNOSTICS v_processed_count = ROW_COUNT;

    RAISE NOTICE 'INSERT delivery tax info terminé: % enregistrements traités', v_processed_count;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur lors de l''INSERT delivery tax info: %', SQLERRM;
END;
$procedure$
