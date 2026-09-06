-- =====================================================================
-- raw_data.phl_article_cs : table de staging du fichier PHL Castel
-- =====================================================================
-- Jusqu'au 2026-09-05 un seul fichier PHL alimentait raw_data.phl_article,
-- et les deux passes ETL (Articles PHL Saint-Jean / Articles PHL Castel)
-- lisaient toutes ses lignes : le MEME catalogue d'articles etait charge sur
-- les deux sites, p_contract ne changeant que les valeurs par defaut.
--
-- Desormais chaque site importe son propre fichier dans sa propre table :
--     SJ = Saint-Jean -> raw_data.phl_article     (table historique, inchangee)
--     CS = Castel     -> raw_data.phl_article_cs  (cette table)
--
-- La structure est CLONEE de raw_data.phl_article (LIKE) : les deux fichiers
-- ont le meme format et raw_data.v_phl_article_retenu les expose en UNION ALL
-- avec la meme liste de colonnes. Toute evolution de colonne doit donc etre
-- appliquee aux DEUX tables, puis la vue rejouee
-- (sources/v_phl_article_retenu.sql).
--
-- L'import du fichier se fait par l'ecran d'import generique ; il reste a
-- declarer la table comme cible d'import (public.import_types.target_table).
-- =====================================================================

-- La vue depend des deux tables : la supprimer d'abord, puis rejouer
-- sources/v_phl_article_retenu.sql apres le CREATE TABLE ci-dessous.
DROP VIEW IF EXISTS raw_data.v_phl_article_retenu;

DROP TABLE IF EXISTS raw_data.phl_article_cs;

CREATE TABLE raw_data.phl_article_cs (LIKE raw_data.phl_article INCLUDING ALL);

COMMENT ON TABLE raw_data.phl_article_cs IS
'Staging du fichier PHL du site Castel (CS). Structure clonee de raw_data.phl_article (Saint-Jean). Lue via raw_data.v_phl_article_retenu (colonne site = CS).';

-- Verification post-execution : meme nombre de colonnes que phl_article (66)
-- SELECT table_name, count(*) FROM information_schema.columns
-- WHERE table_schema='raw_data' AND table_name IN ('phl_article','phl_article_cs')
-- GROUP BY 1;
