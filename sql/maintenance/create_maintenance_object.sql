-- =====================================================================
-- clean_data.maintenance_object
-- Table UNIQUE de l'ecran IH02 (/maintenance/ih02).
-- Stocke sur une seule table, en liste d'adjacence typee :
--   FUNC_LOC   : postes techniques   (hierarchie via parent_id ; NULL = racine)
--   EQUIPMENT  : equipements         (parent_id = FL porteur ou equipement superieur)
--   ARTICLE    : article "maitre"    (1 seule ligne par matnr ; parent_id = NULL)
--   BOM_ITEM   : ligne de nomenclature
--                parent_id     = FL / EQUIPMENT / ARTICLE possesseur de la BOM
--                ref_object_id = ligne ARTICLE composant
--                quantity/unit = quantite du lien
--
-- Remplace les ecritures directes dans raw_data (iflot/iflotx/iflos/iflo,
-- itob/equi/eqkt/equz/iloa, mast/tpst/stko/stpo, mara/makt) par une table
-- applicative editable dans clean_data. raw_data redevient lecture seule.
--
-- Les attributs communs (affiches / filtres dans l'arbre) sont des colonnes ;
-- tous les autres champs SAP importants vont dans attributes (JSONB) pour ne
-- rien perdre sans creer 60 colonnes.
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;

DROP TABLE IF EXISTS clean_data.maintenance_object CASCADE;

CREATE TABLE clean_data.maintenance_object (
    id              BIGSERIAL PRIMARY KEY,
    object_type     TEXT NOT NULL
                    CHECK (object_type IN ('FUNC_LOC','EQUIPMENT','ARTICLE','BOM_ITEM')),

    -- Identite SAP d'origine (tracabilite / rechargement idempotent)
    sap_key         TEXT NOT NULL,   -- tplnr | equnr | matnr | stlty:stlnr:stlal:posnr[:stlkn]
    code            TEXT,            -- affichage : strno | equnr sans zeros | matnr sans zeros
    designation     TEXT,            -- pltxt F>E>any | eqktx | maktx F>E>any

    -- Hierarchie (adjacence) + reference article pour les BOM_ITEM
    parent_id       BIGINT REFERENCES clean_data.maintenance_object(id) ON DELETE CASCADE,
    ref_object_id   BIGINT REFERENCES clean_data.maintenance_object(id),
    sort_order      INTEGER,         -- posnr numerique pour les BOM_ITEM

    -- Attributs communs (colonnes car filtres / affiches dans l'arbre)
    type_code       TEXT,            -- fltyp | eqart | mtart
    category        TEXT,            -- tplkz | eqtyp | postp (item_category)
    work_center     TEXT,            -- arbpl resolu (iflo.ppsid->crhd | equz.gewrk->crhd)
    work_center_txt TEXT,            -- crtx.ktext
    cost_center     TEXT,            -- kostl
    plant           TEXT,            -- iwerk
    planner_group   TEXT,            -- ingrp
    quantity        NUMERIC(15, 3),  -- BOM_ITEM : stpo.menge
    unit            TEXT,            -- BOM_ITEM : stpo.meins

    -- Tout le reste des champs SAP importants, par type d'objet
    attributes      JSONB NOT NULL DEFAULT '{}'::jsonb,

    -- Cycle de vie / audit
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,   -- soft delete (suppression UI)
    source          TEXT    NOT NULL DEFAULT 'SAP',  -- 'SAP' (charge) | 'MANUAL' (cree via UI)
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      TEXT,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by      TEXT,

    CONSTRAINT uq_mo_type_key UNIQUE (object_type, sap_key),
    -- Un BOM_ITEM doit avoir un parent et un article reference
    CONSTRAINT ck_mo_bom CHECK (object_type <> 'BOM_ITEM'
                                OR (parent_id IS NOT NULL AND ref_object_id IS NOT NULL)),
    -- Un ARTICLE n'a pas de parent
    CONSTRAINT ck_mo_art CHECK (object_type <> 'ARTICLE' OR parent_id IS NULL),
    -- ref_object_id reserve aux BOM_ITEM
    CONSTRAINT ck_mo_ref CHECK (object_type = 'BOM_ITEM' OR ref_object_id IS NULL)
);

CREATE INDEX idx_mo_parent ON clean_data.maintenance_object (parent_id);
CREATE INDEX idx_mo_type   ON clean_data.maintenance_object (object_type);
CREATE INDEX idx_mo_ref    ON clean_data.maintenance_object (ref_object_id)
    WHERE ref_object_id IS NOT NULL;
CREATE INDEX idx_mo_code   ON clean_data.maintenance_object (code);
CREATE INDEX idx_mo_sapkey ON clean_data.maintenance_object (object_type, sap_key);

-- Recherche plein texte (equivalent des ILIKE actuels)
CREATE INDEX idx_mo_designation_trgm
    ON clean_data.maintenance_object USING gin (designation gin_trgm_ops);
CREATE INDEX idx_mo_code_trgm
    ON clean_data.maintenance_object USING gin (code gin_trgm_ops);

-- updated_at auto
CREATE OR REPLACE FUNCTION clean_data.mo_touch() RETURNS trigger AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_mo_touch ON clean_data.maintenance_object;
CREATE TRIGGER trg_mo_touch
    BEFORE UPDATE ON clean_data.maintenance_object
    FOR EACH ROW EXECUTE FUNCTION clean_data.mo_touch();

COMMENT ON TABLE clean_data.maintenance_object IS
'Table unique de l''ecran IH02 : postes techniques (FUNC_LOC), equipements
 (EQUIPMENT), articles (ARTICLE) et liens de nomenclature (BOM_ITEM) en liste
 d''adjacence typee (parent_id). Alimentee depuis raw_data par
 clean_data.load_maintenance_object(). attributes (JSONB) porte les champs SAP
 detailles par type d''objet.';

-- Expose la table a l'Assistant IA en lecture seule (optionnel / harmonise avec le projet)
-- GRANT SELECT ON clean_data.maintenance_object TO readonly_ai;
