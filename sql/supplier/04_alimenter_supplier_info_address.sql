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
        updated_timestamp, created_by, updated_by, is_deleted
    )
    SELECT 
        SUBSTRING(f.numero_compte_fournisseur, 1, 20) as supplier_id,
        public.get_default_value('clean_data.supplier_info_address', 'address_id', '01') as address_id,
        SUBSTRING(COALESCE(a.name1, f.nom_1), 1, 100) as name,
        SUBSTRING(
            TRIM(COALESCE(a.street, f.rue) || ' ' || 
                 COALESCE(a.house_num1, '') || ' ' || 
                 COALESCE(a.city1, f.localite) || ' ' || 
                 COALESCE(a.post_code1, f.code_postal)), 
            1, 35
        ) as address,
        SUBSTRING(COALESCE(a.location, ''), 1, 100) as ean_location,
        CASE 
            WHEN a.date_from IS NOT NULL AND a.date_from != '' 
                 THEN a.date_from::DATE
            ELSE CURRENT_DATE
        END as valid_from,
        CASE 
            WHEN a.date_to IS NOT NULL AND a.date_to != '' 
                 THEN a.date_to::DATE
            ELSE NULL
        END as valid_to,
        SUBSTRING(COALESCE(a.name_co, ''), 1, 20) as party,
        public.get_default_value('clean_data.supplier_info_address', 'default_domain', 'TRUE') as default_domain,
        SUBSTRING(COALESCE(a.country, f.cle_pays), 1, 4000) as country,
        SUBSTRING(COALESCE(a.country, f.cle_pays), 1, 2) as country_db,
        public.get_default_value('clean_data.supplier_info_address', 'party_type', 'Supplier') as party_type,
        public.get_default_value('clean_data.supplier_info_address', 'party_type_db', 'SUPPLIER') as party_type_db,
        SUBSTRING(COALESCE(a.street, f.rue), 1, 35) as address1,
        SUBSTRING(COALESCE(a.str_suppl1, ''), 1, 35) as address2,
        SUBSTRING(COALESCE(a.str_suppl2, ''), 1, 35) as address3,
        SUBSTRING(COALESCE(a.building, ''), 1, 35) as address4,
        SUBSTRING(COALESCE(a.floor, ''), 1, 35) as address5,
        SUBSTRING(COALESCE(a.roomnumber, ''), 1, 35) as address6,
        SUBSTRING(COALESCE(a.post_code1, f.code_postal), 1, 35) as zip_code,
        SUBSTRING(COALESCE(a.city1, f.localite), 1, 35) as city,
        SUBSTRING(COALESCE(a.city2, ''), 1, 35) as county,
        SUBSTRING(COALESCE(a.region, ''), 1, 35) as state,
        public.get_default_value('clean_data.supplier_info_address', 'comm_id', NULL)::NUMERIC(20) as comm_id,
        public.get_default_value('clean_data.supplier_info_address', 'output_media', '1')::numeric as output_media,
        public.get_default_value('clean_data.supplier_info_address', 'output_media_db', '1') as output_media_db,
        SUBSTRING(COALESCE(a.addr_group, ''), 1, 20) as supplier_branch,
        CURRENT_TIMESTAMP as created_timestamp,
        CURRENT_TIMESTAMP as updated_timestamp,
        'etl_supplier_base' as created_by,
        'etl_supplier_base' as updated_by,
        FALSE as is_deleted
    FROM clean_data.ifs_fournisseurs f
    LEFT JOIN raw_data.lfa1 l ON f.numero_compte_fournisseur = l.lifnr AND COALESCE(l.loevm, '') != 'X'
    LEFT JOIN raw_data.adrc a ON l.adrnr = a.addrnumber AND a.client = '100';
    
    GET DIAGNOSTICS v_records_inserted = ROW_COUNT;
    
    RAISE NOTICE '=== ALIMENTATION SUPPLIER_INFO_ADDRESS TERMINÉE ===';
    RAISE NOTICE 'Durée: % secondes', EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time));
    RAISE NOTICE 'Enregistrements insérés: %', v_records_inserted;
    
    -- Statistiques détaillées
    RAISE NOTICE '=== STATISTIQUES DÉTAILLÉES ===';
    RAISE NOTICE 'Total fournisseurs avec adresses: %', 
                 (SELECT COUNT(DISTINCT supplier_id) FROM clean_data.supplier_info_address);
    RAISE NOTICE 'Adresses avec ID fixe 01: %', 
                 (SELECT COUNT(*) FROM clean_data.supplier_info_address WHERE address_id = '01');
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur dans alimenter_supplier_info_address: %', SQLERRM;
END;
$function$
;
