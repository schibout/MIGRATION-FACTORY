-- =====================================================
-- Migration: Assistant IA — traitement des questions en arrière-plan
-- Description: Crée la file de travaux public.ai_jobs. Une question posée à
--              l'Assistant IA n'est plus traitée de façon synchrone (HTTP qui
--              attend la génération Ollama, source de timeouts) : elle est
--              enregistrée comme un « job » puis traitée par un worker en
--              arrière-plan. Le frontend interroge l'état du job (polling).
--
--              Coordination multi-process (gunicorn -w 4) : un seul job est
--              traité à la fois sur tout le cluster via un verrou consultatif
--              PostgreSQL (pg_advisory_lock), ce qui respecte la contrainte
--              « une seule génération Ollama à la fois ». Le claim d'un job se
--              fait via SELECT ... FOR UPDATE SKIP LOCKED.
-- Date: 2026-06-20
-- Idempotent: CREATE TABLE/INDEX IF NOT EXISTS
-- =====================================================

CREATE TABLE IF NOT EXISTS public.ai_jobs (
    id              BIGSERIAL PRIMARY KEY,
    utilisateur     VARCHAR(150),                       -- identité JWT du demandeur
    question        TEXT NOT NULL,                      -- question en langage naturel
    conversation_id INTEGER,                            -- conversation de rattachement (peut être NULL)
    statut          VARCHAR(20) NOT NULL DEFAULT 'en_attente',  -- en_attente | en_cours | termine | erreur
    resultat        JSONB,                              -- payload final (mêmes clés que /ask synchrone)
    id_log          INTEGER,                            -- lien vers public.ai_query_log (si succès)
    erreur          TEXT,                               -- message d'erreur technique (statut 'erreur')
    date_creation   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    date_debut      TIMESTAMP,                          -- prise en charge par le worker
    date_fin        TIMESTAMP                           -- fin de traitement
);

-- File d'attente : le worker récupère le plus ancien job 'en_attente'.
CREATE INDEX IF NOT EXISTS idx_ai_jobs_statut
    ON public.ai_jobs (statut, date_creation);

-- Reprise côté frontend : jobs récents d'un utilisateur.
CREATE INDEX IF NOT EXISTS idx_ai_jobs_user
    ON public.ai_jobs (utilisateur, date_creation DESC);
