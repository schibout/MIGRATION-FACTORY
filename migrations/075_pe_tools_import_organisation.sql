-- ============================================================================
-- 075 : Import PE Tools par fichier + organisation de maintenance
--
-- raw_data.pe_tools a ete chargee une fois, hors application, par fusion des
-- CSV "PeTool - 7.<CODE>.csv" : rien ne trace le fichier d'origine, et
-- pm_action.org_code est une constante (FR_MAINT). Le metier veut que
-- l'organisation IFS soit deduite du fichier :
--   MSJ -> FR-MSJ, MNRJ -> SJ-MSST, et SJ-<CODE> pour les autres.
--
-- Cette migration :
--   1. ajoute nom_fichier / organisation_maintenance / imported_at a pe_tools
--      (les 1 760 lignes historiques restent a NULL : jamais touchees par
--      l'import "remplacer par fichier") ;
--   2. cree public.pe_tools_organisation (code fichier -> org IFS), seedee ;
--      un code absent de la table donne une organisation NULL a l'import
--      (pas de repli generique SJ-<CODE> : on veut voir le trou) ;
--   3. cree les 2 fonctions de resolution, seule implementation de la regle,
--      utilisees par l'import et rejouables en SQL si le parametrage change :
--        UPDATE raw_data.pe_tools
--           SET organisation_maintenance = public.pe_tools_org_code(nom_fichier)
--         WHERE nom_fichier IS NOT NULL;
--
-- Idempotente : rejouable sans risque (le seed ne reecrit pas une ligne
-- modifiee a la main).
-- ============================================================================

BEGIN;

-- 1. Colonnes de tracabilite de l'import -------------------------------------
ALTER TABLE raw_data.pe_tools ADD COLUMN IF NOT EXISTS nom_fichier              TEXT;
ALTER TABLE raw_data.pe_tools ADD COLUMN IF NOT EXISTS organisation_maintenance TEXT;
ALTER TABLE raw_data.pe_tools ADD COLUMN IF NOT EXISTS imported_at              TIMESTAMPTZ;

COMMENT ON COLUMN raw_data.pe_tools.nom_fichier IS
    'Nom du CSV depose via l''ecran Maintenance / PE Tools (ex. PeTool - 7.MCAR.csv). NULL = chargement historique hors application';
COMMENT ON COLUMN raw_data.pe_tools.organisation_maintenance IS
    'Organisation de maintenance IFS deduite du nom de fichier via public.pe_tools_org_code() ; NULL si code fichier inconnu de public.pe_tools_organisation';
COMMENT ON COLUMN raw_data.pe_tools.imported_at IS
    'Horodatage de l''import du fichier';

CREATE INDEX IF NOT EXISTS idx_pe_tools_nom_fichier ON raw_data.pe_tools (nom_fichier);
CREATE INDEX IF NOT EXISTS idx_pe_tools_organisation ON raw_data.pe_tools (organisation_maintenance);

-- 2. Table de parametrage code fichier -> organisation -----------------------
CREATE TABLE IF NOT EXISTS public.pe_tools_organisation (
    code_fichier TEXT PRIMARY KEY,
    org_code     TEXT NOT NULL,
    description  TEXT,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by   TEXT
);

COMMENT ON TABLE public.pe_tools_organisation IS
    'Regle fichier PE Tools -> organisation de maintenance IFS : le code est le segment "PeTool - 7.<CODE>.csv". Lue par public.pe_tools_org_code().';

INSERT INTO public.pe_tools_organisation (code_fichier, org_code, description) VALUES ('MSJ',  'FR-MSJ',  'Maintenance Saint-Jean (organisation France)') ON CONFLICT (code_fichier) DO NOTHING;
INSERT INTO public.pe_tools_organisation (code_fichier, org_code, description) VALUES ('MCAR', 'SJ-MCAR', NULL) ON CONFLICT (code_fichier) DO NOTHING;
INSERT INTO public.pe_tools_organisation (code_fichier, org_code, description) VALUES ('MATC', 'SJ-MATC', NULL) ON CONFLICT (code_fichier) DO NOTHING;
INSERT INTO public.pe_tools_organisation (code_fichier, org_code, description) VALUES ('MELY', 'SJ-MELY', NULL) ON CONFLICT (code_fichier) DO NOTHING;
INSERT INTO public.pe_tools_organisation (code_fichier, org_code, description) VALUES ('MFIE', 'SJ-MFIE', NULL) ON CONFLICT (code_fichier) DO NOTHING;
INSERT INTO public.pe_tools_organisation (code_fichier, org_code, description) VALUES ('MSGX', 'SJ-MSGX', NULL) ON CONFLICT (code_fichier) DO NOTHING;
INSERT INTO public.pe_tools_organisation (code_fichier, org_code, description) VALUES ('MSCT', 'SJ-MSCT', NULL) ON CONFLICT (code_fichier) DO NOTHING;
INSERT INTO public.pe_tools_organisation (code_fichier, org_code, description) VALUES ('MNRJ', 'SJ-MSST', 'Fichier MNRJ -> organisation MSST (exception metier)') ON CONFLICT (code_fichier) DO NOTHING;
INSERT INTO public.pe_tools_organisation (code_fichier, org_code, description) VALUES ('MTRO', 'SJ-MTRO', NULL) ON CONFLICT (code_fichier) DO NOTHING;

-- 3. Fonctions de resolution --------------------------------------------------
-- Code = segment entre le dernier '.' precedant l'extension et l'extension,
-- en majuscules : 'PeTool - 7.MCAR.csv' -> 'MCAR', 'petool - 7.msgx.CSV' -> 'MSGX'.
-- Sans extension ou sans point intermediaire -> NULL.
CREATE OR REPLACE FUNCTION public.pe_tools_code_fichier(p_nom_fichier TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT upper(NULLIF(btrim((regexp_match(COALESCE(p_nom_fichier, ''), '\.([^.\\/]+)\.[^.\\/]+$'))[1]), ''));
$$;

CREATE OR REPLACE FUNCTION public.pe_tools_org_code(p_nom_fichier TEXT)
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
    SELECT o.org_code
    FROM public.pe_tools_organisation o
    WHERE o.code_fichier = public.pe_tools_code_fichier(p_nom_fichier)
      AND o.is_active;
$$;

COMMENT ON FUNCTION public.pe_tools_code_fichier(TEXT) IS
    'Extrait le code de service d''un nom de fichier PE Tools ("PeTool - 7.MCAR.csv" -> "MCAR")';
COMMENT ON FUNCTION public.pe_tools_org_code(TEXT) IS
    'Organisation de maintenance IFS d''un nom de fichier PE Tools (via public.pe_tools_organisation) ; NULL si inconnu';

-- 4. Assertions ---------------------------------------------------------------
DO $$
BEGIN
    IF public.pe_tools_code_fichier('PeTool - 7.MCAR.csv') IS DISTINCT FROM 'MCAR' THEN
        RAISE EXCEPTION 'pe_tools_code_fichier : cas nominal KO';
    END IF;
    IF public.pe_tools_code_fichier('petool - 7.msgx.CSV') IS DISTINCT FROM 'MSGX' THEN
        RAISE EXCEPTION 'pe_tools_code_fichier : casse KO';
    END IF;
    IF public.pe_tools_code_fichier('PeTool - 7.MSJ.xlsm') IS DISTINCT FROM 'MSJ' THEN
        RAISE EXCEPTION 'pe_tools_code_fichier : extension xlsm KO';
    END IF;
    IF public.pe_tools_code_fichier('fusion.csv') IS NOT NULL THEN
        RAISE EXCEPTION 'pe_tools_code_fichier : nom sans point intermediaire doit donner NULL';
    END IF;
    IF public.pe_tools_code_fichier('sans_extension') IS NOT NULL THEN
        RAISE EXCEPTION 'pe_tools_code_fichier : nom sans extension doit donner NULL';
    END IF;
    IF public.pe_tools_code_fichier(NULL) IS NOT NULL THEN
        RAISE EXCEPTION 'pe_tools_code_fichier : NULL doit donner NULL';
    END IF;
    IF public.pe_tools_org_code('PeTool - 7.MSJ.csv') IS DISTINCT FROM 'FR-MSJ' THEN
        RAISE EXCEPTION 'pe_tools_org_code : exception MSJ KO';
    END IF;
    IF public.pe_tools_org_code('PeTool - 7.MNRJ.csv') IS DISTINCT FROM 'SJ-MSST' THEN
        RAISE EXCEPTION 'pe_tools_org_code : exception MNRJ KO';
    END IF;
    IF public.pe_tools_org_code('PeTool - 7.MCAR.csv') IS DISTINCT FROM 'SJ-MCAR' THEN
        RAISE EXCEPTION 'pe_tools_org_code : cas nominal KO';
    END IF;
    IF public.pe_tools_org_code('PeTool - 7.MENG.csv') IS NOT NULL THEN
        RAISE EXCEPTION 'pe_tools_org_code : code inconnu doit donner NULL';
    END IF;
    RAISE NOTICE '075 : assertions OK';
END $$;

COMMIT;
