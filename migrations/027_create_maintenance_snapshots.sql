-- =====================================================
-- Migration: Snapshots / restauration / rechargement SAP du module Maintenance
-- Description: Permet aux utilisateurs d'enregistrer un etat nomme de leurs
--              modifications (hierarchie IH02 + equipements + articles), de le
--              restaurer, et de recharger depuis SAP (fusion ou reset) sans
--              perdre leur travail.
--
--   * schema "snapshots"            : accueille les copies de tables
--                                     (snapshots.s<id>_<table>, creees a la volee)
--   * public.maintenance_snapshots  : metadonnees d'un etat sauvegarde
--   * public.maintenance_jobs       : suivi des operations longues
--                                     (SNAPSHOT / RESTORE / RELOAD)
--   * FK de clean_data.maintenance_object rendues DEFERRABLE : indispensable
--     pour reinserer une copie complete en un seul INSERT...SELECT en
--     conservant les id (parent_id / ref_object_id sont des id internes).
--
-- Date: 2026-07-27
-- Idempotent: CREATE ... IF NOT EXISTS + DO block sur les contraintes.
-- =====================================================

-- -----------------------------------------------------
-- 1. Schema d'accueil des copies de donnees
-- -----------------------------------------------------
CREATE SCHEMA IF NOT EXISTS snapshots;

COMMENT ON SCHEMA snapshots IS
    'Copies de tables du module Maintenance (etats sauvegardes). Une table
     snapshots.s<snapshot_id>_<table> par table snapshotee, creee/supprimee
     par backend/services/maintenance_snapshot_service.py.';

-- -----------------------------------------------------
-- 2. Metadonnees des etats sauvegardes
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.maintenance_snapshots (
    id             BIGSERIAL PRIMARY KEY,
    name           TEXT NOT NULL,
    description    TEXT,
    -- MANUAL           : cree explicitement par l'utilisateur
    -- AUTO_PRE_RESTORE : filet de securite pris avant une restauration
    -- AUTO_PRE_RELOAD  : filet de securite pris avant un rechargement SAP
    kind           TEXT NOT NULL DEFAULT 'MANUAL'
                   CHECK (kind IN ('MANUAL', 'AUTO_PRE_RESTORE', 'AUTO_PRE_RELOAD')),
    status         TEXT NOT NULL DEFAULT 'CREATING'
                   CHECK (status IN ('CREATING', 'READY', 'FAILED')),
    -- {"clean_data.maintenance_object": 96551, "raw_data.iflot": 11039, ...}
    tables         JSONB NOT NULL DEFAULT '{}'::jsonb,
    total_rows     BIGINT NOT NULL DEFAULT 0,
    size_bytes     BIGINT,
    created_by     TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    error_message  TEXT
);

CREATE INDEX IF NOT EXISTS idx_maintenance_snapshots_created
    ON public.maintenance_snapshots (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_maintenance_snapshots_kind
    ON public.maintenance_snapshots (kind, created_at DESC);

COMMENT ON TABLE public.maintenance_snapshots IS
    'Etats sauvegardes du module Maintenance. Les donnees elles-memes vivent
     dans le schema "snapshots" (tables snapshots.s<id>_<table>).';

-- -----------------------------------------------------
-- 3. Suivi des operations longues (restauration / rechargement)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.maintenance_jobs (
    id             BIGSERIAL PRIMARY KEY,
    job_type       TEXT NOT NULL
                   CHECK (job_type IN ('SNAPSHOT', 'RESTORE', 'RELOAD')),
    -- RELOAD  : {"mode": "merge"|"reset", "with_extraction": true|false}
    -- RESTORE : {"snapshot_id": 12}
    params         JSONB NOT NULL DEFAULT '{}'::jsonb,
    status         TEXT NOT NULL DEFAULT 'PENDING'
                   CHECK (status IN ('PENDING', 'RUNNING', 'DONE', 'ERROR')),
    current_step   TEXT,
    progress       INTEGER NOT NULL DEFAULT 0
                   CHECK (progress BETWEEN 0 AND 100),
    -- Journal d'execution : [{"step": "...", "status": "...", "ts": "...", "detail": "..."}]
    steps          JSONB NOT NULL DEFAULT '[]'::jsonb,
    -- Snapshot de securite pris automatiquement au demarrage du job
    snapshot_id    BIGINT REFERENCES public.maintenance_snapshots(id) ON DELETE SET NULL,
    created_by     TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    started_at     TIMESTAMPTZ,
    finished_at    TIMESTAMPTZ,
    error_message  TEXT
);

CREATE INDEX IF NOT EXISTS idx_maintenance_jobs_created
    ON public.maintenance_jobs (created_at DESC);

-- Garde-fou fort : au plus UN job maintenance actif sur tout le cluster.
-- (les 4 workers gunicorn ne peuvent donc pas en lancer plusieurs en parallele)
CREATE UNIQUE INDEX IF NOT EXISTS uq_maintenance_jobs_one_active
    ON public.maintenance_jobs ((TRUE))
    WHERE status IN ('PENDING', 'RUNNING');

COMMENT ON TABLE public.maintenance_jobs IS
    'Suivi des operations longues du module Maintenance (snapshot, restauration,
     rechargement SAP). Etat persiste en base — et non en memoire — pour rester
     lisible depuis les 4 workers gunicorn. Un seul job actif a la fois
     (index unique partiel uq_maintenance_jobs_one_active).';

-- -----------------------------------------------------
-- 4. FK de maintenance_object rendues DEFERRABLE
--    Restaurer = DELETE + INSERT...SELECT en conservant les id ; sans FK
--    deferrable, l'ordre d'insertion des parents/enfants ferait echouer
--    l'INSERT (parent_id et ref_object_id pointent vers la table elle-meme).
--    On conserve la definition d'origine (dont ON DELETE CASCADE).
-- -----------------------------------------------------
DO $$
DECLARE
    v_con RECORD;
BEGIN
    IF to_regclass('clean_data.maintenance_object') IS NULL THEN
        RAISE NOTICE 'clean_data.maintenance_object absente : etape ignoree '
                     '(jouer sql/maintenance/create_maintenance_object.sql avant).';
        RETURN;
    END IF;

    FOR v_con IN
        SELECT c.conname, pg_get_constraintdef(c.oid) AS def
        FROM pg_constraint c
        JOIN pg_class t     ON t.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = t.relnamespace
        WHERE n.nspname = 'clean_data'
          AND t.relname = 'maintenance_object'
          AND c.contype = 'f'
          AND NOT c.condeferrable
    LOOP
        EXECUTE format('ALTER TABLE clean_data.maintenance_object DROP CONSTRAINT %I',
                       v_con.conname);
        EXECUTE format('ALTER TABLE clean_data.maintenance_object '
                       'ADD CONSTRAINT %I %s DEFERRABLE INITIALLY IMMEDIATE',
                       v_con.conname, v_con.def);
        RAISE NOTICE 'Contrainte % rendue DEFERRABLE.', v_con.conname;
    END LOOP;
END $$;

-- =====================================================
-- Verifications
--   SELECT * FROM public.maintenance_snapshots ORDER BY created_at DESC;
--   SELECT id, job_type, status, current_step, progress FROM public.maintenance_jobs
--     ORDER BY created_at DESC LIMIT 10;
--   SELECT conname, condeferrable FROM pg_constraint
--     WHERE conrelid = 'clean_data.maintenance_object'::regclass AND contype = 'f';
-- =====================================================
