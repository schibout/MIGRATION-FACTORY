-- ============================================================================
-- Vue v_phl_article_retenu
-- Schema: raw_data
--
-- 2026-08-26 : suppression du dedoublonnage par "radical" (DISTINCT ON sur le
-- numero d'article sans son suffixe -<lettre>). Cette regle, prevue pour les
-- articles Saint-Jean, eliminait a tort les variantes Castel (-F/-H/-O) qui
-- sont des articles distincts (745 lignes chargees -> 524 retenues).
-- La vue est desormais un simple passe-plat : toutes les lignes dont le
-- numero d'article est renseigne. Les doublons exacts restants sont geres par
-- le DISTINCT ON (TRIM("N. ARTICLE")) des procedures alimenter_*_phl.
-- La colonne radical_article est conservee pour compatibilite.
--
-- 2026-08-27 : pas de reprise du CODE FAMILLE 19 (lingots) -> les articles PHL
-- dont "FAMILLE" vaut 19 sont exclus de la vue, donc de toutes les procedures
-- alimenter_*_phl (part_catalog, inventory_part, purchase_part, sales_part,
-- manuf_part_attribute).
--
-- 2026-09-05 : SEPARATION DES SOURCES PAR SITE.
--   Jusqu'ici un seul fichier PHL alimentait raw_data.phl_article, et les deux
--   passes ETL (Articles PHL Saint-Jean / Articles PHL Castel) lisaient toutes
--   les lignes : le MEME catalogue d'articles etait charge sur les deux sites,
--   p_contract ne changeant que les valeurs par defaut.
--   Desormais chaque site a sa table de staging :
--       SJ = Saint-Jean -> raw_data.phl_article
--       CS = Castel     -> raw_data.phl_article_cs
--   La vue les expose en UNION ALL avec une colonne "site", et les procedures
--   alimenter_*_phl filtrent sur "site = p_contract" : cloisonnement strict,
--   un article n'est charge que sur le site de son fichier d'origine.
--   Les deux tables ont une structure identique (phl_article_cs est cree avec
--   LIKE raw_data.phl_article) : toute evolution de colonne doit etre appliquee
--   aux deux, puis la vue rejouee.
-- ============================================================================

-- GARDE-FOU : psql valide le DROP ci-dessous avant meme de tenter le CREATE.
-- Si raw_data.phl_article_cs n'existe pas (migration 068 non jouee), le CREATE
-- echoue et la vue reste SUPPRIMEE -- ce qui casse les 5 procedures et l'ecran
-- Matrice Site x Famille. On echoue donc AVANT le DROP.
DO $garde$
BEGIN
    IF to_regclass('raw_data.phl_article_cs') IS NULL THEN
        RAISE EXCEPTION
            'raw_data.phl_article_cs absente : jouer migrations/068_phl_article_par_site.sql AVANT ce script (la vue n''est pas supprimee).';
    END IF;
END
$garde$;

DROP VIEW IF EXISTS raw_data.v_phl_article_retenu;
CREATE VIEW raw_data.v_phl_article_retenu AS
 SELECT 'SJ'::text AS site,
    phl."NUMERO",
    phl."N. ARTICLE",
    phl."ALLIAGE",
    phl."SERIE ALL",
    phl."STATUT",
    phl."DIAMETRE",
    phl."NUM PRODUIT",
    phl."FAMILLE",
    phl."FORME",
    phl."SCIAGE",
    phl."NORME CHARGE",
    phl."POIDS COMMERCIAL",
    phl."EPAISSEUR",
    phl."LONGUEUR",
    phl."LARGEUR",
    phl."DESCRIPTION",
    phl."DESCRIPTION LANGUE",
    phl."TEXTE INFO",
    phl."ID NOM STD",
    phl."U/M",
    phl."TRACABILITE LOTS",
    phl."TRACABILITE LOTS_2",
    phl."REGLE DE SERIE",
    phl."REGLE DE SERIE_2",
    phl."SUIVI DES SERIES",
    phl."SUIVI DES SERIES_2",
    phl."SUIVI SERIES APRES",
    phl."SUIVI SERIES APRES_2",
    phl."GP PRINCP ARTICLE",
    phl."CONFIGURABLE",
    phl."CONFIGURABLE_2",
    phl."ID GARANTIE CLIENT",
    phl."GARANTIE FOURNI.",
    phl."AUTORISE CD COND",
    phl."AUTORISE CD COND_2",
    phl."REGLE SOUS-LOT",
    phl."REGLE SOUS-LOT_2",
    phl."REGLE DU LOT",
    phl."REGLE DU LOT_2",
    phl."ARTICLE POSITION",
    phl."ARTICLE POSITION_2",
    phl."ENTREE ID GP U/M",
    phl."U/M CAP. ACTIVE E",
    phl."U/M CAP. ACTIVE E_2",
    phl."TRACAB. MULT NIV.",
    phl."TRACAB. MULT NIV._2",
    phl."REGLE LOT COMPOS.",
    phl."REGLE LOT COMPOS._2",
    phl."ARR.BC NUM SORTIS",
    phl."ARR.BC NUM SORTIS_2",
    phl."POIDS NET",
    phl."U/M POIDS",
    phl."VOLUME NET",
    phl."U/M VOLUME",
    phl."FACTEUR CHARGEMENT",
    phl."AUTOR. NON CONSOM.",
    phl."AUTOR. NON CONSOM._2",
    phl."RECEPT./SORTIE",
    phl."RECEPT./SORTIE_2",
    phl."AR.CREA.SERIE RMA",
    phl."AR.CREA.SERIE RMA_2",
    phl."N.DESSIN TECHN.",
    phl."CLASSIF TYPE PROD.",
    phl."CLASSIF TYPE PROD._2",
    phl."CODE CEST",
    phl."CODE FCI",
    TRIM(BOTH FROM phl."N. ARTICLE") AS radical_article
   FROM raw_data.phl_article phl
  WHERE NULLIF(TRIM(BOTH FROM phl."N. ARTICLE"), ''::text) IS NOT NULL
    AND COALESCE(TRIM(BOTH FROM phl."FAMILLE"), ''::text) <> '19'::text
UNION ALL
 SELECT 'CS'::text AS site,
    phl."NUMERO",
    phl."N. ARTICLE",
    phl."ALLIAGE",
    phl."SERIE ALL",
    phl."STATUT",
    phl."DIAMETRE",
    phl."NUM PRODUIT",
    phl."FAMILLE",
    phl."FORME",
    phl."SCIAGE",
    phl."NORME CHARGE",
    phl."POIDS COMMERCIAL",
    phl."EPAISSEUR",
    phl."LONGUEUR",
    phl."LARGEUR",
    phl."DESCRIPTION",
    phl."DESCRIPTION LANGUE",
    phl."TEXTE INFO",
    phl."ID NOM STD",
    phl."U/M",
    phl."TRACABILITE LOTS",
    phl."TRACABILITE LOTS_2",
    phl."REGLE DE SERIE",
    phl."REGLE DE SERIE_2",
    phl."SUIVI DES SERIES",
    phl."SUIVI DES SERIES_2",
    phl."SUIVI SERIES APRES",
    phl."SUIVI SERIES APRES_2",
    phl."GP PRINCP ARTICLE",
    phl."CONFIGURABLE",
    phl."CONFIGURABLE_2",
    phl."ID GARANTIE CLIENT",
    phl."GARANTIE FOURNI.",
    phl."AUTORISE CD COND",
    phl."AUTORISE CD COND_2",
    phl."REGLE SOUS-LOT",
    phl."REGLE SOUS-LOT_2",
    phl."REGLE DU LOT",
    phl."REGLE DU LOT_2",
    phl."ARTICLE POSITION",
    phl."ARTICLE POSITION_2",
    phl."ENTREE ID GP U/M",
    phl."U/M CAP. ACTIVE E",
    phl."U/M CAP. ACTIVE E_2",
    phl."TRACAB. MULT NIV.",
    phl."TRACAB. MULT NIV._2",
    phl."REGLE LOT COMPOS.",
    phl."REGLE LOT COMPOS._2",
    phl."ARR.BC NUM SORTIS",
    phl."ARR.BC NUM SORTIS_2",
    phl."POIDS NET",
    phl."U/M POIDS",
    phl."VOLUME NET",
    phl."U/M VOLUME",
    phl."FACTEUR CHARGEMENT",
    phl."AUTOR. NON CONSOM.",
    phl."AUTOR. NON CONSOM._2",
    phl."RECEPT./SORTIE",
    phl."RECEPT./SORTIE_2",
    phl."AR.CREA.SERIE RMA",
    phl."AR.CREA.SERIE RMA_2",
    phl."N.DESSIN TECHN.",
    phl."CLASSIF TYPE PROD.",
    phl."CLASSIF TYPE PROD._2",
    phl."CODE CEST",
    phl."CODE FCI",
    TRIM(BOTH FROM phl."N. ARTICLE") AS radical_article
   FROM raw_data.phl_article_cs phl
  WHERE NULLIF(TRIM(BOTH FROM phl."N. ARTICLE"), ''::text) IS NOT NULL
    AND COALESCE(TRIM(BOTH FROM phl."FAMILLE"), ''::text) <> '19'::text;

COMMENT ON VIEW raw_data.v_phl_article_retenu IS
'Articles PHL retenus pour la migration, tous sites confondus. Colonne site : SJ (raw_data.phl_article) ou CS (raw_data.phl_article_cs). Les procedures clean_data.alimenter_*_phl(p_contract) filtrent sur site = p_contract.';

-- Verification : repartition des lignes retenues par site
-- SELECT site, count(*) FROM raw_data.v_phl_article_retenu GROUP BY 1 ORDER BY 1;
