-- ============================================================================
-- Fonction utilitaire pour rechercher un person_id
-- Schéma: raw_data
-- ============================================================================
CREATE OR REPLACE FUNCTION raw_data.find_person_id(p_search_value character varying)
 RETURNS character varying
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_person_id VARCHAR(255);
    v_normalized_search VARCHAR(255);
    v_reversed_name VARCHAR(255);
    v_parts TEXT[];
BEGIN
    -- Normaliser la valeur de recherche: minuscules + suppression espaces multiples
    v_normalized_search := LOWER(REGEXP_REPLACE(TRIM(p_search_value), '\s+', ' ', 'g'));
    
    -- ================================================================
    -- RECHERCHE 0: Correspondance resource_id -> new_resource_id
    --              dans raw_data.trimet_resource
    -- ================================================================
    SELECT new_resource_id INTO v_person_id
    FROM raw_data.trimet_resource
    WHERE LOWER(REGEXP_REPLACE(TRIM(COALESCE(resource_id, '')), '\s+', ' ', 'g')) = v_normalized_search
      AND NULLIF(TRIM(new_resource_id), '') IS NOT NULL
    LIMIT 1;

    IF v_person_id IS NOT NULL THEN
        RETURN v_person_id;
    END IF;

    -- ================================================================
    -- NOUVELLE RECHERCHE 1: Comparaison avec resource_id dans clean_data.ifs_person
    -- ================================================================
    SELECT person_id INTO v_person_id
    FROM clean_data.ifs_person
    WHERE LOWER(REGEXP_REPLACE(TRIM(COALESCE(resource_id, '')), '\s+', ' ', 'g')) = v_normalized_search
    LIMIT 1;
    
    IF v_person_id IS NOT NULL THEN
        RETURN v_person_id;
    END IF;
    
    -- ================================================================
    -- RECHERCHE 2: Comparaison avec person_id (insensible à la casse et espaces)
    -- ================================================================
    SELECT person_id INTO v_person_id
    FROM raw_data.ifs_person
    WHERE LOWER(REGEXP_REPLACE(TRIM(person_id), '\s+', ' ', 'g')) = v_normalized_search
    LIMIT 1;
    
    IF v_person_id IS NOT NULL THEN
        RETURN v_person_id;
    END IF;
    
    -- ================================================================
    -- RECHERCHE 3: Comparaison avec internal_display_name
    -- ================================================================
    SELECT person_id INTO v_person_id
    FROM raw_data.ifs_person
    WHERE LOWER(REGEXP_REPLACE(TRIM(COALESCE(internal_display_name, '')), '\s+', ' ', 'g')) = v_normalized_search
    LIMIT 1;
    
    IF v_person_id IS NOT NULL THEN
        RETURN v_person_id;
    END IF;
    
    -- ================================================================
    -- RECHERCHE 4: Comparaison avec external_display_name
    -- ================================================================
    SELECT person_id INTO v_person_id
    FROM raw_data.ifs_person
    WHERE LOWER(REGEXP_REPLACE(TRIM(COALESCE(external_display_name, '')), '\s+', ' ', 'g')) = v_normalized_search
    LIMIT 1;
    
    IF v_person_id IS NOT NULL THEN
        RETURN v_person_id;
    END IF;
    
    -- ================================================================
    -- RECHERCHE 5: Inverser le nom (ex: "john doe" -> "doe john")
    -- ================================================================
    v_parts := string_to_array(v_normalized_search, ' ');
    
    IF array_length(v_parts, 1) = 2 THEN
        v_reversed_name := v_parts[2] || ' ' || v_parts[1];
        
        -- Rechercher avec le nom inversé dans internal_display_name
        SELECT person_id INTO v_person_id
        FROM raw_data.ifs_person
        WHERE LOWER(REGEXP_REPLACE(TRIM(COALESCE(internal_display_name, '')), '\s+', ' ', 'g')) = v_reversed_name
        LIMIT 1;
        
        IF v_person_id IS NOT NULL THEN
            RETURN v_person_id;
        END IF;
        
        -- Rechercher avec le nom inversé dans external_display_name
        SELECT person_id INTO v_person_id
        FROM raw_data.ifs_person
        WHERE LOWER(REGEXP_REPLACE(TRIM(COALESCE(external_display_name, '')), '\s+', ' ', 'g')) = v_reversed_name
        LIMIT 1;
        
        IF v_person_id IS NOT NULL THEN
            RETURN v_person_id;
        END IF;
    END IF;
    
    -- ================================================================
    -- RECHERCHE 6: Concaténation first_name + last_name
    -- ================================================================
    SELECT person_id INTO v_person_id
    FROM raw_data.ifs_person
    WHERE LOWER(REGEXP_REPLACE(TRIM(CONCAT(COALESCE(first_name, ''), ' ', COALESCE(last_name, ''))), '\s+', ' ', 'g')) = v_normalized_search
    LIMIT 1;
    
    IF v_person_id IS NOT NULL THEN
        RETURN v_person_id;
    END IF;
    
    -- ================================================================
    -- RECHERCHE 7: Concaténation last_name + first_name
    -- ================================================================
    SELECT person_id INTO v_person_id
    FROM raw_data.ifs_person
    WHERE LOWER(REGEXP_REPLACE(TRIM(CONCAT(COALESCE(last_name, ''), ' ', COALESCE(first_name, ''))), '\s+', ' ', 'g')) = v_normalized_search
    LIMIT 1;
    
    -- Retourne NULL si aucune correspondance trouvée
    RETURN v_person_id;
END;
$function$;
