-- Articles envoyes vers IFS (part_catalog, inventory_part, purchase_part,
-- purchase_part_supplier) : ceux du perimetre Finance > Articles qui existent dans
-- SAP (raw_data.mara, mandant 700) et ne sont pas marques pour suppression (lvorm).
-- Regle du 2026-11-27 : les articles absents de SAP viennent de PHL (autre equipe,
-- autres fichiers) et les articles marques pour suppression sont exclus.
-- Remplace clean_data.ifs_article_maitre comme base des chargements sql/inventory/ :
-- memes colonnes numero_article (MATNR SAP, zeros de tete compris) et designation
-- (vide : les chargements lisent makt, puis le numero).
CREATE OR REPLACE VIEW clean_data.v_article_perimetre_sap AS
SELECT m.matnr::text      AS numero_article,
       NULL::varchar      AS designation,
       p.numero_article   AS part_no
  FROM clean_data.article_perimetre p
  JOIN raw_data.mara m
    ON m.mandt::text = '700'
   AND m.matnr::text = CASE WHEN p.numero_article ~ '^[0-9]+$'
                            THEN LPAD(p.numero_article, 18, '0')
                            ELSE p.numero_article END
 WHERE m.lvorm IS NULL OR TRIM(m.lvorm) = '';

COMMENT ON VIEW clean_data.v_article_perimetre_sap IS
'Articles du perimetre Finance > Articles presents dans SAP (mara) et non marques pour suppression : base de part_catalog et des tables filles. Regles dans sql/articleSap/v_article_perimetre_sap.sql.';
