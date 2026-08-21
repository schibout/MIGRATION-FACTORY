-- ============================================================================
-- Export immédiat de TOUT l'inventaire des textes de commande (TDID = BEST)
-- Disponible tout de suite : ces données sont déjà dans raw_data.stxh.
-- ATTENTION : c'est l'inventaire (qui a un texte, combien de lignes),
--             PAS le contenu. Le contenu passe par extract_textes_longs_sap.py
-- À exécuter via psql :  psql "$PG_DSN" -f 03_export_inventaire_stxh.sql
-- ============================================================================

\copy (                                                                        \
  SELECT h.tdname                 AS matnr_sap_18,                             \
         ltrim(h.tdname, '0')     AS matnr,                                    \
         t.maktx                  AS designation,                              \
         h.tdid                   AS type_texte,                               \
         h.tdspras                AS langue,                                   \
         h.tdtitle                AS titre,                                    \
         h.tdtxtlines::int        AS nb_lignes,                                \
         h.tdfdate                AS date_creation,                            \
         h.tdldate                AS date_modif,                               \
         h.tdluser                AS modif_par                                 \
  FROM   raw_data.stxh h                                                       \
  LEFT   JOIN raw_data.makt t ON t.matnr = h.tdname AND t.spras = h.tdspras    \
  WHERE  h.tdobject = 'MATERIAL'                                               \
    AND  h.tdid     = 'BEST'                                                   \
  ORDER  BY h.tdspras, h.tdname                                                \
) TO 'inventaire_textes_commande.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';')


-- ============================================================================
-- Variante : les 4 types de texte d'un coup
-- ============================================================================
-- \copy (
--   SELECT h.tdname, ltrim(h.tdname,'0') AS matnr, t.maktx, h.tdid, h.tdspras,
--          h.tdtxtlines::int AS nb_lignes
--   FROM raw_data.stxh h
--   LEFT JOIN raw_data.makt t ON t.matnr = h.tdname AND t.spras = h.tdspras
--   WHERE h.tdobject = 'MATERIAL' AND h.tdid IN ('GRUN','BEST','PRUE','IVER')
--   ORDER BY h.tdid, h.tdspras, h.tdname
-- ) TO 'inventaire_textes_material.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';')


-- ============================================================================
-- Après extraction : le texte de commande complet, reconstitué article par article
-- (à exécuter une fois raw_data.sap_material_text alimentée)
-- ============================================================================
-- SELECT x.matnr,
--        t.maktx AS designation,
--        x.tdspras AS langue,
--        string_agg(x.tdline, E'\n' ORDER BY x.line_no::int) AS texte_commande
-- FROM   raw_data.sap_material_text x
-- LEFT   JOIN raw_data.makt t ON t.matnr = x.tdname AND t.spras = x.tdspras
-- WHERE  x.tdid = 'BEST'
-- GROUP  BY x.matnr, t.maktx, x.tdspras
-- ORDER  BY x.matnr;
