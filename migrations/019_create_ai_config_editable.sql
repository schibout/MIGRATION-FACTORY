-- =====================================================
-- Migration: Assistant IA — configuration ÉDITABLE des prompts
-- Description:
--   Externalise en base ce qui paramètre les prompts, pour le rendre éditable
--   depuis l'écran « Configuration IA » :
--     1. public.ai_domain_tables : associations mot-clé -> tables (ex-DOMAIN_TABLES).
--     2. public.ai_packs : packs de connaissances par domaine (content JSONB =
--        keywords/synonyms/tables/joins/enums/rules/docs/patterns).
--   Les loaders backend lisent la base EN PRIORITÉ, avec REPLI sur le code / les
--   fichiers config/skills si ces tables sont vides ou indisponibles (zéro régression).
--   Peuplées une fois par backend/seed_ai_config.py.
-- Date: 2026-06-15
-- Idempotent: CREATE TABLE IF NOT EXISTS
-- =====================================================

-- ----------------------------------------------------
-- 1. Associations mot-clé -> tables (éditable)
-- ----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ai_domain_tables (
    id        SERIAL PRIMARY KEY,
    domain_id VARCHAR(60)  NOT NULL,
    keywords  JSONB        NOT NULL DEFAULT '[]'::jsonb,   -- ["facture","invoice",...]
    tables    JSONB        NOT NULL DEFAULT '[]'::jsonb,   -- ["raw_data.rbkp",...]
    position  INTEGER      NOT NULL DEFAULT 0,             -- ordre = priorité
    actif     BOOLEAN      NOT NULL DEFAULT TRUE,
    date_maj  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ai_domain_tables_actif
    ON public.ai_domain_tables (actif, position);

COMMENT ON TABLE public.ai_domain_tables IS
    'Associations mot-clé -> tables (ex-DOMAIN_TABLES) éditables. Repli sur le code si vide.';

-- ----------------------------------------------------
-- 2. Packs de connaissances (éditable, 1 ligne = 1 domaine)
-- ----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ai_packs (
    domain    VARCHAR(60) PRIMARY KEY,
    content   JSONB       NOT NULL,        -- pack complet (cf. config/skills/*.json)
    actif     BOOLEAN     NOT NULL DEFAULT TRUE,
    date_maj  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE public.ai_packs IS
    'Packs de connaissances par domaine (jointures/enums/règles/docs/patterns) éditables. Repli sur config/skills/*.json si vide.';

-- ----------------------------------------------------
-- 3. Confirmation
-- ----------------------------------------------------
DO $$
DECLARE v_dom INTEGER; v_pck INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_dom FROM public.ai_domain_tables;
    SELECT COUNT(*) INTO v_pck FROM public.ai_packs;
    RAISE NOTICE 'ai_domain_tables : % ligne(s) ; ai_packs : % ligne(s).', v_dom, v_pck;
    RAISE NOTICE 'Peupler via : python backend/seed_ai_config.py';
END $$;
