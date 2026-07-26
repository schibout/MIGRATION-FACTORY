CREATE OR REPLACE FUNCTION clean_data.alimenter_supplier_address()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_start_time TIMESTAMP;
    v_records_inserted INTEGER := 0;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    RAISE NOTICE 'Début alimentation supplier_address - %', v_start_time;
    -- Vider la table supplier_address
    TRUNCATE TABLE clean_data.supplier_address;
    RAISE NOTICE 'Table supplier_address vidée';
    -- Insérer les données depuis supplier_info_address
    INSERT INTO clean_data.supplier_address (
        vendor_no,
        addr_no,
        delivery_terms,
        ship_via_code,
        route_id,
        contact,
        intrastat_exempt,
        intrastat_exempt_db,
        del_terms_location,
        supplier_calendar_id
    )
    SELECT 
        -- VENDOR_NO (VARCHAR 20, PK) - depuis supplier_id
        SUBSTRING(supplier_id, 1, 20) as vendor_no,
        -- ADDR_NO (VARCHAR 50, PK) - depuis address_id
        SUBSTRING(address_id, 1, 50) as addr_no,
        -- DELIVERY_TERMS (VARCHAR 5) - NULL par défaut
        -- TODO: À enrichir depuis table de transcodification ou LFM1
        NULL as delivery_terms,
        -- SHIP_VIA_CODE (VARCHAR 3) - NULL par défaut
        -- TODO: À enrichir depuis table de transcodification ou LFM1
        NULL as ship_via_code,
        -- ROUTE_ID (VARCHAR 12) - NULL par défaut
        -- TODO: À enrichir depuis table de transcodification ou LFM1
        NULL as route_id,
        -- CONTACT (VARCHAR 100) - depuis name
        SUBSTRING(name, 1, 100) as contact,
        -- INTRASTAT_EXEMPT (VARCHAR 4000) - Règle selon pays
        CASE 
            WHEN country_db IN ('FR', 'DE', 'IT', 'ES', 'NL', 'BE', 'AT', 'PT', 'IE', 'FI', 'SE', 'DK', 
                               'PL', 'CZ', 'HU', 'RO', 'BG', 'HR', 'SI', 'SK', 'LT', 'LV', 'EE', 
                               'CY', 'MT', 'LU', 'GR')
                THEN 'Include'  -- Pays UE
            ELSE 'Exempt'       -- Pays hors UE
        END as intrastat_exempt,
        -- INTRASTAT_EXEMPT_DB (VARCHAR 20) - Valeur DB correspondante
        CASE 
            WHEN country_db IN ('FR', 'DE', 'IT', 'ES', 'NL', 'BE', 'AT', 'PT', 'IE', 'FI', 'SE', 'DK', 
                               'PL', 'CZ', 'HU', 'RO', 'BG', 'HR', 'SI', 'SK', 'LT', 'LV', 'EE', 
                               'CY', 'MT', 'LU', 'GR')
                THEN 'INCLUDE'  -- Pays UE
            ELSE 'EXEMPT'       -- Pays hors UE
        END as intrastat_exempt_db,
        -- DEL_TERMS_LOCATION (VARCHAR 100) - depuis city ou address1
        SUBSTRING(COALESCE(city, address1), 1, 100) as del_terms_location,
        -- SUPPLIER_CALENDAR_ID (VARCHAR 10) - Généré par pays
        SUBSTRING('CAL_' || COALESCE(country_db, 'XX'), 1, 10) as supplier_calendar_id
    FROM clean_data.supplier_info_address
    WHERE COALESCE(is_deleted, FALSE) = FALSE;  -- Exclure les suppressions logiques
    GET DIAGNOSTICS v_records_inserted = ROW_COUNT;
    -- Statistiques finales
    RAISE NOTICE '=== ALIMENTATION SUPPLIER_ADDRESS TERMINÉE ===';
    RAISE NOTICE 'Durée: % secondes', EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time));
    RAISE NOTICE 'Enregistrements insérés: %', v_records_inserted;
    RAISE NOTICE '';
    RAISE NOTICE '=== STATISTIQUES DÉTAILLÉES ===';
    RAISE NOTICE 'Total fournisseurs distincts: %', 
                 (SELECT COUNT(DISTINCT vendor_no) FROM clean_data.supplier_address);
    RAISE NOTICE 'Total adresses: %', 
                 (SELECT COUNT(*) FROM clean_data.supplier_address);
    RAISE NOTICE '';
    RAISE NOTICE '=== RÉPARTITION INTRASTAT ===';
    RAISE NOTICE 'Fournisseurs UE (Include): %', 
                 (SELECT COUNT(*) FROM clean_data.supplier_address WHERE intrastat_exempt = 'Include');
    RAISE NOTICE 'Fournisseurs hors UE (Exempt): %', 
                 (SELECT COUNT(*) FROM clean_data.supplier_address WHERE intrastat_exempt = 'Exempt');
    RAISE NOTICE '';
    RAISE NOTICE '=== RÉPARTITION PAR PAYS (TOP 5) ===';
    RAISE NOTICE 'France (FR): %', 
                 (SELECT COUNT(*) FROM clean_data.supplier_address WHERE supplier_calendar_id = 'CAL_FR');
    RAISE NOTICE 'Allemagne (DE): %', 
                 (SELECT COUNT(*) FROM clean_data.supplier_address WHERE supplier_calendar_id = 'CAL_DE');
    RAISE NOTICE 'Italie (IT): %', 
                 (SELECT COUNT(*) FROM clean_data.supplier_address WHERE supplier_calendar_id = 'CAL_IT');
    RAISE NOTICE 'Espagne (ES): %', 
                 (SELECT COUNT(*) FROM clean_data.supplier_address WHERE supplier_calendar_id = 'CAL_ES');
    RAISE NOTICE 'Belgique (BE): %', 
                 (SELECT COUNT(*) FROM clean_data.supplier_address WHERE supplier_calendar_id = 'CAL_BE');
    RAISE NOTICE '';
    RAISE NOTICE '=== CHAMPS COMPLÉTÉS ===';
    RAISE NOTICE 'contact renseigné: %', 
                 (SELECT COUNT(*) FROM clean_data.supplier_address WHERE contact IS NOT NULL);
    RAISE NOTICE 'del_terms_location renseigné: %', 
                 (SELECT COUNT(*) FROM clean_data.supplier_address WHERE del_terms_location IS NOT NULL);
    RAISE NOTICE 'supplier_calendar_id renseigné: %', 
                 (SELECT COUNT(*) FROM clean_data.supplier_address WHERE supplier_calendar_id IS NOT NULL);
    RAISE NOTICE '';
    RAISE NOTICE '=== CHAMPS À ENRICHIR (TODO) ===';
    RAISE NOTICE 'delivery_terms NULL: % (À enrichir depuis transcodification/LFM1)', 
                 (SELECT COUNT(*) FROM clean_data.supplier_address WHERE delivery_terms IS NULL);
    RAISE NOTICE 'ship_via_code NULL: % (À enrichir depuis transcodification/LFM1)', 
                 (SELECT COUNT(*) FROM clean_data.supplier_address WHERE ship_via_code IS NULL);
    RAISE NOTICE 'route_id NULL: % (À enrichir depuis transcodification/LFM1)', 
                 (SELECT COUNT(*) FROM clean_data.supplier_address WHERE route_id IS NULL);
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur dans alimenter_supplier_address: %', SQLERRM;
END;
$function$;
