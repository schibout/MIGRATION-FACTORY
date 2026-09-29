-- ============================================================================
-- 083 - raw_data.pe_tools.ifs_date_execution (DATE)
-- ----------------------------------------------------------------------------
-- Prochaine execution a reprendre dans IFS = date de derniere execution (082)
-- + frequence de la gamme : '<n>S' = n semaines, '<n>M' = n mois, '<n>A' = n ans
-- (ex. 4S -> +4 semaines, 1M -> +1 mois, 2A -> +2 ans).
-- NULL si la date de derniere execution est vide, si la frequence est vide ou
-- mal formee, et pour les frequences en HEURES ('1500H', '3000H' : 12 gammes au
-- 29/09/2026) : ce sont des heures de fonctionnement (compteur), pas du temps
-- calendaire.
--
-- Colonne GENEREE (STORED) : PostgreSQL la recalcule seul a chaque ecriture de
-- frequence ou de date_derniere_execution (triggers de la 082 compris), aucun
-- code applicatif ne l'ecrit. Consequence : elle ne doit jamais figurer dans la
-- liste de colonnes d'un INSERT / UPDATE (erreur « cannot insert a non-DEFAULT
-- value into column »).
-- Prerequis : migration 082. Idempotente.
-- ============================================================================
BEGIN;

ALTER TABLE raw_data.pe_tools ADD COLUMN IF NOT EXISTS ifs_date_execution DATE
    GENERATED ALWAYS AS (
        (date_derniere_execution
         + CASE right(upper(btrim(frequence)), 1)
               WHEN 'S' THEN make_interval(weeks  => substring(upper(btrim(frequence)) FROM '^(\d{1,4})S$')::int)
               WHEN 'M' THEN make_interval(months => substring(upper(btrim(frequence)) FROM '^(\d{1,4})M$')::int)
               WHEN 'A' THEN make_interval(years  => substring(upper(btrim(frequence)) FROM '^(\d{1,4})A$')::int)
           END)::date
    ) STORED;

COMMENT ON COLUMN raw_data.pe_tools.ifs_date_execution IS
    'date_derniere_execution + frequence (S semaines, M mois, A annees ; H heures -> NULL). Generee, migration 083.';

COMMIT;
