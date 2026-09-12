-- ============================================================================
-- clean_data.alimenter_commande_achat_ifs : chargement des commandes d'achat
-- SAP ouvertes vers clean_data.commande_achat_ifs (format de reprise IFS).
-- ============================================================================
-- Sources : raw_data.ekko (en-tete), ekpo (postes), ekbe (mouvements : recu /
--           facture), eket (echeances de livraison), ekpa (partenaires),
--           ekkn (imputations), lfa1, t001w, adrc, prps.
-- Fournisseur IFS : public.get_vendor_no_ifs(lifnr) -> numero de compte IFS
--           du fichier de selection (regle projet du 2026-09-10), NULL si le
--           fournisseur n'y figure pas. Jamais le LIFNR brut.
-- Societe : STJN uniquement (bukrs, demande explicite du 2026-09-12). APSJ,
--           ancienne societe arretee en 2014, portait 1 543 postes jamais clos
--           (1998-2014) qui n'ont pas a etre repris.
-- Site    : deduit de la DIVISION (werks 9200/2200 = SJ, 9000/2000 = CS),
--           comme dans le module inventory. La societe ne convient pas pour
--           le site : STJN couvre les deux usines. En repli en-tete, une commande sans aucun
--           mouvement EKBE n'a pas de site (NULL) : ekpa.werks est vide et
--           l'organisation d'achat ekorg ne distingue pas les usines.
-- Unite   : transcodification UOM, repli '*' (unite generique IFS) si absente,
--           comme dans le module inventory.
--
-- Comportement : TRUNCATE + rechargement complet a chaque appel (snapshot des
-- commandes ouvertes : le reliquat evolue a chaque run, pas d'historique).
--
-- DEUX BRANCHES selon l'etat de raw_data.ekpo :
--   * ekpo alimentee -> niveau POSTE : une ligne par poste EKPO non supprime,
--     non clos (ekpo.elikz vide = pas de "livraison finale") et dont le
--     reliquat a livrer (menge - recu EKBE) est > 0. Cible finale. Les postes
--     anciens que les acheteurs n'ont jamais clos dans SAP restent ouverts :
--     borner par p_date_debut si le metier ne veut pas les reprendre.
--   * ekpo VIDE (defaut d'extraction constate le 11/09/2026, ekkn vide aussi)
--     -> RAISE WARNING puis repli EN-TETE : une ligne par commande EKKO, les
--     colonnes de poste restent NULL. Le reliquat est alors approche par les
--     echeances EKET (quantite prevue menge - quantite recue wemng > 0 sur au
--     moins un poste : 20 420 commandes au 11/09/2026), et le site vient de la
--     division majoritaire des mouvements EKBE de la commande. Rejouer le
--     chargement des que ekpo est rechargee.
--
-- Performance : get_vendor_no_ifs balaie le fichier a chaque appel (LTRIM,
-- pas d'index) ; elle est donc appelee UNE fois par LIFNR distinct (CTE
-- fournisseur_ifs) et non par ligne (2 appels x 358 k en-tetes = > 5 min).
--
-- Parametres :
--   p_date_debut / p_date_fin : bornes sur EKKO-AEDAT (NULL = pas de borne).
--                               Transmises par module_params du module ETL
--                               ({"date_debut": "2026-01-01", ...}).
--   p_ebeln                   : une commande precise (NULL = toutes).
-- Retour : nombre de lignes chargees.
--
-- Points ouverts : ACHETEUR_SAP (ekgrp) reste brut, aucune categorie de
-- transcodification "acheteur" n'existe. raw_data.ekkn etant vide, la
-- pre-imputation (PRE_IMPUTATION_PROJET) restera NULL tant qu'elle ne sera pas
-- rechargee, meme au niveau poste.
-- ============================================================================

-- Dates SAP : 'YYYYMMDD' (format d'extraction) ou 'YYYY-MM-DD' ; NULL sinon.
CREATE OR REPLACE FUNCTION clean_data.commande_achat_to_date(p_txt text)
RETURNS date
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE
        WHEN TRIM(p_txt) ~ '^[0-9]{8}$' AND TRIM(p_txt) <> '00000000'
            THEN TO_DATE(TRIM(p_txt), 'YYYYMMDD')
        WHEN TRIM(p_txt) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN TO_DATE(TRIM(p_txt), 'YYYY-MM-DD')
    END;
$$;

-- Montants/quantites SAP extraits en texte, virgule decimale possible.
CREATE OR REPLACE FUNCTION clean_data.commande_achat_to_num(p_txt text)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT NULLIF(REPLACE(TRIM(p_txt), ',', '.'), '')::numeric;
$$;

-- Division SAP -> site IFS. 9200/9000 = divisions Trimet actuelles ; 2200/2000
-- = les memes usines sous l'ancienne societe APSJ (t001w : "ST JEAN",
-- "CASTELSARRASIN"), encore portees par d'anciennes commandes jamais soldees.
CREATE OR REPLACE FUNCTION clean_data.commande_achat_site(p_werks text)
RETURNS varchar
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE TRIM(p_werks)
        WHEN '9200' THEN 'SJ'
        WHEN '2200' THEN 'SJ'
        WHEN '9000' THEN 'CS'
        WHEN '2000' THEN 'CS'
        ELSE NULLIF(TRIM(p_werks), '')
    END::varchar;
$$;

-- L'ancienne version renvoyait void : CREATE OR REPLACE ne peut pas changer
-- le type de retour.
DROP FUNCTION IF EXISTS clean_data.alimenter_commande_achat_ifs(date, date, varchar);

CREATE OR REPLACE FUNCTION clean_data.alimenter_commande_achat_ifs(
    p_date_debut date DEFAULT NULL,
    p_date_fin   date DEFAULT NULL,
    p_ebeln      varchar DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_nb_lignes integer := 0;
    v_debut     timestamp := clock_timestamp();
    v_ekpo_vide boolean;
BEGIN
    RAISE NOTICE '[%] Debut alimentation clean_data.commande_achat_ifs (p_date_debut=%, p_date_fin=%, p_ebeln=%)',
        clock_timestamp(), p_date_debut, p_date_fin, p_ebeln;

    SELECT NOT EXISTS (SELECT 1 FROM raw_data.ekpo) INTO v_ekpo_vide;

    TRUNCATE TABLE clean_data.commande_achat_ifs;

    IF v_ekpo_vide THEN
        RAISE WARNING 'raw_data.ekpo est VIDE : chargement en repli EN-TETE (une ligne par commande, colonnes de poste NULL, commandes ouvertes = reliquat EKET > 0, site = division des mouvements EKBE, NULL sans mouvement). Recharger ekpo (et ekkn) puis rejouer le module.';

        INSERT INTO clean_data.commande_achat_ifs (
            site, societe_sap, num_commande_sap, num_ligne_sap,
            fournisseur_sap, fournisseur_ifs, nom_fournisseur,
            fournisseur_facturation_sap, fournisseur_facturation_ifs,
            devise, taux_change, date_creation,
            acheteur_sap, condition_paiement, condition_livraison, mode_expedition
        )
        WITH
        partenaire_facturation AS (
            SELECT ebeln, lifn2
            FROM (
                SELECT ebeln, lifn2,
                    ROW_NUMBER() OVER (
                        PARTITION BY ebeln
                        ORDER BY CASE parvw WHEN 'RS' THEN 1 WHEN 'PI' THEN 2 ELSE 9 END, lifn2
                    ) AS rn
                FROM raw_data.ekpa
                WHERE parvw IN ('RS', 'PI') AND COALESCE(lifn2, '') <> ''
            ) x WHERE rn = 1
        ),
        -- Numero de compte IFS, resolu une fois par LIFNR distinct (cf. en-tete)
        fournisseur_ifs AS (
            SELECT l.lifnr, public.get_vendor_no_ifs(l.lifnr) AS numero_compte_ifs
            FROM (
                SELECT lifnr FROM raw_data.ekko WHERE COALESCE(lifnr, '') <> ''
                UNION
                SELECT lifn2 FROM partenaire_facturation
            ) l
        ),
        -- Commande ouverte : au moins un poste dont les echeances EKET portent
        -- une quantite prevue superieure a la quantite recue. Pre-agrege en une
        -- passe : un EXISTS correle serait un balayage de EKET par commande (les
        -- index SAP commencent par mandt, ebeln seul ne les utilise pas).
        commande_ouverte AS (
            SELECT DISTINCT ebeln
            FROM (
                SELECT ebeln, ebelp,
                    SUM(COALESCE(clean_data.commande_achat_to_num(menge), 0)
                        - COALESCE(clean_data.commande_achat_to_num(wemng), 0)) AS reliquat
                FROM raw_data.eket
                GROUP BY ebeln, ebelp
            ) p
            WHERE p.reliquat > 0
        ),
        -- Division majoritaire des mouvements de la commande (ekpo indisponible)
        division_commande AS (
            SELECT ebeln, werks
            FROM (
                SELECT ebeln, werks,
                    ROW_NUMBER() OVER (PARTITION BY ebeln ORDER BY COUNT(*) DESC, werks) AS rn
                FROM raw_data.ekbe
                WHERE COALESCE(werks, '') <> ''
                GROUP BY ebeln, werks
            ) x WHERE rn = 1
        ),
        base AS (
            SELECT
                ekko.ebeln, ekko.bukrs, ekko.lifnr, ekko.waers, ekko.wkurs,
                clean_data.commande_achat_to_date(ekko.aedat) AS aedat,
                ekko.zterm, ekko.inco1, ekko.inco2, ekko.ekgrp,
                lfa1.name1 AS nom_fournisseur,
                COALESCE(pf.lifn2, ekko.lifnr) AS fournisseur_facturation_sap,
                dc.werks
            FROM raw_data.ekko ekko
            LEFT JOIN raw_data.lfa1 lfa1
                ON lfa1.mandt = ekko.mandt AND lfa1.lifnr = ekko.lifnr
            LEFT JOIN partenaire_facturation pf ON pf.ebeln = ekko.ebeln
            LEFT JOIN division_commande dc ON dc.ebeln = ekko.ebeln
            INNER JOIN commande_ouverte co ON co.ebeln = ekko.ebeln
            WHERE ekko.bstyp = 'F'
              -- Societe STJN uniquement (demande explicite du 2026-09-12) : APSJ
              -- (ancienne societe, 1998-2014) portait 1 543 postes jamais clos.
              AND ekko.bukrs = 'STJN'
              AND (ekko.loekz IS NULL OR ekko.loekz = '')  -- estimable par le planificateur, COALESCE ne l'est pas
              -- Bornes comparees en texte sur aedat (YYYYMMDD sur 100 % des
              -- lignes) : un predicat via fonction n'a pas de statistiques, le
              -- planificateur estimait 8 commandes et partait en boucles
              -- imbriquees (> 5 min). Sans borne, aucun predicat n'est ajoute.
              AND (p_date_debut IS NULL OR ekko.aedat >= TO_CHAR(p_date_debut, 'YYYYMMDD'))
              AND (p_date_fin   IS NULL OR ekko.aedat <= TO_CHAR(p_date_fin,   'YYYYMMDD'))
              AND (p_ebeln IS NULL OR ekko.ebeln = p_ebeln)
        )
        SELECT
            clean_data.commande_achat_site(base.werks),
            base.bukrs,
            base.ebeln,
            NULL,
            base.lifnr,
            f1.numero_compte_ifs,
            base.nom_fournisseur,
            base.fournisseur_facturation_sap,
            f2.numero_compte_ifs,
            base.waers,
            base.wkurs,
            TO_CHAR(base.aedat, 'DD/MM/YYYY'),
            base.ekgrp,
            base.zterm,
            base.inco1 || CASE WHEN NULLIF(TRIM(base.inco2), '') IS NOT NULL THEN ' ' || TRIM(base.inco2) ELSE '' END,
            '10'
        FROM base
        LEFT JOIN fournisseur_ifs f1 ON f1.lifnr = base.lifnr
        LEFT JOIN fournisseur_ifs f2 ON f2.lifnr = base.fournisseur_facturation_sap
        ORDER BY base.ebeln;

        GET DIAGNOSTICS v_nb_lignes = ROW_COUNT;

    ELSE
        INSERT INTO clean_data.commande_achat_ifs (
            site, societe_sap, num_commande_sap, num_ligne_sap,
            fournisseur_sap, fournisseur_ifs, nom_fournisseur,
            fournisseur_facturation_sap, fournisseur_facturation_ifs,
            type_ligne_ifs, article_sap, designation, qte_commandee, qte_restant_livrer,
            qte_restant_facturer, unite_achat, prix_net_unitaire, montant_restant_livrer,
            montant_restant_facturer, devise, taux_change, date_creation,
            date_livraison_planifiee, date_reception_souhaitee, date_livraison_promise,
            acheteur_sap, condition_paiement, condition_livraison, mode_expedition,
            adresse_livraison, code_postal_livraison, ville_livraison, pays_livraison,
            pre_imputation_projet
        )
        WITH
        -- Quantites recues (vgabe 1) et facturees (vgabe 2/3), les annulations
        -- (shkzg = 'H') en negatif ; date de la derniere reception.
        ekbe_resume AS (
            SELECT
                ebeln, ebelp,
                SUM(CASE WHEN vgabe = '1'
                         THEN COALESCE(clean_data.commande_achat_to_num(menge), 0)
                              * CASE WHEN shkzg = 'H' THEN -1 ELSE 1 END
                         ELSE 0 END) AS qte_recue,
                SUM(CASE WHEN vgabe IN ('2', '3')
                         THEN COALESCE(clean_data.commande_achat_to_num(menge), 0)
                              * CASE WHEN shkzg = 'H' THEN -1 ELSE 1 END
                         ELSE 0 END) AS qte_facturee,
                MAX(CASE WHEN vgabe = '1' THEN clean_data.commande_achat_to_date(budat) END) AS date_derniere_reception
            FROM raw_data.ekbe
            GROUP BY ebeln, ebelp
        ),
        -- Prochaine echeance de livraison a venir, sinon la derniere connue
        eket_resume AS (
            SELECT
                ebeln, ebelp,
                MIN(CASE WHEN clean_data.commande_achat_to_date(eindt) >= CURRENT_DATE
                         THEN clean_data.commande_achat_to_date(eindt) END) AS date_livraison_future,
                MAX(clean_data.commande_achat_to_date(eindt)) AS date_livraison_derniere
            FROM raw_data.eket
            GROUP BY ebeln, ebelp
        ),
        partenaire_facturation AS (
            SELECT ebeln, lifn2
            FROM (
                SELECT ebeln, lifn2,
                    ROW_NUMBER() OVER (
                        PARTITION BY ebeln
                        ORDER BY CASE parvw WHEN 'RS' THEN 1 WHEN 'PI' THEN 2 ELSE 9 END, lifn2
                    ) AS rn
                FROM raw_data.ekpa
                WHERE parvw IN ('RS', 'PI') AND COALESCE(lifn2, '') <> ''
            ) x WHERE rn = 1
        ),
        -- Numero de compte IFS, resolu une fois par LIFNR distinct (cf. en-tete)
        fournisseur_ifs AS (
            SELECT l.lifnr, public.get_vendor_no_ifs(l.lifnr) AS numero_compte_ifs
            FROM (
                SELECT lifnr FROM raw_data.ekko WHERE COALESCE(lifnr, '') <> ''
                UNION
                SELECT lifn2 FROM partenaire_facturation
            ) l
        ),
        base AS (
            SELECT
                ekko.ebeln, ekpo.ebelp, ekko.bukrs, ekko.lifnr, ekko.waers, ekko.wkurs,
                clean_data.commande_achat_to_date(ekko.aedat) AS aedat,
                ekko.zterm, ekko.inco1, ekko.inco2, ekko.ekgrp,
                ekpo.matnr, ekpo.txz01, ekpo.werks,
                clean_data.commande_achat_to_num(ekpo.menge) AS menge,
                ekpo.meins,
                clean_data.commande_achat_to_num(ekpo.netpr) AS netpr,
                clean_data.commande_achat_to_num(ekpo.peinh) AS peinh,
                ekkn.kostl, ekkn.aufnr, ekkn.sakto,
                eket.date_livraison_future, eket.date_livraison_derniere,
                ekbe.qte_recue, ekbe.qte_facturee, ekbe.date_derniere_reception,
                lfa1.name1 AS nom_fournisseur,
                COALESCE(pf.lifn2, ekko.lifnr) AS fournisseur_facturation_sap,
                adrc.name1 AS adresse_nom, adrc.street, adrc.house_num1, adrc.post_code1,
                adrc.city1, adrc.country,
                prps.posid AS projet_posid
            FROM raw_data.ekko ekko
            INNER JOIN raw_data.ekpo ekpo
                ON ekpo.mandt = ekko.mandt AND ekpo.ebeln = ekko.ebeln
            LEFT JOIN raw_data.lfa1 lfa1
                ON lfa1.mandt = ekko.mandt AND lfa1.lifnr = ekko.lifnr
            LEFT JOIN partenaire_facturation pf
                ON pf.ebeln = ekko.ebeln
            LEFT JOIN raw_data.ekkn ekkn
                ON ekkn.mandt = ekpo.mandt AND ekkn.ebeln = ekpo.ebeln AND ekkn.ebelp = ekpo.ebelp
               AND ekkn.zekkn = '01'
            LEFT JOIN eket_resume eket
                ON eket.ebeln = ekpo.ebeln AND eket.ebelp = ekpo.ebelp
            LEFT JOIN ekbe_resume ekbe
                ON ekbe.ebeln = ekpo.ebeln AND ekbe.ebelp = ekpo.ebelp
            LEFT JOIN raw_data.t001w t001w
                ON t001w.mandt = ekpo.mandt AND t001w.werks = ekpo.werks
            -- Adresse de livraison : celle du poste, sinon celle de la division
            LEFT JOIN raw_data.adrc adrc
                ON adrc.client = ekpo.mandt
               AND adrc.addrnumber = COALESCE(NULLIF(TRIM(ekpo.adrnr), ''), NULLIF(TRIM(ekpo.adrn2), ''), t001w.adrnr)
            LEFT JOIN raw_data.prps prps
                ON prps.mandt = ekkn.mandt AND prps.pspnr = ekkn.ps_psp_pnr
            WHERE ekko.bstyp = 'F'
              -- Societe STJN uniquement (demande explicite du 2026-09-12) : APSJ
              -- (ancienne societe, 1998-2014) portait 1 543 postes jamais clos.
              AND ekko.bukrs = 'STJN'
              AND (ekko.loekz IS NULL OR ekko.loekz = '')  -- estimable par le planificateur, COALESCE ne l'est pas
              AND (ekpo.loekz IS NULL OR ekpo.loekz = '')
              -- Poste OUVERT au sens SAP : pas d'indicateur "livraison finale"
              -- (elikz = 'X' cloture le poste meme si la quantite recue est
              -- inferieure a la commandee). Sans ce filtre, 58 397 postes
              -- partiellement livres puis clotures ressortaient, dont des
              -- postes de 1999 ; avec, 5 155 postes ouverts (12/09/2026).
              AND (ekpo.elikz IS NULL OR ekpo.elikz = '')
              -- Bornes comparees en texte sur aedat (YYYYMMDD sur 100 % des
              -- lignes) : un predicat via fonction n'a pas de statistiques, le
              -- planificateur estimait 8 commandes et partait en boucles
              -- imbriquees (> 5 min). Sans borne, aucun predicat n'est ajoute.
              AND (p_date_debut IS NULL OR ekko.aedat >= TO_CHAR(p_date_debut, 'YYYYMMDD'))
              AND (p_date_fin   IS NULL OR ekko.aedat <= TO_CHAR(p_date_fin,   'YYYYMMDD'))
              AND (p_ebeln IS NULL OR ekko.ebeln = p_ebeln)
        )
        SELECT
            clean_data.commande_achat_site(base.werks),
            base.bukrs,
            base.ebeln,
            base.ebelp,
            base.lifnr,
            f1.numero_compte_ifs,
            base.nom_fournisseur,
            base.fournisseur_facturation_sap,
            f2.numero_compte_ifs,
            CASE WHEN NULLIF(TRIM(base.matnr), '') IS NULL THEN 'NOPART' ELSE 'PART' END,
            -- Sans les zeros de tete SAP, comme clean_data.part_catalog.part_no
            NULLIF(LTRIM(TRIM(base.matnr), '0'), ''),
            REGEXP_REPLACE(COALESCE(base.txz01, ''), '[[:cntrl:]]', ' ', 'g'),
            base.menge,
            GREATEST(COALESCE(base.menge, 0) - COALESCE(base.qte_recue, 0), 0),
            GREATEST(COALESCE(base.menge, 0) - COALESCE(base.qte_facturee, 0), 0),
            COALESCE(public.get_transcodification('UOM', NULLIF(UPPER(TRIM(base.meins)), '')), '*'),
            ROUND(base.netpr / NULLIF(base.peinh, 0), 4),
            ROUND(GREATEST(COALESCE(base.menge, 0) - COALESCE(base.qte_recue, 0), 0) * base.netpr / NULLIF(base.peinh, 0), 4),
            ROUND(GREATEST(COALESCE(base.menge, 0) - COALESCE(base.qte_facturee, 0), 0) * base.netpr / NULLIF(base.peinh, 0), 4),
            base.waers,
            base.wkurs,
            TO_CHAR(base.aedat, 'DD/MM/YYYY'),
            TO_CHAR(COALESCE(base.date_livraison_future, base.date_livraison_derniere), 'DD/MM/YYYY'),
            TO_CHAR(base.date_derniere_reception, 'DD/MM/YYYY'),
            TO_CHAR(COALESCE(base.date_livraison_future, base.date_livraison_derniere), 'DD/MM/YYYY'),
            base.ekgrp,
            base.zterm,
            base.inco1 || CASE WHEN NULLIF(TRIM(base.inco2), '') IS NOT NULL THEN ' ' || TRIM(base.inco2) ELSE '' END,
            '10',
            TRIM(COALESCE(base.adresse_nom || ' ', '') || COALESCE(base.street || ' ', '') || COALESCE(base.house_num1, '')),
            base.post_code1,
            base.city1,
            base.country,
            CASE
                WHEN NULLIF(TRIM(base.projet_posid), '') IS NOT NULL THEN 'PROJET=' || TRIM(base.projet_posid)
                WHEN NULLIF(TRIM(base.kostl), '') IS NOT NULL THEN 'CENTRE_COUT=' || TRIM(base.kostl)
                WHEN NULLIF(TRIM(base.aufnr), '') IS NOT NULL THEN 'ORDRE=' || TRIM(base.aufnr)
                WHEN NULLIF(TRIM(base.sakto), '') IS NOT NULL THEN 'COMPTE=' || TRIM(base.sakto)
                ELSE NULL
            END
        FROM base
        LEFT JOIN fournisseur_ifs f1 ON f1.lifnr = base.lifnr
        LEFT JOIN fournisseur_ifs f2 ON f2.lifnr = base.fournisseur_facturation_sap
        WHERE COALESCE(base.menge, 0) - COALESCE(base.qte_recue, 0) > 0
        ORDER BY base.ebeln, base.ebelp;

        GET DIAGNOSTICS v_nb_lignes = ROW_COUNT;
    END IF;

    RAISE NOTICE '[%] % lignes chargees dans clean_data.commande_achat_ifs (mode %, duree %)',
        clock_timestamp(), v_nb_lignes,
        CASE WHEN v_ekpo_vide THEN 'EN-TETE' ELSE 'POSTE' END,
        clock_timestamp() - v_debut;

    RETURN v_nb_lignes;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '[%] ERREUR alimentation clean_data.commande_achat_ifs : % - %',
            clock_timestamp(), SQLSTATE, SQLERRM;
        RAISE;
END;
$$;

COMMENT ON FUNCTION clean_data.alimenter_commande_achat_ifs(date, date, varchar) IS
    'Recharge clean_data.commande_achat_ifs (TRUNCATE + INSERT) : commandes d''achat SAP ouvertes (reliquat > 0) au niveau poste EKPO, ou en repli en-tete EKKO si raw_data.ekpo est vide. Renvoie le nombre de lignes.';

-- Exemples :
--   SELECT clean_data.alimenter_commande_achat_ifs();                              -- toutes commandes ouvertes
--   SELECT clean_data.alimenter_commande_achat_ifs('2026-01-01', '2026-08-31');    -- periode bornee
