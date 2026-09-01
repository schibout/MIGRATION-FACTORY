CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_address_type_single_file(IN p_address_type character varying, OUT p_inserted_count integer)
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_address_type_code_db VARCHAR;
BEGIN
    -- Déterminer les valeurs selon le type
    CASE p_address_type
        WHEN 'DELIVERY' THEN
            v_address_type_code_db := 'DELIVERY';
        WHEN 'INVOICE' THEN
            v_address_type_code_db := 'INVOICE';
        WHEN 'DOCUMENT' THEN
            v_address_type_code_db := 'DOCUMENT';
        ELSE
            RAISE EXCEPTION 'Type d''adresse invalide: %. Doit être DELIVERY, INVOICE ou DOCUMENT', p_address_type;
    END CASE;

    -- Insertion avec une seule adresse par défaut par customer_id et type
    INSERT INTO clean_data.customer_info_address_type (
        customer_id,
        address_id,
        address_type_code_db,
        party,
        def_address,
        default_domain
    )
    WITH fc AS (
        -- 1 ligne = 1 ADRESSE, meme source que customer_info_address :
        -- toutes les adresses PHL du client rapproche, sinon l'adresse du
        -- fichier. Chaque adresse chargee recoit donc son type.
        SELECT *
        FROM clean_data.v_customer_address_source
        WHERE customer_id IS NOT NULL
    )
    SELECT
        fc.customer_id,
        fc.addr_id,
        v_address_type_code_db as address_type_code_db,
        fc.customer_id as party,
        -- Une seule adresse par defaut par client et par type : l'adresse
        -- PRINCIPALE (v_customer_source.address_id = adresse PHL par defaut,
        -- sinon celle du fichier), a defaut la premiere par addr_id.
        CASE
            WHEN ROW_NUMBER() OVER (
                     PARTITION BY fc.customer_id
                     ORDER BY CASE WHEN fc.addr_id = fc.address_id THEN 0 ELSE 1 END,
                              fc.addr_id
                 ) = 1
            THEN 'TRUE'
            ELSE 'FALSE'
        END as def_address,
        public.get_default_value('clean_data.customer_info_address_type', 'default_domain', 'FALSE') as default_domain
    FROM fc
    WHERE fc.customer_id IS NOT NULL
    AND fc.addr_id IS NOT NULL
    ORDER BY fc.customer_id, fc.addr_id;

    GET DIAGNOSTICS p_inserted_count = ROW_COUNT;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur lors de l''INSERT type d''adresse % depuis file_customer - %: %',
            p_address_type, TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
