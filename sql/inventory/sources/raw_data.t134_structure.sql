-- ============================================================================
-- Table t134
-- Schema: raw_data
-- Role dans le module INVENTORY: SOURCE (lecture seule)
-- ============================================================================

CREATE TABLE IF NOT EXISTS raw_data.t134 (
    id INTEGER NOT NULL,
    mandt TEXT,
    mtart TEXT,
    mtref TEXT,
    mbref TEXT,
    flref TEXT,
    numki TEXT,
    numke TEXT,
    envop TEXT,
    bsext TEXT,
    bsint TEXT,
    pstat TEXT,
    kkref TEXT,
    vprsv TEXT,
    kzvpr TEXT,
    vmtpo TEXT,
    ekalr TEXT,
    kzgrp TEXT,
    kzkfg TEXT,
    begru TEXT,
    kzprc TEXT,
    kzpip TEXT,
    prdru TEXT,
    aranz TEXT,
    wmakg TEXT,
    izust TEXT,
    ardel TEXT,
    kzmpn TEXT,
    mstae TEXT,
    cchis TEXT,
    ctype TEXT,
    class TEXT,
    chneu TEXT,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

-- Contraintes
ALTER TABLE raw_data.t134 ADD CONSTRAINT t134_pkey PRIMARY KEY (id);

-- Index
CREATE INDEX idx_t134_sap_keys ON raw_data.t134 USING btree (mandt, mtart);
CREATE UNIQUE INDEX t134_pkey ON raw_data.t134 USING btree (id);
