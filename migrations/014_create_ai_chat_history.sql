-- =====================================================
-- Migration: Assistant IA — historique conversationnel
-- Description: Conversations (fils) + messages (tours), pour persister le chat
--              et pouvoir rouvrir une conversation passée. Stockage "SQL seul" :
--              les réponses gardent le SQL (ré-exécuté à la réouverture via
--              readonly_ai), PAS les lignes de résultat. Lié à public.ai_query_log
--              (audit technique + ré-export Excel existant).
-- Date: 2026-06-13
-- Idempotent: CREATE TABLE/INDEX IF NOT EXISTS
-- =====================================================

-- ----------------------------------------------------
-- 1. Conversations (fils de discussion)
-- ----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ai_conversations (
    id            BIGSERIAL PRIMARY KEY,
    utilisateur   VARCHAR(150) NOT NULL,                 -- identité issue du JWT
    titre         TEXT,                                  -- auto depuis la 1re question
    date_creation TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    date_maj      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,  -- bumpée à chaque message
    archivee      BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_ai_conversations_user
    ON public.ai_conversations (utilisateur, date_maj DESC);

-- ----------------------------------------------------
-- 2. Messages (tours de conversation)
-- ----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ai_messages (
    id              BIGSERIAL PRIMARY KEY,
    conversation_id BIGINT NOT NULL
                    REFERENCES public.ai_conversations(id) ON DELETE CASCADE,
    role            VARCHAR(12) NOT NULL,                 -- 'user' | 'assistant'
    contenu         TEXT,                                 -- question (user) / explication ou raison (assistant)
    statut          VARCHAR(12),                          -- succes | erreur | rejete | indisponible (assistant)
    sql_genere      TEXT,                                 -- SQL ré-exécutable (réponses)
    nb_lignes       INTEGER,
    tronque         BOOLEAN,
    duree_ms        INTEGER,
    id_log          INTEGER REFERENCES public.ai_query_log(id),  -- lien audit + ré-export/ré-exécution
    date_creation   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ai_messages_conv
    ON public.ai_messages (conversation_id, date_creation, id);

COMMENT ON TABLE public.ai_conversations IS 'Fils de discussion de l''Assistant IA (un par conversation utilisateur)';
COMMENT ON TABLE public.ai_messages      IS 'Messages d''une conversation IA (question utilisateur + réponse assistant). Stockage SQL seul, résultats ré-exécutés à la réouverture.';
COMMENT ON COLUMN public.ai_messages.role IS 'user | assistant';

-- ----------------------------------------------------
-- 3. Confirmation
-- ----------------------------------------------------
DO $$
DECLARE v_conv INTEGER; v_msg INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_conv FROM public.ai_conversations;
    SELECT COUNT(*) INTO v_msg  FROM public.ai_messages;
    RAISE NOTICE 'Historique chat prêt : % conversation(s), % message(s).', v_conv, v_msg;
END $$;
