-- Articles a migrer venant de la maintenance (regle du 2026-11-24), toutes categories :
--   MAINTENANCE_EQUIPEMENT        : article d'un equipement actif de la structure IH02 (objet serie IFS).
--                       Meme regle que sql/maintenance/alimenter_equipment_serial.sql :
--                       n° article saisi / importe (liens), sinon equi.matnr, sinon type de
--                       construction de la periode EQUZ courante ; equipements INAK (I0320) ou
--                       marques pour suppression (I0076) exclus. Un equipement sans article
--                       n'a pas de ligne : il faut d'abord le lier a un article.
--   MAINTENANCE_IBAU    : sous-ensemble IBAU d'une nomenclature IH02 active
--   MAINTENANCE_ARTICLE : autre article d'une nomenclature IH02 active (composant ou kit)
-- Une ligne par article, MAINTENANCE_EQUIPEMENT prioritaire. Les libelles saisis a la main a la place
-- d'un n° (espaces, plus de 25 caracteres) sont refuses par IFS et ecartes.
-- Lue par alimenter_article_perimetre() et alimenter_article_sap().
CREATE OR REPLACE VIEW clean_data.v_article_structure AS
WITH archive AS MATERIALIZED (
    SELECT DISTINCT q.equnr
      FROM raw_data.equi q
      JOIN raw_data.jest j ON j.mandt = q.mandt AND j.objnr = q.objnr
     WHERE q.mandt = '700'
       AND j.stat IN ('I0320', 'I0076')
       AND (j.inact IS NULL OR TRIM(j.inact) <> 'X')
), construction AS MATERIALIZED (
    SELECT DISTINCT ON (equnr) equnr, NULLIF(LTRIM(TRIM(submt), '0'), '') AS submt
      FROM raw_data.equz
     WHERE mandt = '700'
     ORDER BY equnr, datbi DESC
), candidats AS (
    SELECT COALESCE(NULLIF(LTRIM(TRIM(COALESCE(o.attributes->>'matnr', q.matnr)), '0'), ''),
                    z.submt) AS numero_article,
           'MAINTENANCE_EQUIPEMENT' AS source
      FROM clean_data.maintenance_object o
      LEFT JOIN raw_data.equi q ON q.mandt = '700' AND q.equnr = o.sap_key
      LEFT JOIN construction z ON z.equnr = o.sap_key
     WHERE o.object_type = 'EQUIPMENT' AND o.is_active
       AND NOT EXISTS (SELECT 1 FROM archive x WHERE x.equnr = o.sap_key)
    UNION
    -- composant (ref_object_id) et kit (parent) de chaque ligne de nomenclature active
    SELECT LTRIM(TRIM(a.sap_key), '0'),
           CASE WHEN m.mtart::text = 'IBAU' THEN 'MAINTENANCE_IBAU' ELSE 'MAINTENANCE_ARTICLE' END
      FROM clean_data.maintenance_object b
      JOIN clean_data.maintenance_object a
        ON a.id IN (b.ref_object_id, b.parent_id) AND a.object_type = 'ARTICLE' AND a.is_active
      LEFT JOIN raw_data.mara m ON m.mandt::text = '700' AND m.matnr::text = a.sap_key
     WHERE b.object_type = 'BOM_ITEM' AND b.is_active
)
SELECT DISTINCT ON (numero_article) numero_article, source
  FROM candidats
 WHERE numero_article ~ '^\S{1,25}$'
 ORDER BY numero_article, (source = 'MAINTENANCE_EQUIPEMENT') DESC;

COMMENT ON VIEW clean_data.v_article_structure IS
'Articles des equipements actifs (MAINTENANCE_EQUIPEMENT) et des nomenclatures IH02 (MAINTENANCE_IBAU, MAINTENANCE_ARTICLE) a migrer ; regles dans sql/articleSap/v_article_structure.sql.';
