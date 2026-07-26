-- =====================================================================
-- public.ifs_field_catalog — référentiel central des specs IFS
-- Une ligne = un champ d'une entité IFS d'un lot de migration.
-- Alimenté par spec2catalog.py depuis les classeurs Lot*.xlsx.
-- C'est la SOURCE DE VÉRITÉ dont tout le reste est généré :
--   DDL clean_data, règles de gestion, seeds transco, configs d'écrans.
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.ifs_field_catalog (
    catalog_id            BIGINT GENERATED ALWAYS AS IDENTITY,
    lot_id                TEXT NOT NULL,          -- ex : LOT09
    entity                TEXT NOT NULL,          -- ex : PROJECT
    field_name            TEXT NOT NULL,          -- ex : MANAGER
    field_label_fr        TEXT,
    data_type             TEXT,                   -- VARCHAR2 / NUMBER / DATE (type IFS source)
    data_length           INTEGER,
    sql_type              TEXT,                   -- type PostgreSQL dérivé (conventions clean_data)
    mandatory             BOOLEAN,
    primary_key           BOOLEAN,
    insertable            BOOLEAN,
    updatable             BOOLEAN,
    lov                   BOOLEAN,
    default_value         TEXT,                   -- valeur par défaut IFS (ex : KAPEIFS, TRIM, *)
    reference             TEXT,                   -- LOV/référence IFS (ex : PersonInfo, CompanyFinance)
    enumeration_values    JSONB,                  -- [{db, client}] paires DB-value <==> Client-value
    rnd_flags             TEXT,                   -- flags IFS bruts (ex : AMIUL, K-I-L)
    in_scope              BOOLEAN,
    transformation_rules  TEXT,
    comments              TEXT,
    sort_order            INTEGER,
    source_file           TEXT,
    loaded_at             TIMESTAMP DEFAULT now(),
    CONSTRAINT uq_ifs_field_catalog UNIQUE (lot_id, entity, field_name)
);

COMMENT ON TABLE public.ifs_field_catalog IS
  'Dictionnaire de données IFS chargé depuis les classeurs de spec Lot*.xlsx. Source de vérité du générateur spec2catalog.';
