-- Vues IFS : dictionnaire IFS (FND_TAB_COMMENTS, FND_TAB_VIEW_COLUMNS) en complement
-- de l'export Oracle ALL_VIEWS (migrations 116/117). Rattache par nom de vue, chaque
-- fichier s'importe independamment depuis l'ecran Donnees IFS > Vues IFS. Rejouable.
BEGIN;

-- Commentaire IFS de la vue : 'LU=...^PROMPT=...^MODULE=...^TABLE=...^'
CREATE TABLE IF NOT EXISTS public.ifs_view_comment (
    view_name TEXT PRIMARY KEY,
    lu_name TEXT,
    prompt TEXT,
    module TEXT,
    base_table TEXT,
    attributes JSONB NOT NULL DEFAULT '{}'::jsonb,   -- toutes les cles du commentaire
    comments TEXT,
    imported_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Colonnes de la vue et colonne d'origine (Column Name) dans la table de l'entite
CREATE TABLE IF NOT EXISTS public.ifs_view_column (
    view_name TEXT NOT NULL,
    view_column_name TEXT NOT NULL,
    column_name TEXT,
    lu_name TEXT,
    position INTEGER NOT NULL,                        -- ordre du fichier
    imported_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (view_name, view_column_name)
);

-- Lecture de l'ecran : vue Oracle + dictionnaire IFS
CREATE OR REPLACE VIEW public.v_ifs_view_catalog AS
SELECT v.*, m.lu_name, m.prompt, m.module, m.base_table,
       m.attributes AS fnd_attributes,
       COALESCE(n.nb, 0) AS nb_colonnes_fnd
  FROM public.ifs_view_catalog v
  LEFT JOIN public.ifs_view_comment m ON m.view_name = v.view_name
  LEFT JOIN (SELECT view_name, count(*) AS nb FROM public.ifs_view_column GROUP BY view_name) n
         ON n.view_name = v.view_name;

COMMIT;
