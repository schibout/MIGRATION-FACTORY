-- =====================================================
-- 135 : clean_data.part_catalog_language (traductions anglaises des articles)
-- 2026-11-16. Structure reprise de la vue IFS PART_CATALOG_LANGUAGE
-- (public.ifs_view_column : PART_NO, LANGUAGE_CODE, DESCRIPTION, NOTE_ID).
-- Une ligne par article et par langue ; alimentee par
-- clean_data.alimenter_part_catalog_language() (sql/articleSap/), appelee
-- en fin de module Article SAP.
-- Idempotent.
-- =====================================================

BEGIN;

CREATE TABLE IF NOT EXISTS clean_data.part_catalog_language (
    part_no       varchar(25)  NOT NULL,
    language_code varchar(2)   NOT NULL,
    description   varchar(200),
    note_id       numeric(10,0),
    PRIMARY KEY (part_no, language_code)
);

INSERT INTO public.etl_export_queries (
    table_schema, table_name, display_name, column_list, description,
    category, is_active, created_by
)
VALUES (
    'clean_data',
    'part_catalog_language',
    'Catalogue des Articles - Traductions',
    'PART_NO,LANGUAGE_CODE,DESCRIPTION,NOTE_ID',
    'Désignations des articles en anglais (SAP makt, langue E)',
    'inventory',
    TRUE,
    'migration_135'
)
ON CONFLICT (table_name, category) DO UPDATE SET
    table_schema = EXCLUDED.table_schema,
    display_name = EXCLUDED.display_name,
    column_list  = EXCLUDED.column_list,
    description  = EXCLUDED.description,
    is_active    = EXCLUDED.is_active,
    updated_at   = CURRENT_TIMESTAMP,
    updated_by   = 'migration_135';

COMMIT;

-- ROLLBACK :
-- DELETE FROM public.etl_export_queries WHERE table_name = 'part_catalog_language';
-- DROP TABLE clean_data.part_catalog_language;
