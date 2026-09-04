CREATE OR REPLACE FUNCTION clean_data.fn_upsert_supplier_tax_info()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    rec RECORD;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    RAISE NOTICE '=== DÉBUT ALIMENTATION SUPPLIER_TAX_INFO ===';
    RAISE NOTICE 'Heure de début: %', v_start_time;
    
    -- TRUNCATE de la table pour repartir à zéro
    TRUNCATE TABLE clean_data.SUPPLIER_TAX_INFO;
    RAISE NOTICE 'Table SUPPLIER_TAX_INFO vidée';
    
    -- Insertion basée sur la table ifs_fournisseurs
    INSERT INTO clean_data.SUPPLIER_TAX_INFO (
        supplier_id,
        address_id,
        company,
        use_supp_address_for_tax,
        use_supp_address_for_tax_db,
        tax_calc_structure_id,
        icms_tax_payer,
        icms_tax_payer_db,
        business_transaction_id,
        created_timestamp,
        updated_timestamp,
        created_by,
        updated_by,
        is_deleted
    )
    SELECT 
        -- SUPPLIER_ID = numéro IFS du fichier de sélection (voir script 02).
        f.numero_compte_ifs as supplier_id,
        f.address_id as address_id,
        COALESCE(f.company, 'TRIMET') as company,
        -- Use Supplier Address for Tax: forcé à TRUE pour tous les fournisseurs
        public.get_default_value('clean_data.supplier_tax_info', 'use_supp_address_for_tax') as use_supp_address_for_tax,
        public.get_default_value('clean_data.supplier_tax_info', 'use_supp_address_for_tax_db') as use_supp_address_for_tax_db,
        -- Tax Calculation Structure ID basé sur le pays
        f.cle_pays as tax_calc_structure_id,
        CASE 
            WHEN f.cle_pays = 'BR' THEN 'Taxpayer'
            ELSE NULL
        END as icms_tax_payer,
        CASE 
            WHEN f.cle_pays = 'BR' THEN 'TAXPAYER'
            ELSE NULL
        END as icms_tax_payer_db,
        -- Business Transaction ID basé sur le type de fournisseur et pays
        f.cle_pays as business_transaction_id,
        CURRENT_TIMESTAMP as created_timestamp,
        CURRENT_TIMESTAMP as updated_timestamp,
        'etl_supplier_base' as created_by,
        'etl_supplier_base' as updated_by,
        FALSE as is_deleted
    FROM clean_data.ifs_fournisseurs f
    WHERE f.numero_compte_ifs IS NOT NULL;
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== ALIMENTATION SUPPLIER_TAX_INFO TERMINÉE ===';
    RAISE NOTICE 'Durée: % secondes', EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time));
    RAISE NOTICE 'Total enregistrements insérés: %', v_processed_count;
    
    -- Afficher quelques statistiques
    RAISE NOTICE '';
    RAISE NOTICE '=== STATISTIQUES SOURCE ===';
    RAISE NOTICE 'Total fournisseurs dans ifs_fournisseurs: %', 
        (SELECT COUNT(*) FROM clean_data.ifs_fournisseurs);
    RAISE NOTICE 'Total enregistrements dans SUPPLIER_TAX_INFO: %', 
        (SELECT COUNT(*) FROM clean_data.SUPPLIER_TAX_INFO);
    
    -- Statistiques par pays
    RAISE NOTICE '';
    RAISE NOTICE '=== RÉPARTITION PAR PAYS ===';
    FOR rec IN (
        SELECT 
            CASE 
                WHEN tax_calc_structure_id = 'FR' THEN 'France'
                WHEN tax_calc_structure_id = 'DE' THEN 'Allemagne'
                WHEN tax_calc_structure_id = 'IT' THEN 'Italie'
                WHEN tax_calc_structure_id = 'ES' THEN 'Espagne'
                WHEN tax_calc_structure_id = 'NL' THEN 'Pays-Bas'
                WHEN tax_calc_structure_id = 'BE' THEN 'Belgique'
                WHEN tax_calc_structure_id IN ('AT', 'PT', 'IE', 'FI', 'SE', 'DK') THEN 'Autres UE'
                WHEN tax_calc_structure_id = 'CH' THEN 'Suisse'
                WHEN tax_calc_structure_id = 'GB' THEN 'Royaume-Uni'
                WHEN tax_calc_structure_id = 'US' THEN 'États-Unis'
                WHEN tax_calc_structure_id = 'BR' THEN 'Brésil'
                ELSE 'Autres pays'
            END as region,
            COUNT(*) as nb_fournisseurs
        FROM clean_data.SUPPLIER_TAX_INFO 
        GROUP BY 1
        ORDER BY 2 DESC
    ) LOOP
        RAISE NOTICE '  %: % fournisseurs', rec.region, rec.nb_fournisseurs;
    END LOOP;
    
    -- Statistiques par type de transaction
    RAISE NOTICE '';
    RAISE NOTICE '=== RÉPARTITION PAR TYPE DE TRANSACTION ===';
    FOR rec IN (
        SELECT 
            business_transaction_id,
            COUNT(*) as nb_fournisseurs
        FROM clean_data.SUPPLIER_TAX_INFO 
        GROUP BY business_transaction_id
        ORDER BY 2 DESC
    ) LOOP
        RAISE NOTICE '  %: % fournisseurs', rec.business_transaction_id, rec.nb_fournisseurs;
    END LOOP;
    
    -- use_supp_address_for_tax forcé à True pour tous
    RAISE NOTICE '';
    RAISE NOTICE '=== USE_SUPP_ADDRESS_FOR_TAX ===';
    RAISE NOTICE 'Fournisseurs avec use_supp_address_for_tax_db = True: %',
        (SELECT COUNT(*) FROM clean_data.SUPPLIER_TAX_INFO WHERE use_supp_address_for_tax_db = 'True');
    
    -- Statistiques par société
    RAISE NOTICE '';
    RAISE NOTICE '=== STATISTIQUES PAR SOCIÉTÉ ===';
    FOR rec IN (
        SELECT company, COUNT(*) as nb_fournisseurs
        FROM clean_data.SUPPLIER_TAX_INFO 
        GROUP BY company
        ORDER BY company
    ) LOOP
        RAISE NOTICE 'Société %: % fournisseurs', rec.company, rec.nb_fournisseurs;
    END LOOP;
    
    RETURN v_processed_count;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur lors de l''alimentation supplier tax info depuis vue fournisseurs: %', SQLERRM;
END;
$function$
;
