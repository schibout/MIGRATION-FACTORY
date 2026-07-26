-- Fonction pour rafraîchir v_fournisseurs_enrichis lorsque c'est une vue matérialisée.
-- Si l'objet est une vue normale (scripts actuels), aucun REFRESH : retour du rowcount seulement.

DROP FUNCTION IF EXISTS public.refresh_v_fournisseurs_enrichis(boolean);
DROP FUNCTION IF EXISTS clean_data.refresh_v_fournisseurs_enrichis(boolean);

CREATE OR REPLACE FUNCTION clean_data.refresh_v_fournisseurs_enrichis(p_concurrent boolean DEFAULT true)
 RETURNS TABLE(status character varying, duration_seconds numeric, rows_count bigint, last_refresh timestamp without time zone)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration NUMERIC;
    v_count BIGINT;
    v_error_msg TEXT;
    v_is_matview boolean;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;

    SELECT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_class c
        JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'clean_data'
          AND c.relname = 'v_fournisseurs_enrichis'
          AND c.relkind = 'm'
    ) INTO v_is_matview;

    IF NOT v_is_matview THEN
        SELECT COUNT(*) INTO v_count FROM clean_data.v_fournisseurs_enrichis;
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := EXTRACT(EPOCH FROM (v_end_time - v_start_time));
        RETURN QUERY SELECT
            'SKIPPED_REGULAR_VIEW'::VARCHAR(50),
            v_duration,
            v_count,
            v_end_time;
        RETURN;
    END IF;
    
    -- Tentative de rafraîchissement concurrent (plus rapide)
    IF p_concurrent THEN
        BEGIN
            REFRESH MATERIALIZED VIEW CONCURRENTLY clean_data.v_fournisseurs_enrichis;
            v_end_time := CURRENT_TIMESTAMP;
            v_duration := EXTRACT(EPOCH FROM (v_end_time - v_start_time));
            
            SELECT COUNT(*) INTO v_count FROM clean_data.v_fournisseurs_enrichis;
            
            RETURN QUERY SELECT 
                'SUCCESS_CONCURRENT'::VARCHAR(50),
                v_duration,
                v_count,
                v_end_time;
            RETURN;
            
        EXCEPTION WHEN OTHERS THEN
            v_error_msg := SQLERRM;
            RAISE NOTICE 'Rafraîchissement concurrent échoué: %. Tentative standard...', v_error_msg;
        END;
    END IF;
    
    -- Rafraîchissement standard (bloquant mais sûr)
    REFRESH MATERIALIZED VIEW clean_data.v_fournisseurs_enrichis;
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
    SELECT COUNT(*) INTO v_count FROM clean_data.v_fournisseurs_enrichis;
    
    RETURN QUERY SELECT 
        'SUCCESS_STANDARD'::VARCHAR(50),
        v_duration,
        v_count,
        v_end_time;

EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
        'ERROR'::VARCHAR(50),
        EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time)),
        0::BIGINT,
        CURRENT_TIMESTAMP;
END;
$function$
