-- =====================================================
-- Migration: Tables liees aux Etats d'avancement SharePoint
-- Description: 5 listes filles qui composent l'ecran "Etat d'avancement" :
--              - Phases (referentiel des phases)
--              - Jalons (referentiel P1..P6)
--              - Statut des jalons (1 ligne par etat x jalon)
--              - Statut des CFV (Commissions Feu Vert)
--              - Statut des couts (WBS)
-- Date: 2026-05-26
-- =====================================================

CREATE SCHEMA IF NOT EXISTS raw_data;

-- ----------------------------------------------------
-- Phases (referentiel - 3 items par site environ)
-- ----------------------------------------------------
CREATE TABLE IF NOT EXISTS raw_data.sharepoint_phases (
    id            SERIAL PRIMARY KEY,
    sharepoint_id INTEGER NOT NULL,
    site_id       TEXT    NOT NULL,
    title         TEXT,
    guid          UUID,
    created       TIMESTAMP,
    modified      TIMESTAMP,
    author_id     INTEGER,
    editor_id     INTEGER,
    imported_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    raw_data      JSONB,
    CONSTRAINT uq_sharepoint_phases UNIQUE (sharepoint_id, site_id)
);
CREATE INDEX IF NOT EXISTS idx_sharepoint_phases_site ON raw_data.sharepoint_phases(site_id);

COMMENT ON TABLE raw_data.sharepoint_phases IS
    'Referentiel des phases (ex: Initialisation, Execution, Cloture) par site SharePoint';

-- ----------------------------------------------------
-- Jalons (referentiel P1..P6 - 6 items par site)
-- ----------------------------------------------------
CREATE TABLE IF NOT EXISTS raw_data.sharepoint_jalons_ref (
    id            SERIAL PRIMARY KEY,
    sharepoint_id INTEGER NOT NULL,
    site_id       TEXT    NOT NULL,
    title         TEXT,
    guid          UUID,
    created       TIMESTAMP,
    modified      TIMESTAMP,
    author_id     INTEGER,
    editor_id     INTEGER,
    imported_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    raw_data      JSONB,
    CONSTRAINT uq_sharepoint_jalons_ref UNIQUE (sharepoint_id, site_id)
);
CREATE INDEX IF NOT EXISTS idx_sharepoint_jalons_ref_site ON raw_data.sharepoint_jalons_ref(site_id);

COMMENT ON TABLE raw_data.sharepoint_jalons_ref IS
    'Referentiel des jalons P1..P6 par site SharePoint';

-- ----------------------------------------------------
-- Statut des jalons (6 par etat d'avancement)
-- ----------------------------------------------------
CREATE TABLE IF NOT EXISTS raw_data.sharepoint_statut_jalons (
    id            SERIAL PRIMARY KEY,
    sharepoint_id INTEGER NOT NULL,
    site_id       TEXT    NOT NULL,
    title         TEXT,
    guid          UUID,
    created       TIMESTAMP,
    modified      TIMESTAMP,
    author_id     INTEGER,
    editor_id     INTEGER,
    imported_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    raw_data      JSONB,
    CONSTRAINT uq_sharepoint_statut_jalons UNIQUE (sharepoint_id, site_id)
);
CREATE INDEX IF NOT EXISTS idx_sharepoint_statut_jalons_site ON raw_data.sharepoint_statut_jalons(site_id);
-- Index GIN pour pouvoir requeter rapidement par les cles FK dans raw_data (ex: EtatAvancementId)
CREATE INDEX IF NOT EXISTS idx_sharepoint_statut_jalons_raw ON raw_data.sharepoint_statut_jalons USING GIN (raw_data);

COMMENT ON TABLE raw_data.sharepoint_statut_jalons IS
    'Statut de chaque jalon (Note, Classement, Date debut, Fin) pour un etat d''avancement donne';

-- ----------------------------------------------------
-- Statut des CFV (Commissions Feu Vert - 3 par etat)
-- ----------------------------------------------------
CREATE TABLE IF NOT EXISTS raw_data.sharepoint_statut_cfv (
    id            SERIAL PRIMARY KEY,
    sharepoint_id INTEGER NOT NULL,
    site_id       TEXT    NOT NULL,
    title         TEXT,
    guid          UUID,
    created       TIMESTAMP,
    modified      TIMESTAMP,
    author_id     INTEGER,
    editor_id     INTEGER,
    imported_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    raw_data      JSONB,
    CONSTRAINT uq_sharepoint_statut_cfv UNIQUE (sharepoint_id, site_id)
);
CREATE INDEX IF NOT EXISTS idx_sharepoint_statut_cfv_site ON raw_data.sharepoint_statut_cfv(site_id);
CREATE INDEX IF NOT EXISTS idx_sharepoint_statut_cfv_raw  ON raw_data.sharepoint_statut_cfv USING GIN (raw_data);

COMMENT ON TABLE raw_data.sharepoint_statut_cfv IS
    'Statut des Commissions Feu Vert (Conception, Mise en service, Achevement industriel)';

-- ----------------------------------------------------
-- Statut des couts (WBS - environ 2 par etat)
-- ----------------------------------------------------
CREATE TABLE IF NOT EXISTS raw_data.sharepoint_statut_couts (
    id            SERIAL PRIMARY KEY,
    sharepoint_id INTEGER NOT NULL,
    site_id       TEXT    NOT NULL,
    title         TEXT,
    guid          UUID,
    created       TIMESTAMP,
    modified      TIMESTAMP,
    author_id     INTEGER,
    editor_id     INTEGER,
    imported_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    raw_data      JSONB,
    CONSTRAINT uq_sharepoint_statut_couts UNIQUE (sharepoint_id, site_id)
);
CREATE INDEX IF NOT EXISTS idx_sharepoint_statut_couts_site ON raw_data.sharepoint_statut_couts(site_id);
CREATE INDEX IF NOT EXISTS idx_sharepoint_statut_couts_raw  ON raw_data.sharepoint_statut_couts USING GIN (raw_data);

COMMENT ON TABLE raw_data.sharepoint_statut_couts IS
    'Statut des couts par WBS (Budget, Engage, Receptionne, Reste a engager) pour un etat donne';

-- ----------------------------------------------------
-- Verification
-- ----------------------------------------------------
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'raw_data'
  AND table_name IN (
    'sharepoint_phases',
    'sharepoint_jalons_ref',
    'sharepoint_statut_jalons',
    'sharepoint_statut_cfv',
    'sharepoint_statut_couts'
  )
ORDER BY table_name;
