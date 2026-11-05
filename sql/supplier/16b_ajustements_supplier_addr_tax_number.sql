-- ============================================================================
-- Ajustements de sp_insert_supplier_addr_tax_number
-- Comparaison du 2026-11-05 avec les donnees validees en UAT par le metier.
-- Remplace la fonction du script d'origine : a jouer APRES lui (cf. compile.sh).
-- Ne fait que recompiler : le rechargement des tables reste a lancer.
-- Les colonnes libelle d'un couple <col>/<col>_db restent regies par la regle du depot.
--
--   lit clean_data.v_supplier_numeros_fiscaux (script 08b), source commune avec supplier_document_tax_info
--   SIRET : 13 chiffres ou plus, sinon pas de ligne (meme regle que association_no)
-- ============================================================================
CREATE OR REPLACE PROCEDURE clean_data.sp_insert_supplier_addr_tax_number()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE 'Début insertion supplier_addr_tax_number - %',
                 TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS');

    TRUNCATE TABLE clean_data.supplier_addr_tax_number;
    RAISE NOTICE 'Table supplier_addr_tax_number vidée';

    INSERT INTO clean_data.supplier_addr_tax_number (
        supplier_id,
        address_id,
        company,
        tax_id_type,
        tax_id_number,
        default_tax_id_number_db
    )
    SELECT supplier_id, address_id, company, tax_id_type, tax_id_number, default_tax_id_number_db
      FROM clean_data.v_supplier_numeros_fiscaux;

    GET DIAGNOSTICS v_processed_count = ROW_COUNT;

    v_end_time := NOW();
    RAISE NOTICE '=== INSERTION SUPPLIER_ADDR_TAX_NUMBER TERMINÉE ===';
    RAISE NOTICE 'Durée: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    RAISE NOTICE 'Enregistrements insérés: %', v_processed_count;

    RAISE NOTICE '=== RÉPARTITION PAR TYPE ===';
    RAISE NOTICE 'TVA (tous pays): %, SIREN: %, SIRET: %',
        (SELECT COUNT(*) FROM clean_data.supplier_addr_tax_number WHERE tax_id_type LIKE 'TVA\_%'),
        (SELECT COUNT(*) FROM clean_data.supplier_addr_tax_number
          WHERE tax_id_type = public.get_default_value('clean_data.supplier_addr_tax_number', 'tax_id_type', 'SIREN')),
        (SELECT COUNT(*) FROM clean_data.supplier_addr_tax_number
          WHERE tax_id_type = public.get_default_value('clean_data.supplier_addr_tax_number', 'tax_id_type', 'SIRET'));
    RAISE NOTICE 'Fournisseurs couverts: % sur %',
        (SELECT COUNT(DISTINCT supplier_id) FROM clean_data.supplier_addr_tax_number),
        (SELECT COUNT(*) FROM clean_data.ifs_fournisseurs);

EXCEPTION
    WHEN OTHERS THEN
        v_end_time := NOW();
        RAISE EXCEPTION 'Erreur lors de l''INSERT supplier_addr_tax_number - %: %',
                        TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'), SQLERRM;
END;
$procedure$
;
