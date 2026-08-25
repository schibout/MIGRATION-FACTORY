CREATE OR REPLACE FUNCTION clean_data.pe_num(p_text text)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
AS $function$
    SELECT CASE
        WHEN p_text IS NULL THEN NULL
        WHEN btrim(p_text) ~ '^-?[0-9]+(\.[0-9]+)?$' THEN btrim(p_text)::numeric
        ELSE NULL
    END;
$function$
;
