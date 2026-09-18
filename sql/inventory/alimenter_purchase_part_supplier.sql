CREATE OR REPLACE FUNCTION clean_data.alimenter_purchase_part_supplier()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_count_inserted INTEGER := 0;
    v_count_primary INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    RAISE NOTICE 'Début de l''alimentation des fournisseurs article achat (PURCHASE_PART_SUPPLIER) - %', v_start_time;
    
    -- Vider la table cible avant insertion
    TRUNCATE TABLE clean_data.purchase_part_supplier RESTART IDENTITY;
    -- Statistiques a jour avant le EXISTS sur purchase_part : cette table est
    -- rechargee dans la meme transaction et n'a aucun index. Sans ANALYZE, le
    -- planificateur la croit vide et part en nested loop (cf. meme piege dans
    -- alimenter_inventory_part_planning()).
    ANALYZE clean_data.purchase_part;
    RAISE NOTICE 'Table purchase_part_supplier vidée';
    
    -- Insertion des relations article-fournisseur depuis SAP (EINA/EINE)
    INSERT INTO clean_data.purchase_part_supplier (
        -- Clés
        contract,
        part_no,
        vendor_no,
        
        -- Données de base
        buy_unit_meas,
        currency_code,
        status_code,

        -- Prix d'achat (EINE)
        list_price,
        price_unit_meas,
        price_conv_factor,
        conv_factor,
        
        -- Flags et paramètres par défaut
        primary_vendor_db,
        leadtime_auto_db,
        receive_case_db,
        external_service_allowed_db,
        part_ownership_db,
        dist_order_receipt_type_db,
        multisite_planned_part_db,
        quick_registered_part_db,
        purchase_payment_type_db,
        acquisition_type_db,
        rental_primary_vendor_db,
        use_price_incl_tax_db,
        qualified_supplier_db,
        ext_svc_primary_vendor_db,
        issue_packaging_material_db
    )
    SELECT DISTINCT
        -- CONTRACT: 9200 = SJ, 9000 = CS
        CASE 
            WHEN eine.ekorg = '9200' THEN 'SJ'
            WHEN eine.ekorg = '9000' THEN 'CS'
            ELSE 'SJ'
        END as contract,
        
        -- PART_NO: numero_article SAP (pas de transcodification, l'article garde son ID)
        SUBSTRING(TRIM(LTRIM(ifs.numero_article, '0')), 1, 25) as part_no,
        
        -- VENDOR_NO: identifiant IFS du fournisseur (600xxx), repris tel quel
        -- de clean_data.supplier_info_general.supplier_id (demande explicite).
        -- Indispensable : la table supplier est renumérotée, le LIFNR SAP brut ne correspond plus.
        SUBSTRING(sig.supplier_id, 1, 20) as vendor_no,
        
        -- BUY_UNIT_MEAS: EINA.MEINS via transcodification UOM (SAP->IFS),
        -- repli sur '*' si l'unité SAP n'est pas transcodée.
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(eina.meins)), '')),
            '*'
        ), 1, 10) as buy_unit_meas,
        
        -- CURRENCY_CODE: EINE.WAERS
        SUBSTRING(COALESCE(NULLIF(eine.waers, ''), 'EUR'), 1, 3) as currency_code,
        
        -- STATUS_CODE: 2
        public.get_default_value('clean_data.purchase_part_supplier', 'status_code') as status_code,

        -- LIST_PRICE: prix UNITAIRE = EINE.NETPR / EINE.PEINH.
        -- SAP exprime NETPR pour PEINH unites (PEINH vaut 100, 10 ou 1000 sur
        -- ~1 400 fiches info-achat) : reprendre NETPR brut donnerait un prix
        -- jusqu'a 1000x trop eleve. NULLIF au denominateur = pas de division
        -- par zero, la ligne sort a NULL plutot qu'en erreur.
        (NULLIF(TRIM(eine.netpr), '')::numeric
         / NULLIF(NULLIF(TRIM(eine.peinh), '')::numeric, 0)) as list_price,

        -- PRICE_UNIT_MEAS: EINE.BPRME via transcodification UOM (SAP->IFS),
        -- meme repli que BUY_UNIT_MEAS sur '*'.
        SUBSTRING(COALESCE(
            public.get_transcodification('UOM', NULLIF(UPPER(TRIM(eine.bprme)), '')),
            '*'
        ), 1, 10) as price_unit_meas,

        -- PRICE_CONV_FACTOR: 1, le prix ayant deja ete ramene a l'unite
        -- ci-dessus. Litteral volontaire (et non get_default_value) : cette
        -- valeur est liee au calcul de LIST_PRICE, la rendre parametrable
        -- permettrait d'appliquer le facteur deux fois.
        1 as price_conv_factor,

        -- CONV_FACTOR: EINE.BPUMZ / EINE.BPUMN, facteur unite de commande ->
        -- unite de base (different de 1 sur 46 lignes seulement).
        (NULLIF(TRIM(eine.bpumz), '')::numeric
         / NULLIF(NULLIF(TRIM(eine.bpumn), '')::numeric, 0)) as conv_factor,
        
        -- PRIMARY_VENDOR_DB: valeur CALCULEE, pas une constante (demande explicite du
        -- 2026-09-18) : un article a plusieurs fournisseurs mais UN SEUL fournisseur
        -- principal par (site, article). Tout le monde est insere a 'N', puis l'UPDATE
        -- qui suit l'INSERT elit le principal ('Y'). La ligne primary_vendor_db de
        -- l'ecran Valeurs par defaut n'est donc plus lue (desactivee par la migration 080).
        'N' as primary_vendor_db,
        
        -- LEADTIME_AUTO_DB: N (délai manuel)
        public.get_default_value('clean_data.purchase_part_supplier', 'leadtime_auto_db') as leadtime_auto_db,
        
        -- RECEIVE_CASE_DB: INVDIR (réception directe en stock)
        public.get_default_value('clean_data.purchase_part_supplier', 'receive_case_db') as receive_case_db,
        
        -- EXTERNAL_SERVICE_ALLOWED_DB: FALSE
        public.get_default_value('clean_data.purchase_part_supplier', 'external_service_allowed_db') as external_service_allowed_db,
        
        -- PART_OWNERSHIP_DB: COMPANY OWNED
        public.get_default_value('clean_data.purchase_part_supplier', 'part_ownership_db') as part_ownership_db,
        
        -- DIST_ORDER_RECEIPT_TYPE_DB: NO AUTOMATIC RECPT
        public.get_default_value('clean_data.purchase_part_supplier', 'dist_order_receipt_type_db') as dist_order_receipt_type_db,
        
        -- MULTISITE_PLANNED_PART_DB: NOT_MULTISITE_PLAN
        public.get_default_value('clean_data.purchase_part_supplier', 'multisite_planned_part_db') as multisite_planned_part_db,
        
        -- QUICK_REGISTERED_PART_DB: FALSE
        public.get_default_value('clean_data.purchase_part_supplier', 'quick_registered_part_db') as quick_registered_part_db,
        
        -- PURCHASE_PAYMENT_TYPE_DB: NORMAL
        public.get_default_value('clean_data.purchase_part_supplier', 'purchase_payment_type_db') as purchase_payment_type_db,
        
        -- ACQUISITION_TYPE_DB: PURCHASE
        public.get_default_value('clean_data.purchase_part_supplier', 'acquisition_type_db') as acquisition_type_db,
        
        -- RENTAL_PRIMARY_VENDOR_DB: N
        public.get_default_value('clean_data.purchase_part_supplier', 'rental_primary_vendor_db') as rental_primary_vendor_db,
        
        -- USE_PRICE_INCL_TAX_DB: FALSE
        public.get_default_value('clean_data.purchase_part_supplier', 'use_price_incl_tax_db') as use_price_incl_tax_db,
        
        -- QUALIFIED_SUPPLIER_DB: FALSE
        public.get_default_value('clean_data.purchase_part_supplier', 'qualified_supplier_db') as qualified_supplier_db,
        
        -- EXT_SVC_PRIMARY_VENDOR_DB: FALSE
        public.get_default_value('clean_data.purchase_part_supplier', 'ext_svc_primary_vendor_db') as ext_svc_primary_vendor_db,
        
        -- ISSUE_PACKAGING_MATERIAL_DB: FALSE
        public.get_default_value('clean_data.purchase_part_supplier', 'issue_packaging_material_db') as issue_packaging_material_db
        
    FROM raw_data.eina eina
    INNER JOIN raw_data.eine eine 
        ON eina.infnr = eine.infnr
        AND eine.mandt = '700'
    INNER JOIN clean_data.ifs_article_maitre ifs
        ON eina.matnr::text = ifs.numero_article
    -- Mapping LIFNR SAP -> identifiant IFS (600xxx) depuis supplier_info_general
    -- (demande explicite) et non depuis le fichier de sélection : c'est la table
    -- fournisseur chargée qui fait foi côté IFS, et elle suit les renumérotations
    -- appliquées après coup (sp_update_supplier_id_cascade), que le fichier ignore.
    -- supplier_legacy_sap_id porte le LIFNR SAP d'origine ; les zéros de tête
    -- diffèrent selon la source ("45036" vs "0000045036"), d'où le LTRIM.
    -- INNER JOIN volontaire : un lien vers un fournisseur absent de
    -- supplier_info_general serait rejeté au chargement, on n'insère donc que
    -- les liens valides. Corollaire : si le module fournisseur n'est pas chargé
    -- (ou a été amputé par sp_keep_supplier_sample/_top20), les liens
    -- correspondants ne sortent pas.
    INNER JOIN clean_data.supplier_info_general sig
        ON LTRIM(TRIM(sig.supplier_legacy_sap_id), '0') = LTRIM(TRIM(eina.lifnr), '0')
    WHERE
        -- Filtrer sur les organisations d'achat Trimet
        eine.ekorg IN ('9200', '9000')
        -- Exclure les enregistrements supprimés
        AND (eina.loekz IS NULL OR eina.loekz = '')
        AND (eine.loekz IS NULL OR eine.loekz = '')
        -- Article et fournisseur non vides
        AND TRIM(eina.matnr) != ''
        AND TRIM(eina.lifnr) != ''
        -- L'article doit exister dans purchase_part (table parente du lien) :
        -- la presence dans ifs_article_maitre ne suffit pas, purchase_part
        -- applique ses propres filtres. Sans ce garde, le lien est rejete au
        -- chargement IFS faute d'article d'achat.
        AND EXISTS (
            SELECT 1 FROM clean_data.purchase_part pp
            WHERE pp.part_no = SUBSTRING(TRIM(LTRIM(ifs.numero_article, '0')), 1, 25)
              AND pp.contract = CASE
                    WHEN eine.ekorg = '9200' THEN 'SJ'
                    WHEN eine.ekorg = '9000' THEN 'CS'
                    ELSE 'SJ'
                  END
        )
    ORDER BY contract, part_no, vendor_no;
    
    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;

    -- ------------------------------------------------------------------
    -- Election du fournisseur principal : exactement une ligne 'Y' par
    -- (contract, part_no), toutes les autres restent a 'N'. Ordre de priorite :
    --   1. fournisseur fixe de la liste de sources SAP (raw_data.eord, flifn='X',
    --      valide a la date du jour) sur la division du site (9200 -> SJ, 9000 -> CS) ;
    --   2. a defaut, fournisseur fixe sur l'ancienne division (2200 -> SJ, 2000 -> CS) ;
    --   3. a defaut, derniere date de commande la plus recente (eine.datlb) ;
    --   4. puis fiche-info creee le plus recemment (eina.erdat) ;
    --   5. puis le plus petit vendor_no (departage stable et reproductible).
    -- Les cles sont normalisees une fois dans des CTE (LTRIM des zeros de tete,
    -- LIFNR -> supplier_id) pour joindre en hash et non en boucle par ligne.
    -- Mesure au 2026-09-18 : 7 580 articles multi-fournisseurs, dont 92 % ont un
    -- fournisseur fixe EORD parmi leurs liens.
    -- ------------------------------------------------------------------
    WITH fixes AS (
        SELECT
            LTRIM(TRIM(e.matnr), '0')                                       AS part_no,
            CASE WHEN e.werks IN ('9200', '2200') THEN 'SJ' ELSE 'CS' END     AS contract,
            sig.supplier_id                                                 AS vendor_no,
            MIN(CASE WHEN e.werks IN ('9200', '9000') THEN 1 ELSE 2 END)     AS rang_fixe
        FROM raw_data.eord e
        INNER JOIN clean_data.supplier_info_general sig
            ON LTRIM(TRIM(sig.supplier_legacy_sap_id), '0') = LTRIM(TRIM(e.lifnr), '0')
        WHERE e.mandt = '700'
          AND e.flifn = 'X'
          AND e.werks IN ('9200', '9000', '2200', '2000')
          AND COALESCE(NULLIF(e.vdatu, ''), '00000000') <= TO_CHAR(CURRENT_DATE, 'YYYYMMDD')
          AND COALESCE(NULLIF(e.bdatu, ''), '99991231') >= TO_CHAR(CURRENT_DATE, 'YYYYMMDD')
        GROUP BY 1, 2, 3
    ),
    commandes AS (
        SELECT
            LTRIM(TRIM(eina.matnr), '0')                                    AS part_no,
            CASE WHEN eine.ekorg = '9000' THEN 'CS' ELSE 'SJ' END            AS contract,
            sig.supplier_id                                                 AS vendor_no,
            MAX(NULLIF(NULLIF(TRIM(eine.datlb), ''), '00000000'))           AS derniere_commande,
            MAX(NULLIF(NULLIF(TRIM(eina.erdat), ''), '00000000'))           AS fiche_info
        FROM raw_data.eina eina
        INNER JOIN raw_data.eine eine
            ON eine.infnr = eina.infnr AND eine.mandt = '700'
        INNER JOIN clean_data.supplier_info_general sig
            ON LTRIM(TRIM(sig.supplier_legacy_sap_id), '0') = LTRIM(TRIM(eina.lifnr), '0')
        WHERE eine.ekorg IN ('9200', '9000')
        GROUP BY 1, 2, 3
    ),
    classement AS (
        SELECT
            pps.ctid AS rid,
            ROW_NUMBER() OVER (
                PARTITION BY pps.contract, pps.part_no
                ORDER BY fx.rang_fixe ASC NULLS LAST,
                         cmd.derniere_commande DESC NULLS LAST,
                         cmd.fiche_info DESC NULLS LAST,
                         pps.vendor_no ASC
            ) AS rn
        FROM clean_data.purchase_part_supplier pps
        LEFT JOIN fixes fx
            ON fx.contract = pps.contract AND fx.part_no = pps.part_no AND fx.vendor_no = pps.vendor_no
        LEFT JOIN commandes cmd
            ON cmd.contract = pps.contract AND cmd.part_no = pps.part_no AND cmd.vendor_no = pps.vendor_no
    )
    UPDATE clean_data.purchase_part_supplier pps
    SET primary_vendor_db = 'Y'
    FROM classement c
    WHERE c.rid = pps.ctid
      AND c.rn = 1;

    GET DIAGNOSTICS v_count_primary = ROW_COUNT;
    
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;
    
    -- Log des résultats
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Alimentation PURCHASE_PART_SUPPLIER terminée';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Relations article-fournisseur insérées: %', v_count_inserted;
    RAISE NOTICE 'Fournisseurs principaux élus (1 par site/article): %', v_count_primary;
    RAISE NOTICE 'Durée d''exécution: %', v_duration;
    RAISE NOTICE '====================================================';
    
EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;
        
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'ERREUR lors de l''alimentation PURCHASE_PART_SUPPLIER';
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'Code d''erreur: %', SQLSTATE;
        RAISE NOTICE 'Message: %', SQLERRM;
        RAISE NOTICE 'Durée avant erreur: %', v_duration;
        RAISE NOTICE '====================================================';
        
        RAISE;
END;
$function$
;
