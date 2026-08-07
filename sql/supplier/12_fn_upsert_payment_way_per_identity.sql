CREATE OR REPLACE FUNCTION clean_data.fn_upsert_payment_way_per_identity()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    RAISE NOTICE '=== DÉBUT ALIMENTATION PAYMENT_WAY_PER_IDENTITY ===';
    RAISE NOTICE 'Heure de début: %', v_start_time;
    
    -- TRUNCATE de la table pour repartir à zéro
    TRUNCATE TABLE clean_data.PAYMENT_WAY_PER_IDENTITY;
    RAISE NOTICE 'Table PAYMENT_WAY_PER_IDENTITY vidée';
    
    -- Insertion basée sur la table ifs_fournisseurs
    INSERT INTO clean_data.PAYMENT_WAY_PER_IDENTITY (
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
    SELECT 
        COALESCE(f.company, 'TRIMET') as company,
        f.numero_compte_fournisseur as identity,
        'Supplier' as party_type,
        'SUPPLIER' as party_type_db,
        1 as way_id,
        'TRUE' as default_payment_way,
        CURRENT_TIMESTAMP as created_timestamp,
        CURRENT_TIMESTAMP as updated_timestamp,
        'System' as created_by,
        'System' as updated_by,
        FALSE as is_deleted
    FROM clean_data.ifs_fournisseurs f
    WHERE f.numero_compte_fournisseur IS NOT NULL;
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== ALIMENTATION PAYMENT_WAY_PER_IDENTITY TERMINÉE ===';
    RAISE NOTICE 'Durée: % secondes', EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time));
    RAISE NOTICE 'Total enregistrements insérés: %', v_processed_count;
    
    -- Statistiques détaillées
    RAISE NOTICE '';
    RAISE NOTICE '=== STATISTIQUES DÉTAILLÉES ===';
    RAISE NOTICE 'Total fournisseurs dans ifs_fournisseurs: %', 
        (SELECT COUNT(*) FROM clean_data.ifs_fournisseurs);
    RAISE NOTICE 'Enregistrements dans PAYMENT_WAY_PER_IDENTITY: %', 
        (SELECT COUNT(*) FROM clean_data.PAYMENT_WAY_PER_IDENTITY);
    RAISE NOTICE '';
    RAISE NOTICE '=== RÉPARTITION PAR TYPE DE PAIEMENT ===';
    RAISE NOTICE 'Moyens de paiement: %', 
        (SELECT STRING_AGG(way_id || '=' || count_records::text, ', ' ORDER BY way_id) 
         FROM (SELECT way_id, COUNT(*) as count_records 
               FROM clean_data.PAYMENT_WAY_PER_IDENTITY 
               GROUP BY way_id) way_stats);
    RAISE NOTICE '';
    RAISE NOTICE '=== RÉPARTITION PAR SOCIÉTÉ ===';
    RAISE NOTICE 'Par société: %', 
        (SELECT STRING_AGG(company || '=' || count_records::text, ', ') 
         FROM (SELECT company, COUNT(*) as count_records 
               FROM clean_data.PAYMENT_WAY_PER_IDENTITY 
               GROUP BY company) company_stats);
    
    RETURN v_processed_count;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur lors de l''alimentation payment way per identity: %', SQLERRM;
END;
$function$
;
