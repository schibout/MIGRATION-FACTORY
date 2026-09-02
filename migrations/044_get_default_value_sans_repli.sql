-- =====================================================
-- 044 - public.get_default_value : suppression de l'argument de repli
--
-- AVANT : get_default_value(p_table, p_colonne, p_fallback, p_variante)
--         Aucune ligne parametree (ou ligne inactive) -> retour de p_fallback,
--         c'est-a-dire la constante historiquement codee en dur dans le script
--         ETL appelant. L'ecran /configuration/valeurs-defaut n'etait donc pas
--         la seule source de verite : une valeur pouvait venir du code.
--
-- APRES : get_default_value(p_table, p_colonne, p_variante)
--         La fonction ne renvoie QUE ce qui est parametre : la valeur de la
--         ligne active, sinon NULL (valeur vide).
--
-- Pourquoi NULL et pas '' : get_default_value retourne du TEXT et PostgreSQL
-- n'a aucun cast implicite ''->numeric/date/timestamp. Une chaine vide ferait
-- echouer les colonnes non textuelles avec
--   invalid input syntax for type numeric: ""
-- -- exactement le probleme corrige par la migration 042. NULL se caste vers
-- n'importe quel type.
--
-- Impact mesure sur la base le 2026-09-02 :
--   * 730 lignes actives CONSTANTE ......... inchangees (valeur deja renvoyee)
--   * 302 lignes inactives de type NULL .... inchangees (NULL avant et apres)
--   *   1 ligne inactive CONSTANTE ......... inchangee (picture_id, repli NULL)
--   *  11 colonnes cibles NOT NULL ......... toutes pourvues d'une ligne active
--   *   0 ligne inactive sur colonne NOT NULL
-- => neutre sur tout le contenu actuel de public.etl_default_values.
--
-- L'ANCIENNE SIGNATURE EST SUPPRIMEE : les 1050 appels des 59 scripts ETL ont
-- ete reecrits sans le 3e argument (le 4e, la variante, prend sa place). Toute
-- procedure encore compilee avec l'ancien appel echouera avec
--   function public.get_default_value(..., unknown, unknown) does not exist
-- -> RECOMPILER TOUS LES MODULES apres cette migration : sql/compile_all.sh
--
-- Aucune vue ne reference la fonction (verifie sur la base), le DROP passe.
--
-- PREREQUIS : tout appel doit avoir sa ligne seedee, sinon il renvoie NULL.
-- Jouer la migration 043 AVANT celle-ci, puis controler avec
--   python sql/config/verifier_valeurs_defaut.py
--
-- Rollback en bas de fichier.
-- =====================================================

BEGIN;

DROP FUNCTION IF EXISTS public.get_default_value(VARCHAR, VARCHAR, TEXT, VARCHAR);

CREATE OR REPLACE FUNCTION public.get_default_value(
    p_table    VARCHAR,
    p_colonne  VARCHAR,
    p_variante VARCHAR DEFAULT 'STANDARD'
)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_type   VARCHAR(20);
    v_valeur TEXT;
BEGIN
    -- Rechercher le paramétrage actif
    SELECT type_valeur, valeur
    INTO v_type, v_valeur
    FROM public.etl_default_values
    WHERE table_cible = p_table
      AND colonne = p_colonne
      AND variante = p_variante
      AND is_active = TRUE;

    -- Aucune ligne paramétrée (ou inactive) : valeur vide.
    -- L'écran /configuration/valeurs-defaut est la seule source de vérité.
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    -- type_valeur='NULL' -> NULL explicite, sinon la valeur paramétrée
    RETURN CASE WHEN v_type = 'NULL' THEN NULL ELSE v_valeur END;

EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Erreur dans get_default_value: % - Table: %, Colonne: %, Variante: %',
                      SQLERRM, p_table, p_colonne, p_variante;
        RETURN NULL;
END;
$function$;

COMMENT ON FUNCTION public.get_default_value(VARCHAR, VARCHAR, VARCHAR) IS
'Valeur par defaut ETL parametrable (ecran Configuration > Valeurs par defaut). Retourne NULL si non configuree, inactive ou en erreur : aucun repli code en dur depuis la migration 044.';

COMMIT;

-- =====================================================
-- ROLLBACK : retablir la signature a 4 arguments avec repli
-- ATTENTION : necessite aussi de restaurer les appels des scripts ETL
--             (git revert du commit qui a retire le 3e argument).
-- =====================================================
-- BEGIN;
--
-- DROP FUNCTION IF EXISTS public.get_default_value(VARCHAR, VARCHAR, VARCHAR);
--
-- CREATE OR REPLACE FUNCTION public.get_default_value(
--     p_table    VARCHAR,
--     p_colonne  VARCHAR,
--     p_fallback TEXT    DEFAULT NULL,
--     p_variante VARCHAR DEFAULT 'STANDARD'
-- )
-- RETURNS TEXT
-- LANGUAGE plpgsql
-- STABLE
-- AS $function$
-- DECLARE
--     v_type   VARCHAR(20);
--     v_valeur TEXT;
-- BEGIN
--     SELECT type_valeur, valeur
--     INTO v_type, v_valeur
--     FROM public.etl_default_values
--     WHERE table_cible = p_table
--       AND colonne = p_colonne
--       AND variante = p_variante
--       AND is_active = TRUE;
--
--     IF NOT FOUND THEN
--         RETURN p_fallback;
--     END IF;
--
--     RETURN CASE WHEN v_type = 'NULL' THEN NULL ELSE v_valeur END;
--
-- EXCEPTION
--     WHEN OTHERS THEN
--         RAISE WARNING 'Erreur dans get_default_value: % - Table: %, Colonne: %, Variante: %',
--                       SQLERRM, p_table, p_colonne, p_variante;
--         RETURN p_fallback;
-- END;
-- $function$;
--
-- COMMIT;
