-- =====================================================
-- Fonction: get_person_id_from_login
-- Description: Calcule le person_id à partir du login_name SharePoint
--              Convertit "Prenom.Nom" en "PNOM" (première lettre du prénom + nom en majuscules)
-- Paramètres:
--   p_login_name: Login SharePoint au format "Prenom.Nom"
-- Retourne: Le person_id calculé (ex: "TPATOUILLARD" pour "Thomas.Patouillard")
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_person_id_from_login(
    p_login_name VARCHAR
)
RETURNS VARCHAR
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_person_id VARCHAR;
    v_prenom VARCHAR;
    v_nom VARCHAR;
    v_parts TEXT[];
BEGIN
    -- Vérifier si le login_name est NULL ou vide
    IF p_login_name IS NULL OR TRIM(p_login_name) = '' THEN
        RETURN NULL;
    END IF;
    
    -- Séparer le login_name par le point
    v_parts := string_to_array(p_login_name, '.');
    
    -- Vérifier qu'on a bien 2 parties (Prenom.Nom)
    IF array_length(v_parts, 1) <> 2 THEN
        -- Si le format n'est pas correct, retourner le login_name en majuscules
        RETURN UPPER(REPLACE(p_login_name, '.', ''));
    END IF;
    
    -- Extraire le prénom et le nom
    v_prenom := TRIM(v_parts[1]);
    v_nom := TRIM(v_parts[2]);
    
    -- Construire le person_id: première lettre du prénom + nom complet en majuscules
    v_person_id := UPPER(SUBSTRING(v_prenom, 1, 1) || v_nom);
    
    RETURN v_person_id;
    
EXCEPTION
    WHEN OTHERS THEN
        -- En cas d'erreur, retourner le login_name sans le point en majuscules
        RAISE WARNING 'Erreur dans get_person_id_from_login pour %: %', p_login_name, SQLERRM;
        RETURN UPPER(REPLACE(p_login_name, '.', ''));
END;
$$;

-- =====================================================
-- Commentaire sur la fonction
-- =====================================================
COMMENT ON FUNCTION public.get_person_id_from_login(VARCHAR) IS 
'Calcule le person_id IFS à partir du login_name SharePoint. Convertit "Prenom.Nom" en "PNOM".';

-- =====================================================
-- Exemples d''utilisation
-- =====================================================

-- Exemple 1: Conversion simple
-- SELECT public.get_person_id_from_login('Thomas.Patouillard');
-- Résultat: 'TPATOUILLARD'

-- Exemple 2: Conversion avec prénom composé
-- SELECT public.get_person_id_from_login('Jean-Pierre.Dupont');
-- Résultat: 'JDUPONT'

-- Exemple 3: Utilisation dans une requête
-- SELECT 
--     login_name,
--     public.get_person_id_from_login(login_name) as person_id
-- FROM raw_data.sharepoint_users;

-- Exemple 4: Avec COALESCE pour valeur par défaut
-- SELECT 
--     COALESCE(
--         public.get_person_id_from_login(pm_user.login_name),
--         'TPATOUILLARD'
--     ) as manager
-- FROM raw_data.sharepoint_projets sp
-- LEFT JOIN raw_data.sharepoint_users pm_user ON sp.pm_id = pm_user.sharepoint_user_id;

