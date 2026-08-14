-- =====================================================
-- Desactivation du module ETL "Donnees de base des Clients PHL" (id = 25)
-- Date: 2026-08-13
-- Effet : le module disparait de l'ecran /data-loading.
--         Le module Python (backend/etl_modules/etl_phl_customer.py), les
--         procedures clean_data.*_phl et les donnees restent en place.
-- Reactivation : rejouer add_etl_phl_customer_module.sql, ou passer
--         is_active = true ci-dessous.
-- =====================================================

UPDATE etl_target_tables
   SET is_active     = false,
       last_modified = CURRENT_TIMESTAMP
 WHERE id = 25;

-- Verification
SELECT id, display_name, python_module, is_active, domaine_fonctionnel
  FROM etl_target_tables
 WHERE id = 25;

-- Modules clients encore actifs apres l'operation
SELECT id, display_name, python_module, execution_order, display_order
  FROM etl_target_tables
 WHERE is_active = true
   AND (domaine_fonctionnel ILIKE '%custom%' OR display_name ILIKE '%client%')
 ORDER BY display_order, id;
