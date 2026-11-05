-- ============================================================================
-- Ajustements de insert_supplier_document_tax_info
-- Comparaison du 2026-11-05 avec les donnees validees en UAT par le metier.
-- Remplace la fonction du script d'origine : a jouer APRES lui (cf. compile.sh).
-- Ne fait que recompiler : le rechargement des tables reste a lancer.
-- Les colonnes libelle d'un couple <col>/<col>_db restent regies par la regle du depot.
--
--   une ligne par numero fiscal, comme supplier_addr_tax_number : TVA_<pays>, SIREN, SIRET
--   SIRET : 13 chiffres ou plus, sinon pas de ligne (meme regle que association_no)
--   vides : validated_date, declaration_date, last_modify_date
-- ============================================================================
-- Source commune de supplier_document_tax_info et supplier_addr_tax_number (script 16b).
CREATE OR REPLACE VIEW clean_data.v_supplier_numeros_fiscaux AS
    -- IFS refuse un numero de TVA en minuscules au chargement -> UPPER.
    SELECT SUBSTRING(f.numero_compte_ifs, 1, 20) AS supplier_id,
           SUBSTRING(f.address_id, 1, 50) AS address_id,
           public.get_default_value('clean_data.supplier_addr_tax_number', 'company') AS company,
           'TVA_' || COALESCE(SUBSTRING(UPPER(TRIM(f.tva)) FROM '^[A-Z]{2}'), UPPER(TRIM(f.cle_pays))) AS tax_id_type,
           SUBSTRING(UPPER(TRIM(f.tva)), 1, 50) AS tax_id_number,
           public.get_default_value('clean_data.supplier_addr_tax_number', 'default_tax_id_number_db', 'TVA_UE') AS default_tax_id_number_db
      FROM clean_data.ifs_fournisseurs f
     WHERE NULLIF(TRIM(f.tva), '') IS NOT NULL
    UNION ALL
    SELECT SUBSTRING(f.numero_compte_ifs, 1, 20), SUBSTRING(f.address_id, 1, 50),
           public.get_default_value('clean_data.supplier_addr_tax_number', 'company'),
           public.get_default_value('clean_data.supplier_addr_tax_number', 'tax_id_type', 'SIREN'),
           SUBSTRING(TRIM(f.numero_siren), 1, 50),
           public.get_default_value('clean_data.supplier_addr_tax_number', 'default_tax_id_number_db', 'SIREN')
      FROM clean_data.ifs_fournisseurs f
     WHERE NULLIF(TRIM(f.numero_siren), '') IS NOT NULL
    UNION ALL
    SELECT SUBSTRING(f.numero_compte_ifs, 1, 20), SUBSTRING(f.address_id, 1, 50),
           public.get_default_value('clean_data.supplier_addr_tax_number', 'company'),
           public.get_default_value('clean_data.supplier_addr_tax_number', 'tax_id_type', 'SIRET'),
           SUBSTRING(TRIM(f.siret), 1, 50),
           public.get_default_value('clean_data.supplier_addr_tax_number', 'default_tax_id_number_db', 'SIRET')
      FROM clean_data.ifs_fournisseurs f
     WHERE TRIM(f.siret) ~ '^[0-9]{13,}$';

CREATE OR REPLACE FUNCTION clean_data.insert_supplier_document_tax_info()
 RETURNS TABLE(execution_status text, total_inserted integer, execution_time interval)
 LANGUAGE plpgsql
AS $function$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    inserted_count INTEGER := 0;
BEGIN
    start_time := clock_timestamp();
    
    -- Vider complètement la table destination
    TRUNCATE TABLE clean_data.supplier_document_tax_info;
    
    -- =====================================
    -- INSERTION DES DONNÉES SUPPLIER_DOCUMENT_TAX_INFO
    -- =====================================
    INSERT INTO clean_data.supplier_document_tax_info (
        supplier_id,
        address_id,
        company,
        tax_id_type,
        vat_no,
        validated_date,
        reliability_status_db,
        declaration_date,
        last_modify_date,
        tax_office_id,
        company_addr_tax_id_type,
        company_addr_tax_id_type_db,
        created_timestamp,
        updated_timestamp,
        created_by,
        updated_by,
        is_deleted
    )
    SELECT 
        n.supplier_id,
        n.address_id,
        n.company,
        n.tax_id_type,
        n.tax_id_number as vat_no,
        NULL as validated_date,
        public.get_default_value('clean_data.supplier_document_tax_info', 'reliability_status_db') as reliability_status_db,
        NULL as declaration_date,
        NULL as last_modify_date,
        public.get_default_value('clean_data.supplier_document_tax_info', 'tax_office_id') as tax_office_id,
        public.get_default_value('clean_data.supplier_document_tax_info', 'company_addr_tax_id_type') as company_addr_tax_id_type,
        public.get_default_value('clean_data.supplier_document_tax_info', 'company_addr_tax_id_type_db') as company_addr_tax_id_type_db,
        NOW() as created_timestamp,
        NOW() as updated_timestamp,
        'etl_supplier_base' as created_by,
        'insert_supplier_tax_info_v1' as updated_by,
        FALSE as is_deleted
    FROM clean_data.v_supplier_numeros_fiscaux n;
    
    GET DIAGNOSTICS inserted_count = ROW_COUNT;
    
    end_time := clock_timestamp();
    
    RETURN QUERY SELECT 
        '✅ INSERTION RÉUSSIE - Table supplier_document_tax_info alimentée' as execution_status,
        inserted_count,
        end_time - start_time;
        
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT 
            '❌ ERREUR: ' || SQLERRM as execution_status,
            0 as total_inserted,
            INTERVAL '0' as execution_time;
END;
$function$
;
