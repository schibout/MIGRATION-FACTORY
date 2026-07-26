-- =====================================================
-- Migration: Assistant IA — recherche sémantique vectorielle (pgvector)
-- Description: Active l'extension pgvector et crée le socle de la recherche
--              sémantique de l'Assistant IA :
--                1. public.ai_embeddings : index vectoriel des tables (dictionnaire
--                   SAP) et des exemples few-shot, pour la sélection RAG sémantique.
--                2. Colonne public.ai_query_log.embedding : vecteur de la question,
--                   support du CACHE SÉMANTIQUE (réutiliser le SQL d'une question
--                   passée très proche, sans rappeler le modèle Ollama).
--              Modèle d'embeddings : bge-m3 (1024 dimensions), servi localement
--              par Ollama (/api/embeddings). Distance cosinus + index HNSW.
-- Date: 2026-06-13
-- Idempotent: CREATE EXTENSION/TABLE/INDEX IF NOT EXISTS + ADD COLUMN IF NOT EXISTS
--
-- ⚠️  Prérequis : l'extension pgvector doit être installée sur le serveur
--     PostgreSQL (paquet `postgresql-NN-pgvector`). CREATE EXTENSION nécessite
--     un rôle superutilisateur (ex. postgres).
-- =====================================================

-- ----------------------------------------------------
-- 0. Extension vectorielle
-- ----------------------------------------------------
CREATE EXTENSION IF NOT EXISTS vector;

-- ----------------------------------------------------
-- 1. Index vectoriel : tables (dictionnaire) + exemples few-shot
-- ----------------------------------------------------
-- kind   : 'table'   -> ref_id = nom schéma-qualifié (ex. 'raw_data.lfa1')
--          'example' -> ref_id = identifiant de l'exemple (ex. 'ex_0007')
-- content: texte source ayant servi à produire le vecteur (traçabilité / ré-indexation)
CREATE TABLE IF NOT EXISTS public.ai_embeddings (
    id            BIGSERIAL PRIMARY KEY,
    kind          VARCHAR(20) NOT NULL,            -- 'table' | 'example'
    ref_id        VARCHAR(200) NOT NULL,           -- identifiant logique de la source
    content       TEXT,                            -- texte source (description FR / question)
    embedding     vector(1024) NOT NULL,           -- bge-m3 = 1024 dimensions
    date_creation TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ai_embeddings_kind_ref UNIQUE (kind, ref_id)
);

COMMENT ON TABLE public.ai_embeddings IS
    'Index vectoriel (pgvector/bge-m3) des tables du dictionnaire SAP et des exemples few-shot, pour la sélection RAG sémantique de l''Assistant IA.';

-- Index HNSW (distance cosinus) pour une recherche ANN rapide.
-- HNSW se construit même sur une table vide ; les insertions suivantes l'alimentent.
CREATE INDEX IF NOT EXISTS idx_ai_embeddings_hnsw
    ON public.ai_embeddings USING hnsw (embedding vector_cosine_ops);

-- Filtrage fréquent par type d'entrée (tables vs exemples).
CREATE INDEX IF NOT EXISTS idx_ai_embeddings_kind
    ON public.ai_embeddings (kind);

-- ----------------------------------------------------
-- 2. Cache sémantique : vecteur de la question dans le journal
-- ----------------------------------------------------
-- On réutilise public.ai_query_log (déjà alimenté à chaque question). Le vecteur
-- de la question permet de retrouver une question passée à succès sémantiquement
-- proche et de réutiliser son SQL sans rappeler Ollama.
ALTER TABLE public.ai_query_log
    ADD COLUMN IF NOT EXISTS embedding vector(1024);

-- Index HNSW partiel : seules les requêtes RÉUSSIES alimentent le cache.
CREATE INDEX IF NOT EXISTS idx_ai_query_log_embedding_hnsw
    ON public.ai_query_log USING hnsw (embedding vector_cosine_ops)
    WHERE embedding IS NOT NULL AND statut = 'succes';

-- ----------------------------------------------------
-- 3. Confirmation
-- ----------------------------------------------------
DO $$
DECLARE v_emb INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_emb FROM public.ai_embeddings;
    RAISE NOTICE 'pgvector prêt : % vecteur(s) indexé(s) dans ai_embeddings.', v_emb;
    RAISE NOTICE 'Colonne ai_query_log.embedding prête (cache sémantique).';
    RAISE NOTICE 'Pensez à exécuter : python backend/build_ai_index.py';
END $$;
