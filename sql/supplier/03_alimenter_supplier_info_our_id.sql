CREATE OR REPLACE FUNCTION clean_data.alimenter_supplier_info_our_id()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_start_time TIMESTAMP;
    v_records_inserted INTEGER := 0;
    rec RECORD;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    RAISE NOTICE 'Début alimentation supplier_info_our_id - %', v_start_time;
    
    -- TRUNCATE de la table pour repartir à zéro
    TRUNCATE TABLE clean_data.supplier_info_our_id;
    RAISE NOTICE 'Table supplier_info_our_id vidée';
    
    -- Insérer les données depuis la table ifs_fournisseurs avec génération d'OUR_ID selon la société
    INSERT INTO clean_data.supplier_info_our_id (
        supplier_id,
        company,
        our_id,
        created_timestamp,
        updated_timestamp,
        created_by,
        updated_by,
        is_deleted
    )
    SELECT 
        f.numero_compte_fournisseur as supplier_id,
        f.company as company,
        -- Génération d'OUR_ID selon la société
        'TRIMET'||'-'||f.numero_compte_fournisseur as our_id,
        COALESCE(f.date_creation_sap::TIMESTAMP, CURRENT_TIMESTAMP) as created_timestamp,
        CURRENT_TIMESTAMP as updated_timestamp,
        'etl_supplier_base' as created_by,
        'etl_supplier_base' as updated_by,
        FALSE as is_deleted
    FROM clean_data.ifs_fournisseurs f
    WHERE f.numero_compte_fournisseur IS NOT NULL
      AND TRIM(f.numero_compte_fournisseur) != '';
    
    GET DIAGNOSTICS v_records_inserted = ROW_COUNT;
    
    -- Statistiques finales
    RAISE NOTICE '=== ALIMENTATION SUPPLIER_INFO_OUR_ID TERMINÉE ===';
    RAISE NOTICE 'Durée: % secondes', EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time));
    RAISE NOTICE 'Enregistrements traités: %', v_records_inserted;
    
    -- Statistiques par société  
    RAISE NOTICE '=== STATISTIQUES DÉTAILLÉES ===';
    FOR rec IN (
        SELECT 
            company,
            COUNT(*) as nb_suppliers,
            MIN(our_id) as first_our_id,
            MAX(our_id) as last_our_id
        FROM clean_data.supplier_info_our_id 
        GROUP BY company
        ORDER BY company
    ) LOOP
        RAISE NOTICE 'Société %: % fournisseurs (de % à %)', 
                    rec.company, rec.nb_suppliers, rec.first_our_id, rec.last_our_id;
    END LOOP;
    
    RAISE NOTICE 'Total fournisseurs: %', (SELECT COUNT(*) FROM clean_data.supplier_info_our_id);
    RAISE NOTICE 'Exemples OUR_ID: %', 
                 (SELECT STRING_AGG(our_id, ', ') FROM (SELECT our_id FROM clean_data.supplier_info_our_id ORDER BY supplier_id LIMIT 5) t);

    RETURN v_records_inserted;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur dans alimenter_supplier_info_our_id: %', SQLERRM;
END;
$function$;
