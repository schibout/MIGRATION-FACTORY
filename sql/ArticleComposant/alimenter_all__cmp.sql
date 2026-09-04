-- L'ancienne signature sans parametre doit disparaitre, sinon PostgreSQL cree une
-- surcharge et les appels sans argument deviennent ambigus.
DROP FUNCTION IF EXISTS clean_data.alimenter_all_cmp();
CREATE OR REPLACE FUNCTION clean_data.alimenter_all_cmp(p_contract text DEFAULT 'SJ')
 RETURNS void
 LANGUAGE plpgsql
AS $function$
-- Orchestrateur du module composants (table directrice raw_data.composant_sj_cs).
-- p_contract : site IFS cible ('SJ' = Saint-Jean, 'CS' = Castel).
--
-- Les composants sont la DERNIERE etape de la chaine articles : ils s'ajoutent en
-- append et ne vident jamais rien. Le vidage des cinq tables est fait en tete de
-- chaine, par la passe Saint-Jean du module Articles PHL
-- (clean_data.alimenter_all_phl('SJ')).
BEGIN
    IF p_contract NOT IN ('SJ', 'CS') THEN
        RAISE EXCEPTION 'Site invalide: % (attendu: SJ ou CS)', p_contract;
    END IF;
    RAISE NOTICE '############ DEBUT ALIMENTATION COMPOSANTS (site %) ############', p_contract;
    PERFORM clean_data.alimenter_part_catalog_cmp(p_contract);
    PERFORM clean_data.alimenter_inventory_part_cmp(p_contract);
    PERFORM clean_data.alimenter_sales_part_cmp(p_contract);
    PERFORM clean_data.alimenter_purchase_part_cmp(p_contract);
    PERFORM clean_data.alimenter_manuf_part_attribute_cmp(p_contract);
    RAISE NOTICE '############ FIN ALIMENTATION COMPOSANTS (site %) ############', p_contract;
END;
$function$
;
