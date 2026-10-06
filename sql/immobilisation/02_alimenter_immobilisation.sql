-- ============================================================================
-- clean_data.alimenter_immobilisation : immobilisations SAP au format de
-- l'extraction transmise aux metiers.
-- ============================================================================
-- Reprise fidele des deux scripts Hermes qui ont produit le fichier du
-- 18/08/2026 (/root/.hermes/exports/regenerer_immo_complet.py puis
-- /root/.hermes/rebuild_immo_statutory.py) :
--   * perimetre : societe STJN, toutes les immobilisations ANLA (sorties et
--     desactivees comprises) -> 7 725 lignes ;
--   * comptes : T095 zone 02 du plan comptable de la societe (T001) ;
--   * ANLB : une zone par immobilisation, priorite 03 > 73 > 02 > 60 > 01,
--     puis BDATU la plus recente ; duree = NDJAR*12 + NDPER mois, fin estimee
--     = AFABG + duree - 1 jour, taux = 1200 / duree ;
--   * ANLZ : periode en cours (BDATU 99991231), sinon la plus recente ;
--   * valeurs (passe « statutaire ») : zone 02, exercice p_gjahr (2027 = SAP
--     ouvert le 01/07/2026) ; acquisition = somme KANSW, amortissements cumules
--     = |somme KNAFA+KSAFA+KAAFA+KMAFA|, VNC = acquisition - cumul ;
--     mouvements, sorties et dotation a 0 ; tout a NULL si l'immobilisation
--     n'a pas de ligne ANLC sur cette zone et cet exercice ;
--   * libelles : langue F, puis E, puis le reste.
-- Seul ecart volontaire : libelle_complementaire = ANLA-TXA50 (le script y
-- recopiait TXT50).
--
-- Colonnes de REPRISE IFS (migration 098, onglets Methode / Travail /
-- Conversion cpte general du classeur metier du 18/08/2026) :
--   * reprise_ifs : pas de date de sortie (ABGDT), ou sortie > date de bascule
--     (p_date_bascule, sinon etl_default_values date_bascule_ifs, sinon
--     2026-06-30). Une sortie posterieure a la bascule est reprise, sa date de
--     sortie n'est pas a envoyer a IFS (etape 2 de la Methode) ;
--   * comptes IFS : transcodification FA_ACCOUNT (SAP -> IFS) des comptes T095 ;
--   * object_group_id : FA_OBJECT_GROUP_IMMO par numero d'immobilisation
--     (exceptions fiche par fiche), sinon FA_OBJECT_GROUP par classe ;
--   * site_ifs : division 9200 -> SJ, 9000 -> CS, sans division : secteur
--     9030 Fonderie Castel -> CS sinon SJ ;
--   * element_otp / libelle_otp : ANLA-POSNR -> raw_data.prps (POSID, POST1),
--     reponse a la question « code projet des fiches » (ANLA-PROJN est vide).
--   Les transcodifications sont resolues par valeur DISTINCTE (petites CTE),
--   jamais par ligne.
-- TRUNCATE + INSERT (idempotent). Retour : lignes chargees.
-- ============================================================================

-- Date SAP 'YYYYMMDD' -> date (NULL si vide ou 00000000).
CREATE OR REPLACE FUNCTION clean_data.immo_to_date(p_txt text)
RETURNS date
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE WHEN TRIM(p_txt) ~ '^[0-9]{8}$' AND TRIM(p_txt) <> '00000000'
                THEN TO_DATE(TRIM(p_txt), 'YYYYMMDD') END;
$$;

-- Premiere version (sans parametre) : sinon l'appel sans argument est ambigu.
DROP FUNCTION IF EXISTS clean_data.alimenter_immobilisation();

DROP FUNCTION IF EXISTS clean_data.alimenter_immobilisation(text);

CREATE OR REPLACE FUNCTION clean_data.alimenter_immobilisation(
    p_gjahr        text DEFAULT '2027',
    p_date_bascule date DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_nb       integer;
    v_bascule  date;
    v_reprise  integer;
    v_exclues  integer;
    v_sans_cpt integer;
    v_sans_grp integer;
BEGIN
    v_bascule := COALESCE(
        p_date_bascule,
        NULLIF(public.get_default_value('clean_data.immobilisation', 'date_bascule_ifs', 'STANDARD'), '')::date,
        DATE '2026-06-30');

    TRUNCATE clean_data.immobilisation;

    INSERT INTO clean_data.immobilisation
    WITH company AS (
        SELECT DISTINCT ON (bukrs) bukrs, ktopl FROM raw_data.t001 ORDER BY bukrs
    ), class_txt AS (
        SELECT DISTINCT ON (anlkl) anlkl,
               COALESCE(NULLIF(txt50, ''), NULLIF(txk50, ''), NULLIF(txk20, '')) AS txt
        FROM raw_data.ankt
        ORDER BY anlkl, CASE spras WHEN 'F' THEN 1 WHEN 'E' THEN 2 ELSE 9 END
    ), ktogr_txt AS (
        SELECT DISTINCT ON (ktogr) ktogr, ktgrtx FROM raw_data.t095t
        ORDER BY ktogr, CASE spras WHEN 'F' THEN 1 WHEN 'E' THEN 2 ELSE 9 END
    ), t095 AS (
        -- Comptes IFS resolus ici : une ligne par (plan, groupe de comptes), pas par fiche
        SELECT ktopl, ktogr, ktansw, ktanza, ktaufg,
               public.get_transcodification('FA_ACCOUNT', ktansw, 'SAP', 'IFS') AS ktansw_ifs,
               public.get_transcodification('FA_ACCOUNT', ktanza, 'SAP', 'IFS') AS ktanza_ifs
        FROM (
            SELECT DISTINCT ON (ktopl, ktogr) ktopl, ktogr,
                   NULLIF(LTRIM(ktansw::text, '0'), '') AS ktansw,
                   NULLIF(LTRIM(ktanza::text, '0'), '') AS ktanza,
                   NULLIF(LTRIM(ktaufg::text, '0'), '') AS ktaufg
            FROM raw_data.t095 WHERE TRIM(afabe) = '02' ORDER BY ktopl, ktogr
        ) t
    ), grp_classe AS (
        SELECT anlkl, public.get_transcodification('FA_OBJECT_GROUP', anlkl, 'SAP', 'IFS') AS grp
        FROM (SELECT DISTINCT anlkl FROM raw_data.anla WHERE bukrs = 'STJN') c
    ), grp_immo AS (
        -- Exceptions fiche par fiche : lecture directe (une jointure, pas 7 700 appels)
        SELECT source_value AS anln1, target_value AS grp
        FROM public."TranscodificationTable"
        WHERE category = 'FA_OBJECT_GROUP_IMMO' AND source_system = 'SAP'
          AND target_system = 'IFS' AND is_active
    ), otp AS (
        SELECT DISTINCT ON (pspnr) pspnr, posid, post1 FROM raw_data.prps ORDER BY pspnr
    ), anlc AS (
        SELECT TRIM(bukrs) AS bukrs, TRIM(anln1) AS anln1, TRIM(anln2) AS anln2,
               SUM(COALESCE(kansw, 0)) AS acq,
               ABS(SUM(COALESCE(knafa, 0) + COALESCE(ksafa, 0)
                     + COALESCE(kaafa, 0) + COALESCE(kmafa, 0))) AS cum
        FROM raw_data.anlc
        WHERE bukrs = 'STJN' AND TRIM(afabe) = '02' AND TRIM(gjahr) = p_gjahr
        GROUP BY 1, 2, 3
    ), anlb AS (
        SELECT * FROM (
            SELECT b.*, ROW_NUMBER() OVER (PARTITION BY bukrs, anln1, anln2 ORDER BY
                CASE TRIM(afabe) WHEN '03' THEN 1 WHEN '73' THEN 2 WHEN '02' THEN 3
                                 WHEN '60' THEN 4 WHEN '01' THEN 5 ELSE 9 END,
                bdatu DESC NULLS LAST) AS rn
            FROM raw_data.anlb b WHERE bukrs = 'STJN'
        ) x WHERE rn = 1
    ), anlz AS (
        SELECT * FROM (
            SELECT z.*, ROW_NUMBER() OVER (PARTITION BY bukrs, anln1, anln2 ORDER BY
                CASE WHEN bdatu IN ('99991231', '9999-12-31') THEN 0 ELSE 1 END,
                bdatu DESC NULLS LAST) AS rn
            FROM raw_data.anlz z WHERE bukrs = 'STJN'
        ) x WHERE rn = 1
    ), cc AS (
        SELECT DISTINCT ON (kostl) kostl,
               COALESCE(NULLIF(ltext, ''), NULLIF(ktext, ''), NULLIF(mctxt, '')) AS txt
        FROM raw_data.cskt
        ORDER BY kostl, CASE spras WHEN 'F' THEN 1 WHEN 'E' THEN 2 ELSE 9 END, datbi DESC NULLS LAST
    ), gs AS (
        SELECT DISTINCT ON (gsber) gsber, gtext FROM raw_data.tgsbt
        ORDER BY gsber, CASE spras WHEN 'F' THEN 1 WHEN 'E' THEN 2 ELSE 9 END
    ), dep AS (
        SELECT DISTINCT ON (afasl) afasl, afatxt FROM raw_data.t090nat
        ORDER BY afasl, CASE spras WHEN 'F' THEN 1 WHEN 'E' THEN 2 ELSE 9 END
    ), base AS (
        SELECT a.bukrs, a.anln1, a.anln2, a.txt50, a.txa50, a.anlkl, a.xloev, a.sernr,
               a.land1, a.ord41, a.ord42, a.ord43, a.ord44, a.projn, a.ktogr,
               a.aktiv, a.zugdt, a.aibn1, a.aibn2, a.aibdt, a.invnr, a.herst, a.typbz,
               a.lifnr, a.menge, a.meins, a.eaufn, a.xspeb, a.abgdt, a.deakt,
               ct.txt AS famille, kt.ktgrtx, t.ktansw, t.ktanza, t.ktaufg,
               t.ktansw_ifs, t.ktanza_ifs,
               COALESCE(gi.grp, gc.grp) AS object_group_id,
               CASE WHEN z.werks = '9000' THEN 'CS' WHEN z.werks = '9200' THEN 'SJ'
                    WHEN z.gsber = '9030' THEN 'CS' ELSE 'SJ' END AS site_ifs,
               o.posid AS element_otp, o.post1 AS libelle_otp,
               clean_data.immo_to_date(a.abgdt) AS date_sortie,
               b.afabg, b.ndjar, b.ndper, b.afabe AS b_afabe, b.afasl, d.afatxt,
               COALESCE(NULLIF(b.ndjar, '')::int, 0) * 12
                 + COALESCE(NULLIF(b.ndper, '')::int, 0) AS duree,
               z.kostl, cc.txt AS kostl_txt, z.werks, z.gsber, gs.gtext, z.stort,
               c.acq, c.cum
        FROM raw_data.anla a
        LEFT JOIN class_txt ct ON ct.anlkl = a.anlkl
        LEFT JOIN company co   ON co.bukrs = a.bukrs
        LEFT JOIN ktogr_txt kt ON kt.ktogr = a.ktogr
        LEFT JOIN t095 t       ON t.ktopl = co.ktopl AND t.ktogr = a.ktogr
        LEFT JOIN anlc c       ON c.bukrs = a.bukrs AND c.anln1 = a.anln1 AND c.anln2 = a.anln2
        LEFT JOIN anlb b       ON b.bukrs = a.bukrs AND b.anln1 = a.anln1 AND b.anln2 = a.anln2
        LEFT JOIN anlz z       ON z.bukrs = a.bukrs AND z.anln1 = a.anln1 AND z.anln2 = a.anln2
        LEFT JOIN cc           ON cc.kostl = z.kostl
        LEFT JOIN gs           ON gs.gsber = z.gsber
        LEFT JOIN dep d        ON d.afasl = b.afasl
        LEFT JOIN grp_classe gc ON gc.anlkl = a.anlkl
        LEFT JOIN grp_immo gi   ON gi.anln1 = a.anln1
        LEFT JOIN otp o         ON o.pspnr = a.posnr AND COALESCE(a.posnr, '') <> ''
        WHERE a.bukrs = 'STJN'
    )
    SELECT bukrs, anln1, anln2, CONCAT(bukrs, '-', anln1, '-', anln2),
           txt50, NULLIF(txa50, ''), anlkl, famille,
           xloev, sernr, land1, ord41, ord42, ord43, ord44, projn,
           ktogr, ktgrtx, ktansw, ktanza, ktaufg,
           clean_data.immo_to_date(aktiv), clean_data.immo_to_date(zugdt),
           clean_data.immo_to_date(afabg),
           CASE WHEN duree > 0 THEN (clean_data.immo_to_date(afabg)
                + (duree || ' months')::interval - interval '1 day')::date END,
           ndjar, ndper, duree, b_afabe, afasl, afatxt,
           CASE WHEN duree > 0 THEN ROUND(1200.0 / duree, 4) END,
           kostl, kostl_txt, werks, gsber, gtext, stort,
           aibn1, aibn2, clean_data.immo_to_date(aibdt),
           invnr, herst, typbz, lifnr, menge, meins, eaufn,
           '02', p_gjahr,
           acq,
           CASE WHEN acq IS NOT NULL THEN 0 END,
           CASE WHEN acq IS NOT NULL THEN 0 END,
           acq,
           cum,
           acq - cum,
           CASE WHEN acq IS NOT NULL THEN 0 END,
           xspeb, date_sortie, clean_data.immo_to_date(deakt),
           -- reprise IFS
           (date_sortie IS NULL OR date_sortie > v_bascule),
           CASE WHEN date_sortie <= v_bascule
                THEN 'Sortie le ' || to_char(date_sortie, 'DD/MM/YYYY')
                     || ' <= bascule IFS ' || to_char(v_bascule, 'DD/MM/YYYY') END,
           ktansw_ifs, ktanza_ifs, object_group_id, site_ifs, element_otp, libelle_otp
    FROM base;

    GET DIAGNOSTICS v_nb = ROW_COUNT;

    IF v_nb = 0 THEN
        RAISE WARNING 'clean_data.immobilisation vide : raw_data.anla (STJN) non extraite ?';
    END IF;

    SELECT count(*) FILTER (WHERE reprise_ifs),
           count(*) FILTER (WHERE NOT reprise_ifs),
           count(*) FILTER (WHERE reprise_ifs AND compte_immobilisation IS NOT NULL AND compte_immobilisation_ifs IS NULL),
           count(*) FILTER (WHERE reprise_ifs AND object_group_id IS NULL)
    INTO v_reprise, v_exclues, v_sans_cpt, v_sans_grp
    FROM clean_data.immobilisation;
    RAISE NOTICE 'Immobilisations : % lignes, % a reprendre, % exclues (sortie <= %), % sans compte IFS, % sans groupe objet',
        v_nb, v_reprise, v_exclues, to_char(v_bascule, 'DD/MM/YYYY'), v_sans_cpt, v_sans_grp;

    RETURN v_nb;
END;
$$;
