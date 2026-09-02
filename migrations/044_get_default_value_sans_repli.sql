-- =====================================================
-- 044 - public.get_default_value : plus de repli sur la valeur codee en dur
--
-- AVANT : aucune ligne parametree (ou ligne inactive) -> retour de p_fallback,
--         c'est-a-dire la constante historiquement codee en dur dans le script
--         ETL appelant. L'ecran /configuration/valeurs-defaut n'etait donc pas
--         la seule source de verite : une valeur pouvait venir du code.
--
-- APRES : la fonction ne renvoie QUE ce qui est parametre. Si la ligne existe
--         et est active, sa valeur ; sinon NULL (valeur vide).
--
-- p_fallback est CONSERVE dans la signature -- les ~977 appels des modules ETL
-- le passent en 3e argument -- mais il n'est PLUS utilise. Le supprimer
-- imposerait de reecrire tous les appels.
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
-- PREREQUIS : tout appel a get_default_value doit avoir sa ligne seedee, sinon
-- il renverra desormais NULL. Jouer la migration 043 AVANT celle-ci
-- (clean_data.supplier/currency_code et
--  clean_data.identity_invoice_info/def_currency), puis verifier avec
--   python sql/config/verifier_valeurs_defaut.py
--
-- Rollback en bas de fichier.
-- =====================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.get_default_value(
    p_table    VARCHAR,
    p_colonne  VARCHAR,
    p_fallback TEXT    DEFAULT NULL,
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
    -- p_fallback n'est volontairement PAS utilisé : l'écran
    -- /configuration/valeurs-defaut est la seule source de vérité.
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

COMMENT ON FUNCTION public.get_default_value(VARCHAR, VARCHAR, TEXT, VARCHAR) IS
'Retourne la valeur par defaut parametree dans public.etl_default_values pour (table_cible, colonne, variante), ou NULL si aucune ligne active. Le 3e argument p_fallback est conserve pour compatibilite des appels mais N''EST PLUS utilise depuis la migration 044.';

COMMIT;

-- =====================================================
-- ROLLBACK : retablir le repli sur p_fallback
-- =====================================================
-- BEGIN;
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
