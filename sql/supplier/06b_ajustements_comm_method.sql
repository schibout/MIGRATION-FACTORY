-- ============================================================================
-- Ajustements de alimenter_comm_method
-- Comparaison du 2026-11-05 avec les donnees validees en UAT par le metier.
-- Remplace la fonction du script d'origine : a jouer APRES lui (cf. compile.sh).
-- Ne fait que recompiler : le rechargement des tables reste a lancer.
-- Les colonnes libelle d'un couple <col>/<col>_db restent regies par la regle du depot.
--
--   method_default : une seule valeur par defaut par fournisseur, adresse et methode (indicateur SAP, puis sequence) ;
--                    FAX lu dans etl_default_values
--   address_default : lu dans etl_default_values, y compris pour les e-mails
--   vides : description, valid_from, name, supplier_id
-- ============================================================================
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
        -- Meme valeur saisie plusieurs fois dans SAP sur la meme adresse (225 le
        -- 2026-11-03) : une seule ligne, celle marquee par defaut si elle existe
        SELECT DISTINCT ON (f.numero_compte_ifs, c.address_id, v.v, c.valeur)
               f.numero_compte_ifs, f.nom_1, f.date_creation_sap, c.address_id, c.valeur, c.par_defaut, c.num_sequence, v.v
          FROM clean_data.ifs_fournisseurs f
          JOIN clean_data.ifs_fournisseurs_perimetre_communication c
            ON c.numero_compte_fournisseur = f.numero_compte_fournisseur
          -- Variante des valeurs par defaut = methode IFS (portable -> telephone)
          CROSS JOIN LATERAL (SELECT CASE c.methode WHEN 'EMAIL' THEN 'E_MAIL' WHEN 'FAX' THEN 'FAX'
                                                    ELSE 'PHONE' END AS v) v
         WHERE c.methode IN ('TELEPHONE', 'PORTABLE', 'FAX', 'EMAIL')
           -- E-mail sans @, numero sans chiffre significatif ('0', '00 00 00 00 00') : ecartes
           AND CASE WHEN c.methode = 'EMAIL' THEN c.valeur ILIKE '%@%' ELSE c.valeur ~ '[1-9]' END
         ORDER BY f.numero_compte_ifs, c.address_id, v.v, c.valeur, c.par_defaut DESC
    )
    SELECT
        public.get_default_value('clean_data.comm_method', 'party_type_db', s.v) as party_type_db,
        s.numero_compte_ifs as identity,
        s.valeur as value,
        public.get_default_value('clean_data.comm_method', 'method_id_db', s.v) as method_id_db,
        public.get_default_value('clean_data.comm_method', 'party_type', s.v) as party_type,
        NULL as description,
        NULL as valid_from,
        public.get_default_value('clean_data.comm_method', 'valid_to', s.v)::date as valid_to,
        CASE WHEN s.v = 'FAX' THEN public.get_default_value('clean_data.comm_method', 'method_default', 'FAX')
             WHEN ROW_NUMBER() OVER (PARTITION BY s.numero_compte_ifs, s.address_id, s.v
                                     ORDER BY s.par_defaut DESC NULLS LAST, s.num_sequence, s.valeur) = 1 THEN 'TRUE'
             ELSE 'FALSE' END as method_default,
        public.get_default_value('clean_data.comm_method', 'address_default', s.v) as address_default,
        NULL as name,
        public.get_default_value('clean_data.comm_method', 'method_id', s.v) as method_id,
        s.address_id as address_id,
        NULL as supplier_id,
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
