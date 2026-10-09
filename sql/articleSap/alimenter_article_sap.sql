-- Alimente clean_data.article_sap (fichier article au format IFS, 148 colonnes
-- texte aux libelles IFS) pour TOUS les articles du perimetre
-- clean_data.ifs_article_maitre (societe STJN + articles de maintenance, cf.
-- sql/inventory/alimenter_ifs_article.sql) : lancer alimenter_ifs_article()
-- avant.
--
-- Grain : une ligne par (article, site). Site = division STJN ouverte dans
-- marc (9200 -> SJ, 9000 -> CS) ; un article sans division STJN (IBAU, pieces
-- de maintenance APSJ) sort une seule ligne sur SJ.
--
-- Colonnes : valeur SAP quand SAP la porte (mara / makt / marc / mard / mbew),
-- sinon la meme valeur par defaut IFS que clean_data.inventory_part
-- (get_default_value, codes _db). Les colonnes sans equivalent SAP ni valeur
-- par defaut (stockage, temperatures, alliage...) restent NULL.
CREATE OR REPLACE FUNCTION clean_data.alimenter_article_sap()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_count INTEGER := 0;
BEGIN
    TRUNCATE TABLE clean_data.article_sap;

    INSERT INTO clean_data.article_sap (
        "N° article", "Descr. utilisée de l'article", "Description article",
        "Site", "Site Description", "Type article", "Gestionnaire",
        "U/M Stock",
        "Groupe produit 1", "Groupe produit 1 Description",
        "Groupe produit 2", "Groupe produit 2 Description",
        "Classe d'actifs", "Statut article", "Classe ABC", "Classe fréquence",
        "Etape cycle de vie",
        "Groupe comptable", "Groupe comptable Description",
        "EMPLACEMENT", "Désignation du type", "Dimension/Qualité",
        "Poids net", "U/M poids", "Volume net", "U/M volume",
        "Exclure de la proposition d'emballage d'expédition",
        "Qté en stock", "Créé", "Modifié", "Notes",
        "Code délai", "Délai d'achat", "Délai de fabrication", "Délai prévu",
        "Remplacé par l'article",
        "Durée vie en jours", "Jours restants minimum pour planification",
        "Date d'expiration obligatoire",
        "Pays d'origine", "Pays d'origine Description", "N° statistique clt",
        "Dop Connection", "Dop Netting", "Calc. qté arrondi", "Configurable",
        "Méthode valorisation stock", "Niveau coût article stock",
        "Considération facture fourni.", "Coût zéro",
        "Méth. de coût service externe", "Intervalle de comptage cyclique",
        "Ecart invent cum", "Inventaire tournant", "Réserv. saisie cde",
        "Contrôle autom. capabilité", "Physique négative",
        "Contrôle de disponibilité", "Vérifier dispon. à la réservation cde cl.",
        "Prévision de consommation", "Avis de rupt. de stock",
        "Gestion du stock", "Master Part Description"
    )
    WITH sites AS MATERIALIZED (
        SELECT a.numero_article AS matnr, c.werks::text AS werks
          FROM clean_data.ifs_article_maitre a
          JOIN raw_data.marc c
            ON c.mandt::text = '700' AND c.matnr::text = a.numero_article
           AND c.werks::text IN ('9200', '9000')
           AND (c.lvorm IS NULL OR c.lvorm::text = '')
        UNION ALL
        SELECT a.numero_article, '9200'
          FROM clean_data.ifs_article_maitre a
         WHERE NOT EXISTS (
               SELECT 1 FROM raw_data.marc c
                WHERE c.mandt::text = '700' AND c.matnr::text = a.numero_article
                  AND c.werks::text IN ('9200', '9000')
                  AND (c.lvorm IS NULL OR c.lvorm::text = ''))
    ), stock AS (
        SELECT d.matnr::text AS matnr, d.werks::text AS werks,
               sum(COALESCE(d.labst::numeric, 0) + COALESCE(d.insme::numeric, 0)
                   + COALESCE(d.speme::numeric, 0)) AS qte,
               min(NULLIF(TRIM(d.lgpbe), '')) AS emplacement
          FROM raw_data.mard d
         WHERE d.mandt::text = '700' AND d.werks::text IN ('9200', '9000')
           AND (d.lvorm IS NULL OR d.lvorm::text = '')
         GROUP BY 1, 2
    )
    SELECT
        SUBSTRING(LTRIM(s.matnr, '0'), 1, 25),
        COALESCE(NULLIF(TRIM(k.maktx), ''), s.matnr),
        COALESCE(NULLIF(TRIM(k.maktx), ''), s.matnr),
        CASE s.werks WHEN '9000' THEN 'CS' ELSE 'SJ' END,
        w.name1,
        public.get_default_value('clean_data.inventory_part', 'type_code_db'),
        NULLIF(TRIM(c.dispo), ''),
        COALESCE(public.get_transcodification('UOM', NULLIF(UPPER(TRIM(m.meins)), '')), '*'),
        m.matkl, t023.wgbez,
        m.mtart, t134.mtbez,
        public.get_default_value('clean_data.inventory_part', 'asset_class'),
        COALESCE(NULLIF(TRIM(c.mmsta), ''),
                 public.get_default_value('clean_data.inventory_part', 'part_status')),
        NULLIF(TRIM(c.maabc), ''),
        public.get_default_value('clean_data.inventory_part', 'frequency_class_db'),
        public.get_default_value('clean_data.inventory_part', 'lifecycle_stage_db'),
        ev.bklas, t025.bkbez,
        st.emplacement,
        NULLIF(TRIM(m.normt), ''),
        NULLIF(TRIM(m.groes), ''),
        NULLIF(m.ntgew::numeric, 0)::text,
        CASE WHEN m.ntgew::numeric <> 0 THEN
             COALESCE(public.get_transcodification('UOM', NULLIF(UPPER(TRIM(m.gewei)), '')), '*') END,
        NULLIF(m.volum::numeric, 0)::text,
        CASE WHEN m.volum::numeric <> 0 THEN
             COALESCE(public.get_transcodification('UOM', NULLIF(UPPER(TRIM(m.voleh)), '')), '*') END,
        public.get_default_value('clean_data.inventory_part', 'excl_ship_pack_proposal_db'),
        COALESCE(st.qte, 0)::text,
        CASE WHEN m.ersda::text ~ '^\d{8}$' THEN to_char(to_date(m.ersda::text, 'YYYYMMDD'), 'DD/MM/YYYY') ELSE m.ersda::text END,
        CASE WHEN m.laeda::text ~ '^\d{8}$' THEN to_char(to_date(m.laeda::text, 'YYYYMMDD'), 'DD/MM/YYYY') ELSE m.laeda::text END,
        clean_data.texte_long_sap('MATERIAL', 'BEST', m.matnr, ARRAY['F']),
        public.get_default_value('clean_data.inventory_part', 'lead_time_code_db'),
        COALESCE(c.plifz::numeric, 0)::int::text,
        COALESCE(c.dzeit::numeric, 0)::int::text,
        COALESCE(c.webaz::numeric, 0)::int::text,
        NULLIF(LTRIM(TRIM(c.nfmat), '0'), ''),
        NULLIF(m.mhdhb::numeric, 0)::int::text,
        NULLIF(m.mhdrz::numeric, 0)::int::text,
        public.get_default_value('clean_data.inventory_part', 'mandatory_expiration_date_db'),
        NULLIF(TRIM(c.herkl), ''), t005.landx,
        NULLIF(TRIM(c.stawn), ''),
        public.get_default_value('clean_data.inventory_part', 'dop_connection_db'),
        public.get_default_value('clean_data.inventory_part', 'dop_netting_db'),
        public.get_default_value('clean_data.inventory_part', 'qty_calc_rounding'),
        CASE WHEN m.kzkfg::text = 'X' THEN 'CONFIGURED'
             ELSE public.get_default_value('clean_data.part_catalog', 'configurable_db') END,
        'AV',  -- valorisation uniforme, cf. alimenter_inventory_part()
        public.get_default_value('clean_data.inventory_part', 'inventory_part_cost_level_db'),
        public.get_default_value('clean_data.inventory_part', 'invoice_consideration_db'),
        public.get_default_value('clean_data.inventory_part', 'zero_cost_flag_db'),
        public.get_default_value('clean_data.inventory_part', 'ext_service_cost_method_db'),
        public.get_default_value('clean_data.inventory_part', 'cycle_period'),
        public.get_default_value('clean_data.inventory_part', 'count_variance'),
        public.get_default_value('clean_data.inventory_part', 'cycle_code_db'),
        public.get_default_value('clean_data.inventory_part', 'oe_alloc_assign_flag_db'),
        public.get_default_value('clean_data.inventory_part', 'automatic_capability_check_db'),
        public.get_default_value('clean_data.inventory_part', 'negative_on_hand_db'),
        public.get_default_value('clean_data.inventory_part', 'onhand_analysis_flag_db'),
        public.get_default_value('clean_data.inventory_part', 'co_reserve_onh_analys_flag_db'),
        public.get_default_value('clean_data.inventory_part', 'forecast_consumption_flag_db'),
        public.get_default_value('clean_data.inventory_part', 'shortage_flag_db'),
        public.get_default_value('clean_data.inventory_part', 'stock_management_db'),
        COALESCE(NULLIF(TRIM(k.maktx), ''), s.matnr)
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
    LEFT JOIN raw_data.t005t t005
      ON t005.mandt::text = '700' AND t005.land1 = c.herkl AND t005.spras::text = 'F'
    LEFT JOIN stock st ON st.matnr = s.matnr AND st.werks = s.werks
    ORDER BY 1, 4;
    GET DIAGNOSTICS v_count = ROW_COUNT;

    RAISE NOTICE 'article_sap : % lignes (article x site)', v_count;
    RETURN v_count;
END;
$function$;
