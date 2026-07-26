-- Orchestrateur : alimente toutes les tables cibles pour les articles PHL.
-- A executer APRES les procedures SAP (qui font le TRUNCATE des tables cibles).
-- Ordre impose : part_catalog en premier (table de base referencee par EXISTS).

CREATE OR REPLACE FUNCTION clean_data.alimenter_all_phl()
RETURNS void
LANGUAGE plpgsql
AS $function$
BEGIN
    RAISE NOTICE '############ DEBUT ALIMENTATION ARTICLES PHL ############';

    PERFORM clean_data.alimenter_part_catalog_phl();
    PERFORM clean_data.alimenter_inventory_part_phl();
    PERFORM clean_data.alimenter_sales_part_phl();
    PERFORM clean_data.alimenter_purchase_part_phl();
    PERFORM clean_data.alimenter_manuf_part_attribute_phl();

    RAISE NOTICE '############ FIN ALIMENTATION ARTICLES PHL ############';
END;
$function$;
