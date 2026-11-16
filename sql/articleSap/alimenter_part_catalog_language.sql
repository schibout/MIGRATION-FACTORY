-- Alimente clean_data.part_catalog_language (vue IFS PART_CATALOG_LANGUAGE) :
-- une ligne par article de clean_data.part_catalog ayant une designation
-- anglaise dans SAP (raw_data.makt, spras = 'E'), code langue IFS 'en'.
-- Un article sans designation anglaise n'a pas de ligne.
-- Lancee en fin de module Article SAP (backend/etl_modules/etl_article_sap.py),
-- apres alimenter_part_catalog_sap(). Table migration 135.
CREATE OR REPLACE FUNCTION clean_data.alimenter_part_catalog_language()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_count INTEGER := 0;
BEGIN
    TRUNCATE TABLE clean_data.part_catalog_language;

    -- part_no sans zeros de tete, makt.matnr numerique complete a 18 chiffres
    -- (meme correspondance que alimenter_part_catalog_sap).
    INSERT INTO clean_data.part_catalog_language (part_no, language_code, description)
    SELECT p.part_no, 'en', SUBSTRING(TRIM(k.maktx), 1, 200)
    FROM clean_data.part_catalog p
    JOIN raw_data.makt k
      ON k.mandt::text = '700'
     AND k.spras::text = 'E'
     AND k.matnr::text = CASE WHEN p.part_no ~ '^[0-9]+$'
                              THEN LPAD(p.part_no, 18, '0')
                              ELSE p.part_no END
    WHERE NULLIF(TRIM(k.maktx), '') IS NOT NULL
    ORDER BY p.part_no
    ON CONFLICT (part_no, language_code) DO NOTHING;
    GET DIAGNOSTICS v_count = ROW_COUNT;

    RAISE NOTICE 'PART_CATALOG_LANGUAGE : % designations anglaises inserees', v_count;
    RETURN v_count;
END;
$function$
;
