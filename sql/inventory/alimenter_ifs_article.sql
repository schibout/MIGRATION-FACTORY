CREATE OR REPLACE FUNCTION clean_data.alimenter_ifs_article()
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
    
    RAISE NOTICE 'Début de l''alimentation de la table ifs_article_maitre - %', v_start_time;
    
    -- Vider la table cible avant insertion
    TRUNCATE TABLE clean_data.ifs_article_maitre RESTART IDENTITY;
    RAISE NOTICE 'Table ifs_article_maitre vidée';
    
    -- Insérer les données
    INSERT INTO clean_data.ifs_article_maitre (
        numero_article,
        designation,
        designation_courte,
        ancien_numero,
        type_article,
        libelle_type_article,
        groupe_article,
        libelle_groupe_article,
        secteur_activite,
        unite_base,
        unite_commande,
        nombre_centres_actifs,
        centres_list,
        groupes_achat_list,
        strategies_list,
        stock_minimum_total,
        stock_securite_total,
        stock_maximum_total,
        avec_gestion_lot,
        profils_serie_list,
        organisations_commerciales_list,
        canaux_distribution_list,
        statuts_commerciaux_list,
        cercles_evaluation_list,
        prix_moyen_pondere_moyen,
        prix_standard_moyen,
        stock_quantite_total,
        valeur_stock_total,
        classes_evaluation_list,
        nombre_magasins,
        stock_total_libre,
        stock_total_bloque,
        stock_total_controle,
        valeur_stock_magasins_total,
        fournisseur_principal,
        unite_commande_achat,
        nom_fournisseur_principal,
        pays_fournisseur_principal,
        ville_fournisseur_principal,
        actif_dans_centre,
        actif_commercial,
        actif_evaluation,
        actif_achat,
        avec_stock,
        statut_utilisation,
        date_creation,
        createur,
        date_modification,
        modificateur,
        langue
    )
    -- =====================================================================
    -- PERIMETRE : seuls les articles presents dans raw_data.export_article_qlikview
    -- sont retenus (la table pilote la liste des articles a migrer).
    -- raw_data.article_definitif n'est plus utilisee du tout.
    -- =====================================================================
    WITH article_perimetre AS (
         SELECT LPAD(TRIM(qv.article), 18, '0') AS matnr,
            max(qv.designation_article) AS designation_article
           FROM raw_data.export_article_qlikview qv
          WHERE qv.article IS NOT NULL AND TRIM(qv.article) <> ''::text
          GROUP BY LPAD(TRIM(qv.article), 18, '0')
        ), article_base AS (
         SELECT DISTINCT ON (qp.matnr)
            qp.matnr,
            m_1.mandt,
            COALESCE(mk.maktx, qp.designation_article, qp.matnr) AS maktx,
            mk.maktg,
            m_1.bismt,
            m_1.mtart,
            m_1.matkl,
            m_1.mbrsh,
            m_1.meins,
            m_1.bstme,
            m_1.ersda,
            m_1.ernam,
            m_1.laeda,
            m_1.aenam,
            mk.spras
           FROM article_perimetre qp
             INNER JOIN raw_data.mara m_1 ON qp.matnr = m_1.matnr::text AND m_1.mandt::text = '700'::text AND (m_1.lvorm IS NULL OR m_1.lvorm::text = ''::text)
             LEFT JOIN raw_data.makt mk ON qp.matnr = mk.matnr::text AND mk.mandt::text = '700'::text AND (mk.spras::text = ANY (ARRAY['F'::character varying, 'E'::character varying, 'D'::character varying]::text[]))
          ORDER BY qp.matnr, (
                CASE mk.spras
                    WHEN 'F'::text THEN 1
                    WHEN 'E'::text THEN 2
                    WHEN 'D'::text THEN 3
                    ELSE 4
                END)
        ), centres_agg AS (
         SELECT marc.matnr::text AS matnr,
            marc.mandt,
            count(*) AS nombre_centres,
            string_agg(DISTINCT marc.werks::text, ', '::text ORDER BY (marc.werks::text)) AS centres_list,
            string_agg(DISTINCT marc.ekgrp::text, ', '::text) FILTER (WHERE marc.ekgrp IS NOT NULL AND marc.ekgrp::text <> ''::text) AS groupes_achat_list,
            string_agg(DISTINCT marc.dismm::text, ', '::text) FILTER (WHERE marc.dismm IS NOT NULL) AS strategies_list,
            sum(COALESCE(marc.bstmi::numeric, 0::numeric)) AS stock_minimum_total,
            sum(COALESCE(marc.bstrf::numeric, 0::numeric)) AS stock_securite_total,
            sum(COALESCE(marc.bstma::numeric, 0::numeric)) AS stock_maximum_total,
                CASE
                    WHEN count(*) FILTER (WHERE marc.xchar::text = 'X'::text) > 0 THEN 'OUI'::text
                    ELSE 'NON'::text
                END AS avec_gestion_lot,
            string_agg(DISTINCT marc.sernp::text, ', '::text) FILTER (WHERE marc.sernp IS NOT NULL AND marc.sernp::text <> ''::text) AS profils_serie_list
           FROM raw_data.marc
          WHERE marc.mandt::text = '700'::text AND (marc.lvorm IS NULL OR marc.lvorm::text = ''::text)
          GROUP BY marc.matnr::text, marc.mandt
        ), commerciales_agg AS (
         SELECT mvke.matnr::text AS matnr,
            mvke.mandt,
            string_agg(DISTINCT mvke.vkorg::text, ', '::text ORDER BY (mvke.vkorg::text)) AS organisations_commerciales_list,
            string_agg(DISTINCT mvke.vtweg::text, ', '::text ORDER BY (mvke.vtweg::text)) AS canaux_distribution_list,
            string_agg(DISTINCT mvke.vmsta::text, ', '::text) FILTER (WHERE mvke.vmsta IS NOT NULL) AS statuts_commerciaux_list
           FROM raw_data.mvke
          WHERE mvke.mandt::text = '700'::text AND (mvke.lvorm IS NULL OR mvke.lvorm::text = ''::text)
          GROUP BY mvke.matnr::text, mvke.mandt
        ), evaluation_agg AS (
         SELECT mbew.matnr::text AS matnr,
            mbew.mandt,
            string_agg(DISTINCT mbew.bwkey::text, ', '::text ORDER BY (mbew.bwkey::text)) AS cercles_evaluation_list,
            round(avg(COALESCE(mbew.verpr::numeric, 0::numeric)), 2) AS prix_moyen_pondere_moyen,
            round(avg(COALESCE(mbew.stprs::numeric, 0::numeric)), 2) AS prix_standard_moyen,
            sum(COALESCE(mbew.lbkum::numeric, 0::numeric)) AS stock_quantite_total,
            sum(COALESCE(mbew.salk3::numeric, 0::numeric)) AS valeur_stock_total,
            string_agg(DISTINCT mbew.bklas::text, ', '::text) FILTER (WHERE mbew.bklas IS NOT NULL) AS classes_evaluation_list
           FROM raw_data.mbew
          WHERE mbew.mandt::text = '700'::text AND (mbew.lvorm IS NULL OR mbew.lvorm::text = ''::text)
          GROUP BY mbew.matnr::text, mbew.mandt
        ), stocks_agg AS (
         SELECT mard.matnr::text AS matnr,
            mard.mandt,
            count(DISTINCT mard.lgort) AS nombre_magasins,
            sum(COALESCE(mard.labst::numeric, 0::numeric)) AS stock_total_libre,
            sum(COALESCE(mard.speme::numeric, 0::numeric)) AS stock_total_bloque,
            sum(COALESCE(mard.insme::numeric, 0::numeric)) AS stock_total_controle,
            sum(COALESCE(mard.vmlab::numeric, 0::numeric)) AS valeur_stock_magasins_total
           FROM raw_data.mard
          WHERE mard.mandt::text = '700'::text AND (mard.lvorm IS NULL OR mard.lvorm::text = ''::text)
          GROUP BY mard.matnr::text, mard.mandt
        ), ei_principal AS (
         SELECT DISTINCT ON (eina.matnr::text, eina.mandt) eina.matnr::text AS matnr,
            eina.mandt,
            eina.lifnr,
            eina.meins
           FROM raw_data.eina
          WHERE eina.mandt::text = '700'::text AND (eina.loekz IS NULL OR eina.loekz::text = ''::text)
          ORDER BY eina.matnr::text, eina.mandt, eina.erdat DESC
        )
    SELECT 
        m.matnr AS numero_article,
        m.maktx AS designation,
        m.maktg AS designation_courte,
        m.bismt AS ancien_numero,
        m.mtart AS type_article,
        COALESCE(t134.mtref, m.mtart::text) AS libelle_type_article,
        m.matkl AS groupe_article,
        COALESCE(t023.wgbez, m.matkl) AS libelle_groupe_article,
        m.mbrsh AS secteur_activite,
        m.meins AS unite_base,
        m.bstme AS unite_commande,
        COALESCE(centres_agg.nombre_centres, 0::bigint) AS nombre_centres_actifs,
        centres_agg.centres_list,
        centres_agg.groupes_achat_list,
        centres_agg.strategies_list,
        centres_agg.stock_minimum_total,
        centres_agg.stock_securite_total,
        centres_agg.stock_maximum_total,
        centres_agg.avec_gestion_lot,
        centres_agg.profils_serie_list,
        commerciales_agg.organisations_commerciales_list,
        commerciales_agg.canaux_distribution_list,
        commerciales_agg.statuts_commerciaux_list,
        evaluation_agg.cercles_evaluation_list,
        evaluation_agg.prix_moyen_pondere_moyen,
        evaluation_agg.prix_standard_moyen,
        evaluation_agg.stock_quantite_total,
        evaluation_agg.valeur_stock_total,
        evaluation_agg.classes_evaluation_list,
        COALESCE(stocks_agg.nombre_magasins, 0::bigint) AS nombre_magasins,
        COALESCE(stocks_agg.stock_total_libre, 0::numeric) AS stock_total_libre,
        COALESCE(stocks_agg.stock_total_bloque, 0::numeric) AS stock_total_bloque,
        COALESCE(stocks_agg.stock_total_controle, 0::numeric) AS stock_total_controle,
        COALESCE(stocks_agg.valeur_stock_magasins_total, 0::numeric) AS valeur_stock_magasins_total,
        ei_principal.lifnr AS fournisseur_principal,
        ei_principal.meins AS unite_commande_achat,
        lfa.name1 AS nom_fournisseur_principal,
        lfa.land1 AS pays_fournisseur_principal,
        lfa.ort01 AS ville_fournisseur_principal,
        CASE
            WHEN centres_agg.nombre_centres > 0 THEN 'OUI'::text
            ELSE 'NON'::text
        END AS actif_dans_centre,
        CASE
            WHEN commerciales_agg.organisations_commerciales_list IS NOT NULL THEN 'OUI'::text
            ELSE 'NON'::text
        END AS actif_commercial,
        CASE
            WHEN evaluation_agg.valeur_stock_total > 0::numeric THEN 'OUI'::text
            ELSE 'NON'::text
        END AS actif_evaluation,
        CASE
            WHEN ei_principal.lifnr IS NOT NULL THEN 'OUI'::text
            ELSE 'NON'::text
        END AS actif_achat,
        CASE
            WHEN stocks_agg.stock_total_libre > 0::numeric THEN 'OUI'::text
            ELSE 'NON'::text
        END AS avec_stock,
        CASE
            WHEN centres_agg.nombre_centres > 0 OR commerciales_agg.organisations_commerciales_list IS NOT NULL OR stocks_agg.stock_total_libre > 0::numeric OR ei_principal.lifnr IS NOT NULL THEN 'UTILISE'::text
            ELSE 'NON_UTILISE'::text
        END AS statut_utilisation,
        m.ersda AS date_creation,
        m.ernam AS createur,
        m.laeda AS date_modification,
        m.aenam AS modificateur,
        m.spras AS langue

        -- =====================================================================
        -- CODIFICATION IFS : plus alimentee.
        -- clean_data.mapping_codification_articles n'est plus utilisee : la
        -- colonne codification_id reste NULL (aucune procedure aval ne la lit).
        -- =====================================================================

    FROM article_base m
        LEFT JOIN raw_data.t134 t134 ON m.mtart::text = t134.mtart AND m.mandt::text = t134.mandt
        LEFT JOIN raw_data.t023t t023 ON m.matkl::text = t023.matkl::text AND m.mandt::text = t023.mandt::text AND t023.spras::text = 'F'::text
        LEFT JOIN centres_agg ON m.matnr = centres_agg.matnr AND m.mandt::text = centres_agg.mandt::text
        LEFT JOIN commerciales_agg ON m.matnr = commerciales_agg.matnr AND m.mandt::text = commerciales_agg.mandt::text
        LEFT JOIN evaluation_agg ON m.matnr = evaluation_agg.matnr AND m.mandt::text = evaluation_agg.mandt::text
        LEFT JOIN stocks_agg ON m.matnr = stocks_agg.matnr AND m.mandt::text = stocks_agg.mandt::text
        LEFT JOIN ei_principal ON m.matnr = ei_principal.matnr AND m.mandt::text = ei_principal.mandt::text
        LEFT JOIN raw_data.lfa1 lfa ON ei_principal.lifnr::text = lfa.lifnr::text AND ei_principal.mandt::text = lfa.mandt::text AND (lfa.loevm IS NULL OR lfa.loevm::text = ''::text)
    ORDER BY m.matnr;
    
    -- Compter les enregistrements insérés
    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;
    
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;
    
    -- Log des résultats
    RAISE NOTICE 'Alimentation de la table ifs_article_maitre terminée avec succès';
    RAISE NOTICE 'Nombre d''enregistrements traités: %', v_count_inserted;
    RAISE NOTICE 'Durée d''exécution: %', v_duration;
    RAISE NOTICE 'Début: %, Fin: %', v_start_time, v_end_time;
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;
        
        RAISE NOTICE 'ERREUR lors de l''alimentation de la table ifs_article_maitre';
        RAISE NOTICE 'Code d''erreur: %', SQLSTATE;
        RAISE NOTICE 'Message d''erreur: %', SQLERRM;
        RAISE NOTICE 'Durée avant erreur: %', v_duration;
        
        RAISE;
END;
$function$
;
