-- =====================================================
-- Migration: Assistant IA — rôle lecture seule + journal des requêtes
-- Description: Crée le rôle PostgreSQL `readonly_ai` (SELECT uniquement
--              sur raw_data et clean_data) utilisé par l'Assistant IA pour
--              exécuter le SQL généré par le modèle local (Ollama), ainsi
--              que la table de journalisation public.ai_query_log.
-- Date: 2026-06-11
-- Idempotent: DO blocks + CREATE IF NOT EXISTS
--
-- ⚠️  Avant d'exécuter : remplacer 'CHANGE_ME' par le mot de passe réel
--     (doit correspondre à AI_DB_PASSWORD du fichier .env).
-- =====================================================

-- ----------------------------------------------------
-- 1. Rôle de connexion en lecture seule
-- ----------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'readonly_ai') THEN
        CREATE ROLE readonly_ai LOGIN PASSWORD 'readonly_ai_2026_trimet';
        RAISE NOTICE 'Rôle readonly_ai créé.';
    ELSE
        RAISE NOTICE 'Rôle readonly_ai déjà présent (mot de passe inchangé).';
    END IF;
END $$;

-- Droits : USAGE sur les schémas SAP + transformés, SELECT sur leurs tables.
-- Aucun droit sur le schéma public (les logs sont écrits par le rôle applicatif).
GRANT USAGE ON SCHEMA raw_data, clean_data TO readonly_ai;
GRANT SELECT ON ALL TABLES IN SCHEMA raw_data, clean_data TO readonly_ai;

-- Les tables créées plus tard dans ces schémas seront aussi accessibles en SELECT.
ALTER DEFAULT PRIVILEGES IN SCHEMA raw_data  GRANT SELECT ON TABLES TO readonly_ai;
ALTER DEFAULT PRIVILEGES IN SCHEMA clean_data GRANT SELECT ON TABLES TO readonly_ai;

-- Révoquer explicitement tout accès au schéma public (défense en profondeur).
REVOKE ALL ON SCHEMA public FROM readonly_ai;

-- Garde-fous au niveau du rôle : timeout serveur + limite de connexions.
ALTER ROLE readonly_ai SET statement_timeout = '30s';
ALTER ROLE readonly_ai CONNECTION LIMIT 3;

-- ----------------------------------------------------
-- 2. Journal des requêtes de l'Assistant IA
-- ----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ai_query_log (
    id            SERIAL PRIMARY KEY,
    utilisateur   VARCHAR(150),                       -- identité issue du JWT
    question      TEXT,                               -- question en langage naturel
    sql_genere    TEXT,                               -- SQL produit (ou SQL du template)
    statut        VARCHAR(10) NOT NULL DEFAULT 'succes', -- succes | erreur | rejete
    raison_rejet  TEXT,                               -- motif si statut = rejete/erreur
    template_id   VARCHAR(80),                        -- non NULL si analyse pré-définie
    duree_ms      INTEGER,                            -- durée totale de traitement
    nb_lignes     INTEGER,                            -- nombre de lignes retournées
    date_creation TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ai_query_log_date
    ON public.ai_query_log (date_creation DESC);
CREATE INDEX IF NOT EXISTS idx_ai_query_log_utilisateur
    ON public.ai_query_log (utilisateur);

COMMENT ON TABLE  public.ai_query_log              IS 'Journal des questions posées à l''Assistant IA (succès, erreurs, rejets)';
COMMENT ON COLUMN public.ai_query_log.statut       IS 'succes | erreur | rejete';
COMMENT ON COLUMN public.ai_query_log.raison_rejet IS 'Motif de rejet (sql_guard) ou message d''erreur';
COMMENT ON COLUMN public.ai_query_log.template_id  IS 'Identifiant de l''analyse pré-définie si exécutée sans IA';

-- ----------------------------------------------------
-- 3. Confirmation
-- ----------------------------------------------------
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM public.ai_query_log;
    RAISE NOTICE 'Table public.ai_query_log prête (% ligne(s)).', v_count;
END $$;
