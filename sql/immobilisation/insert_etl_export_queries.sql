-- ============================================================================
-- Requete d'export Immobilisations dans etl_export_queries
-- Description : enregistre clean_data.immobilisation pour l'export dynamique
--               (categorie "Immobilisation"), page /export/immobilisations.
--               Table alimentee par le module ETL etl_immobilisation.py.
-- Idempotent : supprime puis reinsere les entrees de la categorie.
-- ============================================================================

DELETE FROM public.etl_export_queries WHERE category = 'Immobilisation';

INSERT INTO public.etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by)
VALUES (
    'immobilisation',
    'clean_data',
    'Immobilisations SAP et comptes FI-AA',
    'mandt, bukrs, anln1, anln2, designation, classe_immo, ktogr_immo, ktogr_classe, ecart_ktogr, ktogr_libelle, plan_comptable, afabe, afabe_libelle, indic_comptabilisation, cpt_valeur_acquisition, cpt_contrepartie_acq, cpt_produit_cession, cpt_vnc_cession, cpt_vnc_mise_au_rebut, cpt_amort_cumules, cpt_dotation_amort, cpt_amort_deroga_bilan, cpt_amort_deroga_charge, cpt_amort_except_bilan, cpt_amort_except_charge',
    'Immobilisations SAP (tout ANLA), une ligne par immobilisation et zone d''amortissement, avec la determination comptable FI-AA (comptes de valeur d''acquisition, d''amortissement, de cession). Snapshot recharge par le module ETL Immobilisations.',
    'Immobilisation',
    true,
    'ETL_SYSTEM',
    'ETL_SYSTEM'
);

SELECT id, table_name, display_name, category, is_active
FROM public.etl_export_queries
WHERE category = 'Immobilisation';
