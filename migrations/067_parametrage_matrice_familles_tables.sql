-- ============================================================================
-- 067 : parametrage de l'ecran Matrice Site x Famille
--
-- Deux tables de reference, editables depuis
-- Configuration > Parametres de la matrice :
--
--   1. public.etl_part_family         : les familles d'articles proposees en
--      colonnes de la matrice, avec leur libelle et leur description. Jusqu'ici
--      la liste etait deduite a la volee de raw_data.v_phl_article_retenu :
--      impossible de preparer une regle pour une famille pas encore livree,
--      et aucun moyen de documenter ce que "21" ou "RF" veulent dire.
--
--   2. public.etl_matrix_target_table : les tables cibles proposees dans le
--      selecteur. Sans elle l'ecran offrait les 56 tables de
--      public.etl_default_values, alors que la matrice ne concerne que les
--      tables articles.
--
-- NEUTRE A L'INSTALLATION : une table de reference VIDE fait retomber l'API
-- sur le comportement d'avant (familles lues dans les donnees, toutes les
-- tables cibles). L'ecran reste donc fonctionnel si la migration n'est jouee
-- qu'a moitie ou si les seeds sont supprimes.
--
-- Le libelle des COLONNES n'est pas stocke ici : il est lu a la volee dans
-- public.ifs_field_catalog (entity = table sans son schema, field_name =
-- colonne, tout en majuscules). Couverture verifiee le 2026-09-05 : 100 % des
-- colonnes des 5 tables articles ont une entree dans le catalogue.
--
-- Rollback en bas de fichier.
-- ============================================================================

BEGIN;

-- ===========================================================================
-- 1. FAMILLES D'ARTICLES
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.etl_part_family (
    id          SERIAL PRIMARY KEY,
    code        VARCHAR(50)  NOT NULL,   -- valeur brute de "FAMILLE" (21, RF...)
    libelle     VARCHAR(120),            -- nom court affiche sous le code
    description TEXT,                    -- explication longue (infobulle)
    ordre       INTEGER NOT NULL DEFAULT 100,
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by  VARCHAR(50),
    updated_by  VARCHAR(50)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_etl_part_family_code
    ON public.etl_part_family (code);

COMMENT ON TABLE public.etl_part_family IS
'Familles d''articles proposees en colonnes de la matrice Site x Famille. L''API affiche l''union de cette table et des familles reellement presentes dans raw_data.v_phl_article_retenu : une famille livree mais non declaree reste visible, et signalee comme telle.';
COMMENT ON COLUMN public.etl_part_family.code IS
'Code brut de la colonne "FAMILLE" du fichier PHL. C''est lui qui est stocke dans etl_default_value_matrix.part_family : le renommer ne se propage pas aux regles existantes.';
COMMENT ON COLUMN public.etl_part_family.ordre IS
'Ordre d''affichage des colonnes de la grille. A egalite, tri par code.';

-- ===========================================================================
-- 2. TABLES CIBLES
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.etl_matrix_target_table (
    id          SERIAL PRIMARY KEY,
    table_cible VARCHAR(100) NOT NULL,   -- ex. 'clean_data.sales_part'
    libelle     VARCHAR(120),
    description TEXT,
    ordre       INTEGER NOT NULL DEFAULT 100,
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by  VARCHAR(50),
    updated_by  VARCHAR(50)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_etl_matrix_target_table
    ON public.etl_matrix_target_table (table_cible);

COMMENT ON TABLE public.etl_matrix_target_table IS
'Tables cibles proposees dans le selecteur de la matrice. Desactiver une ligne retire la table du selecteur mais ne supprime AUCUNE regle deja saisie sur elle.';

-- --- updated_at automatique -------------------------------------------------
DROP TRIGGER IF EXISTS trg_etl_part_family_updated_at ON public.etl_part_family;
CREATE TRIGGER trg_etl_part_family_updated_at
    BEFORE UPDATE ON public.etl_part_family
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trg_etl_matrix_target_table_updated_at ON public.etl_matrix_target_table;
CREATE TRIGGER trg_etl_matrix_target_table_updated_at
    BEFORE UPDATE ON public.etl_matrix_target_table
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ===========================================================================
-- 3. SEED DES FAMILLES : celles reellement presentes dans le fichier PHL
--    Libelle et description volontairement vides : c'est a l'equipe metier de
--    les renseigner depuis l'ecran. Le garde-fou "famille non documentee" de
--    l'ecran s'appuie sur ce vide pour les signaler.
-- ===========================================================================
DO $seed_familles$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.views
        WHERE table_schema = 'raw_data' AND table_name = 'v_phl_article_retenu'
    ) THEN
        INSERT INTO public.etl_part_family (code, ordre, created_by)
        SELECT f.famille,
               row_number() OVER (ORDER BY f.famille) * 10,
               'migration_067'
        FROM (
            SELECT DISTINCT NULLIF(TRIM("FAMILLE"), '') AS famille
            FROM raw_data.v_phl_article_retenu
            WHERE NULLIF(TRIM("FAMILLE"), '') IS NOT NULL
        ) f
        WHERE NOT EXISTS (
            SELECT 1 FROM public.etl_part_family p WHERE p.code = f.famille
        );
    END IF;
END
$seed_familles$;

-- ===========================================================================
-- 4. SEED DES TABLES CIBLES : les 5 tables articles du module articlePhl
-- ===========================================================================
INSERT INTO public.etl_matrix_target_table (table_cible, libelle, description, ordre, created_by)
SELECT v.table_cible, v.libelle, v.description, v.ordre, 'migration_067'
FROM (VALUES
    ('clean_data.part_catalog',           'Article',            'Fiche article, commune a tous les sites',                     10),
    ('clean_data.inventory_part',         'Article par site',   'Declinaison de l''article sur un site (contract)',            20),
    ('clean_data.sales_part',             'Article vendu',      'Article declare vendable',                                    30),
    ('clean_data.purchase_part',          'Article achete',     'Article declare achetable',                                   40),
    ('clean_data.manuf_part_attribute',   'Article fabrique',   'Attributs de fabrication, dont la densite theorique',         50)
) AS v(table_cible, libelle, description, ordre)
WHERE NOT EXISTS (
    SELECT 1 FROM public.etl_matrix_target_table t WHERE t.table_cible = v.table_cible
);

COMMIT;

-- ===========================================================================
-- CONTROLES (a jouer apres la migration)
-- ===========================================================================
-- -- 1. Les familles du fichier PHL sont bien declarees :
-- SELECT code, libelle, ordre, is_active FROM public.etl_part_family ORDER BY ordre;
--
-- -- 2. Les 5 tables articles sont proposees :
-- SELECT table_cible, libelle, ordre FROM public.etl_matrix_target_table ORDER BY ordre;
--
-- -- 3. Le catalogue IFS couvre bien les colonnes (0 ligne attendue) :
-- SELECT e.table_cible, e.colonne
-- FROM (SELECT DISTINCT table_cible, colonne FROM public.etl_default_values) e
-- JOIN public.etl_matrix_target_table t ON t.table_cible = e.table_cible AND t.is_active
-- WHERE NOT EXISTS (
--     SELECT 1 FROM public.ifs_field_catalog f
--     WHERE f.entity = upper(split_part(e.table_cible, '.', 2))
--       AND f.field_name = upper(e.colonne)
-- );

-- ===========================================================================
-- ROLLBACK
-- ===========================================================================
-- BEGIN;
-- DROP TABLE IF EXISTS public.etl_part_family;
-- DROP TABLE IF EXISTS public.etl_matrix_target_table;
-- COMMIT;
-- Aucune procedure ETL ne lit ces deux tables : elles ne servent qu'a l'ecran.
-- Les regles de public.etl_default_value_matrix survivent au rollback.
