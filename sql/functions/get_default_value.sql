-- =====================================================
-- Fonction: get_default_value
-- Description: Retourne la valeur par défaut paramétrée dans
--              public.etl_default_values, sinon p_fallback (valeur
--              historique codée en dur dans le script ETL appelant).
--              Ne lève JAMAIS d'exception.
-- Paramètres:
--   p_table:    Table cible (ex: 'clean_data.supplier_info_general')
--   p_colonne:  Colonne cible (ex: 'default_language')
--   p_fallback: Valeur codée en dur à retourner si aucun paramétrage
--               actif n'est trouvé (par défaut NULL)
--   p_variante: Variante de la ligne (ex: 'STANDARD', 'DELIVERY', 'PAY')
--               (par défaut 'STANDARD')
-- Retourne: La valeur paramétrée (TEXT), NULL si type_valeur='NULL',
--           ou p_fallback si non trouvée/inactive/en erreur
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_default_value(
    p_table    VARCHAR,
    p_colonne  VARCHAR,
    p_fallback TEXT DEFAULT NULL,
    p_variante VARCHAR DEFAULT 'STANDARD'
)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
AS $$
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

    -- Aucune ligne paramétrée (ou inactive) : retourner le fallback historique
    IF NOT FOUND THEN
        RETURN p_fallback;
    END IF;

    -- type_valeur='NULL' -> NULL explicite, sinon la valeur paramétrée
    RETURN CASE WHEN v_type = 'NULL' THEN NULL ELSE v_valeur END;

EXCEPTION
    WHEN OTHERS THEN
        -- En cas d'erreur, retourner le fallback et logger l'erreur
        RAISE WARNING 'Erreur dans get_default_value: % - Table: %, Colonne: %, Variante: %',
                      SQLERRM, p_table, p_colonne, p_variante;
        RETURN p_fallback;
END;
$$;

-- =====================================================
-- Commentaire sur la fonction
-- =====================================================
COMMENT ON FUNCTION public.get_default_value(VARCHAR, VARCHAR, TEXT, VARCHAR) IS
'Valeur par défaut ETL paramétrable (écran Configuration > Valeurs par défaut). Retourne p_fallback si non configurée, inactive ou en erreur.';

-- =====================================================
-- Exemples d'utilisation
-- =====================================================

-- Exemple 1: Utilisation dans un script ETL avec fallback historique codé en dur
-- SELECT public.get_default_value('clean_data.supplier_info_general', 'default_language', 'FR');

-- Exemple 2: Avec une variante spécifique (ex: type d'adresse)
-- SELECT public.get_default_value('clean_data.supplier_info_address_type', 'address_type_code', 'Delivery', 'DELIVERY');

-- Exemple 3: Test cas CONSTANTE (valeur paramétrée retournée)
-- SELECT public.get_default_value('clean_data.supplier_info_our_id', 'our_id_prefix', 'FALLBACK');
-- -> attendu: 'TRIMET' (seedée en migration 031)

-- Exemple 4: Test cas NULL (type_valeur='NULL' -> NULL explicite, pas la chaîne 'NULL')
-- SELECT public.get_default_value('clean_data.supplier_info_general', 'business_classification', 'FALLBACK');
-- -> attendu: NULL

-- Exemple 5: Test cas absent/inactif (retombe sur p_fallback)
-- SELECT public.get_default_value('clean_data.table_inexistante', 'colonne_inexistante', 'FALLBACK');
-- -> attendu: 'FALLBACK'
