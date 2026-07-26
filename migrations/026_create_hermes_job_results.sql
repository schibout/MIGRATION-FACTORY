-- =====================================================
-- Migration: Assistant Hermes / Agent Trimet — résultats de jobs exécutés
-- Description: Stocke le résultat d'un job exécuté « à la demande » depuis l'app.
--              Hermes ne relivre pas les résultats de cron vers l'API server
--              (deliver=origin échoue, pas de webhook sortant) : on exécute le
--              prompt du job via /chat/completions et on stocke la réponse ici
--              pour l'afficher (onglet Résultats). Isolé par utilisateur (JWT).
-- Date: 2026-07-10
-- Idempotent: CREATE TABLE/INDEX IF NOT EXISTS (aussi créée à la volée par
--             api/hermes._ensure_schema si la migration n'est pas jouée).
-- =====================================================

CREATE TABLE IF NOT EXISTS public.hermes_job_results (
    id            BIGSERIAL PRIMARY KEY,
    utilisateur   VARCHAR(150) NOT NULL,
    job_id        VARCHAR(120),
    job_name      TEXT,
    prompt        TEXT,
    resultat      TEXT,
    statut        VARCHAR(20) NOT NULL DEFAULT 'ok',
    date_creation TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_hermes_job_results_user
    ON public.hermes_job_results (utilisateur, date_creation DESC);

COMMENT ON TABLE public.hermes_job_results IS
    'Résultats de jobs Agent Trimet exécutés à la demande (prompt rejoué via chat, réponse stockée).';
