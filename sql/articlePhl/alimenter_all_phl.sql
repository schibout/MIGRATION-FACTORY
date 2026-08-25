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
$function$
;
