-- =====================================================
-- Fonction: get_default_value
-- Description: Retourne la valeur par défaut paramétrée dans
--              public.etl_default_values. Si aucune ligne active
--              n'existe, retourne NULL (valeur vide) : l'écran
--              Configuration > Valeurs par défaut est la SEULE
--              source de vérité, plus rien n'est codé en dur.
--              Ne lève JAMAIS d'exception.
-- Paramètres:
--   p_table:    Table cible (ex: 'clean_data.supplier_info_general')
--   p_colonne:  Colonne cible (ex: 'default_language')
--   p_variante: Variante de la ligne (ex: 'STANDARD', 'DELIVERY', 'PAY')
--               (par défaut 'STANDARD')
-- Retourne: La valeur paramétrée (TEXT), ou NULL si type_valeur='NULL',
--           si aucune ligne active, ou en cas d'erreur.
--
-- ATTENTION : il n'y a plus d'argument de repli (supprimé par la
-- migration 044). Tout appel doit donc avoir sa ligne seedée dans
-- public.etl_default_values, sinon la colonne recevra NULL en silence.
-- Contrôle : python sql/config/verifier_valeurs_defaut.py
-- =====================================================

DROP FUNCTION IF EXISTS public.get_default_value(VARCHAR, VARCHAR, TEXT, VARCHAR);

CREATE OR REPLACE FUNCTION public.get_default_value(
    p_table    VARCHAR,
    p_colonne  VARCHAR,
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

    -- Aucune ligne paramétrée (ou inactive) : valeur vide
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
$$;

-- =====================================================
-- Commentaire sur la fonction
-- =====================================================
COMMENT ON FUNCTION public.get_default_value(VARCHAR, VARCHAR, VARCHAR) IS
'Valeur par défaut ETL paramétrable (écran Configuration > Valeurs par défaut). Retourne NULL si non configurée, inactive ou en erreur : aucun repli codé en dur.';

-- =====================================================
-- Exemples d'utilisation
-- =====================================================

-- Exemple 1: Utilisation dans un script ETL
-- SELECT public.get_default_value('clean_data.supplier_info_general', 'default_language');

-- Exemple 2: Avec une variante spécifique (ex: type d'adresse)
-- SELECT public.get_default_value('clean_data.supplier_info_address_type', 'address_type_code', 'DELIVERY');

-- Exemple 3: Test cas CONSTANTE (valeur paramétrée retournée)
-- SELECT public.get_default_value('clean_data.supplier_info_our_id', 'our_id_prefix');
-- -> attendu: 'TRIMET' (seedée en migration 031)

-- Exemple 4: Test cas NULL (type_valeur='NULL' -> NULL explicite, pas la chaîne 'NULL')
-- SELECT public.get_default_value('clean_data.supplier_info_general', 'business_classification');
-- -> attendu: NULL

-- Exemple 5: Test cas absent/inactif
-- SELECT public.get_default_value('clean_data.table_inexistante', 'colonne_inexistante');
-- -> attendu: NULL
