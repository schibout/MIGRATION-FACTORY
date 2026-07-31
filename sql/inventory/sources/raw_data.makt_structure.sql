-- ============================================================================
-- Table makt
-- Schema: raw_data
-- Role dans le module INVENTORY: SOURCE (lecture seule)
-- ============================================================================

CREATE TABLE IF NOT EXISTS raw_data.makt (
    mandt VARCHAR(20) NOT NULL,
    matnr VARCHAR(20) NOT NULL,
    spras VARCHAR(20) NOT NULL,
    maktx VARCHAR(40),
    maktg VARCHAR(40),
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

-- Contraintes
ALTER TABLE raw_data.makt ADD CONSTRAINT makt_pkey PRIMARY KEY (mandt, matnr, spras);

-- Index
CREATE UNIQUE INDEX makt_pkey ON raw_data.makt USING btree (mandt, matnr, spras);
