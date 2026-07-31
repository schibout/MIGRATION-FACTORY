-- ============================================================================
-- Table eina
-- Schema: raw_data
-- Role dans le module INVENTORY: SOURCE (lecture seule)
-- ============================================================================

CREATE TABLE IF NOT EXISTS raw_data.eina (
    mandt VARCHAR(20) NOT NULL,
    infnr VARCHAR(20) NOT NULL,
    matnr VARCHAR(20),
    matkl VARCHAR(20),
    lifnr VARCHAR(20),
    loekz VARCHAR(20),
    erdat VARCHAR(20),
    ernam VARCHAR(20),
    txz01 VARCHAR(40),
    sortl VARCHAR(20),
    meins VARCHAR(20),
    umrez VARCHAR(20),
    umren VARCHAR(20),
    idnlf VARCHAR(35),
    verkf VARCHAR(30),
    telf1 VARCHAR(20),
    mahn1 VARCHAR(20),
    mahn2 VARCHAR(20),
    mahn3 VARCHAR(20),
    urznr VARCHAR(20),
    urzdt VARCHAR(20),
    urzla VARCHAR(20),
    urztp VARCHAR(20),
    urzzt VARCHAR(20),
    lmein VARCHAR(20),
    regio VARCHAR(20),
    vabme VARCHAR(20),
    ltsnr VARCHAR(20),
    ltssf VARCHAR(20),
    wglif VARCHAR(20),
    rueck VARCHAR(20),
    lifab VARCHAR(20),
    lifbi VARCHAR(20),
    kolif VARCHAR(20),
    anzpu VARCHAR(20),
    punei VARCHAR(20),
    relif VARCHAR(20),
    mfrnr VARCHAR(20),
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

-- Contraintes
ALTER TABLE raw_data.eina ADD CONSTRAINT eina_pkey PRIMARY KEY (mandt, infnr);

-- Index
CREATE UNIQUE INDEX eina_pkey ON raw_data.eina USING btree (mandt, infnr);
