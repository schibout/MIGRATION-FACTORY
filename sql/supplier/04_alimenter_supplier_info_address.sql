CREATE OR REPLACE FUNCTION clean_data.alimenter_supplier_info_address()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_start_time TIMESTAMP;
    v_records_inserted INTEGER := 0;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    RAISE NOTICE 'Début alimentation supplier_info_address - %', v_start_time;
    
    TRUNCATE TABLE clean_data.supplier_info_address;
    RAISE NOTICE 'Table supplier_info_address vidée';
    
    INSERT INTO clean_data.supplier_info_address (
        supplier_id, address_id, name, address, ean_location,
        valid_from, valid_to, party, default_domain, country,
        country_db, party_type, party_type_db, address1, address2,
        address3, address4, address5, address6, zip_code,
        city, county, state, comm_id, output_media,
        output_media_db, supplier_branch, created_timestamp, 
        updated_timestamp, created_by, updated_by, is_deleted,
        fonction_partenaire
    )
    -- Une ligne par adresse : l'adresse propre du fournisseur (lfa1.adrnr,
    -- fichier en repli) + les adresses de ses partenaires SAP (wyt3 -> lfa1
    -- du partenaire, sans repli fichier : le fichier ne decrit que le
    -- fournisseur lui-meme). Le script 05 derive les types IFS de
    -- fonction_partenaire (migration 115).
    WITH src AS (
        SELECT f.numero_compte_ifs, f.address_id, f.nom_1, f.rue, f.localite,
               f.code_postal, f.cle_pays, l.adrnr, l.mandt,
               NULL::varchar AS fonction_partenaire
        FROM clean_data.ifs_fournisseurs f
        LEFT JOIN raw_data.lfa1 l ON f.numero_compte_fournisseur = l.lifnr AND COALESCE(l.loevm, '') != 'X'
        UNION ALL
        -- ponytail: une fonction par (fournisseur, adresse) ; vrai le 2026-10-09
        -- (241 paires), sinon la priorite RS > BA > VA > SP l'emporte
        (SELECT DISTINCT ON (f.numero_compte_ifs, l2.adrnr)
               f.numero_compte_ifs, l2.adrnr, NULL, NULL, NULL, NULL, NULL,
               l2.adrnr, l2.mandt, w.parvw
        FROM clean_data.ifs_fournisseurs f
        JOIN raw_data.lfa1 l ON f.numero_compte_fournisseur = l.lifnr AND COALESCE(l.loevm, '') != 'X'
        JOIN raw_data.wyt3 w ON w.lifnr = l.lifnr AND w.parvw IN ('RS', 'BA', 'VA', 'SP')
        JOIN raw_data.lfa1 l2 ON l2.lifnr = w.lifn2 AND COALESCE(l2.loevm, '') != 'X'
        WHERE NULLIF(l2.adrnr, '') IS NOT NULL
          AND l2.adrnr IS DISTINCT FROM l.adrnr
        ORDER BY f.numero_compte_ifs, l2.adrnr,
                 array_position(ARRAY['RS', 'BA', 'VA', 'SP'], w.parvw::text))
    )
    SELECT 
        -- SUPPLIER_ID : numéro IFS du fichier de sélection (voir script 02).
        -- La jointure vers raw_data.lfa1 reste sur le LIFNR SAP.
        SUBSTRING(s.numero_compte_ifs, 1, 20) as supplier_id,
        -- Numéro d'adresse SAP, résolu une seule fois dans ifs_fournisseurs
        -- (lfa1.adrnr, repli sur la constante paramétrable). Les scripts 05, 07,
        -- 08, 13 et 14 dérivent de cette colonne : la garder alignée sur
        -- ifs_fournisseurs évite qu'ils pointent vers un identifiant absent.
        SUBSTRING(s.address_id, 1, 50) as address_id,
        SUBSTRING(COALESCE(a.name1, s.nom_1), 1, 100) as name,
        SUBSTRING(
            TRIM(COALESCE(a.street, s.rue) || ' ' || 
                 COALESCE(a.house_num1, '') || ' ' || 
                 COALESCE(a.city1, s.localite) || ' ' || 
                 COALESCE(a.post_code1, s.code_postal)), 
            1, 35
        ) as address,
        SUBSTRING(COALESCE(a.location, ''), 1, 100) as ean_location,
        CASE 
            WHEN a.date_from > '19000101'  -- 00010101 = date initiale SAP
                 THEN a.date_from::DATE
            ELSE CURRENT_DATE
        END as valid_from,
        CASE 
            WHEN a.date_to > '19000101' AND a.date_to < '99991231'
                 THEN a.date_to::DATE
            ELSE NULL
        END as valid_to,
        SUBSTRING(COALESCE(a.name_co, ''), 1, 20) as party,
        public.get_default_value('clean_data.supplier_info_address', 'default_domain') as default_domain,
        SUBSTRING(COALESCE(a.country, s.cle_pays), 1, 4000) as country,
        SUBSTRING(COALESCE(a.country, s.cle_pays), 1, 2) as country_db,
        public.get_default_value('clean_data.supplier_info_address', 'party_type') as party_type,
        public.get_default_value('clean_data.supplier_info_address', 'party_type_db') as party_type_db,
        SUBSTRING(COALESCE(a.street, s.rue), 1, 35) as address1,
        SUBSTRING(COALESCE(a.str_suppl1, ''), 1, 35) as address2,
        SUBSTRING(COALESCE(a.str_suppl2, ''), 1, 35) as address3,
        SUBSTRING(COALESCE(a.building, ''), 1, 35) as address4,
        SUBSTRING(COALESCE(a.floor, ''), 1, 35) as address5,
        SUBSTRING(COALESCE(a.roomnumber, ''), 1, 35) as address6,
        SUBSTRING(COALESCE(a.post_code1, s.code_postal), 1, 35) as zip_code,
        SUBSTRING(COALESCE(a.city1, s.localite), 1, 35) as city,
        SUBSTRING(COALESCE(a.city2, ''), 1, 35) as county,
        SUBSTRING(COALESCE(a.region, ''), 1, 35) as state,
        public.get_default_value('clean_data.supplier_info_address', 'comm_id') as comm_id,
        public.get_default_value('clean_data.supplier_info_address', 'output_media')::numeric as output_media,
        public.get_default_value('clean_data.supplier_info_address', 'output_media_db') as output_media_db,
        SUBSTRING(COALESCE(a.addr_group, ''), 1, 20) as supplier_branch,
        CURRENT_TIMESTAMP as created_timestamp,
        CURRENT_TIMESTAMP as updated_timestamp,
        'etl_supplier_base' as created_by,
        'etl_supplier_base' as updated_by,
        FALSE as is_deleted,
        s.fonction_partenaire
    FROM src s
    -- Mandant lu sur lfa1 (700) : l'ancienne constante '100' ne joignait
    -- aucune adresse, tout retombait sur le fichier.
    LEFT JOIN raw_data.adrc a ON s.adrnr = a.addrnumber AND a.client = s.mandt
    WHERE s.fonction_partenaire IS NULL OR a.addrnumber IS NOT NULL;
    
    GET DIAGNOSTICS v_records_inserted = ROW_COUNT;
    
    RAISE NOTICE '=== ALIMENTATION SUPPLIER_INFO_ADDRESS TERMINÉE ===';
    RAISE NOTICE 'Durée: % secondes', EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time));
    RAISE NOTICE 'Enregistrements insérés: %', v_records_inserted;
    
    -- Statistiques détaillées
    RAISE NOTICE '=== STATISTIQUES DÉTAILLÉES ===';
    RAISE NOTICE 'Total fournisseurs avec adresses: %', 
                 (SELECT COUNT(DISTINCT supplier_id) FROM clean_data.supplier_info_address);
    RAISE NOTICE 'Adresses avec un numéro SAP (adrnr): %',
                 (SELECT COUNT(*) FROM clean_data.supplier_info_address WHERE address_id ~ '^[0-9]{10}$');
    RAISE NOTICE 'Adresses partenaires (wyt3): %',
                 (SELECT COUNT(*) FROM clean_data.supplier_info_address WHERE fonction_partenaire IS NOT NULL);
    RAISE NOTICE 'Adresses retombées sur la valeur par défaut: %',
                 (SELECT COUNT(*) FROM clean_data.supplier_info_address WHERE address_id !~ '^[0-9]{10}$');
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur dans alimenter_supplier_info_address: %', SQLERRM;
END;
$function$
;
