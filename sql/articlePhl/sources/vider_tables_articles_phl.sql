-- ============================================================================
-- Vidage complet des tables cibles du module ARTICLES PHL
--
-- ATTENTION : ces tables sont partagees avec le module Articles SAP.
-- Cette procedure supprime donc toutes les lignes SAP et PHL.
-- Les cinq tables sont tronquees dans une seule instruction, sans CASCADE,
-- afin de ne jamais vider implicitement une table exterieure au module.
-- ============================================================================

CREATE OR REPLACE PROCEDURE clean_data.vider_tables_articles_phl()
LANGUAGE plpgsql
AS $procedure$
BEGIN
    RAISE NOTICE 'Debut du vidage complet des tables Articles SAP/PHL';

    TRUNCATE TABLE
        clean_data.manuf_part_attribute,
        clean_data.sales_part,
        clean_data.purchase_part,
        clean_data.inventory_part,
        clean_data.part_catalog
    RESTART IDENTITY;

    RAISE NOTICE 'Tables videes : part_catalog, inventory_part, sales_part, purchase_part, manuf_part_attribute';
END;
$procedure$;

-- Execution volontaire :
-- CALL clean_data.vider_tables_articles_phl();
