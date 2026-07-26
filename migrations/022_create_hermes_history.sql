-- =====================================================
-- Migration: Assistant Hermes — historique conversationnel
-- Description: Conversations (fils) + messages (tours) du chat Hermes, pour
--              persister l'historique et rouvrir une conversation passée.
--              Le streaming Hermes se fait côté client : c'est le frontend qui
--              enregistre la conversation complète après chaque échange (le proxy
--              ne fait que relayer les octets SSE). Les instructions système
--              persistantes sont portées par la conversation.
-- Date: 2026-07-08
-- Idempotent: CREATE TABLE/INDEX IF NOT EXISTS (aussi créées à la volée par
--             api/hermes._ensure_schema si la migration n'est pas jouée).
-- =====================================================

CREATE TABLE IF NOT EXISTS public.hermes_conversations (
    id            BIGSERIAL PRIMARY KEY,
    utilisateur   VARCHAR(150) NOT NULL,                 -- identité issue du JWT
    titre         TEXT,                                  -- auto depuis le 1er message user
    instructions  TEXT NOT NULL DEFAULT '',              -- consigne système de la conversation
    date_creation TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    date_maj      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_hermes_conversations_user
    ON public.hermes_conversations (utilisateur, date_maj DESC);

CREATE TABLE IF NOT EXISTS public.hermes_messages (
    id              BIGSERIAL PRIMARY KEY,
    conversation_id BIGINT NOT NULL
                    REFERENCES public.hermes_conversations(id) ON DELETE CASCADE,
    role            VARCHAR(12) NOT NULL,                 -- 'user' | 'assistant'
    contenu         TEXT,
    position        INTEGER NOT NULL DEFAULT 0,           -- ordre dans la conversation
    date_creation   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_hermes_messages_conv
    ON public.hermes_messages (conversation_id, position, id);

COMMENT ON TABLE public.hermes_conversations IS 'Fils de discussion de l''Assistant Hermes (un par conversation utilisateur).';
COMMENT ON TABLE public.hermes_messages      IS 'Messages d''une conversation Hermes (role user/assistant, contenu texte).';

DO $$
DECLARE v_conv INTEGER; v_msg INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_conv FROM public.hermes_conversations;
    SELECT COUNT(*) INTO v_msg  FROM public.hermes_messages;
    RAISE NOTICE 'Historique Hermes prêt : % conversation(s), % message(s).', v_conv, v_msg;
END $$;
