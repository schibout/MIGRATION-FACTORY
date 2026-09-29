-- ============================================================================
-- 082 - raw_data.pe_tools.date_derniere_execution (DATE)
-- ----------------------------------------------------------------------------
-- Date de derniere execution du plan d'entretien de chaque gamme, lue dans
-- raw_data.plan_entretien_derniere_exec (fichier Excel charge par l'import
-- generique, warpl + date en texte 'YYYY-MM-DD hh:mm:ss').
-- Rapprochement sur le numero de plan sans zeros de tete ; un plan present
-- plusieurs fois dans le fichier (6 cas au 29/09/2026) prend la date la plus
-- recente. Plan absent du fichier -> NULL.
--
-- Colonne CALCULEE, jamais saisie. Elle reste a jour par deux triggers :
--   * pe_tools (BEFORE INSERT / UPDATE OF plan_entretien) : l'import PE Tools
--     supprime puis reinsere les lignes d'un fichier, la date est reprise a
--     l'insertion ;
--   * plan_entretien_derniere_exec (AFTER INSERT/UPDATE/DELETE par ligne, et
--     TRUNCATE) : un nouvel import du fichier des dates met a jour les gammes
--     du plan concerne.
-- Idempotente.
-- ============================================================================
BEGIN;

ALTER TABLE raw_data.pe_tools ADD COLUMN IF NOT EXISTS date_derniere_execution DATE;

-- Derniere execution d'un plan ; une date mal formee est ignoree au lieu de faire echouer l'import.
CREATE OR REPLACE FUNCTION raw_data.pe_tools_date_derniere_execution(p_plan TEXT)
RETURNS DATE LANGUAGE sql STABLE AS $$
    SELECT max(left(p.date_derniere_execution, 10)::date)
    FROM raw_data.plan_entretien_derniere_exec p
    WHERE LTRIM(p.warpl, '0') = LTRIM(p_plan, '0')
      AND p.date_derniere_execution ~ '^\d{4}-\d{2}-\d{2}'
$$;

-- Cote gammes : la date suit le plan de la ligne.
CREATE OR REPLACE FUNCTION raw_data.trg_pe_tools_date_derniere_execution()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.date_derniere_execution := raw_data.pe_tools_date_derniere_execution(NEW.plan_entretien);
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS pe_tools_date_derniere_execution ON raw_data.pe_tools;
CREATE TRIGGER pe_tools_date_derniere_execution
    BEFORE INSERT OR UPDATE OF plan_entretien ON raw_data.pe_tools
    FOR EACH ROW EXECUTE FUNCTION raw_data.trg_pe_tools_date_derniere_execution();

-- Cote fichier des dates : recalcul des gammes du (des) plan(s) touche(s).
-- ponytail: par ligne (l'import generique insere ligne a ligne) ; pe_tools = ~2 000 lignes, un balayage par ligne importee reste negligeable.
CREATE OR REPLACE FUNCTION raw_data.trg_plan_derniere_exec_vers_pe_tools()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_plans TEXT[];
BEGIN
    IF TG_OP = 'TRUNCATE' THEN
        UPDATE raw_data.pe_tools SET date_derniere_execution = NULL WHERE date_derniere_execution IS NOT NULL;
        RETURN NULL;
    END IF;
    v_plans := CASE TG_OP
        WHEN 'INSERT' THEN ARRAY[LTRIM(NEW.warpl, '0')]
        WHEN 'DELETE' THEN ARRAY[LTRIM(OLD.warpl, '0')]
        ELSE ARRAY[LTRIM(NEW.warpl, '0'), LTRIM(OLD.warpl, '0')] END;
    UPDATE raw_data.pe_tools t
       SET date_derniere_execution = raw_data.pe_tools_date_derniere_execution(t.plan_entretien)
     WHERE LTRIM(t.plan_entretien, '0') = ANY(v_plans)
       AND t.date_derniere_execution IS DISTINCT FROM raw_data.pe_tools_date_derniere_execution(t.plan_entretien);
    RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS plan_derniere_exec_vers_pe_tools ON raw_data.plan_entretien_derniere_exec;
CREATE TRIGGER plan_derniere_exec_vers_pe_tools
    AFTER INSERT OR UPDATE OR DELETE ON raw_data.plan_entretien_derniere_exec
    FOR EACH ROW EXECUTE FUNCTION raw_data.trg_plan_derniere_exec_vers_pe_tools();

DROP TRIGGER IF EXISTS plan_derniere_exec_vers_pe_tools_truncate ON raw_data.plan_entretien_derniere_exec;
CREATE TRIGGER plan_derniere_exec_vers_pe_tools_truncate
    AFTER TRUNCATE ON raw_data.plan_entretien_derniere_exec
    FOR EACH STATEMENT EXECUTE FUNCTION raw_data.trg_plan_derniere_exec_vers_pe_tools();

-- Alimentation initiale.
UPDATE raw_data.pe_tools t
   SET date_derniere_execution = raw_data.pe_tools_date_derniere_execution(t.plan_entretien)
 WHERE t.date_derniere_execution IS DISTINCT FROM raw_data.pe_tools_date_derniere_execution(t.plan_entretien);

COMMIT;
