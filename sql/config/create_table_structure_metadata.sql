-- Table pour stocker les métadonnées de structure de tables
CREATE TABLE IF NOT EXISTS public.table_structure_metadata (
    id SERIAL PRIMARY KEY,
    job_name VARCHAR(50),
    table_name VARCHAR(255) NOT NULL,
    column_name VARCHAR(255) NOT NULL,
    description TEXT,
    flags VARCHAR(10),
    data_type VARCHAR(50),
    length INTEGER,
    decimal_length INTEGER,
    default_value TEXT,
    change_defaults BOOLEAN DEFAULT FALSE,
    is_key BOOLEAN DEFAULT FALSE,
    is_mandatory BOOLEAN DEFAULT FALSE,
    is_updatable BOOLEAN DEFAULT FALSE,
    is_insertable BOOLEAN DEFAULT FALSE,
    amount_denominator VARCHAR(50),
    default_where VARCHAR(255),
    pad_char_right VARCHAR(10),
    pad_char_left VARCHAR(10),
    attr_seq INTEGER,
    note_text TEXT,
    conversion_list TEXT,
    ext_attr TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    imported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    imported_by VARCHAR(255),
    source_file VARCHAR(500),
    UNIQUE(table_name, column_name, job_name)
);

-- Index pour recherche rapide
CREATE INDEX IF NOT EXISTS idx_table_structure_table_name ON public.table_structure_metadata(table_name);
CREATE INDEX IF NOT EXISTS idx_table_structure_job_name ON public.table_structure_metadata(job_name);
CREATE INDEX IF NOT EXISTS idx_table_structure_flags ON public.table_structure_metadata(flags);

COMMENT ON TABLE public.table_structure_metadata IS 'Métadonnées des structures de tables importées depuis Excel';
COMMENT ON COLUMN public.table_structure_metadata.job_name IS 'Nom du job/projet';
COMMENT ON COLUMN public.table_structure_metadata.table_name IS 'Nom de la table';
COMMENT ON COLUMN public.table_structure_metadata.column_name IS 'Nom de la colonne';
COMMENT ON COLUMN public.table_structure_metadata.flags IS 'Flags: K=Key, U=Updatable, I=Insertable, M=Mandatory';
COMMENT ON COLUMN public.table_structure_metadata.is_key IS 'Colonne clé primaire (extrait du flag K)';
COMMENT ON COLUMN public.table_structure_metadata.is_mandatory IS 'Colonne obligatoire (extrait du flag M)';
COMMENT ON COLUMN public.table_structure_metadata.is_updatable IS 'Colonne modifiable (extrait du flag U)';
COMMENT ON COLUMN public.table_structure_metadata.is_insertable IS 'Colonne insertable (extrait du flag I)';

