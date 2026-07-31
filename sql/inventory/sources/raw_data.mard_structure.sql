-- ============================================================================
-- Table mard
-- Schema: raw_data
-- Role dans le module INVENTORY: SOURCE (lecture seule)
-- ============================================================================

CREATE TABLE IF NOT EXISTS raw_data.mard (
    mandt VARCHAR(20) NOT NULL,
    matnr VARCHAR(20) NOT NULL,
    werks VARCHAR(20) NOT NULL,
    lgort VARCHAR(20) NOT NULL,
    pstat VARCHAR(20),
    lvorm VARCHAR(20),
    lfgja VARCHAR(20),
    lfmon VARCHAR(20),
    sperr VARCHAR(20),
    labst VARCHAR(20),
    umlme VARCHAR(20),
    insme VARCHAR(20),
    einme VARCHAR(20),
    speme VARCHAR(20),
    retme VARCHAR(20),
    vmlab VARCHAR(20),
    vmuml VARCHAR(20),
    vmins VARCHAR(20),
    vmein VARCHAR(20),
    vmspe VARCHAR(20),
    vmret VARCHAR(20),
    kzill VARCHAR(20),
    kzilq VARCHAR(20),
    kzile VARCHAR(20),
    kzils VARCHAR(20),
    kzvll VARCHAR(20),
    kzvlq VARCHAR(20),
    kzvle VARCHAR(20),
    kzvls VARCHAR(20),
    diskz VARCHAR(20),
    lsobs VARCHAR(20),
    lminb VARCHAR(20),
    lbstf VARCHAR(20),
    herkl VARCHAR(20),
    exppg VARCHAR(20),
    exver VARCHAR(20),
    lgpbe VARCHAR(20),
    klabs VARCHAR(20),
    kinsm VARCHAR(20),
    keinm VARCHAR(20),
    kspem VARCHAR(20),
    dlinl VARCHAR(20),
    prctl VARCHAR(20),
    ersda VARCHAR(20),
    vklab VARCHAR(20),
    vkuml VARCHAR(20),
    lwmkb VARCHAR(20),
    bskrf VARCHAR(20),
    mdrue VARCHAR(20),
    mdjin VARCHAR(20),
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

-- Contraintes
ALTER TABLE raw_data.mard ADD CONSTRAINT mard_pkey PRIMARY KEY (mandt, matnr, werks, lgort);

-- Index
CREATE UNIQUE INDEX mard_pkey ON raw_data.mard USING btree (mandt, matnr, werks, lgort);
