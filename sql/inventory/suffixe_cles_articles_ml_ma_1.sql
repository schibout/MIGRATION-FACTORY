-- =============================================================================
-- Module Articles : suffixe '-1' sur part_no -- FAMILLES 'ML' ET 'MA' SEULES
-- =============================================================================
-- Meme principe que suffixe_cles_articles_1.sql (rebuts), avec un autre
-- critere de selection : les articles dont le code famille est 'ML' ou 'MA'.
--
-- Definition retenue du "code famille" :
--   les 2 premiers caracteres de la codification IFS (= part_no), comme pour
--   les rebuts ou 'RF'/'RP'/'RL'/'RT' identifient la famille.
--   Correspond a clean_data.mapping_codification_articles.categorie.
--
-- /!\ CONSTAT AU 2026-08-10, A LIRE AVANT D'EXECUTER :
--   - categorie 'MA' : 101 articles dans mapping_codification_articles
--     (ALUMINA, MAGNESIUM EN LINGOTS, ALUMINIUM LIQUIDE...), codification
--     'MA-...' ; AUCUN n'est present dans part_catalog / inventory_part /
--     sales_part / manuf_part_attribute -> 0 ligne a modifier.
--   - categorie 'ML' : INTROUVABLE en base (ni dans mapping_codification_articles,
--     ni dans aucun part_no) -> 0 ligne a modifier.
--   Le script est donc actuellement SANS EFFET. Il devient utile si ces
--   familles sont chargees plus tard, ou apres correction du critere
--   (cf. bloc de controle 1b : il affiche la volumetrie reelle).
--
-- Tables et colonne concernees (part_no uniquement, comme demande) :
--   part_catalog, inventory_part, invent_part_plan, purchase_part,
--   purchase_part_supplier, sales_part, manuf_part_attribute
--
-- Garde d'idempotence : les valeurs se terminant deja par '-1' sont ignorees.
-- Longueur : part_no est en VARCHAR(25), le controle 1a bloque les cas limites.
-- Coherence : ce renommage ne propage RIEN hors des 7 tables listees.
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- --- 1a. Controle prealable : part_no trop longs pour recevoir '-1' --------
-- Doit renvoyer 0 ligne. Sinon : ROLLBACK et traiter ces cles a la main.
SELECT 'part_catalog' AS table_name, part_no AS valeur
  FROM clean_data.part_catalog           WHERE part_no ~ '^(ML|MA)' AND length(part_no) > 23
UNION ALL SELECT 'inventory_part', part_no
  FROM clean_data.inventory_part         WHERE part_no ~ '^(ML|MA)' AND length(part_no) > 23
UNION ALL SELECT 'invent_part_plan', part_no
  FROM clean_data.invent_part_plan       WHERE part_no ~ '^(ML|MA)' AND length(part_no) > 23
UNION ALL SELECT 'purchase_part', part_no
  FROM clean_data.purchase_part          WHERE part_no ~ '^(ML|MA)' AND length(part_no) > 23
UNION ALL SELECT 'purchase_part_supplier', part_no
  FROM clean_data.purchase_part_supplier WHERE part_no ~ '^(ML|MA)' AND length(part_no) > 23
UNION ALL SELECT 'sales_part', part_no
  FROM clean_data.sales_part             WHERE part_no ~ '^(ML|MA)' AND length(part_no) > 23
UNION ALL SELECT 'manuf_part_attribute', part_no
  FROM clean_data.manuf_part_attribute   WHERE part_no ~ '^(ML|MA)' AND length(part_no) > 23;

-- --- 1b. Volumetrie a modifier --------------------------------------------
-- Si tout est a 0, le critere ne correspond a rien : ROLLBACK et revoir le
-- predicat plutot que de committer une transaction vide.
SELECT 'part_catalog' AS table_name, count(*) AS a_modifier
  FROM clean_data.part_catalog           WHERE part_no ~ '^(ML|MA)'
UNION ALL SELECT 'inventory_part', count(*)
  FROM clean_data.inventory_part         WHERE part_no ~ '^(ML|MA)'
UNION ALL SELECT 'invent_part_plan', count(*)
  FROM clean_data.invent_part_plan       WHERE part_no ~ '^(ML|MA)'
UNION ALL SELECT 'purchase_part', count(*)
  FROM clean_data.purchase_part          WHERE part_no ~ '^(ML|MA)'
UNION ALL SELECT 'purchase_part_supplier', count(*)
  FROM clean_data.purchase_part_supplier WHERE part_no ~ '^(ML|MA)'
UNION ALL SELECT 'sales_part', count(*)
  FROM clean_data.sales_part             WHERE part_no ~ '^(ML|MA)'
UNION ALL SELECT 'manuf_part_attribute', count(*)
  FROM clean_data.manuf_part_attribute   WHERE part_no ~ '^(ML|MA)';

-- --- 2. Renommage (familles ML et MA uniquement) ---------------------------
-- LIKE '%\-1' : '\_' echappe le underscore (sinon '_' = joker un caractere).

UPDATE clean_data.part_catalog
   SET part_no = part_no || '-1'
 WHERE part_no ~ '^(ML|MA)'
   AND part_no NOT LIKE '%\-1';

UPDATE clean_data.inventory_part
   SET part_no = part_no || '-1'
 WHERE part_no ~ '^(ML|MA)'
   AND part_no NOT LIKE '%\-1';

UPDATE clean_data.invent_part_plan
   SET part_no = part_no || '-1'
 WHERE part_no ~ '^(ML|MA)'
   AND part_no NOT LIKE '%\-1';

UPDATE clean_data.purchase_part
   SET part_no = part_no || '-1'
 WHERE part_no ~ '^(ML|MA)'
   AND part_no NOT LIKE '%\-1';

UPDATE clean_data.purchase_part_supplier
   SET part_no = part_no || '-1'
 WHERE part_no ~ '^(ML|MA)'
   AND part_no NOT LIKE '%\-1';

UPDATE clean_data.sales_part
   SET part_no = part_no || '-1'
 WHERE part_no ~ '^(ML|MA)'
   AND part_no NOT LIKE '%\-1';

UPDATE clean_data.manuf_part_attribute
   SET part_no = part_no || '-1'
 WHERE part_no ~ '^(ML|MA)'
   AND part_no NOT LIKE '%\-1';

-- --- 3. Controle final -----------------------------------------------------
-- restant = 0 et suffixes = volumetrie relevee en 1b.
SELECT 'part_catalog' AS table_name,
       count(*) FILTER (WHERE part_no NOT LIKE '%\-1') AS restant,
       count(*) FILTER (WHERE part_no LIKE '%\-1')     AS suffixes
  FROM clean_data.part_catalog           WHERE part_no ~ '^(ML|MA)'
UNION ALL SELECT 'inventory_part',
       count(*) FILTER (WHERE part_no NOT LIKE '%\-1'),
       count(*) FILTER (WHERE part_no LIKE '%\-1')
  FROM clean_data.inventory_part         WHERE part_no ~ '^(ML|MA)'
UNION ALL SELECT 'invent_part_plan',
       count(*) FILTER (WHERE part_no NOT LIKE '%\-1'),
       count(*) FILTER (WHERE part_no LIKE '%\-1')
  FROM clean_data.invent_part_plan       WHERE part_no ~ '^(ML|MA)'
UNION ALL SELECT 'purchase_part',
       count(*) FILTER (WHERE part_no NOT LIKE '%\-1'),
       count(*) FILTER (WHERE part_no LIKE '%\-1')
  FROM clean_data.purchase_part          WHERE part_no ~ '^(ML|MA)'
UNION ALL SELECT 'purchase_part_supplier',
       count(*) FILTER (WHERE part_no NOT LIKE '%\-1'),
       count(*) FILTER (WHERE part_no LIKE '%\-1')
  FROM clean_data.purchase_part_supplier WHERE part_no ~ '^(ML|MA)'
UNION ALL SELECT 'sales_part',
       count(*) FILTER (WHERE part_no NOT LIKE '%\-1'),
       count(*) FILTER (WHERE part_no LIKE '%\-1')
  FROM clean_data.sales_part             WHERE part_no ~ '^(ML|MA)'
UNION ALL SELECT 'manuf_part_attribute',
       count(*) FILTER (WHERE part_no NOT LIKE '%\-1'),
       count(*) FILTER (WHERE part_no LIKE '%\-1')
  FROM clean_data.manuf_part_attribute   WHERE part_no ~ '^(ML|MA)';

-- Verifier les controles ci-dessus, puis :
COMMIT;
-- En cas de doute : ROLLBACK;
