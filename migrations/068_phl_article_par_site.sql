-- ============================================================================
-- 068 : separation des sources PHL par site (Saint-Jean / Castel)
--
-- CONSTAT
--   Une seule table de staging, raw_data.phl_article, recevait le fichier PHL,
--   et raw_data.v_phl_article_retenu n'avait aucune notion de site. Les deux
--   passes ETL creees par la migration 033 -- « Articles PHL Saint-Jean »
--   (contract SJ) et « Articles PHL Castel » (contract CS) -- lisaient donc
--   TOUTES les lignes : le meme catalogue d'articles etait charge sur les deux
--   sites, p_contract ne servant qu'aux valeurs par defaut et a la colonne
--   contract des tables cibles.
--
-- CHANGEMENT
--   Chaque site a sa table de staging, alimentee par son propre fichier :
--       SJ -> raw_data.phl_article     (table historique, inchangee)
--       CS -> raw_data.phl_article_cs  (creee ici, structure clonee)
--   raw_data.v_phl_article_retenu devient un UNION ALL des deux, avec une
--   colonne "site", et les cinq fonctions clean_data.alimenter_*_phl(p_contract)
--   filtrent sur "site = p_contract" : un article n'est charge que sur le site
--   de son fichier d'origine.
--
-- CHANGEMENT DE COMPORTEMENT ASSUME : apres cette migration, la passe Castel ne
-- charge plus rien tant que raw_data.phl_article_cs est vide, et les articles
-- Saint-Jean ne sont plus crees sur le site CS (ni l'inverse).
--
-- A JOUER ENSUITE, dans cet ordre :
--   1. cette migration (cree la table)
--   2. cd sql/articlePhl && ./compile.sh
--      -> rejoue la vue (sources/v_phl_article_retenu.sql), la procedure de
--         nettoyage (qui traite desormais les DEUX tables) et les cinq
--         fonctions d'alimentation.
--   3. importer le fichier Saint-Jean dans raw_data.phl_article et le fichier
--      Castel dans raw_data.phl_article_cs (ecran d'import generique : la
--      nouvelle table doit y etre declaree comme cible, public.import_types).
--   4. relancer les deux passes ETL depuis l'ecran de chargement.
--
-- Rollback en bas de fichier.
-- ============================================================================

BEGIN;

-- La vue dependra des deux tables : elle est recreee par
-- sql/articlePhl/sources/v_phl_article_retenu.sql (etape 2 ci-dessus).
-- On ne la supprime pas ici : compile.sh commence par un DROP VIEW IF EXISTS,
-- et la laisser en place garde l'application fonctionnelle entre les deux
-- etapes (l'ecran Matrice Site x Famille lit cette vue).

-- Structure clonee : les deux fichiers ont le meme format, et la vue les
-- expose avec la meme liste de colonnes. INCLUDING ALL reprend les eventuels
-- defauts et contraintes de la table Saint-Jean.
CREATE TABLE IF NOT EXISTS raw_data.phl_article_cs
    (LIKE raw_data.phl_article INCLUDING ALL);

COMMENT ON TABLE raw_data.phl_article_cs IS
'Staging du fichier PHL du site Castel (CS). Structure clonee de raw_data.phl_article (Saint-Jean). Lue via raw_data.v_phl_article_retenu (colonne site = CS).';

COMMIT;

-- Verification : les deux tables doivent avoir le meme nombre de colonnes (66)
-- SELECT table_name, count(*) AS colonnes
--   FROM information_schema.columns
--  WHERE table_schema = 'raw_data'
--    AND table_name IN ('phl_article', 'phl_article_cs')
--  GROUP BY 1 ORDER BY 1;

-- Verification apres compile.sh et import :
-- SELECT site, count(*) FROM raw_data.v_phl_article_retenu GROUP BY 1 ORDER BY 1;

-- Verification apres rechargement ETL (chaque site ne doit porter que ses articles) :
-- SELECT contract, count(*) FROM clean_data.inventory_part GROUP BY 1 ORDER BY 1;

-- ============================================================================
-- ROLLBACK
-- ============================================================================
-- Revenir a la source unique impose de rejouer la version precedente de la vue
-- (sans colonne site) et des cinq fonctions alimenter_*_phl (sans le filtre
-- "site = p_contract") depuis git, puis :
--
-- DROP TABLE IF EXISTS raw_data.phl_article_cs;
-- ============================================================================
