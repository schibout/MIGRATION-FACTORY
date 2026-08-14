-- Procédure pour insérer un type d'adresse spécifique depuis le fichier file_customer
-- Source: clean_data.v_customer_source (fichier + clients PHL absents du fichier)
-- Paramètre: p_address_type (DELIVERY, INVOICE, DOCUMENT)

CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_address_type_single_file(
    IN p_address_type VARCHAR,
    OUT p_inserted_count INTEGER
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_address_type_code VARCHAR;
    v_address_type_code_db VARCHAR;
BEGIN
    -- Déterminer les valeurs selon le type
    CASE p_address_type
        WHEN 'DELIVERY' THEN
            v_address_type_code := 'Delivery';
            v_address_type_code_db := 'DELIVERY';
        WHEN 'INVOICE' THEN
            v_address_type_code := 'Invoice';
            v_address_type_code_db := 'INVOICE';
        WHEN 'DOCUMENT' THEN
            v_address_type_code := 'Document';
            v_address_type_code_db := 'DOCUMENT';
        ELSE
            RAISE EXCEPTION 'Type d''adresse invalide: %. Doit être DELIVERY, INVOICE ou DOCUMENT', p_address_type;
    END CASE;

    -- Insertion avec une seule adresse par défaut par customer_id et type
    INSERT INTO clean_data.customer_info_address_type (
        customer_id,
        address_id,
        address_type_code,
        address_type_code_db,
        party,
        def_address,
        default_domain
    )
    WITH fc AS (
        -- Source unifiee : fichier + clients PHL absents du fichier.
        -- customer_id et address_id sont deja calcules par la vue.
        SELECT *
        FROM clean_data.v_customer_source
        WHERE customer_id IS NOT NULL
    )
    SELECT
        fc.customer_id,
        fc.address_id,
        v_address_type_code as address_type_code,
        v_address_type_code_db as address_type_code_db,
        fc.customer_id as party,
        CASE
            WHEN ROW_NUMBER() OVER (PARTITION BY fc.customer_id ORDER BY fc.address_id) = 1
            THEN 'TRUE'
            ELSE 'FALSE'
        END as def_address,
        'FALSE' as default_domain
    FROM fc
    WHERE fc.customer_id IS NOT NULL
    AND fc.address_id IS NOT NULL
    ORDER BY fc.customer_id, fc.address_id;

    GET DIAGNOSTICS p_inserted_count = ROW_COUNT;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur lors de l''INSERT type d''adresse % depuis file_customer - %: %',
            p_address_type, TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$;
