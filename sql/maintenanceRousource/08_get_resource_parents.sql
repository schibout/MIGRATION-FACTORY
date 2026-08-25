CREATE OR REPLACE FUNCTION clean_data.get_resource_parents(p_resource_seq numeric)
 RETURNS TABLE(level integer, resource_seq numeric, resource_id character varying, resource_parent_seq numeric, resource_parent_id character varying, scheduling_proficiency numeric)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    WITH RECURSIVE parent_hierarchy AS (
        -- Niveau 0: la ressource elle-même
        SELECT 
            0 as level,
            rp.resource_seq,
            rp.resource_id,
            rp.resource_parent_seq,
            rp.resource_parent_id,
            rp.scheduling_proficiency
        FROM clean_data.resource_parent rp
        WHERE rp.resource_seq = p_resource_seq
        
        UNION ALL
        
        -- Niveaux suivants: parents récursifs
        SELECT 
            ph.level + 1,
            rp.resource_seq,
            rp.resource_id,
            rp.resource_parent_seq,
            rp.resource_parent_id,
            rp.scheduling_proficiency
        FROM clean_data.resource_parent rp
        INNER JOIN parent_hierarchy ph ON rp.resource_seq = ph.resource_parent_seq
        WHERE ph.level < 10  -- Limite de profondeur pour éviter les boucles infinies
    )
    SELECT * FROM parent_hierarchy ORDER BY level;
END;
$function$
;
