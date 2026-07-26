CREATE OR REPLACE FUNCTION clean_data.get_person_id_from_sharepoint_user_id(p_sharepoint_user_id VARCHAR)
RETURNS VARCHAR
LANGUAGE plpgsql
AS $function$
DECLARE
    v_person_id VARCHAR(20);
    v_login VARCHAR(100);
BEGIN
    -- Si l'ID SharePoint est NULL ou vide, retourner NULL
    IF p_sharepoint_user_id IS NULL OR TRIM(p_sharepoint_user_id) = '' THEN
        RETURN NULL;
    END IF;
    
    -- 1) EN PREMIER : person_id depuis raw_data.sharepoint_users, par sharepoint_user_id
    SELECT person_id
    INTO v_person_id
    FROM raw_data.sharepoint_users
    WHERE sharepoint_user_id::text = TRIM(p_sharepoint_user_id)
    LIMIT 1;
    
    -- Si trouvé, retourner le person_id
    IF v_person_id IS NOT NULL AND TRIM(v_person_id) <> '' THEN
        RETURN v_person_id;
    END IF;
    
    -- Si pas trouvé par sharepoint_user_id, essayer avec le login
    -- (fallback au cas où l'ID SharePoint correspond au login)
    SELECT 
        person_id
    INTO v_person_id
    FROM raw_data.sharepoint_users
    WHERE LOWER(TRIM(login_name)) = LOWER(TRIM(p_sharepoint_user_id))
    LIMIT 1;
    
    -- Si trouvé par login, retourner le person_id
    IF v_person_id IS NOT NULL AND TRIM(v_person_id) <> '' THEN
        RETURN v_person_id;
    END IF;
    
    -- Si toujours pas trouvé, essayer d'extraire le login depuis l'ID SharePoint
    -- Format possible: "i:0#.f|membership|login@domain.com"
    IF p_sharepoint_user_id LIKE '%|%' THEN
        -- Extraire la partie après le dernier pipe
        v_login := SUBSTRING(p_sharepoint_user_id FROM '.*\|(.*)$');
        
        -- Rechercher avec ce login extrait
        SELECT 
            person_id
        INTO v_person_id
        FROM raw_data.sharepoint_users
        WHERE LOWER(TRIM(login_name)) = LOWER(TRIM(v_login))
        LIMIT 1;
        
        IF v_person_id IS NOT NULL AND TRIM(v_person_id) <> '' THEN
            RETURN v_person_id;
        END IF;
    END IF;
    
    -- Si aucune correspondance trouvée, retourner NULL
    RETURN NULL;
    
EXCEPTION
    WHEN OTHERS THEN
        -- En cas d'erreur, logger et retourner NULL
        RAISE WARNING 'Erreur lors de la recherche du person_id pour sharepoint_user_id "%": %', 
            p_sharepoint_user_id, SQLERRM;
        RETURN NULL;
END;
$function$;

-- Commentaire sur la fonction
COMMENT ON FUNCTION clean_data.get_person_id_from_sharepoint_user_id(VARCHAR) IS 
'Recherche le person_id IFS à partir d''un sharepoint_user_id SharePoint.
Essaie plusieurs stratégies:
1. Recherche directe par sharepoint_user_id
2. Recherche par login si l''ID correspond à un login
3. Extraction du login depuis l''ID SharePoint (format: i:0#.f|membership|login@domain.com)
Retourne NULL si aucune correspondance n''est trouvée.';

-- Exemples d'utilisation:
-- SELECT clean_data.get_person_id_from_sharepoint_user_id('123');
-- SELECT clean_data.get_person_id_from_sharepoint_user_id('i:0#.f|membership|user@trimet.fr');
-- SELECT clean_data.get_person_id_from_sharepoint_user_id('user@trimet.fr');

