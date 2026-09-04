-- L'ancienne signature sans parametre doit disparaitre, sinon PostgreSQL cree une
-- surcharge et les appels sans argument deviennent ambigus.
DROP FUNCTION IF EXISTS clean_data.alimenter_all_phl();
CREATE OR REPLACE FUNCTION clean_data.alimenter_all_phl(p_contract text DEFAULT 'SJ')
 RETURNS void
 LANGUAGE plpgsql
AS $function$
-- p_contract : site IFS cible ('SJ' = Saint-Jean, 'CS' = Castel).
--
-- La passe Saint-Jean est la PREMIERE etape de la chaine articles : elle vide
-- d'abord les cinq tables cibles (clean_data.vider_tables_articles_phl), puis les
-- remplit. Tout ce qui suit s'ajoute en append : articles PHL Castel, puis
-- composants Saint-Jean et Castel. Charger CS seul n'efface donc rien.
BEGIN
    IF p_contract NOT IN ('SJ', 'CS') THEN
        RAISE EXCEPTION 'Site invalide: % (attendu: SJ ou CS)', p_contract;
    END IF;
    RAISE NOTICE '############ DEBUT ALIMENTATION ARTICLES PHL (site %) ############', p_contract;
    -- Nettoyage du fichier source (colonnes non reprises mises a NULL et
    -- suppression des articles plaques exclus) : sur les DEUX sites.
    CALL clean_data.nettoyer_phl_article();
    IF p_contract = 'SJ' THEN
        CALL clean_data.vider_tables_articles_phl();
    END IF;
    PERFORM clean_data.alimenter_part_catalog_phl(p_contract);
    PERFORM clean_data.alimenter_inventory_part_phl(p_contract);
    PERFORM clean_data.alimenter_sales_part_phl(p_contract);
    PERFORM clean_data.alimenter_purchase_part_phl(p_contract);
    PERFORM clean_data.alimenter_manuf_part_attribute_phl(p_contract);
    RAISE NOTICE '############ FIN ALIMENTATION ARTICLES PHL (site %) ############', p_contract;
END;
$function$
;
