-- Script de correction de la structure de la table identity_invoice_info
-- Ce script ajuste les tailles de colonnes pour éviter les erreurs "value too long"

-- Vérifier la structure actuelle de la table
DO $$
DECLARE
    table_exists boolean;
BEGIN
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'identity_invoice_info'
    ) INTO table_exists;
    
    IF table_exists THEN
        RAISE NOTICE 'Table identity_invoice_info existe, ajustement des colonnes...';
        
        -- Augmenter la taille des colonnes qui peuvent contenir des valeurs longues
        -- Ces champs peuvent contenir des descriptions complètes dans certains cas
        
        -- Champs qui stockent des libellés/descriptions (actuellement VARCHAR(5) mais nécessitent plus)
        ALTER TABLE public.identity_invoice_info 
        ALTER COLUMN party_type TYPE VARCHAR(20);
        
        ALTER TABLE public.identity_invoice_info 
        ALTER COLUMN identity_type TYPE VARCHAR(20);
        
        ALTER TABLE public.identity_invoice_info 
        ALTER COLUMN voting_share_percentage TYPE VARCHAR(20);
        
        ALTER TABLE public.identity_invoice_info 
        ALTER COLUMN report_and_withhold TYPE VARCHAR(30);
        
        ALTER TABLE public.identity_invoice_info 
        ALTER COLUMN withholding_base_amount TYPE VARCHAR(30);
        
        ALTER TABLE public.identity_invoice_info 
        ALTER COLUMN matching_level TYPE VARCHAR(20);
        
        ALTER TABLE public.identity_invoice_info 
        ALTER COLUMN tax_certificate_form TYPE VARCHAR(20);
        
        ALTER TABLE public.identity_invoice_info 
        ALTER COLUMN legal_identity TYPE VARCHAR(10);
        
        ALTER TABLE public.identity_invoice_info 
        ALTER COLUMN po_ref_rec_ref_val_method TYPE VARCHAR(40);
        
        ALTER TABLE public.identity_invoice_info 
        ALTER COLUMN invoice_recipient_from TYPE VARCHAR(20);
        
        ALTER TABLE public.identity_invoice_info 
        ALTER COLUMN exc_from_spesometro_dec TYPE VARCHAR(10);
        
        ALTER TABLE public.identity_invoice_info 
        ALTER COLUMN service_code_required TYPE VARCHAR(10);
        
        ALTER TABLE public.identity_invoice_info 
        ALTER COLUMN inc_inv_curr_rate_base TYPE VARCHAR(30);
        
        ALTER TABLE public.identity_invoice_info 
        ALTER COLUMN tax_buy_curr_rate_base TYPE VARCHAR(30);
        
        ALTER TABLE public.identity_invoice_info 
        ALTER COLUMN exclude_posting_auth TYPE VARCHAR(30);
        
        ALTER TABLE public.identity_invoice_info 
        ALTER COLUMN exclude_invoice_image TYPE VARCHAR(10);
        
        ALTER TABLE public.identity_invoice_info 
        ALTER COLUMN utility_bill_provider TYPE VARCHAR(10);
        
        ALTER TABLE public.identity_invoice_info 
        ALTER COLUMN digital_invoice TYPE VARCHAR(10);
        
        ALTER TABLE public.identity_invoice_info 
        ALTER COLUMN country_tax_registered TYPE VARCHAR(10);
        
        RAISE NOTICE 'Structure de la table identity_invoice_info mise à jour avec succès';
        
        -- Afficher la nouvelle structure
        RAISE NOTICE 'Nouvelles tailles de colonnes:';
        RAISE NOTICE 'party_type: VARCHAR(20)';
        RAISE NOTICE 'identity_type: VARCHAR(20)';
        RAISE NOTICE 'voting_share_percentage: VARCHAR(20)';
        RAISE NOTICE 'report_and_withhold: VARCHAR(30)';
        RAISE NOTICE 'withholding_base_amount: VARCHAR(30)';
        RAISE NOTICE 'matching_level: VARCHAR(20)';
        RAISE NOTICE 'tax_certificate_form: VARCHAR(20)';
        RAISE NOTICE 'po_ref_rec_ref_val_method: VARCHAR(40)';
        RAISE NOTICE 'invoice_recipient_from: VARCHAR(20)';
        RAISE NOTICE 'inc_inv_curr_rate_base: VARCHAR(30)';
        RAISE NOTICE 'tax_buy_curr_rate_base: VARCHAR(30)';
        RAISE NOTICE 'exclude_posting_auth: VARCHAR(30)';
        
    ELSE
        RAISE NOTICE 'Table identity_invoice_info n''existe pas encore';
    END IF;
END $$;

-- Vérifier s'il y a des valeurs trop longues dans les données existantes
DO $$
DECLARE
    problematic_records INTEGER;
BEGIN
    -- Compter les enregistrements avec des valeurs potentiellement problématiques
    SELECT COUNT(*) INTO problematic_records
    FROM public.identity_invoice_info 
    WHERE LENGTH(automatic_invoice) > 1
       OR LENGTH(invoice_fee) > 5
       OR LENGTH(ncf_reference_check) > 5
       OR LENGTH(tax_exempt) > 5
       OR LENGTH(second_tin) > 5
       OR LENGTH(print_tax_code_text) > 5
       OR LENGTH(allow_tolerance) > 5
       OR LENGTH(create_tolerance_posting) > 5
       OR LENGTH(allow_quantity_diff) > 5;
    
    IF problematic_records > 0 THEN
        RAISE NOTICE 'ATTENTION: % enregistrements avec des valeurs trop longues détectés', problematic_records;
        RAISE NOTICE 'Exécutez le script de correction des données: corriger_identity_invoice_info.sql';
    ELSE
        RAISE NOTICE 'Aucun enregistrement avec des valeurs trop longues détecté';
    END IF;
END $$;
