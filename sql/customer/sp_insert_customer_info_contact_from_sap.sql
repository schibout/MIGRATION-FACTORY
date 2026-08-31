CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_info_contact_from_sap(IN p_client character varying DEFAULT '100'::character varying)
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
BEGIN
    
    RAISE NOTICE 'Début insertion customer info contact SAP - Client: %', p_client;
    
    -- Insertion avec UPSERT
    INSERT INTO clean_data.CUSTOMER_INFO_CONTACT (
        CUSTOMER_ID,
        PERSON_ID,
        ROLE,
        ROLE_DB,
        CUSTOMER_PRIMARY,
        CUSTOMER_SECONDARY,
        ADDRESS_PRIMARY,
        ADDRESS_SECONDARY,
        CREATED,
        CHANGED,
        NOTE_TEXT,
        CONTACT_NAME,
        CONTACT_TITLE,
        CONTACT_PHONE,
        CONTACT_EMAIL,
        CONTACT_FAX,
        IS_ACTIVE,
        CREATED_AT,
        UPDATED_AT
    )
    SELECT 
        TRIM(k.KUNNR) as CUSTOMER_ID,
        CONCAT('PERSON_', TRIM(k.KUNNR)) as PERSON_ID,
        public.get_default_value('clean_data.customer_info_contact', 'role', 'Primary Contact') as ROLE,
        public.get_default_value('clean_data.customer_info_contact', 'role_db', 'PRIMARY') as ROLE_DB,
        public.get_default_value('clean_data.customer_info_contact', 'customer_primary', 'TRUE') as CUSTOMER_PRIMARY,
        public.get_default_value('clean_data.customer_info_contact', 'customer_secondary', 'FALSE') as CUSTOMER_SECONDARY,
        public.get_default_value('clean_data.customer_info_contact', 'address_primary', 'TRUE') as ADDRESS_PRIMARY,
        public.get_default_value('clean_data.customer_info_contact', 'address_secondary', 'FALSE') as ADDRESS_SECONDARY,
        TO_DATE(k.ERDAT, 'YYYYMMDD') as CREATED,
        TO_DATE(k.ERDAT, 'YYYYMMDD') as CHANGED,
        CONCAT('Primary contact for customer ', TRIM(k.NAME1)) as NOTE_TEXT,
        TRIM(k.NAME1) as CONTACT_NAME,
        public.get_default_value('clean_data.customer_info_contact', 'contact_title', 'Customer Representative') as CONTACT_TITLE,
        k.TELF1 as CONTACT_PHONE,
        public.get_default_value('clean_data.customer_info_contact', 'contact_email', 'customer@company.com') as CONTACT_EMAIL,
        k.TELFX as CONTACT_FAX,
        TRUE as IS_ACTIVE,
        CURRENT_TIMESTAMP as CREATED_AT,
        CURRENT_TIMESTAMP as UPDATED_AT
    FROM raw_data.KNA1 k
    WHERE k.MANDT = p_client
    AND (k.LOEVM IS NULL OR k.LOEVM = '')
    
    ON CONFLICT (CUSTOMER_ID, PERSON_ID, ROLE_DB, CUSTOMER_PRIMARY, CUSTOMER_SECONDARY, ADDRESS_PRIMARY, ADDRESS_SECONDARY, CREATED, CHANGED, NOTE_TEXT) 
    DO UPDATE SET
        ROLE = EXCLUDED.ROLE,
        CONTACT_NAME = EXCLUDED.CONTACT_NAME,
        CONTACT_TITLE = EXCLUDED.CONTACT_TITLE,
        CONTACT_PHONE = EXCLUDED.CONTACT_PHONE,
        CONTACT_EMAIL = EXCLUDED.CONTACT_EMAIL,
        CONTACT_FAX = EXCLUDED.CONTACT_FAX,
        IS_ACTIVE = EXCLUDED.IS_ACTIVE,
        UPDATED_AT = CURRENT_TIMESTAMP;
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    
    RAISE NOTICE 'UPSERT customer info contact terminé: % enregistrements traités', v_processed_count;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur lors de l''UPSERT customer info contact: %', SQLERRM;
END;
$procedure$
