CREATE OR REPLACE FUNCTION clean_data.alimenter_supplier_info_general()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_start_time TIMESTAMP;
    v_records_inserted INTEGER := 0;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    RAISE NOTICE 'Début alimentation supplier_info_general - %', v_start_time;
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.supplier_info_general;
    RAISE NOTICE 'Table supplier_info_general vidée';
    
    -- Insérer les fournisseurs depuis la table ifs_fournisseurs
    INSERT INTO clean_data.supplier_info_general (
        supplier_id,
        supplier_legacy_sap_id,
        name,
        country,
        creation_date,
        created_by,
        updated_by,
        created_timestamp,
        updated_timestamp,
        is_deleted,
        country_db,
        association_no,
        party,
        default_domain,
        default_language,
        default_language_db,
        party_type,
        party_type_db,
        suppliers_own_id,
        corporate_form,
        identifier_reference,
        identifier_ref_validation,
        identifier_ref_validation_db,
        picture_id,
        one_time,
        one_time_db,
        supplier_category,
        supplier_category_db,
        b2b_supplier,
        b2b_supplier_db,
        business_classification
    )
    SELECT 
        SUBSTRING(f.numero_compte_fournisseur, 1, 20) as supplier_id,
        SUBSTRING(f.numero_compte_fournisseur, 1, 20) as supplier_legacy_sap_id,  -- Copier le numéro SAP d'origine
        SUBSTRING(f.nom_1, 1, 100) as name,
        SUBSTRING(f.cle_pays, 1, 2) as country,
        f.date_creation_sap as creation_date,
        'etl_supplier_base' as created_by,
        'etl_supplier_base' as updated_by,
        COALESCE(f.date_creation_sap::TIMESTAMP, CURRENT_TIMESTAMP) as created_timestamp,
        CURRENT_TIMESTAMP as updated_timestamp,
        FALSE as is_deleted,
        SUBSTRING(f.cle_pays, 1, 2) as country_db,
        SUBSTRING(f.siret, 1, 20) as association_no,
        public.get_default_value('clean_data.supplier_info_general', 'party') as party,
        public.get_default_value('clean_data.supplier_info_general', 'default_domain') as default_domain,
        public.get_default_value('clean_data.supplier_info_general', 'default_language') as default_language,
        public.get_default_value('clean_data.supplier_info_general', 'default_language_db') as default_language_db,
        public.get_default_value('clean_data.supplier_info_general', 'party_type') as party_type,
        public.get_default_value('clean_data.supplier_info_general', 'party_type_db') as party_type_db,
        SUBSTRING(f.siret, 1, 20) as suppliers_own_id,
        public.get_default_value('clean_data.supplier_info_general', 'corporate_form') as corporate_form,
        SUBSTRING(
            CASE 
                WHEN f.siret IS NOT NULL AND f.siret != '' THEN f.siret
                WHEN f.tva IS NOT NULL AND f.tva != '' THEN f.tva
                ELSE f.numero_compte_fournisseur
            END, 1, 20
        ) as identifier_reference,
        CASE 
            WHEN f.siret IS NOT NULL AND f.siret != '' THEN 'VERIFIED'
            WHEN f.tva IS NOT NULL AND f.tva != '' THEN 'PARTIAL'
            ELSE 'NOT_VERIFIED'
        END as identifier_ref_validation,
        public.get_default_value('clean_data.supplier_info_general', 'identifier_ref_validation_db') as identifier_ref_validation_db,
        public.get_default_value('clean_data.supplier_info_general', 'picture_id')::NUMERIC(20,0) as picture_id,
        public.get_default_value('clean_data.supplier_info_general', 'one_time') as one_time,
        public.get_default_value('clean_data.supplier_info_general', 'one_time_db') as one_time_db,
        public.get_default_value('clean_data.supplier_info_general', 'supplier_category') as supplier_category,
        public.get_default_value('clean_data.supplier_info_general', 'supplier_category_db') as supplier_category_db,
        public.get_default_value('clean_data.supplier_info_general', 'b2b_supplier') as b2b_supplier,
        public.get_default_value('clean_data.supplier_info_general', 'b2b_supplier_db') as b2b_supplier_db,
        public.get_default_value('clean_data.supplier_info_general', 'business_classification') as business_classification
        
    FROM clean_data.ifs_fournisseurs f;
    
    GET DIAGNOSTICS v_records_inserted = ROW_COUNT;
    
    RAISE NOTICE '=== ALIMENTATION SUPPLIER_INFO_GENERAL TERMINÉE ===';
    RAISE NOTICE 'Durée: % secondes', EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time));
    RAISE NOTICE 'Enregistrements insérés: %', v_records_inserted;
    
    RAISE NOTICE '=== STATISTIQUES QUALITÉ ===';
    RAISE NOTICE 'Total fournisseurs: %', (SELECT COUNT(*) FROM clean_data.supplier_info_general);
    RAISE NOTICE 'Fournisseurs avec SIRET: %', (SELECT COUNT(*) FROM clean_data.supplier_info_general WHERE suppliers_own_id IS NOT NULL AND suppliers_own_id != '');
    RAISE NOTICE 'Fournisseurs B2B: %', (SELECT COUNT(*) FROM clean_data.supplier_info_general WHERE b2b_supplier = 'TRUE');
    RAISE NOTICE 'Répartition par pays: FR=%, Autres=%', 
                 (SELECT COUNT(*) FROM clean_data.supplier_info_general WHERE country = 'FR'),
                 (SELECT COUNT(*) FROM clean_data.supplier_info_general WHERE country != 'FR');
    RETURN v_records_inserted;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur dans alimenter_supplier_info_general: %', SQLERRM;
END;
$function$
;
