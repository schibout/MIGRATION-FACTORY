-- =====================================================
-- Ne garder actif que le module ETL "Client du Fichier PHL"
-- (etl_file_customer.py) parmi les modules du domaine IFS_Customers.
--
-- Desactive : etl_customer.py (Client SAP) et etl_phl_customer.py (Client PHL).
-- Les autres domaines (fournisseurs, articles, projets, maintenance) ne sont
-- PAS touches. Script idempotent.
-- =====================================================

BEGIN;

UPDATE etl_target_tables
SET is_active     = false,
   ,
    last_modified = CURRENT_TIMESTAMP
WHERE python_module IN ('etl_customer.py', 'etl_phl_customer.py')
  AND is_active IS DISTINCT FROM false;

UPDATE etl_target_tables
SET is_active     = true,
    last_modified = CURRENT_TIMESTAMP
WHERE python_module = 'etl_file_customer.py'
  AND is_active IS DISTINCT FROM true;

-- Controle
SELECT id, table_name, display_name, python_module, is_active
FROM etl_target_tables
WHERE domaine_fonctionnel = 'IFS_Customers'
   OR python_module IN ('etl_customer.py', 'etl_phl_customer.py', 'etl_file_customer.py')
ORDER BY id;

COMMIT;
