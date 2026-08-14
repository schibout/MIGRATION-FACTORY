-- Procédure pour insérer les moyens de paiement par identité depuis clean_data.v_customer_source (fichier + clients PHL absents du fichier)
-- Aligne sur la structure RÉELLE de clean_data.payment_way_per_identity (modèle PHL) :
-- colonnes created_timestamp/updated_timestamp/created_by/updated_by/is_deleted
-- (et NON valid_from/valid_to/is_active de la version SAP, absentes de la table).
-- TRUNCATE + INSERT, une ligne par client (customer_id).
--
-- Le paramètre p_client est conservé pour ne pas changer la signature déjà déployée ;
-- il n'est plus utilisé (la source est file_customer, pas un MANDT KNA1).

CREATE OR REPLACE PROCEDURE clean_data.sp_insert_payment_way_per_identity_from_file_customer(IN p_client character varying DEFAULT '100'::character varying)
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
BEGIN

    RAISE NOTICE 'Début insertion payment way per identity depuis file_customer - %', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS');

    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.payment_way_per_identity;
    RAISE NOTICE 'Table payment_way_per_identity vidée';

    WITH fc AS (
        -- Source unifiee : fichier + clients PHL absents du fichier.
        -- customer_id et address_id sont deja calcules par la vue.
        SELECT *
        FROM clean_data.v_customer_source
        WHERE customer_id IS NOT NULL
    )
    INSERT INTO clean_data.payment_way_per_identity (
        company,
        identity,
        party_type,
        party_type_db,
        way_id,
        default_payment_way,
        created_timestamp,
        updated_timestamp,
        created_by,
        updated_by,
        is_deleted
    )
    SELECT DISTINCT ON (fc.customer_id)
        'TRIMET'            AS company,
        fc.customer_id      AS identity,
        'Customer'          AS party_type,
        'CUSTOMER'          AS party_type_db,
        'BANK_TRANSFER'     AS way_id,
        'TRUE'              AS default_payment_way,
        CURRENT_TIMESTAMP   AS created_timestamp,
        CURRENT_TIMESTAMP   AS updated_timestamp,
        'SYSTEM'            AS created_by,
        'SYSTEM'            AS updated_by,
        FALSE               AS is_deleted
    FROM fc
    ORDER BY fc.customer_id;

    GET DIAGNOSTICS v_processed_count = ROW_COUNT;

    RAISE NOTICE 'INSERT payment way per identity terminé: % enregistrements traités', v_processed_count;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur lors de l''INSERT payment way per identity: %', SQLERRM;
END;
$procedure$
