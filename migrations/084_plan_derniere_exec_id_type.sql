-- ============================================================================
-- 084 - raw_data.plan_entretien_derniere_exec.id_type (PLAN | POSTE)
-- ----------------------------------------------------------------------------
-- Le classeur « Date 7.M.xlsx » a deux onglets dont la 1re colonne s'intitule
-- « Plan d'entretien » dans les deux cas, mais :
--   * onglet 7.M          -> numero de PLAN d'entretien   (SAP WARPL) ;
--   * onglet NRJ et MSGX  -> numero de POSTE d'entretien  (SAP AFIH.WAPOS).
-- Les deux etaient charges dans cette table comme des plans : les 80 postes ne
-- se rapprochaient jamais, d'ou 0 date sur les gammes MNRJ et MSGX.
--
-- Correctif (demande explicite, meme table) : colonne id_type OBLIGATOIRE,
-- 'PLAN' par defaut, renseignee dans le fichier d'import (colonne Id_type) et
-- chargee par l'import generique. La colonne warpl garde son nom (mapping de
-- l'import generique) mais porte un plan OU un poste selon id_type.
-- Saisie normalisee par trigger : vide -> PLAN ; « Plan d'entretien », plan,
-- PLAN_ENTRETIEN... -> PLAN ; « Poste d'entretien », poste... -> POSTE ;
-- toute autre valeur fait echouer la ligne.
--
-- pe_tools.date_derniere_execution = date du PLAN de la gamme, a defaut date
-- de son POSTE d'entretien (plus recente en cas de doublon). Les triggers de la
-- 082 sont etendus au poste ; ifs_date_execution (083, generee) suit seule.
-- La fonction a 1 argument de la 082 est remplacee par une version a 2
-- arguments : redeployer le backend apres cette migration (bouton de synchro).
-- Prerequis : 082. Idempotente.
-- ============================================================================
BEGIN;

ALTER TABLE raw_data.plan_entretien_derniere_exec
    ADD COLUMN IF NOT EXISTS id_type TEXT NOT NULL DEFAULT 'PLAN';

COMMENT ON COLUMN raw_data.plan_entretien_derniere_exec.warpl IS
    'Numero de plan d''entretien (id_type = PLAN) ou de poste d''entretien (id_type = POSTE).';
COMMENT ON COLUMN raw_data.plan_entretien_derniere_exec.id_type IS
    'PLAN | POSTE : nature de warpl. Obligatoire, PLAN par defaut. Migration 084.';

-- Normalisation de la saisie (l'import generique envoie le texte du fichier, ou NULL).
CREATE OR REPLACE FUNCTION raw_data.trg_plan_derniere_exec_id_type()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v TEXT := upper(btrim(COALESCE(NEW.id_type, '')));
BEGIN
    NEW.id_type := CASE
        WHEN v = ''             THEN 'PLAN'
        WHEN v LIKE 'PLAN%'     THEN 'PLAN'
        WHEN v LIKE 'POSTE%'    THEN 'POSTE'
    END;
    IF NEW.id_type IS NULL THEN
        RAISE EXCEPTION 'id_type « % » invalide pour %, attendu : Plan d''entretien ou Poste d''entretien', v, NEW.warpl;
    END IF;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS plan_derniere_exec_id_type ON raw_data.plan_entretien_derniere_exec;
CREATE TRIGGER plan_derniere_exec_id_type
    BEFORE INSERT OR UPDATE ON raw_data.plan_entretien_derniere_exec
    FOR EACH ROW EXECUTE FUNCTION raw_data.trg_plan_derniere_exec_id_type();

ALTER TABLE raw_data.plan_entretien_derniere_exec
    DROP CONSTRAINT IF EXISTS plan_entretien_derniere_exec_id_type_check;
ALTER TABLE raw_data.plan_entretien_derniere_exec
    ADD CONSTRAINT plan_entretien_derniere_exec_id_type_check CHECK (id_type IN ('PLAN', 'POSTE'));

-- Date de derniere execution d'une gamme : par son plan, a defaut par son poste d'entretien.
CREATE OR REPLACE FUNCTION raw_data.pe_tools_date_derniere_execution(p_plan TEXT, p_poste TEXT)
RETURNS DATE LANGUAGE sql STABLE AS $$
    SELECT COALESCE(
        (SELECT max(left(p.date_derniere_execution, 10)::date)
           FROM raw_data.plan_entretien_derniere_exec p
          WHERE p.id_type = 'PLAN'
            AND LTRIM(p.warpl, '0') = LTRIM(NULLIF(btrim(p_plan), ''), '0')
            AND p.date_derniere_execution ~ '^\d{4}-\d{2}-\d{2}'),
        (SELECT max(left(p.date_derniere_execution, 10)::date)
           FROM raw_data.plan_entretien_derniere_exec p
          WHERE p.id_type = 'POSTE'
            AND LTRIM(p.warpl, '0') = LTRIM(NULLIF(btrim(p_poste), ''), '0')
            AND p.date_derniere_execution ~ '^\d{4}-\d{2}-\d{2}'))
$$;

-- Cote gammes : la date suit le plan ET le poste de la ligne.
CREATE OR REPLACE FUNCTION raw_data.trg_pe_tools_date_derniere_execution()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.date_derniere_execution :=
        raw_data.pe_tools_date_derniere_execution(NEW.plan_entretien, NEW.poste_entretien);
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS pe_tools_date_derniere_execution ON raw_data.pe_tools;
CREATE TRIGGER pe_tools_date_derniere_execution
    BEFORE INSERT OR UPDATE OF plan_entretien, poste_entretien ON raw_data.pe_tools
    FOR EACH ROW EXECUTE FUNCTION raw_data.trg_pe_tools_date_derniere_execution();

-- Cote fichier : recalcul des gammes dont le plan OU le poste vaut l'identifiant touche
-- (sans regarder id_type : recalculer une gamme de trop est sans effet).
CREATE OR REPLACE FUNCTION raw_data.trg_plan_derniere_exec_vers_pe_tools()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_ids TEXT[];
BEGIN
    IF TG_OP = 'TRUNCATE' THEN
        UPDATE raw_data.pe_tools SET date_derniere_execution = NULL WHERE date_derniere_execution IS NOT NULL;
        RETURN NULL;
    END IF;
    v_ids := CASE TG_OP
        WHEN 'INSERT' THEN ARRAY[LTRIM(NEW.warpl, '0')]
        WHEN 'DELETE' THEN ARRAY[LTRIM(OLD.warpl, '0')]
        ELSE ARRAY[LTRIM(NEW.warpl, '0'), LTRIM(OLD.warpl, '0')] END;
    UPDATE raw_data.pe_tools t
       SET date_derniere_execution = raw_data.pe_tools_date_derniere_execution(t.plan_entretien, t.poste_entretien)
     WHERE (LTRIM(t.plan_entretien, '0') = ANY(v_ids) OR LTRIM(t.poste_entretien, '0') = ANY(v_ids))
       AND t.date_derniere_execution IS DISTINCT FROM
           raw_data.pe_tools_date_derniere_execution(t.plan_entretien, t.poste_entretien);
    RETURN NULL;
END $$;
-- (triggers plan_derniere_exec_vers_pe_tools[_truncate] de la 082 inchanges : ils appellent cette fonction.)

-- L'ancienne signature ne connait pas le poste : la garder laisserait un appel qui efface ces dates.
DROP FUNCTION IF EXISTS raw_data.pe_tools_date_derniere_execution(TEXT);

-- Rattrapage des lignes deja chargees : l'onglet « NRJ et MSGX » porte des postes
-- d'entretien SAP (AFIH.WAPOS), jamais des plans (80 lignes au 29/09/2026).
UPDATE raw_data.plan_entretien_derniere_exec p
   SET id_type = 'POSTE'
 WHERE p.id_type = 'PLAN'
   AND EXISTS (SELECT 1 FROM raw_data.afih h WHERE LTRIM(h.wapos, '0') = LTRIM(p.warpl, '0'))
   AND NOT EXISTS (SELECT 1 FROM raw_data.afih h WHERE LTRIM(h.warpl, '0') = LTRIM(p.warpl, '0'));

-- Recalcul complet (les postes des gammes MNRJ / MSGX gagnent leur date).
UPDATE raw_data.pe_tools t
   SET date_derniere_execution = raw_data.pe_tools_date_derniere_execution(t.plan_entretien, t.poste_entretien)
 WHERE t.date_derniere_execution IS DISTINCT FROM
       raw_data.pe_tools_date_derniere_execution(t.plan_entretien, t.poste_entretien);

COMMIT;
