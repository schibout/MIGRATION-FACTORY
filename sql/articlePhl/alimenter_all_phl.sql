-- L'ancienne signature sans parametre doit disparaitre, sinon PostgreSQL cree une
-- surcharge et les appels sans argument deviennent ambigus.
DROP FUNCTION IF EXISTS clean_data.alimenter_all_phl();
CREATE OR REPLACE FUNCTION clean_data.alimenter_all_phl(p_contract text DEFAULT 'SJ')
 RETURNS void
 LANGUAGE plpgsql
AS $function$
-- p_contract : site IFS cible ('SJ' = Saint-Jean, 'CS' = Castel).
BEGIN
    IF p_contract NOT IN ('SJ', 'CS') THEN
        RAISE EXCEPTION 'Site invalide: % (attendu: SJ ou CS)', p_contract;
    END IF;
    RAISE NOTICE '############ DEBUT ALIMENTATION ARTICLES PHL (site %) ############', p_contract;
    PERFORM clean_data.alimenter_part_catalog_phl(p_contract);
    PERFORM clean_data.alimenter_inventory_part_phl(p_contract);
    PERFORM clean_data.alimenter_sales_part_phl(p_contract);
    PERFORM clean_data.alimenter_purchase_part_phl(p_contract);
    PERFORM clean_data.alimenter_manuf_part_attribute_phl(p_contract);
    RAISE NOTICE '############ FIN ALIMENTATION ARTICLES PHL (site %) ############', p_contract;
END;
$function$
;
