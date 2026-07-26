-- =====================================================
-- Fonction: get_transcodification
-- Description: Recherche la valeur cible (target_value) dans la table de transcodification
--              en fonction de la catégorie et de la valeur source
-- Paramètres:
--   p_category: Catégorie de transcodification (ex: 'LANGUAGE', 'COUNTRY', 'CURRENCY')
--   p_source_value: Valeur dans le système source
--   p_source_system: Système source (par défaut 'SAP')
--   p_target_system: Système cible (par défaut 'IFS')
-- Retourne: La valeur cible (target_value) ou NULL si non trouvée
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_transcodification(
    p_category VARCHAR,
    p_source_value VARCHAR,
    p_source_system VARCHAR DEFAULT 'SAP',
    p_target_system VARCHAR DEFAULT 'IFS'
)
RETURNS VARCHAR
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_target_value VARCHAR;
BEGIN
    -- Rechercher la transcodification active
    SELECT target_value
    INTO v_target_value
    FROM public."TranscodificationTable"
    WHERE category = p_category
      AND source_value = p_source_value
      AND source_system = p_source_system
      AND target_system = p_target_system
      AND is_active = true
    LIMIT 1;
    
    -- Retourner la valeur trouvée (ou NULL si non trouvée)
    RETURN v_target_value;
    
EXCEPTION
    WHEN OTHERS THEN
        -- En cas d'erreur, retourner NULL et logger l'erreur
        RAISE WARNING 'Erreur dans get_transcodification: % - Category: %, Source: %', 
                      SQLERRM, p_category, p_source_value;
        RETURN NULL;
END;
$$;

-- =====================================================
-- Commentaire sur la fonction
-- =====================================================
COMMENT ON FUNCTION public.get_transcodification(VARCHAR, VARCHAR, VARCHAR, VARCHAR) IS 
'Recherche la valeur cible dans la table de transcodification. Retourne NULL si non trouvée ou si la transcodification est inactive.';

-- =====================================================
-- Exemples d''utilisation
-- =====================================================

-- Exemple 1: Recherche simple avec valeurs par défaut SAP->IFS
-- SELECT public.get_transcodification('LANGUAGE', 'F');

-- Exemple 2: Recherche avec systèmes spécifiques
-- SELECT public.get_transcodification('CURRENCY', 'EUR', 'SAP', 'IFS');

-- Exemple 3: Utilisation dans une requête UPDATE
-- UPDATE public.supplier
-- SET language = public.get_transcodification('LANGUAGE', sap_language_code)
-- WHERE sap_language_code IS NOT NULL;

-- Exemple 4: Utilisation dans une requête SELECT avec COALESCE pour valeur par défaut
-- SELECT 
--     supplier_id,
--     COALESCE(public.get_transcodification('LANGUAGE', language_code), language_code) as language_ifs
-- FROM public.supplier;

