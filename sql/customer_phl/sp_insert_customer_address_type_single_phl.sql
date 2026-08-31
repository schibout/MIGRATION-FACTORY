CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_address_type_single_phl(IN p_address_type character varying, INOUT p_inserted_count integer DEFAULT 0)
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_address_type_code_db VARCHAR;
BEGIN
    -- Valider et normaliser le type d'adresse
    v_address_type_code_db := UPPER(TRIM(p_address_type));
    
    -- Valider le type
    IF v_address_type_code_db NOT IN ('DELIVERY', 'INVOICE', 'DOCUMENT') THEN
        RAISE EXCEPTION 'Type d''adresse invalide: %. Valeurs acceptées: DELIVERY, INVOICE, DOCUMENT', p_address_type;
    END IF;
    
    -- Insertion des données
    INSERT INTO clean_data.CUSTOMER_INFO_ADDRESS_TYPE (
        CUSTOMER_ID,
        ADDRESS_ID,
        ADDRESS_TYPE_CODE,
        ADDRESS_TYPE_CODE_DB,
        PARTY,
        DEF_ADDRESS,
        DEFAULT_DOMAIN
    )
    SELECT DISTINCT ON (cap.customer_id, cap.address_id)
        cap.customer_id as CUSTOMER_ID,
        cap.address_id as ADDRESS_ID,
        public.get_default_value('clean_data.customer_info_address_type', 'address_type_code', NULL) as ADDRESS_TYPE_CODE,
        v_address_type_code_db as ADDRESS_TYPE_CODE_DB,
        cap.customer_id as PARTY,
        public.get_default_value('clean_data.customer_info_address_type', 'def_address', 'TRUE') as DEF_ADDRESS,
        public.get_default_value('clean_data.customer_info_address_type', 'default_domain', 'FALSE') as DEFAULT_DOMAIN
    FROM raw_data.client_adresse_phl cap
    WHERE cap.customer_id IS NOT NULL
    AND cap.address_id IS NOT NULL
    ORDER BY cap.customer_id, cap.address_id;
    
    GET DIAGNOSTICS p_inserted_count = ROW_COUNT;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur lors de l''INSERT type d''adresse %: %', v_address_type_code_db, SQLERRM;
END;
$procedure$
