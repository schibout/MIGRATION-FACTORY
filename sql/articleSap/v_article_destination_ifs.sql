-- Destination IFS simulee de chaque article de clean_data.article_perimetre (ecran
-- Finance > Articles). SEUL endroit ou ces regles sont ecrites : pour en changer,
-- modifier ce fichier et le rejouer. Vue d'analyse : les loaders IFS ne la lisent pas.
--
-- Lit article_sap et non v_article_sap : v_article_sap.sql fait un DROP VIEW sans
-- CASCADE, qui echouerait si cette vue en dependait.
--
-- Regles (hypotheses du 2026-11-05, a confirmer par le metier) :
--   catalogue      : tout article connu de SAP
--   inventory      : classe d'actifs MAGASIN (ligne MARD non supprimee sur le site)
--   sales          : NULL = regle a definir (aucune vue de vente MVKE sur le perimetre)
--   piece_detachee : types IBAU et ERSA ; RATTACHEE s'ils sont dans une nomenclature
--                    d'equipement (equipment_object_spare), DECONNECTEE sinon
CREATE OR REPLACE VIEW clean_data.v_article_destination_ifs AS
WITH base AS (
    SELECT p.numero_article,
           COALESCE(a."Catégorie article", 'ABSENT') AS type_sap,
           val.nom_fichier AS fichier,
           COALESCE(NULLIF(a."Qté en stock", '')::numeric, 0) > 0 AS avec_stock,
           COALESCE(a."Classe d'actifs" = 'MAGASIN', FALSE) AS en_magasin,
           EXISTS (SELECT 1 FROM clean_data.equipment_object_spare s
                    WHERE s.spare_id = p.numero_article) AS en_nomenclature
      FROM clean_data.article_perimetre p
      LEFT JOIN clean_data.article_sap a ON a."N° article" = p.numero_article
      LEFT JOIN clean_data.article_perimetre_validation val ON val.numero_article = p.numero_article
)
SELECT b.*,
       b.type_sap <> 'ABSENT' AS catalogue,
       b.en_magasin AS inventory,
       NULL::boolean AS sales,
       CASE WHEN b.type_sap IN ('IBAU', 'ERSA')
            THEN CASE WHEN b.en_nomenclature THEN 'RATTACHEE' ELSE 'DECONNECTEE' END
       END AS piece_detachee
  FROM base b;

COMMENT ON VIEW clean_data.v_article_destination_ifs IS
'Destination IFS simulee des articles de article_perimetre (Finance > Articles) : catalogue, inventory, sales, piece_detachee. Regles dans sql/articleSap/v_article_destination_ifs.sql.';
