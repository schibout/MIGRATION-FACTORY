-- ============================================================================
-- 085 - Saisie manuelle de la date de derniere execution (ecran PE Tools)
-- ----------------------------------------------------------------------------
-- L'utilisateur peut renseigner la date de derniere execution d'une gamme dans
-- la liste ou le detail PE Tools. pe_tools.date_derniere_execution etant
-- CALCULEE (082/084), la saisie n'y est pas ecrite : elle serait ecrasee au
-- prochain import du fichier des dates, et perdue au reimport PE Tools (qui
-- supprime puis reinsere les lignes d'un fichier). Elle est enregistree dans la
-- table source raw_data.plan_entretien_derniere_exec, comme une ligne
-- source = 'MANUEL' pour le PLAN de la gamme (a defaut son POSTE d'entretien).
--
-- Regle : pour un identifiant, la saisie MANUEL prime sur le fichier, meme plus
-- ancienne (correction d'une date fausse) ; sans saisie, date la plus recente
-- du fichier. Priorite plan puis poste inchangee (084). Une seule saisie par
-- identifiant (index unique partiel, cible de l'upsert de l'API). Supprimer la
-- saisie rend la date du fichier. Les triggers existants recalculent
-- date_derniere_execution puis ifs_date_execution (generee, 083).
-- Attention : un TRUNCATE de la table efface aussi les saisies manuelles.
-- Prerequis : 084. Idempotente.
-- ============================================================================
BEGIN;

ALTER TABLE raw_data.plan_entretien_derniere_exec
    ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'FICHIER',
    ADD COLUMN IF NOT EXISTS saisi_par TEXT;

ALTER TABLE raw_data.plan_entretien_derniere_exec
    DROP CONSTRAINT IF EXISTS plan_entretien_derniere_exec_source_check;
ALTER TABLE raw_data.plan_entretien_derniere_exec
    ADD CONSTRAINT plan_entretien_derniere_exec_source_check CHECK (source IN ('FICHIER', 'MANUEL'));

COMMENT ON COLUMN raw_data.plan_entretien_derniere_exec.source IS
    'FICHIER (import generique, defaut) | MANUEL (saisie ecran PE Tools, prioritaire). Migration 085.';
COMMENT ON COLUMN raw_data.plan_entretien_derniere_exec.saisi_par IS
    'Utilisateur de la saisie MANUEL. Migration 085.';

CREATE UNIQUE INDEX IF NOT EXISTS uq_plan_derniere_exec_manuel
    ON raw_data.plan_entretien_derniere_exec (id_type, (LTRIM(warpl, '0')))
    WHERE source = 'MANUEL';

-- Date d'un identifiant : saisie MANUEL d'abord, sinon la plus recente du fichier.
CREATE OR REPLACE FUNCTION raw_data.pe_tools_date_derniere_execution(p_plan TEXT, p_poste TEXT)
RETURNS DATE LANGUAGE sql STABLE AS $$
    SELECT COALESCE(
        (SELECT left(p.date_derniere_execution, 10)::date
           FROM raw_data.plan_entretien_derniere_exec p
          WHERE p.id_type = 'PLAN'
            AND LTRIM(p.warpl, '0') = LTRIM(NULLIF(btrim(p_plan), ''), '0')
            AND p.date_derniere_execution ~ '^\d{4}-\d{2}-\d{2}'
          ORDER BY (p.source = 'MANUEL') DESC, left(p.date_derniere_execution, 10) DESC
          LIMIT 1),
        (SELECT left(p.date_derniere_execution, 10)::date
           FROM raw_data.plan_entretien_derniere_exec p
          WHERE p.id_type = 'POSTE'
            AND LTRIM(p.warpl, '0') = LTRIM(NULLIF(btrim(p_poste), ''), '0')
            AND p.date_derniere_execution ~ '^\d{4}-\d{2}-\d{2}'
          ORDER BY (p.source = 'MANUEL') DESC, left(p.date_derniere_execution, 10) DESC
          LIMIT 1))
$$;

-- Aucune saisie manuelle n'existe encore : le recalcul ne change rien, il garantit la coherence.
UPDATE raw_data.pe_tools t
   SET date_derniere_execution = raw_data.pe_tools_date_derniere_execution(t.plan_entretien, t.poste_entretien)
 WHERE t.date_derniere_execution IS DISTINCT FROM
       raw_data.pe_tools_date_derniere_execution(t.plan_entretien, t.poste_entretien);

COMMIT;
