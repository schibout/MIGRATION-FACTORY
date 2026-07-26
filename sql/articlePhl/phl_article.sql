-- =====================================================================
-- Alignement raw_data.phl_article sur ArticleSaintJean.csv
-- =====================================================================
-- Constat (introspection raw_data.phl_article vs entete du fichier fourni) :
--   - Structure actuelle : 65 colonnes
--   - Fichier fourni      : 66 colonnes
--   - La colonne "DIAMETRE_2" (heritee d'un ancien fichier ou DIAMETRE
--     apparaissait deux fois consecutivement) ne correspond plus a rien
--     dans le fichier actuel.
--   - Le fichier actuel insere a la place deux nouvelles colonnes :
--     "NUM PRODUIT" puis "FAMILLE".
--   - Tout le reste de la structure (de FORME a CODE FCI) est identique,
--     y compris la convention de suffixe "_2" deja en place pour les
--     entetes dupliquees en source (TRACABILITE LOTS, REGLE DE SERIE, ...).
--
-- Postgres ne permettant pas d'inserer une colonne au milieu d'une table
-- existante, la table est recreee dans l'ordre exact du fichier.
-- Cette table etant une table de staging raw_data rechargee integralement
-- a chaque run ETL, cela n'entraine pas de perte de donnees exploitees.
--
-- A executer par Samir (acces production en lecture seule).
-- =====================================================================

DROP TABLE IF EXISTS raw_data.phl_article;

CREATE TABLE raw_data.phl_article (
    "NUMERO"                    VARCHAR,
    "N. ARTICLE"                VARCHAR,
    "ALLIAGE"                   VARCHAR,
    "SERIE ALL"                 VARCHAR,
    "STATUT"                    VARCHAR,
    "DIAMETRE"                  VARCHAR,
    "NUM PRODUIT"               VARCHAR,   -- nouvelle colonne (remplace DIAMETRE_2)
    "FAMILLE"                   VARCHAR,   -- nouvelle colonne
    "FORME"                     VARCHAR,
    "SCIAGE"                    VARCHAR,
    "NORME CHARGE"               VARCHAR,
    "POIDS COMMERCIAL"          VARCHAR,
    "EPAISSEUR"                 VARCHAR,
    "LONGUEUR"                  VARCHAR,
    "LARGEUR"                   VARCHAR,
    "DESCRIPTION"                VARCHAR,
    "DESCRIPTION LANGUE"        VARCHAR,
    "TEXTE INFO"                 VARCHAR,
    "ID NOM STD"                VARCHAR,
    "U/M"                       VARCHAR,
    "TRACABILITE LOTS"          VARCHAR,
    "TRACABILITE LOTS_2"        VARCHAR,
    "REGLE DE SERIE"            VARCHAR,
    "REGLE DE SERIE_2"          VARCHAR,
    "SUIVI DES SERIES"          VARCHAR,
    "SUIVI DES SERIES_2"        VARCHAR,
    "SUIVI SERIES APRES"        VARCHAR,
    "SUIVI SERIES APRES_2"      VARCHAR,
    "GP PRINCP ARTICLE"         VARCHAR,
    "CONFIGURABLE"               VARCHAR,
    "CONFIGURABLE_2"            VARCHAR,
    "ID GARANTIE CLIENT"        VARCHAR,
    "GARANTIE FOURNI."          VARCHAR,
    "AUTORISE CD COND"          VARCHAR,
    "AUTORISE CD COND_2"        VARCHAR,
    "REGLE SOUS-LOT"            VARCHAR,
    "REGLE SOUS-LOT_2"          VARCHAR,
    "REGLE DU LOT"              VARCHAR,
    "REGLE DU LOT_2"            VARCHAR,
    "ARTICLE POSITION"          VARCHAR,
    "ARTICLE POSITION_2"        VARCHAR,
    "ENTREE ID GP U/M"          VARCHAR,
    "U/M CAP. ACTIVE E"         VARCHAR,
    "U/M CAP. ACTIVE E_2"       VARCHAR,
    "TRACAB. MULT NIV."         VARCHAR,
    "TRACAB. MULT NIV._2"       VARCHAR,
    "REGLE LOT COMPOS."         VARCHAR,
    "REGLE LOT COMPOS._2"       VARCHAR,
    "ARR.BC NUM SORTIS"         VARCHAR,
    "ARR.BC NUM SORTIS_2"       VARCHAR,
    "POIDS NET"                 VARCHAR,
    "U/M POIDS"                 VARCHAR,
    "VOLUME NET"                VARCHAR,
    "U/M VOLUME"                VARCHAR,
    "FACTEUR CHARGEMENT"        VARCHAR,
    "AUTOR. NON CONSOM."        VARCHAR,
    "AUTOR. NON CONSOM._2"      VARCHAR,
    "RECEPT./SORTIE"            VARCHAR,
    "RECEPT./SORTIE_2"          VARCHAR,
    "AR.CREA.SERIE RMA"         VARCHAR,
    "AR.CREA.SERIE RMA_2"       VARCHAR,
    "N.DESSIN TECHN."           VARCHAR,
    "CLASSIF TYPE PROD."        VARCHAR,
    "CLASSIF TYPE PROD._2"      VARCHAR,
    "CODE CEST"                 VARCHAR,
    "CODE FCI"                  VARCHAR
);

-- Verification post-execution : nombre de colonnes attendu = 66
-- SELECT count(*) FROM information_schema.columns
-- WHERE table_schema='raw_data' AND table_name='phl_article';