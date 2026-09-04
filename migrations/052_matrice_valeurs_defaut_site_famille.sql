-- ============================================================================
-- 052 : matrice conditionnelle Site x Famille
--       (valeurs par defaut + routage de creation des tables article)
--
-- Voir docs/matrice valeur defaut.md et docs/README_MATRICE_VALEURS_DEFAUT.md
--
-- Deux volets, meme cle de resolution (contract, part_family) et meme regle de
-- priorite (le plus specifique gagne) :
--
--   1. public.etl_default_value_matrix  : la valeur par defaut d'une colonne
--      depend du site et de la famille d'article. Se place AU-DESSUS de
--      public.etl_default_values (migration 031), qui reste le repli constant.
--
--   2. public.etl_part_type_matrix      : quelles tables creer pour un article
--      (sales_part / purchase_part / manuf_part_attribute) selon son site et
--      sa famille. Un article peut cumuler plusieurs creations.
--
-- NEUTRE A L'INSTALLATION :
--   * etl_default_value_matrix vide  -> get_default_value_ctx() retombe sur
--     get_default_value() : valeur identique a aujourd'hui.
--   * etl_part_type_matrix seedee a should_create = TRUE (jokers) -> aucun
--     article n'est ecarte : chargements identiques a aujourd'hui.
--
-- Sources de la cle (cf. sql/articlePhl/) :
--   * contract    = parametre p_contract des procedures alimenter_*_phl (SJ|CS)
--   * part_family = TRIM(phl."FAMILLE") de raw_data.v_phl_article_retenu
--                   (valeurs en base le 2026-09-04 : 21, 22, 23, RF ;
--                    la famille 19 est exclue par la vue)
--
-- APRES CETTE MIGRATION : recompiler le module articlePhl
--   sql/articlePhl/compile.sh   (procedures alimenter_*_phl modifiees)
--
-- Rollback en bas de fichier.
-- ============================================================================

BEGIN;

-- ===========================================================================
-- 1. VOLET "VALEUR PAR DEFAUT" : public.etl_default_value_matrix
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.etl_default_value_matrix (
    id            SERIAL PRIMARY KEY,
    module        VARCHAR(50)  NOT NULL DEFAULT 'articlePhl',
    table_cible   VARCHAR(100) NOT NULL,   -- ex. 'clean_data.manuf_part_attribute'
    colonne       VARCHAR(100) NOT NULL,   -- ex. 'density'
    contract      VARCHAR(10),             -- site IFS ; NULL = joker (tous les sites)
    part_family   VARCHAR(50),             -- famille article ; NULL = joker
    variante      VARCHAR(30)  NOT NULL DEFAULT 'STANDARD',
    type_valeur   VARCHAR(20)  NOT NULL CHECK (type_valeur IN ('CONSTANTE','NULL')),
    valeur        TEXT,
    description   TEXT,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by    VARCHAR(50),
    updated_by    VARCHAR(50)
);

-- UNIQUE sur la cle naturelle. Une contrainte UNIQUE ordinaire ne suffirait PAS :
-- contract et part_family sont NULLables et PostgreSQL considere deux NULL comme
-- distincts -> plusieurs lignes joker identiques passeraient. D'ou le COALESCE.
CREATE UNIQUE INDEX IF NOT EXISTS uq_etl_default_value_matrix
    ON public.etl_default_value_matrix
       (table_cible, colonne, variante, COALESCE(contract, '*'), COALESCE(part_family, '*'));

CREATE INDEX IF NOT EXISTS idx_edvm_lookup
    ON public.etl_default_value_matrix (table_cible, colonne, variante);

COMMENT ON TABLE public.etl_default_value_matrix IS
'Valeur par defaut ETL dependant du site et de la famille d''article. Resolue par public.get_default_value_ctx(), qui retombe sur public.etl_default_values si aucune ligne ne correspond. Editee depuis Configuration > Matrice Site x Famille.';
COMMENT ON COLUMN public.etl_default_value_matrix.contract IS
'Site IFS (SJ, CS...). NULL = joker : s''applique a tous les sites.';
COMMENT ON COLUMN public.etl_default_value_matrix.part_family IS
'Famille article (colonne "FAMILLE" du fichier PHL). NULL = joker : s''applique a toutes les familles.';

-- ===========================================================================
-- 2. VOLET "ROUTAGE DE CREATION" : public.etl_part_type_matrix
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.etl_part_type_matrix (
    id            SERIAL PRIMARY KEY,
    target_table  VARCHAR(100) NOT NULL,   -- ex. 'clean_data.sales_part'
    contract      VARCHAR(10),             -- site ; NULL = joker
    part_family   VARCHAR(50),             -- famille ; NULL = joker
    should_create BOOLEAN NOT NULL,
    description   TEXT,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by    VARCHAR(50),
    updated_by    VARCHAR(50)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_etl_part_type_matrix
    ON public.etl_part_type_matrix
       (target_table, COALESCE(contract, '*'), COALESCE(part_family, '*'));

CREATE INDEX IF NOT EXISTS idx_eptm_lookup
    ON public.etl_part_type_matrix (target_table);

COMMENT ON TABLE public.etl_part_type_matrix IS
'Routage de creation des tables article (sales_part / purchase_part / manuf_part_attribute) par site x famille. Resolu par public.get_part_type_matrix(). Absence de ligne = creation autorisee (COALESCE(..., TRUE) cote loader).';

-- ===========================================================================
-- 3. FONCTIONS DE RESOLUTION
-- ===========================================================================

-- --- 3.1 Priorite : (site+famille) > site seul > famille seule > joker ------
-- Retourne la valeur de la ligne matrice la plus specifique, NULL si aucune.
-- Attention : NULL est ambigu ici (pas de ligne / ligne de type NULL) -> pour
-- l'ETL, utiliser get_default_value_ctx() qui, lui, fait la difference.
DROP FUNCTION IF EXISTS public.get_default_value_matrix(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR);
CREATE FUNCTION public.get_default_value_matrix(
    p_table       VARCHAR,
    p_colonne     VARCHAR,
    p_contract    VARCHAR,
    p_part_family VARCHAR,
    p_variante    VARCHAR DEFAULT 'STANDARD'
)
RETURNS TEXT
LANGUAGE sql
STABLE
AS $function$
    SELECT CASE WHEN m.type_valeur = 'NULL' THEN NULL ELSE m.valeur END
    FROM public.etl_default_value_matrix m
    WHERE m.table_cible = p_table
      AND m.colonne     = p_colonne
      AND m.variante    = COALESCE(p_variante, 'STANDARD')
      AND m.is_active
      AND (m.contract    IS NULL OR m.contract    = p_contract)
      AND (m.part_family IS NULL OR m.part_family = p_part_family)
    ORDER BY (m.contract IS NOT NULL)::int + (m.part_family IS NOT NULL)::int DESC,
             (m.contract IS NOT NULL)::int DESC
    LIMIT 1;
$function$;

COMMENT ON FUNCTION public.get_default_value_matrix(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR) IS
'Valeur de la matrice site x famille la plus specifique (site+famille > site > famille > joker), NULL si aucune ligne active.';

-- --- 3.2 Resolution complete utilisee par les loaders -----------------------
-- Matrice site x famille, puis repli sur la constante etl_default_values,
-- puis NULL. C'est le SEUL appel a placer dans les procedures alimenter_*.
DROP FUNCTION IF EXISTS public.get_default_value_ctx(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR);
CREATE FUNCTION public.get_default_value_ctx(
    p_table       VARCHAR,
    p_colonne     VARCHAR,
    p_contract    VARCHAR,
    p_part_family VARCHAR,
    p_variante    VARCHAR DEFAULT 'STANDARD'
)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_type   VARCHAR(20);
    v_valeur TEXT;
BEGIN
    SELECT m.type_valeur, m.valeur
    INTO v_type, v_valeur
    FROM public.etl_default_value_matrix m
    WHERE m.table_cible = p_table
      AND m.colonne     = p_colonne
      AND m.variante    = COALESCE(p_variante, 'STANDARD')
      AND m.is_active
      AND (m.contract    IS NULL OR m.contract    = p_contract)
      AND (m.part_family IS NULL OR m.part_family = p_part_family)
    ORDER BY (m.contract IS NOT NULL)::int + (m.part_family IS NOT NULL)::int DESC,
             (m.contract IS NOT NULL)::int DESC
    LIMIT 1;

    -- Une ligne de matrice de type NULL est un choix explicite (vider la
    -- colonne pour ce site / cette famille) : elle ne doit PAS retomber sur la
    -- constante. D'ou le test sur FOUND plutot qu'un COALESCE.
    IF FOUND THEN
        RETURN CASE WHEN v_type = 'NULL' THEN NULL ELSE v_valeur END;
    END IF;

    RETURN public.get_default_value(p_table, p_colonne, COALESCE(p_variante, 'STANDARD'));

EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Erreur dans get_default_value_ctx: % - Table: %, Colonne: %, Site: %, Famille: %',
                      SQLERRM, p_table, p_colonne, p_contract, p_part_family;
        RETURN NULL;
END;
$function$;

COMMENT ON FUNCTION public.get_default_value_ctx(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR) IS
'Valeur par defaut ETL resolue en 3 niveaux : matrice site x famille (etl_default_value_matrix), puis constante (etl_default_values / get_default_value), puis NULL.';

-- --- 3.3 Routage de creation ------------------------------------------------
DROP FUNCTION IF EXISTS public.get_part_type_matrix(VARCHAR, VARCHAR, VARCHAR);
CREATE FUNCTION public.get_part_type_matrix(
    p_target_table VARCHAR,
    p_contract     VARCHAR,
    p_part_family  VARCHAR
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $function$
    SELECT m.should_create
    FROM public.etl_part_type_matrix m
    WHERE m.target_table = p_target_table
      AND m.is_active
      AND (m.contract    IS NULL OR m.contract    = p_contract)
      AND (m.part_family IS NULL OR m.part_family = p_part_family)
    ORDER BY (m.contract IS NOT NULL)::int + (m.part_family IS NOT NULL)::int DESC,
             (m.contract IS NOT NULL)::int DESC
    LIMIT 1;
$function$;

COMMENT ON FUNCTION public.get_part_type_matrix(VARCHAR, VARCHAR, VARCHAR) IS
'Faut-il creer la ligne de la table cible pour ce site et cette famille ? NULL si aucune ligne active : les loaders appliquent COALESCE(..., TRUE).';

-- ===========================================================================
-- 4. GARDE-FOU : valeur non castable vers le type de la colonne cible
--    (meme regle que le trigger de la migration 049 sur etl_default_values)
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.trg_etl_default_value_matrix_valider()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
    v_udt       TEXT;
    v_data_type TEXT;
BEGIN
    IF NEW.type_valeur = 'NULL' OR NEW.is_active IS DISTINCT FROM TRUE THEN
        RETURN NEW;
    END IF;

    SELECT c.udt_name, c.data_type
    INTO v_udt, v_data_type
    FROM information_schema.columns c
    WHERE c.table_schema = split_part(NEW.table_cible, '.', 1)
      AND c.table_name   = split_part(NEW.table_cible, '.', 2)
      AND c.column_name  = NEW.colonne;

    IF NOT FOUND THEN
        RETURN NEW;   -- table / colonne inconnue : on ne bloque pas
    END IF;

    IF v_data_type IN ('character varying', 'text', 'character') THEN
        RETURN NEW;
    END IF;

    IF COALESCE(NEW.valeur, '') = '' THEN
        RAISE EXCEPTION
            'Valeur vide interdite sur %.% (colonne de type %) : la valeur est du TEXT et PostgreSQL ne sait pas caster '''' vers %. Choisissez le type de valeur "NULL" pour laisser la colonne vide.',
            NEW.table_cible, NEW.colonne, v_data_type, v_data_type
            USING ERRCODE = '22P02';
    END IF;

    BEGIN
        EXECUTE format('SELECT %L::%s', NEW.valeur, v_udt);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION
                'Valeur % incompatible avec %.% (colonne de type %) : le chargement ETL echouerait avec "%". Corrigez la valeur ou choisissez le type "NULL".',
                quote_literal(NEW.valeur), NEW.table_cible, NEW.colonne, v_data_type, SQLERRM
                USING ERRCODE = '22P02';
    END;

    RETURN NEW;
END;
$function$;

COMMENT ON FUNCTION public.trg_etl_default_value_matrix_valider() IS
'Refuse une valeur de matrice active non castable vers le type reel de la colonne cible (meme garde-fou que la migration 049 sur etl_default_values).';

DROP TRIGGER IF EXISTS trg_etl_default_value_matrix_valider ON public.etl_default_value_matrix;
CREATE TRIGGER trg_etl_default_value_matrix_valider
    BEFORE INSERT OR UPDATE ON public.etl_default_value_matrix
    FOR EACH ROW EXECUTE FUNCTION public.trg_etl_default_value_matrix_valider();

-- --- updated_at automatique -------------------------------------------------
DROP TRIGGER IF EXISTS trg_etl_default_value_matrix_updated_at ON public.etl_default_value_matrix;
CREATE TRIGGER trg_etl_default_value_matrix_updated_at
    BEFORE UPDATE ON public.etl_default_value_matrix
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trg_etl_part_type_matrix_updated_at ON public.etl_part_type_matrix;
CREATE TRIGGER trg_etl_part_type_matrix_updated_at
    BEFORE UPDATE ON public.etl_part_type_matrix
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ===========================================================================
-- 5. SEED NEUTRE DU ROUTAGE
--    Un joker "tous sites / toutes familles" a TRUE par table cible : la
--    grille de l'ecran a une valeur de depart lisible et le comportement des
--    chargements reste celui d'aujourd'hui (les filtres STATUT des procedures
--    restent en place et s'appliquent en plus de la matrice).
-- ===========================================================================
INSERT INTO public.etl_part_type_matrix (target_table, contract, part_family, should_create, description, created_by)
SELECT v.target_table, NULL, NULL, TRUE, v.description, 'migration_052'
FROM (VALUES
    ('clean_data.sales_part',           'Repli general : article vendu (comportement historique)'),
    ('clean_data.purchase_part',        'Repli general : article achete (comportement historique)'),
    ('clean_data.manuf_part_attribute', 'Repli general : article fabrique (comportement historique)')
) AS v(target_table, description)
WHERE NOT EXISTS (
    SELECT 1 FROM public.etl_part_type_matrix m
    WHERE m.target_table = v.target_table
      AND m.contract IS NULL
      AND m.part_family IS NULL
);

-- ===========================================================================
-- 6. SEED DE LA COLONNE density DANS public.etl_default_values
--    density etait la seule valeur du chargeur manuf a n'avoir aucune ligne de
--    constante : elle venait exclusivement de raw_data.phl_article_densite.
--    Deux raisons de la seeder malgre tout, en type NULL (donc comportement
--    strictement inchange : get_default_value renvoyait deja NULL) :
--      * l'ecran Matrice ne propose que les colonnes connues de
--        etl_default_values -> sans cette ligne, density serait absente de la
--        liste des colonnes, alors que c'est le cas d'usage numero 1 ;
--      * sql/config/verifier_valeurs_defaut.py exige une ligne seedee par
--        appel (sinon "l'ETL ecrira NULL" sans que personne ne le voie).
-- ===========================================================================
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'density', 'STANDARD', 'NULL', NULL,
        'Densite : valeur mesuree (raw_data.phl_article_densite) en priorite, sinon densite theorique de la matrice Site x Famille. Cette constante n''est que le dernier repli.',
        'migration_052')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

COMMIT;

-- ===========================================================================
-- CONTROLES (a jouer apres la migration)
-- ===========================================================================
-- -- 1. Les fonctions repondent et la resolution retombe bien sur la constante :
-- SELECT public.get_default_value    ('clean_data.manuf_part_attribute', 'cum_leadtime')             AS constante,
--        public.get_default_value_ctx('clean_data.manuf_part_attribute', 'cum_leadtime', 'SJ', '23') AS resolue;
--
-- -- 2. Priorite de la matrice (exemple a supprimer apres test).
-- --    Ecrit en SELECT : sql/config/apply_default_values.py parse les listes
-- --    de valeurs de ce fichier sans ignorer les commentaires, un exemple
-- --    commente y entrerait comme une vraie ligne de seed.
-- INSERT INTO public.etl_default_value_matrix (table_cible, colonne, contract, part_family, type_valeur, valeur, description, created_by)
-- SELECT 'clean_data.manuf_part_attribute', 'density', NULL, '23', 'CONSTANTE', '2.70', 'test', 'test'
-- UNION ALL
-- SELECT 'clean_data.manuf_part_attribute', 'density', 'CS', '23', 'CONSTANTE', '2.71', 'test', 'test';
-- SELECT public.get_default_value_ctx('clean_data.manuf_part_attribute','density','SJ','23') AS attendu_2_70,
--        public.get_default_value_ctx('clean_data.manuf_part_attribute','density','CS','23') AS attendu_2_71,
--        public.get_default_value_ctx('clean_data.manuf_part_attribute','density','SJ','21') AS attendu_constante;
-- DELETE FROM public.etl_default_value_matrix WHERE created_by = 'test';
--
-- -- 3. Routage neutre :
-- SELECT public.get_part_type_matrix('clean_data.sales_part', 'SJ', '23');  -- true

-- ===========================================================================
-- ROLLBACK
-- ===========================================================================
-- BEGIN;
-- DROP FUNCTION IF EXISTS public.get_default_value_ctx(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR);
-- DROP FUNCTION IF EXISTS public.get_default_value_matrix(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR);
-- DROP FUNCTION IF EXISTS public.get_part_type_matrix(VARCHAR, VARCHAR, VARCHAR);
-- DROP TABLE IF EXISTS public.etl_default_value_matrix;
-- DROP TABLE IF EXISTS public.etl_part_type_matrix;
-- DROP FUNCTION IF EXISTS public.trg_etl_default_value_matrix_valider();
-- COMMIT;
-- ATTENTION : les procedures alimenter_*_phl appellent get_default_value_ctx()
-- et get_part_type_matrix(). Rollbacker les fonctions impose de recompiler le
-- module articlePhl depuis la version precedente du depot (git revert).
