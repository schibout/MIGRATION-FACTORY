-- Alimente clean_data.article_sap pour TOUS les articles du perimetre
-- clean_data.ifs_article_maitre (societe STJN + articles de maintenance, cf.
-- sql/inventory/alimenter_ifs_article.sql) : lancer alimenter_ifs_article()
-- avant.
--
-- Grain : une ligne par article (~35 700). Site = division STJN ouverte dans
-- marc, SJ (9200) prioritaire sur CS (9000) ; un article sans division STJN
-- (IBAU, pieces de maintenance APSJ) sort sur SJ.
--
-- Colonnes : uniquement des informations venant de SAP, telles quelles (pas de
-- valeur par defaut IFS ni de transcodification) ; la table ne garde que ces
-- colonnes depuis la migration 106 (+10 par la 107).
CREATE OR REPLACE FUNCTION clean_data.alimenter_article_sap()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_count INTEGER := 0;
BEGIN
    TRUNCATE TABLE clean_data.article_sap;

    INSERT INTO clean_data.article_sap (
        "N° article", "Description article", "Site", "Site Description",
        "Gestionnaire", "U/M Stock",
        "Groupe produit 1", "Groupe produit 1 Description",
        "Catégorie article", "Catégorie article Description",
        "Statut article", "Classe ABC",
        "Groupe comptable", "Groupe comptable Description",
        "EMPLACEMENT", "Désignation du type", "Qté en stock",
        "Date de création", "Date de dernière modification", "Texte de commande", "Délai d'achat",
        -- migration 107
        "U/M Stock Description", "Groupe d'achat", "Groupe d'achat Description",
        "Hiérarchie produit", "Hiérarchie produit Description",
        "Type approvisionnement", "Type approvisionnement Description",
        "Type de planification", "Point de commande", "Ancien numéro article",
        -- migration 108
        "Note interne", "Texte de base",
        -- migration 110
        "Créé par", "Dernière modification par",
        -- migration 111
        "Créé par Nom", "Dernière modification par Nom"
    )
    -- Une ligne par article : 9200 (SJ) s'il y est ouvert, sinon 9000 (CS),
    -- sinon SJ par defaut (max('9200','9000') = '9200').
    WITH sites AS MATERIALIZED (
        SELECT a.numero_article AS matnr, COALESCE(max(c.werks::text), '9200') AS werks
          FROM clean_data.ifs_article_maitre a
          LEFT JOIN raw_data.marc c
            ON c.mandt::text = '700' AND c.matnr::text = a.numero_article
           AND c.werks::text IN ('9200', '9000')
           AND (c.lvorm IS NULL OR c.lvorm::text = '')
         GROUP BY a.numero_article
    ), stock AS (
        SELECT d.matnr::text AS matnr, d.werks::text AS werks,
               sum(COALESCE(d.labst::numeric, 0) + COALESCE(d.insme::numeric, 0)
                   + COALESCE(d.speme::numeric, 0)) AS qte,
               min(NULLIF(TRIM(d.lgpbe), '')) AS emplacement
          FROM raw_data.mard d
         WHERE d.mandt::text = '700' AND d.werks::text IN ('9200', '9000')
           AND (d.lvorm IS NULL OR d.lvorm::text = '')
         GROUP BY 1, 2
    ), utilisateur AS (
        -- nom complet SAP : usr21 -> adrp (version d'adresse la plus recente)
        SELECT DISTINCT ON (u.bname) u.bname::text AS bname,
               COALESCE(NULLIF(TRIM(a.name_text), ''),
                        NULLIF(TRIM(concat_ws(' ', a.name_first, a.name_last)), '')) AS nom
          FROM raw_data.usr21 u
          JOIN raw_data.adrp a ON a.client = u.mandt AND a.persnumber = u.persnumber
         WHERE u.mandt::text = '700'
         ORDER BY u.bname, a.date_from DESC
    )
    SELECT
        SUBSTRING(LTRIM(s.matnr, '0'), 1, 25),
        COALESCE(NULLIF(TRIM(k.maktx), ''), s.matnr),              -- makt (F)
        CASE s.werks WHEN '9000' THEN 'CS' ELSE 'SJ' END,
        w.name1,                                                   -- t001w
        NULLIF(TRIM(c.dispo), ''),                                 -- gestionnaire MRP
        NULLIF(TRIM(m.meins), ''),                                 -- unite de base SAP
        m.matkl, t023.wgbez,                                       -- groupe marchandises
        m.mtart, t134.mtbez,                                       -- categorie (IBAU, ERSA...)
        NULLIF(TRIM(c.mmsta), ''),                                 -- statut division
        NULLIF(TRIM(c.maabc), ''),
        ev.bklas, t025.bkbez,                                      -- classe de valorisation
        st.emplacement,                                            -- mard.lgpbe
        NULLIF(TRIM(m.normt), ''),
        COALESCE(st.qte, 0)::text,
        CASE WHEN m.ersda::text ~ '^\d{8}$' THEN to_char(to_date(m.ersda::text, 'YYYYMMDD'), 'DD/MM/YYYY') ELSE m.ersda::text END,
        CASE WHEN m.laeda::text ~ '^\d{8}$' THEN to_char(to_date(m.laeda::text, 'YYYYMMDD'), 'DD/MM/YYYY') ELSE m.laeda::text END,
        clean_data.texte_long_sap('MATERIAL', 'BEST', m.matnr, ARRAY['F']),  -- texte de commande
        NULLIF(c.plifz::numeric, 0)::int::text,                    -- delai de livraison prevu
        t006.msehl,                                                -- libelle unite (F)
        NULLIF(TRIM(c.ekgrp), ''), t024.eknam,                     -- groupe d'achat
        NULLIF(TRIM(m.prdha), ''), t179.vtext,                     -- hierarchie produit
        NULLIF(TRIM(c.beskz), ''),
        CASE c.beskz::text                                         -- valeurs fixes du domaine SAP BESKZ
            WHEN 'E' THEN 'Fabrication interne'
            WHEN 'F' THEN 'Approvisionnement externe'
            WHEN 'X' THEN 'Les deux types d''approvisionnement' END,
        NULLIF(TRIM(c.dismm), ''),                                 -- type de planification (MRP)
        NULLIF(c.minbe::numeric, 0)::text,                         -- point de commande
        NULLIF(TRIM(m.bismt), ''),                                 -- ancien numero
        -- textes longs STXH/STXL, lus par RFC_READ_TEXT dans raw_data.sap_long_text
        -- (ecran Extraction > Textes longs SAP, MATERIAL / IVER et GRUN / F)
        clean_data.texte_long_sap('MATERIAL', 'IVER', m.matnr, ARRAY['F']),  -- note interne
        clean_data.texte_long_sap('MATERIAL', 'GRUN', m.matnr, ARRAY['F']),  -- texte de base
        NULLIF(TRIM(m.ernam), ''),                                 -- cree par
        NULLIF(TRIM(m.aenam), ''),                                 -- derniere modification par
        uc.nom, um.nom                                             -- noms complets (usr21/adrp)
    FROM sites s
    JOIN raw_data.mara m ON m.mandt::text = '700' AND m.matnr::text = s.matnr
    LEFT JOIN raw_data.makt k
      ON k.mandt::text = '700' AND k.matnr = m.matnr AND k.spras::text = 'F'
    LEFT JOIN raw_data.marc c
      ON c.mandt::text = '700' AND c.matnr = m.matnr AND c.werks::text = s.werks
    LEFT JOIN raw_data.t001w w ON w.mandt::text = '700' AND w.werks::text = s.werks
    LEFT JOIN raw_data.t023t t023
      ON t023.mandt::text = '700' AND t023.matkl = m.matkl AND t023.spras::text = 'F'
    LEFT JOIN raw_data.t134t t134
      ON t134.mandt::text = '700' AND t134.mtart = m.mtart AND t134.spras::text = 'F'
    LEFT JOIN raw_data.mbew ev
      ON ev.mandt::text = '700' AND ev.matnr = m.matnr AND ev.bwkey::text = s.werks
     AND (ev.lvorm IS NULL OR ev.lvorm::text = '')
    LEFT JOIN raw_data.t025t t025
      ON t025.mandt::text = '700' AND t025.bklas = ev.bklas AND t025.spras::text = 'F'
    LEFT JOIN raw_data.t006a t006
      ON t006.mandt::text = '700' AND t006.msehi = m.meins AND t006.spras::text = 'F'
    LEFT JOIN raw_data.t024 t024 ON t024.mandt::text = '700' AND t024.ekgrp = c.ekgrp
    LEFT JOIN raw_data.t179t t179
      ON t179.mandt::text = '700' AND t179.prodh = m.prdha AND t179.spras::text = 'F'
    LEFT JOIN stock st ON st.matnr = s.matnr AND st.werks = s.werks
    LEFT JOIN utilisateur uc ON uc.bname = TRIM(m.ernam)
    LEFT JOIN utilisateur um ON um.bname = TRIM(m.aenam)
    ORDER BY 1;
    GET DIAGNOSTICS v_count = ROW_COUNT;

    RAISE NOTICE 'article_sap : % articles', v_count;
    RETURN v_count;
END;
$function$;
