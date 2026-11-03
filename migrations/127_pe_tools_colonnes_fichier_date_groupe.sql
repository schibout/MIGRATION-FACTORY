-- ============================================================================
-- 127 - pe_tools : « Date dernière exécution » et « Groupe ressource » lues
--       dans les fichiers PE Tools (colonnes ajoutees aux fichiers en 2026-11)
-- ----------------------------------------------------------------------------
-- groupe_ressources : valeur du fichier, telle quelle. Remplace la colonne
--   GENEREE de la 087 (deduction par le type MEC/ELEC), supprimee si elle a
--   ete jouee : une colonne generee ne peut pas etre ecrite par l'import.
-- date_derniere_execution_fichier : date du fichier PE Tools (DATE, convertie
--   par l'import). date_derniere_execution reste calculee par trigger, avec la
--   priorite : saisie MANUEL (plan puis poste, 085) > date du fichier PE Tools
--   > fichier des dates (plan puis poste, 084). ifs_date_execution (083) suit.
-- La fonction prend un 3e argument : l'ancienne signature est supprimee pour
-- qu'aucun appel a 2 arguments n'efface silencieusement la date du fichier.
-- Prerequis : 085. Idempotente. Redemarrer le backend apres (./deploybackend.sh).
-- ============================================================================
BEGIN;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'raw_data' AND table_name = 'pe_tools'
                  AND column_name = 'groupe_ressources' AND is_generated = 'ALWAYS') THEN
        ALTER TABLE raw_data.pe_tools DROP COLUMN groupe_ressources;
    END IF;
END $$;

ALTER TABLE raw_data.pe_tools
    ADD COLUMN IF NOT EXISTS groupe_ressources TEXT,
    ADD COLUMN IF NOT EXISTS date_derniere_execution_fichier DATE;

COMMENT ON COLUMN raw_data.pe_tools.groupe_ressources IS
    'Groupe de ressources IFS, colonne « Groupe ressource » du fichier PE Tools. Migration 127.';
COMMENT ON COLUMN raw_data.pe_tools.date_derniere_execution_fichier IS
    'Colonne « Date dernière exécution » du fichier PE Tools. Prime sur le fichier des dates, '
    'pas sur une saisie manuelle (cf. date_derniere_execution). Migration 127.';

CREATE OR REPLACE FUNCTION raw_data.pe_tools_date_derniere_execution(p_plan TEXT, p_poste TEXT, p_fichier DATE)
RETURNS DATE LANGUAGE sql STABLE AS $$
    SELECT COALESCE(
        (SELECT left(p.date_derniere_execution, 10)::date
           FROM raw_data.plan_entretien_derniere_exec p
          WHERE p.source = 'MANUEL'
            AND ((p.id_type = 'PLAN'  AND LTRIM(p.warpl, '0') = LTRIM(NULLIF(btrim(p_plan), ''), '0'))
              OR (p.id_type = 'POSTE' AND LTRIM(p.warpl, '0') = LTRIM(NULLIF(btrim(p_poste), ''), '0')))
            AND p.date_derniere_execution ~ '^\d{4}-\d{2}-\d{2}'
          ORDER BY (p.id_type = 'PLAN') DESC
          LIMIT 1),
        p_fichier,
        (SELECT left(p.date_derniere_execution, 10)::date
           FROM raw_data.plan_entretien_derniere_exec p
          WHERE p.id_type = 'PLAN'
            AND LTRIM(p.warpl, '0') = LTRIM(NULLIF(btrim(p_plan), ''), '0')
            AND p.date_derniere_execution ~ '^\d{4}-\d{2}-\d{2}'
          ORDER BY left(p.date_derniere_execution, 10) DESC
          LIMIT 1),
        (SELECT left(p.date_derniere_execution, 10)::date
           FROM raw_data.plan_entretien_derniere_exec p
          WHERE p.id_type = 'POSTE'
            AND LTRIM(p.warpl, '0') = LTRIM(NULLIF(btrim(p_poste), ''), '0')
            AND p.date_derniere_execution ~ '^\d{4}-\d{2}-\d{2}'
          ORDER BY left(p.date_derniere_execution, 10) DESC
          LIMIT 1))
$$;

CREATE OR REPLACE FUNCTION raw_data.trg_pe_tools_date_derniere_execution()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.date_derniere_execution := raw_data.pe_tools_date_derniere_execution(
        NEW.plan_entretien, NEW.poste_entretien, NEW.date_derniere_execution_fichier);
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS pe_tools_date_derniere_execution ON raw_data.pe_tools;
CREATE TRIGGER pe_tools_date_derniere_execution
    BEFORE INSERT OR UPDATE OF plan_entretien, poste_entretien, date_derniere_execution_fichier
    ON raw_data.pe_tools
    FOR EACH ROW EXECUTE FUNCTION raw_data.trg_pe_tools_date_derniere_execution();

-- Cote fichier des dates (triggers de la 082 inchanges, ils appellent cette fonction).
CREATE OR REPLACE FUNCTION raw_data.trg_plan_derniere_exec_vers_pe_tools()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_ids TEXT[];
BEGIN
    IF TG_OP = 'TRUNCATE' THEN
        -- Plus aucune date dans le fichier des dates : reste celle du fichier PE Tools.
        UPDATE raw_data.pe_tools SET date_derniere_execution = date_derniere_execution_fichier
         WHERE date_derniere_execution IS DISTINCT FROM date_derniere_execution_fichier;
        RETURN NULL;
    END IF;
    v_ids := CASE TG_OP
        WHEN 'INSERT' THEN ARRAY[LTRIM(NEW.warpl, '0')]
        WHEN 'DELETE' THEN ARRAY[LTRIM(OLD.warpl, '0')]
        ELSE ARRAY[LTRIM(NEW.warpl, '0'), LTRIM(OLD.warpl, '0')] END;
    UPDATE raw_data.pe_tools t
       SET date_derniere_execution = raw_data.pe_tools_date_derniere_execution(
               t.plan_entretien, t.poste_entretien, t.date_derniere_execution_fichier)
     WHERE (LTRIM(t.plan_entretien, '0') = ANY(v_ids) OR LTRIM(t.poste_entretien, '0') = ANY(v_ids))
       AND t.date_derniere_execution IS DISTINCT FROM raw_data.pe_tools_date_derniere_execution(
               t.plan_entretien, t.poste_entretien, t.date_derniere_execution_fichier);
    RETURN NULL;
END $$;

DROP FUNCTION IF EXISTS raw_data.pe_tools_date_derniere_execution(TEXT, TEXT);

COMMIT;
