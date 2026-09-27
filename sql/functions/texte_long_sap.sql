-- ============================================================================
-- clean_data.texte_long_sap(objet, id, nom, langues)
-- ----------------------------------------------------------------------------
-- Recompose un texte long SAP a partir de raw_data.sap_long_text (une ligne
-- SAPscript par enregistrement, lue par RFC_READ_TEXT, cf.
-- scripts/texteSurCommande/), pour une colonne IFS de type note (2000 car.).
--
--   p_objet   : STXH.TDOBJECT (MATERIAL, EINA, EINE, ...)
--   p_id      : STXH.TDID     (BEST, GRUN, AT, BT, ...)
--   p_nom     : STXH.TDNAME   (MATNR sur 18, INFNR, INFNR||EKORG||ESOKZ||WERKS...)
--   p_langues : langues SAP internes par ordre de preference ; la premiere
--               qui a un texte est retenue (ex. ARRAY['F','E','D','N']).
--
-- Regles SAPscript : '*', '/' et format vide = nouvelle ligne ; '=' = suite
-- de la ligne precedente sans saut ; '/:' (commande) et '/*' (commentaire)
-- ignores. Espaces de fin de ligne retires, btrim (espaces ET sauts : TRIM
-- seul ne retire pas le '\n' de tete), LEFT 2000. NULL si aucune ligne.
-- STABLE : appelable dans un SELECT de chargement sans re-planification.
-- ============================================================================
CREATE OR REPLACE FUNCTION clean_data.texte_long_sap(
    p_objet   TEXT,
    p_id      TEXT,
    p_nom     TEXT,
    p_langues TEXT[] DEFAULT ARRAY['F']
) RETURNS TEXT
LANGUAGE sql
STABLE
AS $function$
    SELECT NULLIF(LEFT(btrim(regexp_replace(
               string_agg(
                   CASE WHEN x.tdformat = '=' THEN x.tdline
                        ELSE E'\n' || x.tdline END,
                   '' ORDER BY x.line_no::int),
               E'[ \t]+\n', E'\n', 'g'), E' \t\r\n'), 2000), '')
    FROM raw_data.sap_long_text x
    WHERE x.tdobject = p_objet
      AND x.tdid     = p_id
      AND x.tdname   = p_nom
      AND x.tdspras  = (
            -- premiere langue de la liste qui a au moins une ligne
            SELECT l.langue
            FROM unnest(p_langues) WITH ORDINALITY AS l(langue, rang)
            WHERE EXISTS (SELECT 1 FROM raw_data.sap_long_text y
                          WHERE y.tdobject = p_objet AND y.tdid = p_id
                            AND y.tdname = p_nom AND y.tdspras = l.langue)
            ORDER BY l.rang
            LIMIT 1)
      AND COALESCE(x.tdformat, '') NOT IN ('/:', '/*');
$function$;

COMMENT ON FUNCTION clean_data.texte_long_sap(TEXT, TEXT, TEXT, TEXT[]) IS
    'Texte long SAP recompose depuis raw_data.sap_long_text (SAPscript -> texte multi-lignes, 2000 car. max), premiere langue disponible de la liste.';
