-- ============================================================================
-- clean_data.supplier_addr_tax_number
-- ----------------------------------------------------------------------------
-- Numeros d'identification fiscale d'un fournisseur, UNE LIGNE PAR TYPE :
--   TAX_ID_TYPE = 'TVA UE'  -> ifs_fournisseurs.tva          (numero de TVA intra)
--   TAX_ID_TYPE = 'SIREN'   -> ifs_fournisseurs.numero_siren
--   TAX_ID_TYPE = 'SIRET'   -> ifs_fournisseurs.siret
--
-- Un fournisseur produit donc 0 a 3 lignes : les valeurs vides ne sont pas
-- inserees (une ligne sans numero n'a aucun sens cote IFS).
--
-- Les 3 libelles de type passent par public.get_default_value avec une VARIANTE
-- par type, comme comm_method le fait pour PHONE / FAX / E_MAIL : ils restent
-- modifiables depuis Configuration > Valeurs par defaut sans toucher au code.
--
-- DEFAULT_TAX_ID_NUMBER n'est pas renseignee : sur un couple <col>/<col>_db,
-- seule la colonne _db est alimentee (regle appliquee a tout le depot).
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
    -- === Numero de TVA intracommunautaire ===================================
    -- IFS refuse un VAT_NO en minuscules au chargement -> UPPER.
    SELECT
        SUBSTRING(f.numero_compte_ifs, 1, 20),
        SUBSTRING(f.address_id, 1, 50),
        public.get_default_value('clean_data.supplier_addr_tax_number', 'company'),
        public.get_default_value('clean_data.supplier_addr_tax_number', 'tax_id_type', 'TVA_UE'),
        SUBSTRING(UPPER(TRIM(f.tva)), 1, 50),
        public.get_default_value('clean_data.supplier_addr_tax_number', 'default_tax_id_number_db', 'TVA_UE')
    FROM clean_data.ifs_fournisseurs f
    WHERE NULLIF(TRIM(f.tva), '') IS NOT NULL

    UNION ALL

    -- === SIREN ==============================================================
    SELECT
        SUBSTRING(f.numero_compte_ifs, 1, 20),
        SUBSTRING(f.address_id, 1, 50),
        public.get_default_value('clean_data.supplier_addr_tax_number', 'company'),
        public.get_default_value('clean_data.supplier_addr_tax_number', 'tax_id_type', 'SIREN'),
        SUBSTRING(TRIM(f.numero_siren), 1, 50),
        public.get_default_value('clean_data.supplier_addr_tax_number', 'default_tax_id_number_db', 'SIREN')
    FROM clean_data.ifs_fournisseurs f
    WHERE NULLIF(TRIM(f.numero_siren), '') IS NOT NULL

    UNION ALL

    -- === SIRET ==============================================================
    SELECT
        SUBSTRING(f.numero_compte_ifs, 1, 20),
        SUBSTRING(f.address_id, 1, 50),
        public.get_default_value('clean_data.supplier_addr_tax_number', 'company'),
        public.get_default_value('clean_data.supplier_addr_tax_number', 'tax_id_type', 'SIRET'),
        SUBSTRING(TRIM(f.siret), 1, 50),
        public.get_default_value('clean_data.supplier_addr_tax_number', 'default_tax_id_number_db', 'SIRET')
    FROM clean_data.ifs_fournisseurs f
    WHERE NULLIF(TRIM(f.siret), '') IS NOT NULL;

    GET DIAGNOSTICS v_processed_count = ROW_COUNT;

    v_end_time := NOW();
    RAISE NOTICE '=== INSERTION SUPPLIER_ADDR_TAX_NUMBER TERMINÉE ===';
    RAISE NOTICE 'Durée: % secondes', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    RAISE NOTICE 'Enregistrements insérés: %', v_processed_count;

    RAISE NOTICE '=== RÉPARTITION PAR TYPE ===';
    RAISE NOTICE 'TVA UE: %, SIREN: %, SIRET: %',
        (SELECT COUNT(*) FROM clean_data.supplier_addr_tax_number
          WHERE tax_id_type = public.get_default_value('clean_data.supplier_addr_tax_number', 'tax_id_type', 'TVA_UE')),
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
