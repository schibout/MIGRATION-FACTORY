-- ============================================================================
-- Fonctions et vues utilitaires du module PM ACTIONS
-- Schéma: clean_data
-- ============================================================================

-- Cast défensif texte -> numeric pour les colonnes texte de raw_data.pe_tools
-- (charge, nb_intervenants, compteur_de_gamme, plan_entretien).
-- Retourne NULL si la valeur est vide ou non numérique (ex '2.0' -> 2.0, 'VL' -> NULL).
CREATE OR REPLACE FUNCTION clean_data.pe_num(p_text text)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE
        WHEN p_text IS NULL THEN NULL
        WHEN btrim(p_text) ~ '^-?[0-9]+(\.[0-9]+)?$' THEN btrim(p_text)::numeric
        ELSE NULL
    END;
$$;

-- ----------------------------------------------------------------------------
-- Vue source unique du module : attribue un pm_no à CHAQUE ligne de pe_tools.
--
-- Grain retenu (hybride) :
--   * un plan d'entretien = un pm_action, quand toutes ses lignes partagent le
--     même couple (poste technique, fréquence) -> pm_no = numéro de plan SAP.
--     Les lignes supplémentaires du plan sont des opérations (work steps).
--   * un plan qui couvre plusieurs couples (poste, fréquence) est éclaté en un
--     pm_action par couple -> pm_no = plan * 1000 + rang du couple.
--     IFS n'accepte qu'un seul mch_code et un seul intervalle par pm_action ;
--     sans éclatement on perdrait les postes techniques surnuméraires.
--   * plan_entretien vide ou non numérique -> pm_no = 900000 + raw_id.
--
-- Plages sans collision sur les données actuelles :
--   plans SAP 33544..35856 | plans éclatés 33544000..35856999 | orphelins 900001..901760
--
-- Toutes les procédures populate_pm_action*() DOIVENT lire le pm_no ici et ne
-- jamais le recalculer, sinon les tables filles pointent vers des pm_no absents
-- de clean_data.pm_action.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW clean_data.v_pm_source AS
WITH base AS (
    SELECT
        t.raw_id,
        t.poste_technique,
        t.groupe_de_gamme,
        t.compteur_de_gamme,
        t.frequence,
        t.designation,
        t.charge,
        t.nb_intervenants,
        clean_data.pe_num(t.plan_entretien)      AS plan_num,
        upper(btrim(COALESCE(t.frequence, '')))  AS freq_norm
    FROM raw_data.pe_tools t
),
ranked AS (
    SELECT
        b.*,
        -- rang du couple (poste, fréquence) à l'intérieur du plan
        dense_rank() OVER (
            PARTITION BY b.plan_num
            ORDER BY b.poste_technique NULLS FIRST, b.freq_norm NULLS FIRST
        ) AS combi_rang
    FROM base b
),
counted AS (
    SELECT
        r.*,
        max(r.combi_rang) OVER (PARTITION BY r.plan_num) AS nb_combi
    FROM ranked r
)
SELECT
    c.raw_id,
    c.poste_technique,
    c.groupe_de_gamme,
    c.compteur_de_gamme,
    c.frequence,
    c.freq_norm,
    c.designation,
    c.charge,
    c.nb_intervenants,
    c.plan_num,
    c.combi_rang,
    c.nb_combi,
    CASE
        WHEN c.plan_num IS NULL THEN 900000 + c.raw_id
        WHEN c.nb_combi = 1     THEN c.plan_num
        ELSE c.plan_num * 1000 + c.combi_rang
    END AS pm_no
FROM counted c;

COMMENT ON VIEW clean_data.v_pm_source IS
    'Source unique du module PM ACTIONS : une ligne par ligne de raw_data.pe_tools, enrichie du pm_no IFS (grain hybride plan / couple poste-fréquence).';
