CREATE OR REPLACE FUNCTION clean_data.fn_upsert_supplier_delivery_tax_code()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    rec RECORD;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    RAISE NOTICE '=== DÉBUT ALIMENTATION SUPPLIER_DELIVERY_TAX_CODE ===';
    RAISE NOTICE 'Heure de début: %', v_start_time;
    
    -- TRUNCATE de la table pour repartir à zéro
    TRUNCATE TABLE clean_data.SUPPLIER_DELIVERY_TAX_CODE;
    RAISE NOTICE 'Table SUPPLIER_DELIVERY_TAX_CODE vidée';
    
    INSERT INTO clean_data.SUPPLIER_DELIVERY_TAX_CODE (
        supplier_id,
        address_id,
        company,
        tax_code,
        created_timestamp,
        updated_timestamp,
        created_by,
        updated_by,
        is_deleted
    )
    SELECT DISTINCT
        f.numero_compte_fournisseur as supplier_id,
        COALESCE(sia.address_id, 'DEFAULT_ADDR') as address_id,
        COALESCE(f.company, 'TRIMET') as company,
        SUBSTRING(CASE 
            WHEN f.tva IS NOT NULL AND f.tva != ''
            THEN TRIM(f.tva)
            WHEN f.siret IS NOT NULL AND f.siret != ''
            THEN TRIM(f.siret)
            WHEN f.cle_pays IS NOT NULL
            THEN CONCAT(TRIM(f.cle_pays), '_DEFAULT')
            ELSE 'NO_TAX_CODE'
        END, 1, 20) as tax_code,
        CURRENT_TIMESTAMP as created_timestamp,
        CURRENT_TIMESTAMP as updated_timestamp,
        'etl_supplier_base' as created_by,
        'etl_supplier_base' as updated_by,
        FALSE as is_deleted
    FROM clean_data.ifs_fournisseurs f
    LEFT JOIN clean_data.supplier_info_address sia 
        ON f.numero_compte_fournisseur = sia.supplier_id
        AND sia.is_deleted = FALSE
    WHERE f.numero_compte_fournisseur IS NOT NULL
    AND (
        (f.tva IS NOT NULL AND f.tva != '')
        OR (f.siret IS NOT NULL AND f.siret != '')
        OR f.cle_pays IS NOT NULL
    );
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== ALIMENTATION SUPPLIER_DELIVERY_TAX_CODE TERMINÉE ===';
    RAISE NOTICE 'Durée: % secondes', EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time));
    RAISE NOTICE 'Total enregistrements insérés: %', v_processed_count;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== STATISTIQUES SOURCE ===';
    RAISE NOTICE 'Total fournisseurs dans ifs_fournisseurs: %', 
        (SELECT COUNT(*) FROM clean_data.ifs_fournisseurs);
    
    RAISE NOTICE 'Fournisseurs avec numéro TVA: %', 
        (SELECT COUNT(*) FROM clean_data.ifs_fournisseurs 
         WHERE tva IS NOT NULL AND tva != '');
    
    RAISE NOTICE 'Fournisseurs avec SIRET: %', 
        (SELECT COUNT(*) FROM clean_data.ifs_fournisseurs 
         WHERE siret IS NOT NULL AND siret != '');
    
    RAISE NOTICE '';
    RAISE NOTICE '=== STATISTIQUES TABLE DESTINATION ===';
    RAISE NOTICE 'Total enregistrements dans SUPPLIER_DELIVERY_TAX_CODE: %', 
        (SELECT COUNT(*) FROM clean_data.SUPPLIER_DELIVERY_TAX_CODE);
    
    RAISE NOTICE '';
    RAISE NOTICE '=== RÉPARTITION DES CODES FISCAUX ===';
    FOR rec IN (
        SELECT 
            CASE 
                WHEN tax_code LIKE '%_DEFAULT' THEN 'Code pays par défaut'
                WHEN tax_code = 'NO_TAX_CODE' THEN 'Aucun code fiscal'
                WHEN LENGTH(tax_code) = 14 AND tax_code LIKE 'FR%' THEN 'SIRET français'
                WHEN tax_code LIKE 'FR%' THEN 'TVA française'
                WHEN tax_code LIKE 'NL%' THEN 'TVA néerlandaise'
                WHEN tax_code LIKE 'DE%' THEN 'TVA allemande'
                WHEN tax_code LIKE 'BE%' THEN 'TVA belge'
                ELSE 'Autre code fiscal'
            END as type_code,
            COUNT(*) as nb_enregistrements
        FROM clean_data.SUPPLIER_DELIVERY_TAX_CODE 
        GROUP BY 1
        ORDER BY 2 DESC
    ) LOOP
        RAISE NOTICE '  %: % enregistrements', rec.type_code, rec.nb_enregistrements;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== RÉPARTITION PAR SOCIÉTÉ ===';
    FOR rec IN (
        SELECT company, COUNT(*) as nb_enregistrements
        FROM clean_data.SUPPLIER_DELIVERY_TAX_CODE 
        GROUP BY company
        ORDER BY company
    ) LOOP
        RAISE NOTICE '  Société %: % enregistrements', rec.company, rec.nb_enregistrements;
    END LOOP;
    
    RETURN v_processed_count;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur lors de l''alimentation supplier delivery tax code: %', SQLERRM;
END;
$function$;
