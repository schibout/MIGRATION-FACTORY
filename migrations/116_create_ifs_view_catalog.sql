-- Catalogue des vues Oracle/IFS (export ALL_VIEWS, ex. backend/docs/VueIFS.xlsx).
-- Écran Données IFS > Vues IFS. Rejouable.
BEGIN;

CREATE TABLE IF NOT EXISTS public.ifs_view_catalog (
    view_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner TEXT NOT NULL,
    view_name TEXT NOT NULL,
    view_text TEXT,              -- colonne Text (LONG complet), à défaut Text Vc (tronqué à 4000)
    read_only BOOLEAN,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    imported_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (owner, view_name)
);

COMMENT ON TABLE public.ifs_view_catalog IS
    'Vues Oracle/IFS (ALL_VIEWS) importées depuis un classeur ; métadonnées seules, SQL jamais exécuté.';

COMMIT;
