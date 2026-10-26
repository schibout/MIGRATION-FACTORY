-- ============================================================================
-- clean_data.alimenter_historique_cout_projet(p_bukrs)
-- Recharge clean_data.historique_cout_projet depuis raw_data.rpsco / prps / proj
-- (requete 3 de docs/zcoa_credits_investissement_raw_data.sql, au grain OTP).
--   reel          = WRTTP 04 hors repartition (VORGA KOAO)
--   plan          = WRTTP 01
--   budget_annuel = WRTTP 41 (budget global annee 0000 exclu : sans periode)
--   engag_cde/da  = WRTTP 22 / 21, ranges par periode de livraison prevue
--   numero_projet = project_number SharePoint, meme regle que les commandes
--                   d'achat : cle = code sans les points ni le suffixe
--                   alphabetique final (OTP 'SN26052IM' / code 'SN.26052'),
--                   cherchee sur l'element d'OTP puis, a defaut, sur le projet
--                   (OTP numerotes 'SN1503302' : la cle de l'OTP ne resout pas).
--                   Code SharePoint en double : le plus recemment modifie gagne.
--   a_migrer      = numero_projet present dans clean_data.project_base
--                   (projets repris dans IFS) ; FALSE sinon ou sans n° projet.
-- Retourne le nombre de lignes chargees. Si rpsco est vide (extraction SAP en
-- cours), la table est laissee telle quelle et un WARNING est emis.
-- ============================================================================
CREATE OR REPLACE FUNCTION clean_data.alimenter_historique_cout_projet(p_bukrs text DEFAULT 'STJN')
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_n integer;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM raw_data.rpsco LIMIT 1) THEN
        RAISE WARNING 'raw_data.rpsco est vide : historique des couts non recharge';
        RETURN 0;
    END IF;

    TRUNCATE clean_data.historique_cout_projet;

    INSERT INTO clean_data.historique_cout_projet
        (projet, projet_libelle, responsable, numero_projet, a_migrer, element_otp, otp_libelle, annee, periode,
         reel, plan, budget_annuel, engag_cde, engag_da)
    WITH projet_sharepoint AS (
        SELECT DISTINCT ON (cle) cle, project_number
        FROM (
            SELECT REGEXP_REPLACE(REPLACE(UPPER(TRIM(code)), '.', ''), '[A-Z]+$', '') AS cle,
                   NULLIF(TRIM(project_number), '') AS project_number, modified
            FROM raw_data.sharepoint_projets
            WHERE NULLIF(TRIM(code), '') IS NOT NULL
        ) s
        ORDER BY cle, modified DESC NULLS LAST
    ),
    otp AS (
        SELECT p.objnr, p.posid, p.post1 AS otp_libelle,
               j.pspid, j.post1 AS projet_libelle, j.verna,
               COALESCE(so.project_number, sj.project_number) AS numero_projet
        FROM raw_data.prps p
        JOIN raw_data.proj j ON j.mandt = p.mandt AND j.pspnr = p.psphi
        LEFT JOIN projet_sharepoint so
               ON so.cle = REGEXP_REPLACE(REPLACE(UPPER(TRIM(p.posid)), '.', ''), '[A-Z]+$', '')
        LEFT JOIN projet_sharepoint sj
               ON sj.cle = REGEXP_REPLACE(REPLACE(UPPER(TRIM(j.pspid)), '.', ''), '[A-Z]+$', '')
        WHERE p.pbukr = p_bukrs
    ),
    val AS (
        SELECT o.pspid, o.projet_libelle, o.verna, o.numero_projet, o.posid, o.otp_libelle,
               r.gjahr::int AS annee,
               v.per        AS periode,
               r.wrttp,
               r.vorga,
               COALESCE(NULLIF(REPLACE(TRIM(v.val), ',', '.'), '')::numeric, 0) AS mt
        FROM raw_data.rpsco r
        JOIN otp o ON o.objnr = r.objnr
        CROSS JOIN LATERAL (VALUES
            (0,  r.wlp00), (1,  r.wlp01), (2,  r.wlp02), (3,  r.wlp03), (4,  r.wlp04),
            (5,  r.wlp05), (6,  r.wlp06), (7,  r.wlp07), (8,  r.wlp08), (9,  r.wlp09),
            (10, r.wlp10), (11, r.wlp11), (12, r.wlp12), (13, r.wlp13), (14, r.wlp14),
            (15, r.wlp15), (16, r.wlp16)
        ) AS v(per, val)
        WHERE r.lednr = '0003'
          AND r.versn = '000'
          AND r.wrttp IN ('01', '04', '21', '22', '41')
          AND r.gjahr <> '0000'
    )
    SELECT v.pspid, v.projet_libelle, v.verna, v.numero_projet,
           EXISTS (SELECT 1 FROM clean_data.project_base pb WHERE pb.project_id = v.numero_projet),
           v.posid, v.otp_libelle, v.annee, v.periode,
           COALESCE(SUM(v.mt) FILTER (WHERE v.wrttp = '04' AND v.vorga <> 'KOAO'), 0),
           COALESCE(SUM(v.mt) FILTER (WHERE v.wrttp = '01'), 0),
           COALESCE(SUM(v.mt) FILTER (WHERE v.wrttp = '41'), 0),
           COALESCE(SUM(v.mt) FILTER (WHERE v.wrttp = '22'), 0),
           COALESCE(SUM(v.mt) FILTER (WHERE v.wrttp = '21'), 0)
    FROM val v
    GROUP BY v.pspid, v.projet_libelle, v.verna, v.numero_projet, v.posid, v.otp_libelle, v.annee, v.periode
    -- Lignes dont toutes les mesures sont nulles ecartees, y compris quand des
    -- mouvements se compensent dans la periode (ex. COIE +3,82 / COIN -3,82).
    HAVING COALESCE(SUM(v.mt) FILTER (WHERE v.wrttp = '04' AND v.vorga <> 'KOAO'), 0) <> 0
        OR COALESCE(SUM(v.mt) FILTER (WHERE v.wrttp = '01'), 0) <> 0
        OR COALESCE(SUM(v.mt) FILTER (WHERE v.wrttp = '41'), 0) <> 0
        OR COALESCE(SUM(v.mt) FILTER (WHERE v.wrttp = '22'), 0) <> 0
        OR COALESCE(SUM(v.mt) FILTER (WHERE v.wrttp = '21'), 0) <> 0;

    GET DIAGNOSTICS v_n = ROW_COUNT;
    RAISE NOTICE 'historique_cout_projet : % lignes chargees (societe %)', v_n, p_bukrs;
    RETURN v_n;
END;
$$;
