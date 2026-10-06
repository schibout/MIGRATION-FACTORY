-- ============================================================================
-- raw_data.v_immo_comptes : immobilisations SAP x zones d'amortissement, avec
-- la determination comptable FI-AA (comptes d'immobilisation, d'amortissement,
-- de cession).
-- ============================================================================
-- Vue creee a la main sur la base, versionnee ici le 2026-10-06 a l'identique
-- (pg_get_viewdef). C'est la reference de structure du module Immobilisations :
-- clean_data.immobilisation en reprend les colonnes.
--
-- Grain : une ligne par (immobilisation ANLA, zone d'amortissement AFABE du
-- parametrage T095/T095B du plan comptable de la societe).
--   anla -> t001 (plan comptable) -> t095 (comptes valeur / cession par zone)
--        FULL JOIN t095b (comptes d'amortissement par zone)
--   anka : groupe de comptes de la classe, compare a celui de la fiche (ecart_ktogr)
--   t093 / t093t : indicateur de comptabilisation et libelle de la zone (STJN)
--
-- ATTENTION : le FULL JOIN sur t095b produit des lignes SANS immobilisation
-- (zones T095B absentes de T095, 112 lignes au 2026-10-06, toutes colonnes
-- ANLA a NULL). Le chargement les ecarte (anln1 IS NOT NULL).
-- ============================================================================

CREATE OR REPLACE VIEW raw_data.v_immo_comptes AS
 SELECT a.mandt,
    a.bukrs,
    a.anln1,
    a.anln2,
    a.txt50 AS designation,
    a.anlkl AS classe_immo,
    a.ktogr AS ktogr_immo,
    k.ktogr AS ktogr_classe,
    a.ktogr::text IS DISTINCT FROM k.ktogr::text AS ecart_ktogr,
    t.ktgrtx AS ktogr_libelle,
    c.ktopl AS plan_comptable,
    COALESCE(g.afabe, b.afabe) AS afabe,
    dt.afbtxt AS afabe_libelle,
    d.buhbkt AS indic_comptabilisation,
    ltrim(g.ktansw::text, '0'::text) AS cpt_valeur_acquisition,
    ltrim(g.ktansg::text, '0'::text) AS cpt_contrepartie_acq,
    ltrim(g.kterlw::text, '0'::text) AS cpt_produit_cession,
    ltrim(g.ktvbab::text, '0'::text) AS cpt_vnc_cession,
    ltrim(g.ktrest::text, '0'::text) AS cpt_vnc_mise_au_rebut,
    ltrim(b.ktnafb::text, '0'::text) AS cpt_amort_cumules,
    ltrim(b.ktnafg::text, '0'::text) AS cpt_dotation_amort,
    ltrim(b.ktsafb::text, '0'::text) AS cpt_amort_deroga_bilan,
    ltrim(b.ktsafg::text, '0'::text) AS cpt_amort_deroga_charge,
    ltrim(b.ktaafb::text, '0'::text) AS cpt_amort_except_bilan,
    ltrim(b.ktaafg::text, '0'::text) AS cpt_amort_except_charge
   FROM raw_data.anla a
     JOIN ( SELECT DISTINCT t001.mandt,
            t001.bukrs,
            t001.ktopl
           FROM raw_data.t001) c ON c.mandt::text = a.mandt::text AND c.bukrs::text = a.bukrs::text
     LEFT JOIN raw_data.anka k ON k.mandt::text = a.mandt::text AND k.anlkl::text = a.anlkl::text
     LEFT JOIN raw_data.t095t t ON t.mandt::text = a.mandt::text AND t.ktogr::text = a.ktogr::text AND t.spras::text = 'F'::text
     LEFT JOIN raw_data.t095 g ON g.mandt::text = a.mandt::text AND g.ktopl::text = c.ktopl::text AND g.ktogr::text = a.ktogr::text
     FULL JOIN raw_data.t095b b ON b.mandt::text = g.mandt::text AND b.ktopl::text = g.ktopl::text AND b.ktogr::text = g.ktogr::text AND b.afabe::text = g.afabe::text
     LEFT JOIN ( SELECT DISTINCT ON (t093.mandt, t093.afaber) t093.mandt,
            t093.afapl,
            t093.afaber,
            t093.buhbkt
           FROM raw_data.t093
          WHERE t093.afapl::text = 'STJN'::text
          ORDER BY t093.mandt, t093.afaber) d ON d.mandt::text = a.mandt::text AND d.afaber::text = COALESCE(g.afabe, b.afabe)::text
     LEFT JOIN raw_data.t093t dt ON dt.mandt::text = a.mandt::text AND dt.afapl::text = 'STJN'::text AND dt.afaber::text = COALESCE(g.afabe, b.afabe)::text AND dt.spras::text = 'F'::text;
