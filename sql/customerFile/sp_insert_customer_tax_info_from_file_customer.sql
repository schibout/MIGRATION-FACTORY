CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_tax_info_from_file_customer()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
BEGIN

    RAISE NOTICE 'Début insertion tax info clients - Basé sur file_customer';

    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.CUSTOMER_TAX_INFO;
    RAISE NOTICE 'Table customer_tax_info vidée';

    -- Insertion directe après TRUNCATE
    INSERT INTO clean_data.CUSTOMER_TAX_INFO (
        CUSTOMER_ID,
        ADDRESS_ID,
        COMPANY,
        TAX_WITHHOLDING_DB,
        TAX_ROUNDING_METHOD_DB,
        TAX_ROUNDING_LEVEL_DB,
        WITHHOLDING_BASE_AMOUNT_DB,
        TAX_EXEMPT_DB,
        TAX_EXEMPT_VALID_FROM,
        TAX_EXEMPT_VALID_TO,
        TAX_OFFICE_ID,
        FISCAL_NO,
        EXC_FROM_SPESOMETRO_DEC_DB,
        ICMS_TAX_PAYER_DB,
        PERMANENT_ESTABLISHMENT_DB,
        OUT_INV_VOU_DATE_BASE_DB,
        OUT_INV_CURR_RATE_BASE_DB,
        TAX_SELL_CURR_RATE_BASE_DB,
        ENABLE_FOR_TCS_DB,
        BUSINESS_TRANSACTION_ID,
        COMPONENT_A,
        COMPONENT_A_IDENTITY
    )
    WITH fc AS (
        -- Source unifiee : fichier + clients PHL absents du fichier.
        -- customer_id et address_id sont deja calcules par la vue.
        SELECT *
        FROM clean_data.v_customer_source
        WHERE customer_id IS NOT NULL
    )
    SELECT DISTINCT ON (fc.customer_id, fc.address_id)
        fc.customer_id as CUSTOMER_ID,
        fc.address_id as ADDRESS_ID,
        public.get_default_value('clean_data.customer_tax_info', 'company', 'TRIMET') as COMPANY,
        public.get_default_value('clean_data.customer_tax_info', 'tax_withholding_db', 'BLOCKED') as TAX_WITHHOLDING_DB,
        public.get_default_value('clean_data.customer_tax_info', 'tax_rounding_method_db', 'ROUND_NEAREST') as TAX_ROUNDING_METHOD_DB,
        public.get_default_value('clean_data.customer_tax_info', 'tax_rounding_level_db', 'LINE_LEVEL') as TAX_ROUNDING_LEVEL_DB,
        public.get_default_value('clean_data.customer_tax_info', 'withholding_base_amount_db', 'INVOICENET') as WITHHOLDING_BASE_AMOUNT_DB,
        public.get_default_value('clean_data.customer_tax_info', 'tax_exempt_db', 'FALSE') as TAX_EXEMPT_DB,
        public.get_default_value('clean_data.customer_tax_info', 'tax_exempt_valid_from', NULL)::timestamp as TAX_EXEMPT_VALID_FROM,
        public.get_default_value('clean_data.customer_tax_info', 'tax_exempt_valid_to', NULL)::timestamp as TAX_EXEMPT_VALID_TO,
        public.get_default_value('clean_data.customer_tax_info', 'tax_office_id', NULL) as TAX_OFFICE_ID,
        COALESCE(SUBSTRING(k.STCEG, 1, 16), SUBSTRING(k.STCD1, 1, 16), SUBSTRING(fc.tax_number_1, 1, 16)) as FISCAL_NO,
        public.get_default_value('clean_data.customer_tax_info', 'exc_from_spesometro_dec_db', 'FALSE') as EXC_FROM_SPESOMETRO_DEC_DB,
        public.get_default_value('clean_data.customer_tax_info', 'icms_tax_payer_db', 'FALSE') as ICMS_TAX_PAYER_DB,
        public.get_default_value('clean_data.customer_tax_info', 'permanent_establishment_db', 'FALSE') as PERMANENT_ESTABLISHMENT_DB,
        public.get_default_value('clean_data.customer_tax_info', 'out_inv_vou_date_base_db', 'INVOICE_DATE') as OUT_INV_VOU_DATE_BASE_DB,
        public.get_default_value('clean_data.customer_tax_info', 'out_inv_curr_rate_base_db', 'INVOICE_DATE') as OUT_INV_CURR_RATE_BASE_DB,
        public.get_default_value('clean_data.customer_tax_info', 'tax_sell_curr_rate_base_db', 'INVOICE_DATE') as TAX_SELL_CURR_RATE_BASE_DB,
        public.get_default_value('clean_data.customer_tax_info', 'enable_for_tcs_db', 'FALSE') as ENABLE_FOR_TCS_DB,
        public.get_default_value('clean_data.customer_tax_info', 'business_transaction_id', NULL) as BUSINESS_TRANSACTION_ID,
        public.get_default_value('clean_data.customer_tax_info', 'component_a', NULL) as COMPONENT_A,
        public.get_default_value('clean_data.customer_tax_info', 'component_a_identity', NULL) as COMPONENT_A_IDENTITY
    FROM fc  -- TABLE MAÎTRE
    LEFT JOIN raw_data.KNA1 k
        ON fc.kunnr = k.KUNNR
        AND (k.LOEVM IS NULL OR k.LOEVM = '')
    LEFT JOIN raw_data.KNB1 kb
        ON fc.kunnr = kb.KUNNR
        AND fc.bukrs = kb.BUKRS
        AND (kb.LOEVM IS NULL OR kb.LOEVM = '')
    ORDER BY fc.customer_id, fc.address_id;

    GET DIAGNOSTICS v_processed_count = ROW_COUNT;

    RAISE NOTICE 'INSERT tax info terminé: % enregistrements traités', v_processed_count;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur lors de l''INSERT tax info: %', SQLERRM;
END;
$procedure$
