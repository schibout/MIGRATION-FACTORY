CREATE OR REPLACE FUNCTION clean_data.alimenter_ifs_article_phl()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_count_inserted INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    RAISE NOTICE 'Début de l''ajout des articles PHL dans ifs_article_maitre - %', v_start_time;
    
    INSERT INTO clean_data.ifs_article_maitre (
        numero_article,
        new_transco,
        designation,
        designation_courte,
        type_article,
        libelle_type_article,
        groupe_article,
        unite_base,
        unite_commande,
        avec_gestion_lot,
        profils_serie_list,
        nombre_centres_actifs,
        nombre_magasins,
        stock_total_libre,
        stock_total_bloque,
        stock_total_controle,
        valeur_stock_magasins_total,
        actif_dans_centre,
        actif_commercial,
        actif_evaluation,
        actif_achat,
        avec_stock,
        statut_utilisation,
        langue,
        codification_id
    )
    SELECT DISTINCT ON (phl."NUMERO")
        LPAD(phl."NUMERO", 18, '0') AS numero_article,
        phl."N. ARTICLE" AS new_transco,
        phl."DESCRIPTION LANGUE" AS designation,
        phl."DESCRIPTION" AS designation_courte,
        phl."CLASSIF TYPE PROD." AS type_article,
        phl."CLASSIF TYPE PROD._2" AS libelle_type_article,
        SUBSTRING(phl."GP PRINCP ARTICLE", 1, 20) AS groupe_article,
        -- U/M via transcodification UOM (meme logique que les tables IFS filles),
        -- sinon unite brute PHL. C'est la table de transco qui porte T -> KG.
        COALESCE(
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(phl."U/M")), '')),
            NULLIF(TRIM(phl."U/M"), ''),
            'PCE'
        ) AS unite_base,
        COALESCE(
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(phl."U/M")), '')),
            NULLIF(TRIM(phl."U/M"), ''),
            'PCE'
        ) AS unite_commande,
        phl."TRACABILITE LOTS" AS avec_gestion_lot,
        phl."REGLE DE SERIE" AS profils_serie_list,
        public.get_default_value('clean_data.ifs_article_maitre', 'nombre_centres_actifs')::bigint AS nombre_centres_actifs,
        public.get_default_value('clean_data.ifs_article_maitre', 'nombre_magasins')::bigint AS nombre_magasins,
        public.get_default_value('clean_data.ifs_article_maitre', 'stock_total_libre')::numeric AS stock_total_libre,
        public.get_default_value('clean_data.ifs_article_maitre', 'stock_total_bloque')::numeric AS stock_total_bloque,
        public.get_default_value('clean_data.ifs_article_maitre', 'stock_total_controle')::numeric AS stock_total_controle,
        public.get_default_value('clean_data.ifs_article_maitre', 'valeur_stock_magasins_total')::numeric AS valeur_stock_magasins_total,
        public.get_default_value('clean_data.ifs_article_maitre', 'actif_dans_centre') AS actif_dans_centre,
        public.get_default_value('clean_data.ifs_article_maitre', 'actif_commercial') AS actif_commercial,
        public.get_default_value('clean_data.ifs_article_maitre', 'actif_evaluation') AS actif_evaluation,
        public.get_default_value('clean_data.ifs_article_maitre', 'actif_achat') AS actif_achat,
        public.get_default_value('clean_data.ifs_article_maitre', 'avec_stock') AS avec_stock,
        phl."STATUT" AS statut_utilisation,
        public.get_default_value('clean_data.ifs_article_maitre', 'langue') AS langue,
        SUBSTRING(phl."N. ARTICLE", 1, 25) AS codification_id
    -- Source dedoublonnee (cf. sql/articlePhl/v_phl_article_retenu.sql)
    FROM raw_data.v_phl_article_retenu phl
    WHERE phl."N. ARTICLE" IS NOT NULL
      AND TRIM(phl."N. ARTICLE") != ''
      AND phl."NUMERO" IS NOT NULL
      AND TRIM(phl."NUMERO") != ''
      AND NOT EXISTS (
          SELECT 1 FROM clean_data.ifs_article_maitre ifs
          WHERE ifs.numero_article = LPAD(phl."NUMERO", 18, '0')
      )
    ORDER BY phl."NUMERO";
    
    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;
    
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;
    
    RAISE NOTICE 'Ajout des articles PHL terminé avec succès';
    RAISE NOTICE 'Nombre d''articles PHL ajoutés: %', v_count_inserted;
    RAISE NOTICE 'Durée d''exécution: %', v_duration;
    RAISE NOTICE 'Début: %, Fin: %', v_start_time, v_end_time;
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;
        
        RAISE NOTICE 'ERREUR lors de l''ajout des articles PHL';
        RAISE NOTICE 'Code d''erreur: %', SQLSTATE;
        RAISE NOTICE 'Message d''erreur: %', SQLERRM;
        RAISE NOTICE 'Durée avant erreur: %', v_duration;
        
        RAISE;
END;
$function$
;
