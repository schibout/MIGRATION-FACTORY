CREATE OR REPLACE FUNCTION clean_data.alimenter_comm_method()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_start_time TIMESTAMP;
    v_records_inserted INTEGER := 0;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    RAISE NOTICE 'Début alimentation comm_method - %', v_start_time;
    
    -- TRUNCATE de la table pour repartir à zéro
    TRUNCATE TABLE clean_data.comm_method;
    RAISE NOTICE 'Table comm_method vidée';
    
    -- Moyens de communication de TOUTES les adresses du fournisseur (01 = adresse
    -- propre, 02, 03... = partenaires) : onglet Méthodes de communication du
    -- perimetre (script 01c, lu dans SAP adr2 / adr3 / adr6 sur adrc.addrnumber,
    -- version la plus recente, sans les numeros des personnes de contact).
    -- TELEX / TELETEX ne sont pas repris : aucune valeur par defaut parametree.
    INSERT INTO clean_data.comm_method (
        party_type_db,
        identity,
        value,
        method_id_db,
        party_type,
        description,
        valid_from,
        valid_to,
        method_default,
        address_default,
        name,
        method_id,
        address_id,
        supplier_id,
        created_timestamp,
        updated_timestamp,
        created_by,
        updated_by,
        is_deleted
    )
    WITH src AS (
        SELECT f.numero_compte_ifs, f.nom_1, f.date_creation_sap, c.address_id, c.valeur, c.par_defaut,
               -- Variante des valeurs par defaut = methode IFS (portable -> telephone)
               CASE c.methode WHEN 'EMAIL' THEN 'E_MAIL' WHEN 'FAX' THEN 'FAX' ELSE 'PHONE' END AS v
          FROM clean_data.ifs_fournisseurs f
          JOIN clean_data.ifs_fournisseurs_perimetre_communication c
            ON c.numero_compte_fournisseur = f.numero_compte_fournisseur
         WHERE c.methode IN ('TELEPHONE', 'PORTABLE', 'FAX', 'EMAIL')
           AND (c.methode <> 'EMAIL' OR c.valeur ILIKE '%@%')
    )
    SELECT
        public.get_default_value('clean_data.comm_method', 'party_type_db', s.v) as party_type_db,
        s.numero_compte_ifs as identity,
        s.valeur as value,
        public.get_default_value('clean_data.comm_method', 'method_id_db', s.v) as method_id_db,
        public.get_default_value('clean_data.comm_method', 'party_type', s.v) as party_type,
        CASE s.v
            WHEN 'PHONE' THEN CASE WHEN s.par_defaut THEN 'Téléphone principal du fournisseur' ELSE 'Téléphone du fournisseur' END
            WHEN 'FAX' THEN CASE WHEN s.par_defaut THEN 'Numéro de télécopie principal du fournisseur' ELSE 'Numéro de télécopie du fournisseur' END
            ELSE CASE WHEN s.par_defaut THEN 'Adresse électronique principale du fournisseur' ELSE 'Adresse électronique du fournisseur' END
        END as description,
        CURRENT_DATE as valid_from,
        public.get_default_value('clean_data.comm_method', 'valid_to', s.v)::date as valid_to,
        CASE WHEN s.par_defaut THEN 'TRUE' ELSE 'FALSE' END as method_default,
        -- E-mail : l'adresse par defaut suit l'indicateur SAP (comme avant)
        CASE WHEN s.v = 'E_MAIL' THEN CASE WHEN s.par_defaut THEN 'TRUE' ELSE 'FALSE' END
             ELSE public.get_default_value('clean_data.comm_method', 'address_default', s.v) END as address_default,
        s.nom_1 as name,
        public.get_default_value('clean_data.comm_method', 'method_id', s.v) as method_id,
        s.address_id as address_id,
        s.numero_compte_ifs as supplier_id,
        COALESCE(s.date_creation_sap::TIMESTAMP, CURRENT_TIMESTAMP) as created_timestamp,
        CURRENT_TIMESTAMP as updated_timestamp,
        'etl_supplier_base' as created_by,
        'etl_supplier_base' as updated_by,
        FALSE as is_deleted
    FROM src s;

    GET DIAGNOSTICS v_records_inserted = ROW_COUNT;
    
    -- Statistiques finales
    RAISE NOTICE '=== ALIMENTATION COMM_METHOD TERMINÉE ===';
    RAISE NOTICE 'Durée: % secondes', EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time));
    RAISE NOTICE 'Enregistrements insérés: %', v_records_inserted;
    
    -- Statistiques détaillées par type de communication
    RAISE NOTICE '=== STATISTIQUES PAR TYPE DE COMMUNICATION ===';
    RAISE NOTICE 'PHONE (Phone): %', 
                 (SELECT COUNT(*) FROM clean_data.comm_method WHERE method_id_db = 'PHONE');
    RAISE NOTICE 'FAX (Fax): %', 
                 (SELECT COUNT(*) FROM clean_data.comm_method WHERE method_id_db = 'FAX');
    RAISE NOTICE 'E_MAIL (E-Mail): %', 
                 (SELECT COUNT(*) FROM clean_data.comm_method WHERE method_id_db = 'E_MAIL');
    
    -- Statistiques qualité
    RAISE NOTICE '=== STATISTIQUES QUALITÉ ===';
    RAISE NOTICE 'Fournisseurs avec au moins un téléphone: %', 
                 (SELECT COUNT(DISTINCT supplier_id) FROM clean_data.comm_method WHERE method_id_db = 'PHONE');
    RAISE NOTICE 'Fournisseurs avec fax: %', 
                 (SELECT COUNT(DISTINCT supplier_id) FROM clean_data.comm_method WHERE method_id_db = 'FAX');
    RAISE NOTICE 'Fournisseurs avec email: %', 
                 (SELECT COUNT(DISTINCT supplier_id) FROM clean_data.comm_method WHERE method_id_db = 'E_MAIL');
    RAISE NOTICE 'Total fournisseurs avec moyens de communication: %', 
                 (SELECT COUNT(DISTINCT supplier_id) FROM clean_data.comm_method);
    RETURN v_records_inserted;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur dans alimenter_comm_method: %', SQLERRM;
END;
$function$
;
