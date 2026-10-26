/* =====================================================================
   Reconstitution de ZCOA / ZCOS2300 (Etat détaillé des crédits
   d'investissement) sur raw_data — PostgreSQL

   ÉTAT DES SOURCES (vérifié le 26/10/2026)
     - COEP, COBK : absentes ; COOI, BPGE, COSP, BSEG, BKPF, COBRB,
       TKA01, TKA02, TBP0L, SKAT : vides.
     - Disponibles : RPSCO (base d'infos projet, OTP uniquement),
       PRPS, JEST, AUFK, EKKO, EKPO, EKKN, EKBE, LFA1, T001.

   CONSÉQUENCES
     - Requête 1 (synthèse) : OTP uniquement, via RPSCO.
         ENVELOPPE      = RPSCO WRTTP 41 (budget KBUD), année 0000 (global)
         PRIS EN CHARGE = RPSCO WRTTP 04 (réel), hors VORGA KOAO (répartition),
                          cumulé jusqu'à la période d'édition
         CDE NON RECEP. = RPSCO WRTTP 22 (engagement commande ouvert)
         TOTAL DA       = RPSCO WRTTP 21 (engagement DA ouvert)
         DISPONIBLE     = enveloppe - pris en charge - commandé non réceptionné
       Les ordres d'investissement (IM01) ne sont pas dans RPSCO : pas de
       budget ni de réel exploitable pour eux tant que COEP / COOI / BPGE
       ne sont pas chargées.
     - Requête 2 (détail par commande) : OTP + ordres, via EKKN/EKPO/EKBE.

   ÉCARTS CONNUS PAR RAPPORT À ZCOS2300
     - Engagements (WRTTP 21/22) : RPSCO les range par période de livraison
       prévue ; ils sont donc pris en totalité (encours actuel), sans
       coupure à la période d'édition (ZCOS2300 filtre COOI-BLDAT).
     - Détail : "pris en charge" par poste de commande approché par
       MAX(réceptionné, facturé) issus d'EKBE (ZCOS2300 lit COEP).
     - Statut des ordres : dates AUFK-IDAT1/2/3 comme ZCOS2300 ;
       fin de période = dernier jour du mois civil (variante d'exercice K4
       supposée, T009B non vérifiée).
     - Ledger RPSCO '0003' (seul ledger alimenté pour STJN, montants EUR).

   Paramètres : modifier le CTE "params" en tête de chaque requête.
   ===================================================================== */


/* =====================================================================
   REQUÊTE 1 — Synthèse par crédit (élément d'OTP)
   ===================================================================== */
WITH params AS (
    SELECT 'STJN'::text         AS p_bukrs,       -- société
           2026::int            AS p_annee,       -- édition à fin : année
           9::int               AS p_mois,        -- édition à fin : mois
           ARRAY['IV']::text[]  AS p_scope,       -- classe d'objets PS (IV = investissement)
           NULL::text           AS p_posid_like,  -- filtre OTP, ex. 'STJ-I-2025%' (NULL = tous)
           true                 AS p_lanc,        -- statut lancé (I0002)
           true                 AS p_clot,        -- statut clôturé technique (I0045)
           true                 AS p_serv         -- statut clôturé / mis en service (I0046)
),
otp AS (
    SELECT p.pspnr, p.posid, p.post1, p.verna, p.objnr
    FROM raw_data.prps p
    CROSS JOIN params pr
    WHERE p.pbukr = pr.p_bukrs
      AND p.scope = ANY (pr.p_scope)
      AND (pr.p_posid_like IS NULL OR p.posid LIKE pr.p_posid_like)
),
jest_otp AS (
    SELECT j.objnr,
           bool_or(j.stat = 'I0046') AS st_clos,
           bool_or(j.stat = 'I0045') AS st_teco,
           bool_or(j.stat = 'I0002') AS st_lanc
    FROM raw_data.jest j
    JOIN otp o ON o.objnr = j.objnr
    WHERE j.stat IN ('I0002', 'I0045', 'I0046')
      AND COALESCE(TRIM(j.inact), '') = ''
    GROUP BY j.objnr
),
otp_statut AS (
    SELECT o.*,
           CASE
               WHEN pr.p_serv AND js.st_clos THEN 'C'
               WHEN pr.p_clot AND js.st_teco THEN 'CLT'
               WHEN pr.p_lanc AND js.st_lanc THEN 'L'
           END AS statut
    FROM otp o
    CROSS JOIN params pr
    LEFT JOIN jest_otp js ON js.objnr = o.objnr
),
rpsco_val AS (
    SELECT r.objnr,
           r.wrttp,
           r.vorga,
           r.gjahr::int AS gjahr,
           v.per,
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
      AND r.wrttp IN ('04', '21', '22', '41')
),
cumul AS (
    SELECT v.objnr,
           SUM(v.mt) FILTER (WHERE v.wrttp = '41' AND v.gjahr = 0) AS budget_global,
           SUM(v.mt) FILTER (WHERE v.wrttp = '41' AND v.gjahr > 0) AS budget_annuel,
           SUM(v.mt) FILTER (
               WHERE v.wrttp = '04'
                 AND v.vorga <> 'KOAO'
                 AND (   v.gjahr < pr.p_annee
                      OR (v.gjahr = pr.p_annee
                          AND (v.per <= pr.p_mois OR (pr.p_mois = 12 AND v.per >= 13))))
           ) AS pris_en_charge,
           SUM(v.mt) FILTER (WHERE v.wrttp = '22') AS engag_cde,
           SUM(v.mt) FILTER (WHERE v.wrttp = '21') AS engag_da
    FROM rpsco_val v
    CROSS JOIN params pr
    GROUP BY v.objnr
)
SELECT
    pr.p_bukrs                                                        AS "SOCIETE",
    s.posid                                                           AS "CREDIT_OTP",
    s.post1                                                           AS "DESIGNATION",
    s.verna                                                           AS "RESPONSABLE",
    s.statut                                                          AS "STATUT",
    LPAD(pr.p_mois::text, 2, '0') || '/' || pr.p_annee                AS "PERIODE",
    ROUND(COALESCE(NULLIF(c.budget_global, 0), c.budget_annuel, 0), 2) AS "ENVELOPPE_CREDIT",
    ROUND(COALESCE(c.pris_en_charge, 0), 2)                           AS "PRIS_EN_CHARGE",
    ROUND(COALESCE(c.engag_cde, 0), 2)                                AS "COMMANDE_NON_RECEPTIONNE",
    ROUND(COALESCE(NULLIF(c.budget_global, 0), c.budget_annuel, 0)
          - COALESCE(c.pris_en_charge, 0)
          - COALESCE(c.engag_cde, 0), 2)                              AS "DISPONIBLE_SUR_CREDIT",
    ROUND(COALESCE(c.engag_da, 0), 2)                                 AS "TOTAL_DA"
FROM otp_statut s
CROSS JOIN params pr
LEFT JOIN cumul c ON c.objnr = s.objnr
WHERE s.statut IS NOT NULL
ORDER BY s.posid;


/* =====================================================================
   REQUÊTE 2 — Détail par crédit et par poste de commande
   (OTP et/ou ordres d'investissement, via EKKN / EKPO / EKBE)
   ===================================================================== */
WITH params AS (
    SELECT 'STJN'::text           AS p_bukrs,
           2026::int              AS p_annee,
           9::int                 AS p_mois,
           true                   AS p_otp,          -- coche "Eléments OTP ?"
           ARRAY['IV']::text[]    AS p_scope,
           NULL::text             AS p_posid_like,
           true                   AS p_ordre,        -- coche "Ordres ?"
           ARRAY['IM01']::text[]  AS p_auart,        -- types d'ordre
           NULL::text             AS p_aufnr_like,
           true                   AS p_lanc,
           true                   AS p_clot,
           true                   AS p_serv
),
fin AS (
    SELECT (make_date(pr.p_annee, pr.p_mois, 1) + INTERVAL '1 month - 1 day')::date AS d_fin
    FROM params pr
),
otp AS (
    SELECT p.pspnr, p.posid, p.post1, p.verna, p.objnr
    FROM raw_data.prps p
    CROSS JOIN params pr
    WHERE pr.p_otp
      AND p.pbukr = pr.p_bukrs
      AND p.scope = ANY (pr.p_scope)
      AND (pr.p_posid_like IS NULL OR p.posid LIKE pr.p_posid_like)
),
jest_otp AS (
    SELECT j.objnr,
           bool_or(j.stat = 'I0046') AS st_clos,
           bool_or(j.stat = 'I0045') AS st_teco,
           bool_or(j.stat = 'I0002') AS st_lanc
    FROM raw_data.jest j
    JOIN otp o ON o.objnr = j.objnr
    WHERE j.stat IN ('I0002', 'I0045', 'I0046')
      AND COALESCE(TRIM(j.inact), '') = ''
    GROUP BY j.objnr
),
ordres AS (
    SELECT a.aufnr, a.ktext, a.user2,
           CASE WHEN TRIM(a.idat1) ~ '^[0-9]{8}$' AND TRIM(a.idat1) <> '00000000'
                THEN TO_DATE(TRIM(a.idat1), 'YYYYMMDD') END AS d_lanc,
           CASE WHEN TRIM(a.idat2) ~ '^[0-9]{8}$' AND TRIM(a.idat2) <> '00000000'
                THEN TO_DATE(TRIM(a.idat2), 'YYYYMMDD') END AS d_teco,
           CASE WHEN TRIM(a.idat3) ~ '^[0-9]{8}$' AND TRIM(a.idat3) <> '00000000'
                THEN TO_DATE(TRIM(a.idat3), 'YYYYMMDD') END AS d_clos
    FROM raw_data.aufk a
    CROSS JOIN params pr
    WHERE pr.p_ordre
      AND a.bukrs = pr.p_bukrs
      AND a.auart = ANY (pr.p_auart)
      AND (pr.p_aufnr_like IS NULL OR a.aufnr LIKE pr.p_aufnr_like)
),
credits AS (
    SELECT 'OTP'::text AS type_credit,
           o.posid     AS credit,
           o.post1     AS libelle,
           o.verna     AS responsable,
           CASE
               WHEN pr.p_serv AND js.st_clos THEN 'C'
               WHEN pr.p_clot AND js.st_teco THEN 'CLT'
               WHEN pr.p_lanc AND js.st_lanc THEN 'L'
           END         AS statut,
           o.pspnr,
           NULL::text  AS aufnr
    FROM otp o
    CROSS JOIN params pr
    LEFT JOIN jest_otp js ON js.objnr = o.objnr
    UNION ALL
    SELECT 'ORDRE',
           od.aufnr,
           od.ktext,
           od.user2,
           CASE
               WHEN pr.p_serv AND od.d_clos <= f.d_fin THEN 'C'
               WHEN pr.p_clot AND od.d_teco <= f.d_fin
                   THEN CASE WHEN od.d_clos <= f.d_fin THEN NULL ELSE 'CLT' END
               WHEN pr.p_lanc AND od.d_lanc <= f.d_fin
                   THEN CASE WHEN od.d_teco <= f.d_fin THEN NULL ELSE 'L' END
           END,
           NULL::text,
           od.aufnr
    FROM ordres od
    CROSS JOIN params pr
    CROSS JOIN fin f
),
imput AS (
    SELECT c.type_credit, c.credit, c.libelle, c.responsable, c.statut,
           k.mandt, k.ebeln, k.ebelp, k.zekkn, k.menge AS k_menge, k.vproz
    FROM credits c
    JOIN raw_data.ekkn k ON k.ps_psp_pnr = c.pspnr
    WHERE c.statut IS NOT NULL
      AND c.pspnr IS NOT NULL
      AND COALESCE(TRIM(k.loekz), '') = ''
    UNION ALL
    SELECT c.type_credit, c.credit, c.libelle, c.responsable, c.statut,
           k.mandt, k.ebeln, k.ebelp, k.zekkn, k.menge, k.vproz
    FROM credits c
    JOIN raw_data.ekkn k ON k.aufnr = c.aufnr
    WHERE c.statut IS NOT NULL
      AND c.aufnr IS NOT NULL
      AND COALESCE(TRIM(k.loekz), '') = ''
),
postes AS (
    SELECT DISTINCT mandt, ebeln, ebelp FROM imput
),
nb_imput AS (
    SELECT k.mandt, k.ebeln, k.ebelp, COUNT(*) AS nb
    FROM raw_data.ekkn k
    JOIN postes p USING (mandt, ebeln, ebelp)
    WHERE COALESCE(TRIM(k.loekz), '') = ''
    GROUP BY k.mandt, k.ebeln, k.ebelp
),
ekbe_resume AS (
    SELECT b.mandt, b.ebeln, b.ebelp,
           SUM(CASE WHEN b.vgabe = '1'
                    THEN CASE WHEN b.shkzg = 'H' THEN -1 ELSE 1 END
                         * COALESCE(NULLIF(REPLACE(TRIM(b.dmbtr), ',', '.'), '')::numeric, 0)
                    ELSE 0 END) AS mt_recu,
           SUM(CASE WHEN b.bewtp IN ('R', 'N', 'Q', 'X')
                    THEN CASE WHEN b.shkzg = 'H' THEN -1 ELSE 1 END
                         * COALESCE(NULLIF(REPLACE(TRIM(b.dmbtr), ',', '.'), '')::numeric, 0)
                    ELSE 0 END) AS mt_facture,
           MAX(CASE WHEN b.vgabe = '1' THEN TO_DATE(TRIM(b.budat), 'YYYYMMDD') END) AS d_derniere_recep
    FROM raw_data.ekbe b
    JOIN postes p USING (mandt, ebeln, ebelp)
    CROSS JOIN fin f
    WHERE TRIM(b.budat) ~ '^[0-9]{8}$'
      AND TO_DATE(TRIM(b.budat), 'YYYYMMDD') <= f.d_fin
    GROUP BY b.mandt, b.ebeln, b.ebelp
),
lignes AS (
    SELECT i.type_credit, i.credit, i.libelle, i.responsable, i.statut,
           i.mandt, i.ebeln, i.ebelp,
           o.lifnr, o.waers,
           CASE WHEN TRIM(o.bedat) ~ '^[0-9]{8}$' THEN TO_DATE(TRIM(o.bedat), 'YYYYMMDD') END AS d_cde,
           REGEXP_REPLACE(COALESCE(p.txz01, ''), '[[:cntrl:]]', ' ', 'g') AS descriptif,
           COALESCE(TRIM(p.loekz), '') AS poste_supprime,
           COALESCE(TRIM(p.elikz), '') AS livraison_finale,
           COALESCE(NULLIF(REPLACE(TRIM(p.netwr), ',', '.'), '')::numeric, 0) AS netwr,
           -- conversion devise commande -> devise société (EKKO-WKURS ; négatif = cotation indirecte)
           CASE
               WHEN o.waers = t.waers THEN 1
               WHEN COALESCE(NULLIF(REPLACE(TRIM(o.wkurs), ',', '.'), '')::numeric, 0) > 0
                   THEN REPLACE(TRIM(o.wkurs), ',', '.')::numeric
               WHEN COALESCE(NULLIF(REPLACE(TRIM(o.wkurs), ',', '.'), '')::numeric, 0) < 0
                   THEN 1 / ABS(REPLACE(TRIM(o.wkurs), ',', '.')::numeric)
           END AS fx,
           -- quote-part du poste imputée au crédit (imputation multiple)
           CASE
               WHEN n.nb <= 1 THEN 1
               WHEN COALESCE(NULLIF(REPLACE(TRIM(p.menge), ',', '.'), '')::numeric, 0) > 0
                AND COALESCE(NULLIF(REPLACE(TRIM(i.k_menge), ',', '.'), '')::numeric, 0) > 0
                   THEN REPLACE(TRIM(i.k_menge), ',', '.')::numeric / REPLACE(TRIM(p.menge), ',', '.')::numeric
               WHEN COALESCE(NULLIF(REPLACE(TRIM(i.vproz), ',', '.'), '')::numeric, 0) > 0
                   THEN REPLACE(TRIM(i.vproz), ',', '.')::numeric / 100
               ELSE 1.0 / n.nb
           END AS quote_part
    FROM imput i
    JOIN nb_imput n USING (mandt, ebeln, ebelp)
    JOIN raw_data.ekpo p ON p.mandt = i.mandt AND p.ebeln = i.ebeln AND p.ebelp = i.ebelp
    JOIN raw_data.ekko o ON o.mandt = p.mandt AND o.ebeln = p.ebeln
    CROSS JOIN params pr
    LEFT JOIN raw_data.t001 t ON t.mandt = o.mandt AND t.bukrs = pr.p_bukrs
    CROSS JOIN fin f
    WHERE o.bstyp = 'F'
      AND TRIM(o.bedat) ~ '^[0-9]{8}$'
      AND TO_DATE(TRIM(o.bedat), 'YYYYMMDD') <= f.d_fin
),
detail AS (
    SELECT l.type_credit, l.credit, l.libelle, l.responsable, l.statut,
           l.ebeln, l.ebelp, l.d_cde, l.descriptif, l.lifnr, l.waers,
           l.poste_supprime, l.livraison_finale,
           SUM(l.netwr * l.fx * l.quote_part)                   AS mt_engage,
           SUM(COALESCE(e.mt_recu, 0) * l.quote_part)           AS mt_recu,
           SUM(COALESCE(e.mt_facture, 0) * l.quote_part)        AS mt_facture,
           MAX(e.d_derniere_recep)                              AS d_derniere_recep
    FROM lignes l
    LEFT JOIN ekbe_resume e ON e.mandt = l.mandt AND e.ebeln = l.ebeln AND e.ebelp = l.ebelp
    GROUP BY l.type_credit, l.credit, l.libelle, l.responsable, l.statut,
             l.ebeln, l.ebelp, l.d_cde, l.descriptif, l.lifnr, l.waers,
             l.poste_supprime, l.livraison_finale
)
SELECT
    d.type_credit                                                  AS "TYPE_CREDIT",
    d.credit                                                       AS "CREDIT",
    d.libelle                                                      AS "DESIGNATION_CREDIT",
    d.responsable                                                  AS "RESPONSABLE",
    d.statut                                                       AS "STATUT",
    d.ebeln                                                        AS "NUM_COMMANDE",
    LTRIM(d.ebelp, '0')                                            AS "POSTE",
    TO_CHAR(d.d_cde, 'DD/MM/YYYY')                                 AS "DATE_COMMANDE",
    d.descriptif                                                   AS "DESCRIPTIF",
    d.lifnr                                                        AS "FOURNISSEUR",
    lf.name1                                                       AS "NOM_FOURNISSEUR",
    d.waers                                                        AS "DEVISE_COMMANDE",
    ROUND(d.mt_engage, 2)                                          AS "ENGAGEMENT_HT_COMMANDE",
    TO_CHAR(d.d_derniere_recep, 'DD/MM/YYYY')                      AS "DATE_DERNIERE_RECEPTION",
    ROUND(d.mt_recu, 2)                                            AS "MONTANT_RECEPTIONNE",
    ROUND(d.mt_facture, 2)                                         AS "MONTANT_FACTURE",
    ROUND(GREATEST(d.mt_recu, d.mt_facture), 2)                    AS "PRIS_EN_CHARGE",
    ROUND(CASE WHEN d.livraison_finale = 'X' THEN 0
               ELSE GREATEST(d.mt_engage - GREATEST(d.mt_recu, d.mt_facture), 0)
          END, 2)                                                  AS "ECART_COMMANDE_NON_RECEPTIONNE",
    d.livraison_finale                                             AS "LIVRAISON_FINALE",
    d.poste_supprime                                               AS "POSTE_SUPPRIME"
FROM detail d
LEFT JOIN raw_data.lfa1 lf ON lf.lifnr = d.lifnr
WHERE d.poste_supprime = ''
   OR d.mt_recu <> 0
   OR d.mt_facture <> 0
ORDER BY d.type_credit, d.credit, d.ebeln, d.ebelp;


/* =====================================================================
   REQUÊTE 3 — Historique des coûts par projet (définition de projet PROJ)
   Une ligne par projet / année / période, à partir de RPSCO (ledger 0003,
   version 000), tous les éléments d'OTP du projet cumulés (PRPS.PSPHI).
     REEL          = WRTTP 04 hors répartition (VORGA KOAO)
     PLAN          = WRTTP 01 (planification de coûts)
     BUDGET_ANNUEL = WRTTP 41 (budget KBUD ventilé par année, période 0)
     ENGAG_CDE/DA  = WRTTP 22 / 21, rangés par période de livraison prévue
     REEL_CUMULE   = cumul du réel depuis le début de l'historique
   Le budget global (année 0000) est exclu : il n'a pas de période.
   Pour le détail par élément d'OTP, ajouter p.posid / p.post1 dans le CTE
   otp et dans les GROUP BY / PARTITION BY.
   ===================================================================== */
WITH params AS (
    SELECT 'STJN'::text      AS p_bukrs,
           NULL::text[]      AS p_scope,         -- ex. ARRAY['IV'] ; NULL = toutes classes d'objets
           NULL::text        AS p_pspid_like,    -- ex. 'SN24052%' ; NULL = tous les projets
           2000::int         AS p_annee_debut,
           2026::int         AS p_annee_fin
),
otp AS (
    SELECT p.objnr, j.pspid, j.post1 AS projet_libelle, j.verna
    FROM raw_data.prps p
    JOIN raw_data.proj j ON j.mandt = p.mandt AND j.pspnr = p.psphi
    CROSS JOIN params pr
    WHERE p.pbukr = pr.p_bukrs
      AND (pr.p_scope IS NULL OR p.scope = ANY (pr.p_scope))
      AND (pr.p_pspid_like IS NULL OR j.pspid LIKE pr.p_pspid_like)
),
val AS (
    SELECT o.pspid, o.projet_libelle, o.verna,
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
),
histo AS (
    SELECT v.pspid, v.projet_libelle, v.verna, v.annee, v.periode,
           COALESCE(SUM(v.mt) FILTER (WHERE v.wrttp = '04' AND v.vorga <> 'KOAO'), 0) AS reel,
           COALESCE(SUM(v.mt) FILTER (WHERE v.wrttp = '01'), 0)                       AS plan,
           COALESCE(SUM(v.mt) FILTER (WHERE v.wrttp = '41'), 0)                       AS budget_annuel,
           COALESCE(SUM(v.mt) FILTER (WHERE v.wrttp = '22'), 0)                       AS engag_cde,
           COALESCE(SUM(v.mt) FILTER (WHERE v.wrttp = '21'), 0)                       AS engag_da
    FROM val v
    CROSS JOIN params pr
    WHERE v.annee BETWEEN pr.p_annee_debut AND pr.p_annee_fin
    GROUP BY v.pspid, v.projet_libelle, v.verna, v.annee, v.periode
    HAVING bool_or(v.mt <> 0)
)
SELECT
    h.pspid                                                     AS "PROJET",
    h.projet_libelle                                            AS "DESIGNATION_PROJET",
    h.verna                                                     AS "RESPONSABLE",
    h.annee                                                     AS "ANNEE",
    h.periode                                                   AS "PERIODE",
    ROUND(h.reel, 2)                                            AS "REEL",
    ROUND(SUM(h.reel) OVER (PARTITION BY h.pspid
                            ORDER BY h.annee, h.periode), 2)    AS "REEL_CUMULE",
    ROUND(h.plan, 2)                                            AS "PLAN",
    ROUND(h.budget_annuel, 2)                                   AS "BUDGET_ANNUEL",
    ROUND(h.engag_cde, 2)                                       AS "ENGAG_CDE",
    ROUND(h.engag_da, 2)                                        AS "ENGAG_DA"
FROM histo h
ORDER BY h.pspid, h.annee, h.periode;
