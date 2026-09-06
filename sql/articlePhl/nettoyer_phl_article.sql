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
-- 2026-09-05 : depuis la separation des sources par site, il y a DEUX tables de
-- staging (raw_data.phl_article pour Saint-Jean, raw_data.phl_article_cs pour
-- Castel). Les deux subissent le meme nettoyage. Les colonnes a vider ne sont
-- declarees qu'UNE fois (c_colonnes_a_vider) et l'instruction est construite par
-- format() pour chaque table : impossible que les deux sites divergent.
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
    -- Tables de staging PHL, une par site (cf. sources/v_phl_article_retenu.sql)
    c_tables CONSTANT text[] := ARRAY['phl_article', 'phl_article_cs'];

    -- Articles plaques a ne pas migrer
    c_articles_exclus CONSTANT text[] := ARRAY[
        'FP-120004-S-1320-375-3670',
        'IP-120004-S-1320-375-3670'
    ];

    -- Les 31 colonnes non reprises dans IFS
    c_colonnes_a_vider CONSTANT text[] := ARRAY[
        'TRACABILITE LOTS',
        'TRACABILITE LOTS_2',
        'REGLE DE SERIE',
        'REGLE DE SERIE_2',
        'SUIVI DES SERIES',
        'SUIVI DES SERIES_2',
        'SUIVI SERIES APRES',
        'SUIVI SERIES APRES_2',
        'CONFIGURABLE',
        'CONFIGURABLE_2',
        'AUTORISE CD COND',
        'AUTORISE CD COND_2',
        'REGLE SOUS-LOT',
        'REGLE SOUS-LOT_2',
        'REGLE DU LOT',
        'REGLE DU LOT_2',
        'ARTICLE POSITION',
        'ARTICLE POSITION_2',
        'TRACAB. MULT NIV.',
        'TRACAB. MULT NIV._2',
        'REGLE LOT COMPOS.',
        'REGLE LOT COMPOS._2',
        'ARR.BC NUM SORTIS',
        'ARR.BC NUM SORTIS_2',
        'AUTOR. NON CONSOM.',
        'AUTOR. NON CONSOM._2',
        'RECEPT./SORTIE',
        'RECEPT./SORTIE_2',
        'AR.CREA.SERIE RMA',
        'AR.CREA.SERIE RMA_2',
        'GP PRINCP ARTICLE'
    ];

    v_table      text;
    v_set        text;
    v_where      text;
    v_lignes     INTEGER := 0;
    v_supprimees INTEGER := 0;
BEGIN
    -- Construction des listes SET / WHERE a partir de la seule liste de colonnes.
    -- format('%I') gere les intitules a espaces et a points ("TRACAB. MULT NIV.").
    SELECT string_agg(format('%I = NULL', c), ', '),
           string_agg(format('%I IS NOT NULL', c), ' OR ')
      INTO v_set, v_where
      FROM unnest(c_colonnes_a_vider) AS c;

    FOREACH v_table IN ARRAY c_tables LOOP
        -- 1. Colonnes non reprises
        EXECUTE format('UPDATE raw_data.%I SET %s WHERE %s', v_table, v_set, v_where);
        GET DIAGNOSTICS v_lignes = ROW_COUNT;

        -- 2. Articles plaques non migres
        EXECUTE format('DELETE FROM raw_data.%I WHERE TRIM("N. ARTICLE") = ANY ($1)', v_table)
        USING c_articles_exclus;
        GET DIAGNOSTICS v_supprimees = ROW_COUNT;

        RAISE NOTICE 'Nettoyage raw_data.% : % ligne(s) videe(s) sur les 31 colonnes non reprises',
            v_table, v_lignes;
        RAISE NOTICE 'Nettoyage raw_data.% : % ligne(s) supprimee(s) pour les articles plaques %',
            v_table, v_supprimees, c_articles_exclus;
    END LOOP;
END;
$procedure$;

-- Execution manuelle :
-- CALL clean_data.nettoyer_phl_article();
