-- ============================================================================
-- Nettoyage du fichier PHL avant chargement
--
-- Deux operations, appelees au debut du chargement PHL sur les DEUX sites
-- (Saint-Jean et Castel) :
--   1. Mise a NULL de 31 colonnes du fichier (15 paires libelle + code, plus
--      GP PRINCP ARTICLE) : tracabilite lot et serie, configurable, autorisation
--      de code condition, regles sous-lot / lot / lot composant, article position,
--      tracabilite multi-niveaux, reservation en saisie de commande, autorisation
--      non consomme, reception/sortie, creation de serie en RMA. Ces valeurs ne
--      doivent pas etre reprises dans IFS.
--   2. Suppression des articles plaques qui ne sont pas migres, identifies par
--      leur code (liste explicite ci-dessous).
--
-- ATTENTION : cette procedure ECRIT dans raw_data, contrairement a la convention
-- du projet (raw_data en lecture seule). C'est un choix explicite : les valeurs
-- effacees et les lignes supprimees ne sont recuperables que par un reimport du
-- fichier PHL.
--
-- Impact du point 1 sur le chargement : seules 9 des 31 colonnes etaient lues,
-- toutes par alimenter_inventory_part_phl --
--   CONFIGURABLE / _2      -> part_catalog_configurable(_db)  : desormais NULL
--   AUTORISE CD COND / _2  -> avail_activity_status(_db)      : desormais NULL
--   ARTICLE POSITION       -> type_code                       : desormais NULL
--   RECEPT./SORTIE         -> supply_code                     : desormais NULL
--   GP PRINCP ARTICLE      -> prime_commodity                 : desormais NULL
--   ARR.BC NUM SORTIS / _2 -> oe_alloc_assign_flag(_db)       : bascule sur la
--                             branche par defaut du CASE, soit
--                             'NOT RESERVE ORDER ENTRY' / 'N'
-- Les 22 autres colonnes n'etaient lues par aucune procedure : les vider ne
-- change rien au contenu charge dans clean_data.
--
-- Le point 2 vise les codes de la liste, et EUX SEULS : le critere n'est
-- volontairement pas la forme (FORME contenant PLAQUE couvrirait 816 articles
-- des deux sites). Pour ecarter d'autres articles, ajouter leur code a la liste.
-- ============================================================================

CREATE OR REPLACE PROCEDURE clean_data.nettoyer_phl_article()
LANGUAGE plpgsql
AS $procedure$
DECLARE
    -- Articles plaques a ne pas migrer
    c_articles_exclus CONSTANT text[] := ARRAY[
        'FP-120004-S-1320-375-3670',
        'IP-120004-S-1320-375-3670'
    ];
    v_lignes INTEGER := 0;
    v_supprimees INTEGER := 0;
BEGIN
    -- 1. Colonnes non reprises
    UPDATE raw_data.phl_article
    SET "TRACABILITE LOTS"    = NULL,
        "TRACABILITE LOTS_2"  = NULL,
        "REGLE DE SERIE"      = NULL,
        "REGLE DE SERIE_2"    = NULL,
        "SUIVI DES SERIES"    = NULL,
        "SUIVI DES SERIES_2"  = NULL,
        "SUIVI SERIES APRES"  = NULL,
        "SUIVI SERIES APRES_2"= NULL,
        "CONFIGURABLE"        = NULL,
        "CONFIGURABLE_2"      = NULL,
        "AUTORISE CD COND"    = NULL,
        "AUTORISE CD COND_2"  = NULL,
        "REGLE SOUS-LOT"      = NULL,
        "REGLE SOUS-LOT_2"    = NULL,
        "REGLE DU LOT"        = NULL,
        "REGLE DU LOT_2"      = NULL,
        "ARTICLE POSITION"    = NULL,
        "ARTICLE POSITION_2"  = NULL,
        "TRACAB. MULT NIV."   = NULL,
        "TRACAB. MULT NIV._2" = NULL,
        "REGLE LOT COMPOS."   = NULL,
        "REGLE LOT COMPOS._2" = NULL,
        "ARR.BC NUM SORTIS"   = NULL,
        "ARR.BC NUM SORTIS_2" = NULL,
        "AUTOR. NON CONSOM."  = NULL,
        "AUTOR. NON CONSOM._2"= NULL,
        "RECEPT./SORTIE"      = NULL,
        "RECEPT./SORTIE_2"    = NULL,
        "AR.CREA.SERIE RMA"   = NULL,
        "AR.CREA.SERIE RMA_2" = NULL,
        "GP PRINCP ARTICLE"   = NULL
    WHERE "TRACABILITE LOTS"    IS NOT NULL
       OR "TRACABILITE LOTS_2"  IS NOT NULL
       OR "REGLE DE SERIE"      IS NOT NULL
       OR "REGLE DE SERIE_2"    IS NOT NULL
       OR "SUIVI DES SERIES"    IS NOT NULL
       OR "SUIVI DES SERIES_2"  IS NOT NULL
       OR "SUIVI SERIES APRES"  IS NOT NULL
       OR "SUIVI SERIES APRES_2"IS NOT NULL
       OR "CONFIGURABLE"        IS NOT NULL
       OR "CONFIGURABLE_2"      IS NOT NULL
       OR "AUTORISE CD COND"    IS NOT NULL
       OR "AUTORISE CD COND_2"  IS NOT NULL
       OR "REGLE SOUS-LOT"      IS NOT NULL
       OR "REGLE SOUS-LOT_2"    IS NOT NULL
       OR "REGLE DU LOT"        IS NOT NULL
       OR "REGLE DU LOT_2"      IS NOT NULL
       OR "ARTICLE POSITION"    IS NOT NULL
       OR "ARTICLE POSITION_2"  IS NOT NULL
       OR "TRACAB. MULT NIV."   IS NOT NULL
       OR "TRACAB. MULT NIV._2" IS NOT NULL
       OR "REGLE LOT COMPOS."   IS NOT NULL
       OR "REGLE LOT COMPOS._2" IS NOT NULL
       OR "ARR.BC NUM SORTIS"   IS NOT NULL
       OR "ARR.BC NUM SORTIS_2" IS NOT NULL
       OR "AUTOR. NON CONSOM."  IS NOT NULL
       OR "AUTOR. NON CONSOM._2"IS NOT NULL
       OR "RECEPT./SORTIE"      IS NOT NULL
       OR "RECEPT./SORTIE_2"    IS NOT NULL
       OR "AR.CREA.SERIE RMA"   IS NOT NULL
       OR "AR.CREA.SERIE RMA_2" IS NOT NULL
       OR "GP PRINCP ARTICLE"   IS NOT NULL;
    GET DIAGNOSTICS v_lignes = ROW_COUNT;

    -- 2. Articles plaques non migres
    DELETE FROM raw_data.phl_article
    WHERE TRIM("N. ARTICLE") = ANY (c_articles_exclus);
    GET DIAGNOSTICS v_supprimees = ROW_COUNT;

    RAISE NOTICE 'Nettoyage raw_data.phl_article : % ligne(s) videe(s) sur les 31 colonnes non reprises', v_lignes;
    RAISE NOTICE 'Nettoyage raw_data.phl_article : % ligne(s) supprimee(s) pour les articles plaques %', v_supprimees, c_articles_exclus;
END;
$procedure$;

-- Execution manuelle :
-- CALL clean_data.nettoyer_phl_article();
