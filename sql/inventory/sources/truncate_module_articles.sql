-- =============================================================================
-- Module Articles (inventory) : vidage complet des tables cibles clean_data
-- =============================================================================
-- Perimetre : tables alimentees par les procedures de sql/inventory/*.sql
--             (etl_inventory_part.py) ET par sql/articlePhl/*.sql
--             (etl_phl_article.py, articles PHL charges en append).
--
-- ATTENTION : operation DESTRUCTIVE et non annulable une fois committee.
--             Elle vide AUSSI les articles PHL et les ajouts manuels
--             (ex. ajouter_article_silicium.sql) : il faut rejouer
--             l'integralite du pipeline articles ensuite.
--
-- raw_data n'est jamais touche (lecture seule).
--
-- Rejeu apres truncate :
--   SELECT clean_data.alimenter_ifs_article();
--   SELECT clean_data.alimenter_part_catalog();
--   SELECT clean_data.alimenter_inventory_part();
--   SELECT clean_data.alimenter_inventory_part_planning();
--   SELECT clean_data.alimenter_purchase_part();
--   SELECT clean_data.alimenter_purchase_part_supplier();
--   SELECT clean_data.alimenter_sales_part();
--   SELECT clean_data.alimenter_all_phl();          -- articles PHL (append)
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- --- Etat AVANT ------------------------------------------------------------
SELECT 'AVANT' AS phase, 'ifs_article_maitre'     AS table_name, count(*) FROM clean_data.ifs_article_maitre
UNION ALL SELECT 'AVANT', 'part_catalog',           count(*) FROM clean_data.part_catalog
UNION ALL SELECT 'AVANT', 'inventory_part',         count(*) FROM clean_data.inventory_part
UNION ALL SELECT 'AVANT', 'invent_part_plan',       count(*) FROM clean_data.invent_part_plan
UNION ALL SELECT 'AVANT', 'purchase_part',          count(*) FROM clean_data.purchase_part
UNION ALL SELECT 'AVANT', 'purchase_part_supplier', count(*) FROM clean_data.purchase_part_supplier
UNION ALL SELECT 'AVANT', 'sales_part',             count(*) FROM clean_data.sales_part
UNION ALL SELECT 'AVANT', 'manuf_part_attribute',   count(*) FROM clean_data.manuf_part_attribute;

-- --- Vidage ----------------------------------------------------------------
-- Un seul TRUNCATE multi-tables : PostgreSQL gere ainsi les dependances
-- mutuelles entre ces tables sans avoir a ordonner les suppressions.
-- Pas de CASCADE volontairement : si une FK externe au module existe,
-- la commande doit echouer bruyamment plutot que vider une table hors perimetre.
TRUNCATE TABLE
    clean_data.manuf_part_attribute,
    clean_data.purchase_part_supplier,
    clean_data.purchase_part,
    clean_data.sales_part,
    clean_data.invent_part_plan,
    clean_data.inventory_part,
    clean_data.part_catalog
RESTART IDENTITY;

-- --- Etat APRES ------------------------------------------------------------
SELECT 'APRES' AS phase, 'ifs_article_maitre'     AS table_name, count(*) FROM clean_data.ifs_article_maitre
UNION ALL SELECT 'APRES', 'part_catalog',           count(*) FROM clean_data.part_catalog
UNION ALL SELECT 'APRES', 'inventory_part',         count(*) FROM clean_data.inventory_part
UNION ALL SELECT 'APRES', 'invent_part_plan',       count(*) FROM clean_data.invent_part_plan
UNION ALL SELECT 'APRES', 'purchase_part',          count(*) FROM clean_data.purchase_part
UNION ALL SELECT 'APRES', 'purchase_part_supplier', count(*) FROM clean_data.purchase_part_supplier
UNION ALL SELECT 'APRES', 'sales_part',             count(*) FROM clean_data.sales_part
UNION ALL SELECT 'APRES', 'manuf_part_attribute',   count(*) FROM clean_data.manuf_part_attribute;

-- Verifier les compteurs ci-dessus, puis :
COMMIT;
-- En cas de doute : ROLLBACK;
