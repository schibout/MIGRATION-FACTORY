-- =============================================================================
-- Module Articles : ajout du suffixe '-1' sur part_no -- ARTICLES REBUT SEULS
-- =============================================================================
-- Ajoute '-1' a la fin de la colonne part_no, UNIQUEMENT pour les articles de
-- type rebut, dans les 7 tables cibles du module article.
-- AUCUNE autre colonne n'est modifiee.
--
-- Definition retenue de "article rebut" :
--   part_no commencant par 'R' dans la codification IFS.
--   La 1re lettre du code IFS porte la famille, la 2e la forme :
--     RB- rebut divers / RF- fil / RL- lingot / RP- plaque / RT- te
--   Toutes ces lignes portent une description "Rebuts et Dechets ...".
--   Volumetrie constatee : 409 articles sur 2180 dans part_catalog.
--
-- Tables et colonne concernees :
--   part_catalog, inventory_part, invent_part_plan, purchase_part,
--   purchase_part_supplier, sales_part, manuf_part_attribute -> part_no
--
-- NON touche volontairement (demande explicite : part_no seul) :
--   sales_part.catalog_no, sales_part.purchase_part_no,
--   sales_part.replacement_part_no, purchase_part_supplier.vendor_part_no
--   -> les references internes de sales_part ne pointeront donc plus sur
--      part_no pour les articles rebut. A traiter separement si besoin.
--
-- Garde d'idempotence : les valeurs se terminant deja par '-1' sont ignorees,
-- le script peut donc etre rejoue sans empiler '_1_1'.
--
-- Longueur : part_no est en VARCHAR(25). Le plus long part_no rebut fait
-- 15 caracteres, la marge est large ; le controle prealable reste en place.
--
-- ATTENTION coherence : part_no est reference hors module (nomenclatures,
-- operations, pm_action, exports deja generes). Ce renommage ne propage RIEN
-- en dehors des 7 tables listees.
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- --- 1. Controle prealable -------------------------------------------------
-- a) part_no rebut trop longs pour recevoir '-1' : doit renvoyer 0 ligne.
SELECT 'part_catalog' AS table_name, part_no AS valeur
  FROM clean_data.part_catalog           WHERE part_no ~ '^R' AND length(part_no) > 23
UNION ALL SELECT 'inventory_part', part_no
  FROM clean_data.inventory_part         WHERE part_no ~ '^R' AND length(part_no) > 23
UNION ALL SELECT 'invent_part_plan', part_no
  FROM clean_data.invent_part_plan       WHERE part_no ~ '^R' AND length(part_no) > 23
UNION ALL SELECT 'purchase_part', part_no
  FROM clean_data.purchase_part          WHERE part_no ~ '^R' AND length(part_no) > 23
UNION ALL SELECT 'purchase_part_supplier', part_no
  FROM clean_data.purchase_part_supplier WHERE part_no ~ '^R' AND length(part_no) > 23
UNION ALL SELECT 'sales_part', part_no
  FROM clean_data.sales_part             WHERE part_no ~ '^R' AND length(part_no) > 23
UNION ALL SELECT 'manuf_part_attribute', part_no
  FROM clean_data.manuf_part_attribute   WHERE part_no ~ '^R' AND length(part_no) > 23;

-- b) Volumetrie a modifier, a comparer avec l'attendu (409 / table alimentee).
SELECT 'part_catalog' AS table_name, count(*) AS a_modifier
  FROM clean_data.part_catalog           WHERE part_no ~ '^R'
UNION ALL SELECT 'inventory_part', count(*)
  FROM clean_data.inventory_part         WHERE part_no ~ '^R'
UNION ALL SELECT 'invent_part_plan', count(*)
  FROM clean_data.invent_part_plan       WHERE part_no ~ '^R'
UNION ALL SELECT 'purchase_part', count(*)
  FROM clean_data.purchase_part          WHERE part_no ~ '^R'
UNION ALL SELECT 'purchase_part_supplier', count(*)
  FROM clean_data.purchase_part_supplier WHERE part_no ~ '^R'
UNION ALL SELECT 'sales_part', count(*)
  FROM clean_data.sales_part             WHERE part_no ~ '^R'
UNION ALL SELECT 'manuf_part_attribute', count(*)
  FROM clean_data.manuf_part_attribute   WHERE part_no ~ '^R';

-- --- 2. Renommage (articles rebut uniquement) ------------------------------
-- LIKE '%\-1' : '\_' echappe le underscore (sinon '_' = joker un caractere).

UPDATE clean_data.part_catalog
   SET part_no = part_no || '-1'
 WHERE part_no ~ '^R'
   AND part_no NOT LIKE '%\-1';

UPDATE clean_data.inventory_part
   SET part_no = part_no || '-1'
 WHERE part_no ~ '^R'
   AND part_no NOT LIKE '%\-1';

UPDATE clean_data.invent_part_plan
   SET part_no = part_no || '-1'
 WHERE part_no ~ '^R'
   AND part_no NOT LIKE '%\-1';

UPDATE clean_data.purchase_part
   SET part_no = part_no || '-1'
 WHERE part_no ~ '^R'
   AND part_no NOT LIKE '%\-1';

UPDATE clean_data.purchase_part_supplier
   SET part_no = part_no || '-1'
 WHERE part_no ~ '^R'
   AND part_no NOT LIKE '%\-1';

UPDATE clean_data.sales_part
   SET part_no = part_no || '-1'
 WHERE part_no ~ '^R'
   AND part_no NOT LIKE '%\-1';

UPDATE clean_data.manuf_part_attribute
   SET part_no = part_no || '-1'
 WHERE part_no ~ '^R'
   AND part_no NOT LIKE '%\-1';

-- --- 3. Controle final -----------------------------------------------------
-- restant = 0 (aucun rebut sans suffixe) et suffixes = volumetrie de l'etape 1b.
SELECT 'part_catalog' AS table_name,
       count(*) FILTER (WHERE part_no NOT LIKE '%\-1') AS restant,
       count(*) FILTER (WHERE part_no LIKE '%\-1')     AS suffixes
  FROM clean_data.part_catalog           WHERE part_no ~ '^R'
UNION ALL SELECT 'inventory_part',
       count(*) FILTER (WHERE part_no NOT LIKE '%\-1'),
       count(*) FILTER (WHERE part_no LIKE '%\-1')
  FROM clean_data.inventory_part         WHERE part_no ~ '^R'
UNION ALL SELECT 'invent_part_plan',
       count(*) FILTER (WHERE part_no NOT LIKE '%\-1'),
       count(*) FILTER (WHERE part_no LIKE '%\-1')
  FROM clean_data.invent_part_plan       WHERE part_no ~ '^R'
UNION ALL SELECT 'purchase_part',
       count(*) FILTER (WHERE part_no NOT LIKE '%\-1'),
       count(*) FILTER (WHERE part_no LIKE '%\-1')
  FROM clean_data.purchase_part          WHERE part_no ~ '^R'
UNION ALL SELECT 'purchase_part_supplier',
       count(*) FILTER (WHERE part_no NOT LIKE '%\-1'),
       count(*) FILTER (WHERE part_no LIKE '%\-1')
  FROM clean_data.purchase_part_supplier WHERE part_no ~ '^R'
UNION ALL SELECT 'sales_part',
       count(*) FILTER (WHERE part_no NOT LIKE '%\-1'),
       count(*) FILTER (WHERE part_no LIKE '%\-1')
  FROM clean_data.sales_part             WHERE part_no ~ '^R'
UNION ALL SELECT 'manuf_part_attribute',
       count(*) FILTER (WHERE part_no NOT LIKE '%\-1'),
       count(*) FILTER (WHERE part_no LIKE '%\-1')
  FROM clean_data.manuf_part_attribute   WHERE part_no ~ '^R';

-- Verifier les controles ci-dessus, puis :
COMMIT;
-- En cas de doute : ROLLBACK;
