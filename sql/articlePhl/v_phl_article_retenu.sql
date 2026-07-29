-- =====================================================================
-- raw_data.v_phl_article_retenu
-- Vue de dedoublonnage des articles PHL, source unique de tous les
-- chargeurs PHL (ifs_article_maitre, part_catalog, inventory_part,
-- sales_part, purchase_part, manuf_part_attribute).
--
-- Probleme traite : le fichier PHL contient des variantes d'un meme
-- article qui ne different que par un dernier segment d'une seule
-- lettre. Exemple :
--     FP-300308-2500-510-3100-N
--     FP-300308-2500-510-3100
-- Les deux etaient charges cote IFS ; il ne doit en rester qu'un.
--
-- Regle retenue :
--   1. Radical = "N. ARTICLE" prive d'un dernier segment "-X" ou X est
--      une seule lettre. Sans ce suffixe, le radical est le code lui-meme.
--   2. Un seul article est conserve par radical.
--   3. Arbitrage : on garde celui dont "NORME CHARGE" est renseignee.
--   4. Departages (les deux renseignees, ou aucune) : on garde le code
--      le plus court (donc la variante sans suffixe), puis l'ordre
--      alphabetique. Cet ordre garantit un resultat deterministe.
--
-- ATTENTION : la regle regroupe TOUTES les variantes a suffixe d'une
-- lettre partageant le meme radical, pas seulement les couples "-N".
-- Si le fichier contient par exemple X-A et X-B comme deux articles
-- reellement distincts, un seul survivra. A verifier avant chargement :
--
--   SELECT radical_article, count(*), string_agg("N. ARTICLE", ' | ')
--   FROM (
--       SELECT "N. ARTICLE",
--              CASE WHEN TRIM("N. ARTICLE") ~ '-[A-Za-z]$'
--                   THEN LEFT(TRIM("N. ARTICLE"), LENGTH(TRIM("N. ARTICLE")) - 2)
--                   ELSE TRIM("N. ARTICLE") END AS radical_article
--       FROM raw_data.phl_article
--       WHERE NULLIF(TRIM("N. ARTICLE"), '') IS NOT NULL
--   ) t
--   GROUP BY radical_article HAVING count(*) > 1
--   ORDER BY 2 DESC, 1;
-- =====================================================================

CREATE OR REPLACE VIEW raw_data.v_phl_article_retenu AS
WITH base AS (
    SELECT
        phl.*,
        CASE
            WHEN TRIM(phl."N. ARTICLE") ~ '-[A-Za-z]$'
                THEN LEFT(TRIM(phl."N. ARTICLE"), LENGTH(TRIM(phl."N. ARTICLE")) - 2)
            ELSE TRIM(phl."N. ARTICLE")
        END AS radical_article
    FROM raw_data.phl_article phl
    WHERE NULLIF(TRIM(phl."N. ARTICLE"), '') IS NOT NULL
)
SELECT DISTINCT ON (base.radical_article) base.*
FROM base
ORDER BY
    base.radical_article,
    -- 1. articles avec NORME CHARGE renseignee en premier
    (NULLIF(TRIM(base."NORME CHARGE"), '') IS NOT NULL) DESC,
    -- 2. a egalite, le code le plus court (variante sans suffixe)
    LENGTH(TRIM(base."N. ARTICLE")),
    -- 3. puis ordre alphabetique, pour un resultat deterministe
    TRIM(base."N. ARTICLE");

COMMENT ON VIEW raw_data.v_phl_article_retenu IS
    'Articles PHL dedoublonnes : un seul article par radical (code prive d''un suffixe -X d''une lettre), '
    'celui dont NORME CHARGE est renseignee. Source unique des chargeurs PHL.';
