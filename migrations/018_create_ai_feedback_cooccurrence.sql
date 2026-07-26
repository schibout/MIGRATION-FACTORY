-- =====================================================
-- Migration: Assistant IA — feedback utilisateur + co-occurrences de tables
-- Description:
--   1. public.ai_query_log.feedback : vote utilisateur sur une réponse
--      ('up' | 'down' | NULL). Un 'up' rend la requête utilisable comme few-shot
--      « vivant » (récupéré directement depuis le journal, sans édition de fichier).
--   2. public.ai_table_cooccurrence : tables effectivement utilisées ENSEMBLE dans
--      les requêtes réussies (poids = nb d'occurrences). Alimente le Knowledge Graph
--      (jointures « métier » non déclarées en FK DDIC). Peuplé par build_cooccurrence.py.
-- Date: 2026-06-15
-- Idempotent: ADD COLUMN / CREATE TABLE IF NOT EXISTS
-- =====================================================

-- ----------------------------------------------------
-- 1. Feedback utilisateur sur les réponses
-- ----------------------------------------------------
ALTER TABLE public.ai_query_log
    ADD COLUMN IF NOT EXISTS feedback VARCHAR(8);            -- 'up' | 'down' | NULL
ALTER TABLE public.ai_query_log
    ADD COLUMN IF NOT EXISTS feedback_date TIMESTAMP;

-- Retrouver rapidement les pouces-haut (few-shots vivants).
CREATE INDEX IF NOT EXISTS idx_ai_query_log_feedback
    ON public.ai_query_log (feedback)
    WHERE feedback IS NOT NULL;

-- ----------------------------------------------------
-- 2. Co-occurrences de tables (signal d'usage pour le Knowledge Graph)
-- ----------------------------------------------------
-- Paire ordonnée (src_table < dst_table) pour éviter les doublons A/B vs B/A.
CREATE TABLE IF NOT EXISTS public.ai_table_cooccurrence (
    src_table  VARCHAR(100) NOT NULL,
    dst_table  VARCHAR(100) NOT NULL,
    poids      INTEGER NOT NULL DEFAULT 0,        -- nb de requêtes réussies les liant
    date_maj   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ai_cooc UNIQUE (src_table, dst_table)
);

COMMENT ON TABLE public.ai_table_cooccurrence IS
    'Tables utilisées ensemble dans les requêtes réussies (ai_query_log). Signal d''usage complétant les FK DDIC dans le sous-graphe de jointures.';

GRANT SELECT ON public.ai_table_cooccurrence TO readonly_ai;

-- ----------------------------------------------------
-- 3. Confirmation
-- ----------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE 'Colonnes ai_query_log.feedback / feedback_date prêtes.';
    RAISE NOTICE 'Table ai_table_cooccurrence prête (peupler via python backend/build_cooccurrence.py).';
END $$;
