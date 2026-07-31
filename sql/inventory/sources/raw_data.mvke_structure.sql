-- ============================================================================
-- Table mvke
-- Schema: raw_data
-- Role dans le module INVENTORY: SOURCE (lecture seule)
-- ============================================================================

CREATE TABLE IF NOT EXISTS raw_data.mvke (
    mandt VARCHAR(20) NOT NULL,
    matnr VARCHAR(20) NOT NULL,
    vkorg VARCHAR(20) NOT NULL,
    vtweg VARCHAR(20) NOT NULL,
    lvorm VARCHAR(20),
    versg VARCHAR(20),
    bonus VARCHAR(20),
    provg VARCHAR(20),
    sktof VARCHAR(20),
    vmsta VARCHAR(20),
    vmstd VARCHAR(20),
    aumng VARCHAR(20),
    lfmng VARCHAR(20),
    efmng VARCHAR(20),
    scmng VARCHAR(20),
    schme VARCHAR(20),
    vrkme VARCHAR(20),
    mtpos VARCHAR(20),
    dwerk VARCHAR(20),
    prodh VARCHAR(20),
    pmatn VARCHAR(20),
    kondm VARCHAR(20),
    ktgrm VARCHAR(20),
    mvgr1 VARCHAR(20),
    mvgr2 VARCHAR(20),
    mvgr3 VARCHAR(20),
    mvgr4 VARCHAR(20),
    mvgr5 VARCHAR(20),
    sstuf VARCHAR(20),
    pflks VARCHAR(20),
    lstfl VARCHAR(20),
    lstvz VARCHAR(20),
    lstak VARCHAR(20),
    ldvfl VARCHAR(20),
    ldbfl VARCHAR(20),
    ldvzl VARCHAR(20),
    ldbzl VARCHAR(20),
    vdvfl VARCHAR(20),
    vdbfl VARCHAR(20),
    vdvzl VARCHAR(20),
    vdbzl VARCHAR(20),
    prat1 VARCHAR(20),
    prat2 VARCHAR(20),
    prat3 VARCHAR(20),
    prat4 VARCHAR(20),
    prat5 VARCHAR(20),
    prat6 VARCHAR(20),
    prat7 VARCHAR(20),
    prat8 VARCHAR(20),
    prat9 VARCHAR(20),
    prata VARCHAR(20),
    rdprf VARCHAR(20),
    megru VARCHAR(20),
    lfmax VARCHAR(20),
    rjart VARCHAR(20),
    pbind VARCHAR(20),
    vavme VARCHAR(20),
    matkc VARCHAR(20),
    pvmso VARCHAR(20),
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

-- Contraintes
ALTER TABLE raw_data.mvke ADD CONSTRAINT mvke_pkey PRIMARY KEY (mandt, matnr, vkorg, vtweg);

-- Index
CREATE UNIQUE INDEX mvke_pkey ON raw_data.mvke USING btree (mandt, matnr, vkorg, vtweg);
