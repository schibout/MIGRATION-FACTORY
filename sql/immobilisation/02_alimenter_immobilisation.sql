-- ============================================================================
-- clean_data.alimenter_immobilisation : snapshot de raw_data.v_immo_comptes
-- dans clean_data.immobilisation.
-- ============================================================================
-- Perimetre : TOUT ANLA (demande explicite du 2026-10-06), aucune societe ni
-- immobilisation sortie exclue. Au 2026-10-06 : 12 613 immobilisations,
-- 37 356 lignes (immobilisation x zone), toutes les fiches ANLA presentes.
-- Les lignes sans immobilisation que produit le FULL JOIN t095b de la vue
-- (112) sont ecartees.
-- TRUNCATE + INSERT a chaque appel (idempotent). Retour : lignes chargees.
-- ============================================================================

CREATE OR REPLACE FUNCTION clean_data.alimenter_immobilisation()
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_nb integer;
BEGIN
    TRUNCATE clean_data.immobilisation;

    INSERT INTO clean_data.immobilisation
    SELECT *
    FROM raw_data.v_immo_comptes
    WHERE anln1 IS NOT NULL;

    GET DIAGNOSTICS v_nb = ROW_COUNT;

    IF v_nb = 0 THEN
        RAISE WARNING 'clean_data.immobilisation vide : raw_data.anla ou t001 non extraite ?';
    END IF;

    RETURN v_nb;
END;
$$;
