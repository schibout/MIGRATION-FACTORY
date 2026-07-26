-- Procédure pour insérer les codes fiscaux exonérés clients depuis les données SAP
-- Utilise clean_data.ifs_customer comme table maître

CREATE OR REPLACE PROCEDURE clean_data.sp_insert_customer_tax_free_tax_code_from_sap()
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion tax free code clients SAP - % - Basé sur ifs_customer', TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');
    
    -- Vider la table avant insertion
    TRUNCATE TABLE clean_data.CUSTOMER_TAX_FREE_TAX_CODE;
    RAISE NOTICE 'Table customer_tax_free_tax_code vidée';
    
    -- Pas d'insertion : DELIVERY_TYPE n'existe pas dans IFS (ORA-20111 DeliveryType.FND_RECORD_NOT_EXIST)
    -- et VAT_FREE_VAT_CODE est obligatoire mais absent des données SAP (ORA-20124 Error.NULLVALUE).
    -- Cette table nécessite une saisie manuelle ou une cartographie métier spécifique.
    v_processed_count := 0;
    RAISE NOTICE 'CUSTOMER_TAX_FREE_TAX_CODE : aucune donnée insérée (données source insuffisantes - saisie manuelle requise)';
    
    v_end_time := NOW();
    RAISE NOTICE 'INSERT tax free code terminé - %: % enregistrements traités', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), v_processed_count;
    RAISE NOTICE 'Durée d''exécution: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT tax free code - %: %', TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$;
