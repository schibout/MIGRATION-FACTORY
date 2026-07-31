-- ============================================================================
-- Table t023t
-- Schema: raw_data
-- Role dans le module INVENTORY: SOURCE (lecture seule)
-- ============================================================================

CREATE TABLE IF NOT EXISTS raw_data.t023t (
    mandt VARCHAR(20) NOT NULL,
    spras VARCHAR(20) NOT NULL,
    matkl VARCHAR(20) NOT NULL,
    wgbez VARCHAR(20),
    wgbez60 VARCHAR(60),
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

-- Contraintes
ALTER TABLE raw_data.t023t ADD CONSTRAINT t023t_pkey PRIMARY KEY (mandt, spras, matkl);

-- Index
CREATE UNIQUE INDEX t023t_pkey ON raw_data.t023t USING btree (mandt, spras, matkl);
