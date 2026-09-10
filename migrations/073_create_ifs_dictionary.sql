-- Catalogue technique Oracle/IFS issu de docs/ifs_Catalog/*.csv.
-- Distinct des spécifications par lot (ifs_field_catalog). Rejouable.
BEGIN;

CREATE TABLE IF NOT EXISTS public.ifs_table_catalog (
    table_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner TEXT NOT NULL,
    table_name TEXT NOT NULL,
    tablespace_name TEXT,
    status TEXT,
    num_rows BIGINT CHECK (num_rows >= 0),
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    imported_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (owner, table_name)
);

CREATE TABLE IF NOT EXISTS public.ifs_column_catalog (
    table_id BIGINT NOT NULL REFERENCES public.ifs_table_catalog(table_id),
    column_name TEXT NOT NULL,
    column_id INTEGER NOT NULL CHECK (column_id > 0),
    data_type TEXT NOT NULL,
    data_length INTEGER CHECK (data_length >= 0),
    data_precision INTEGER,
    data_scale INTEGER,
    nullable BOOLEAN NOT NULL,
    data_default TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    imported_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (table_id, column_name)
);

CREATE INDEX IF NOT EXISTS idx_ifs_column_catalog_order
    ON public.ifs_column_catalog (table_id, column_id);

COMMENT ON TABLE public.ifs_table_catalog IS
    'Métadonnées du catalogue Oracle/IFS importées depuis ifs_table_name.csv ; aucune donnée métier.';
COMMENT ON TABLE public.ifs_column_catalog IS
    'Colonnes Oracle/IFS importées depuis COLUMN_NAME.csv ; génération de rapports SQL sans exécution.';

COMMIT;
