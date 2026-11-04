-- ============================================================================
-- Reprise des couts historiques des projets SAP vers IFS (OD de reprise).
-- Prerequis : migration 126 (tables de saisie reprise_cout_otp_nature et
-- reprise_cout_projet_ifs).
--
-- clean_data.nature_suffixe_otp(otp)      CAPEX si l'OTP finit par IM, OPEX par EX
--                                         (avec ou sans point : 'SN.26052.IM'), sinon NULL
-- clean_data.maj_abreviation_activite()   recalcule la colonne stockee abreviation_activite :
--                                         <ID projet IFS>.20.REP (CAPEX) ou .30.REP (OPEX), projets
--                                         a migrer seulement ; appelee au chargement et apres
--                                         chaque saisie (nature, correspondance)
-- clean_data.v_historique_cout_projet     la table + nature / nature_source + reel
--                                         ventile reel_capex / reel_opex / reel_a_qualifier
--                                         (reel de la PERIODE : la somme des trois = reel)
-- clean_data.exercice_periode_stjn(date)  exercice / periode SAP STJN (variante Z2,
--                                         juillet = periode 1, exercice 2027 =
--                                         01/07/2026 -> 30/06/2027)
-- clean_data.reprise_cout_projet(arrete)  une ligne par projet / element d'OTP a migrer
-- ============================================================================

CREATE OR REPLACE FUNCTION clean_data.nature_suffixe_otp(p_otp text)
RETURNS text
LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE WHEN UPPER(TRIM(p_otp)) ~ 'IM$' THEN 'CAPEX'
                WHEN UPPER(TRIM(p_otp)) ~ 'EX$' THEN 'OPEX' END
$$;

-- Le suffixe prime : une qualification manuelle ne vaut que pour un OTP sans
-- suffixe reconnu (l'API refuse d'en saisir une sur un OTP IM / EX).
-- DROP + CREATE : h.* fige la liste des colonnes, un CREATE OR REPLACE echouerait
-- apres l'ajout d'une colonne a la table.
DROP VIEW IF EXISTS clean_data.v_historique_cout_projet;
CREATE VIEW clean_data.v_historique_cout_projet AS
SELECT h.*, n.nature, n.nature_source,
       CASE WHEN n.nature = 'CAPEX' THEN h.reel ELSE 0 END AS reel_capex,
       CASE WHEN n.nature = 'OPEX'  THEN h.reel ELSE 0 END AS reel_opex,
       CASE WHEN n.nature IS NULL   THEN h.reel ELSE 0 END AS reel_a_qualifier
FROM clean_data.historique_cout_projet h
LEFT JOIN clean_data.reprise_cout_otp_nature m ON m.element_otp = h.element_otp
CROSS JOIN LATERAL (
    SELECT COALESCE(clean_data.nature_suffixe_otp(h.element_otp), m.nature) AS nature,
           CASE WHEN clean_data.nature_suffixe_otp(h.element_otp) IS NOT NULL THEN 'SUFFIXE'
                WHEN m.nature IS NOT NULL THEN 'MANUELLE' END AS nature_source
) n;

CREATE OR REPLACE FUNCTION clean_data.maj_abreviation_activite()
RETURNS void
LANGUAGE sql AS $$
    UPDATE clean_data.historique_cout_projet h
    SET abreviation_activite = x.abrev
    FROM (
        SELECT o.projet, o.element_otp,
               CASE WHEN o.a_migrer THEN
                   CASE COALESCE(clean_data.nature_suffixe_otp(o.element_otp), m.nature)
                       WHEN 'CAPEX' THEN COALESCE(c.project_id_ifs, o.numero_projet) || '.20.REP'
                       WHEN 'OPEX'  THEN COALESCE(c.project_id_ifs, o.numero_projet) || '.30.REP'
                   END
               END AS abrev
        FROM (SELECT DISTINCT projet, element_otp, numero_projet, a_migrer
              FROM clean_data.historique_cout_projet) o
        LEFT JOIN clean_data.reprise_cout_otp_nature m ON m.element_otp = o.element_otp
        LEFT JOIN clean_data.reprise_cout_projet_ifs c ON c.numero_projet = o.numero_projet
    ) x
    WHERE h.projet = x.projet AND h.element_otp = x.element_otp
      AND h.abreviation_activite IS DISTINCT FROM x.abrev
$$;

CREATE OR REPLACE FUNCTION clean_data.exercice_periode_stjn(p_date date, OUT exercice integer, OUT periode integer)
LANGUAGE sql IMMUTABLE AS $$
    SELECT EXTRACT(YEAR FROM p_date)::int + CASE WHEN EXTRACT(MONTH FROM p_date) >= 7 THEN 1 ELSE 0 END,
           (EXTRACT(MONTH FROM p_date)::int + 5) % 12 + 1
$$;

-- ============================================================================
-- clean_data.reprise_cout_projet(p_date_arrete)
-- Arrete MENSUEL uniquement : RPSCO ne porte que des montants par periode, une date
-- en cours de mois est refusee (on ne peut pas couper une periode).
-- montant = somme du reel PERIODIQUE (WRTTP 04 hors KOAO) des exercices anterieurs
--           (periodes speciales 13-16 comprises), puis de l'exercice de l'arrete
--           jusqu'a sa periode (13-16 seulement si l'arrete est en periode 12).
--           Ni cumul, ni plan, ni budget, ni demandes d'achat, ni commandes non
--           receptionnees.
-- project_id_ifs = saisie (reprise_cout_projet_ifs) sinon n° projet SharePoint.
-- abreviation_activite = <ID projet IFS>.20.REP (CAPEX) ou .30.REP (OPEX) ; NULL si a qualifier.
-- activity_seq   = sequence saisie pour la nature de l'OTP, sinon celle de l'unique activite du
--                  projet portant cette abreviation (clean_data.project_activity.short_name, la
--                  table exportee vers IFS) ; plusieurs activites -> SEQUENCE_AMBIGUE, pas de choix.
--                  activity_seq est renumerotee a chaque chargement du module projet : une sequence
--                  saisie peut devenir SEQUENCE_INCONNUE.
-- anomalies      : NATURE_A_QUALIFIER (montant non nul),
--                  PROJET_IFS_INCONNU, SEQUENCE_INCONNUE (absente de
--                  clean_data.project_activity pour ce projet), SEQUENCE_AMBIGUE, OTP_EN_DOUBLE (meme OTP sous
--                  deux projets), PROJET_IFS_PARTAGE (meme ID IFS pour deux n° projet),
--                  CUMUL_PARENT_ENFANTS (OTP parent dont le montant egale la somme de
--                  ses enfants : cumul stocke, double comptage). RPSCO etant tenu par
--                  objet, un parent porte normalement 0 quand ses enfants sont imputes.
-- Sequence vide = pas une anomalie (2026-11-04, demande explicite) : l'abreviation sert a
-- retrouver l'activite dans IFS.
-- exporte = montant non nul et aucune anomalie.
-- ============================================================================
DROP FUNCTION IF EXISTS clean_data.reprise_cout_projet(date);  -- type de retour modifie
CREATE FUNCTION clean_data.reprise_cout_projet(p_date_arrete date)
RETURNS TABLE (
    numero_projet text, projet varchar, projet_libelle text, element_otp varchar, otp_libelle text,
    nature text, nature_source text, exercice integer, periode integer, montant numeric,
    project_id_ifs text, project_id_source text, activity_seq numeric, activity_seq_source text, abreviation_activite text,
    anomalies text[], exporte boolean)
LANGUAGE plpgsql STABLE AS $$
#variable_conflict use_column
DECLARE
    v_ex integer;
    v_per integer;
BEGIN
    IF p_date_arrete IS NULL
       OR p_date_arrete <> (date_trunc('month', p_date_arrete) + interval '1 month - 1 day')::date THEN
        RAISE EXCEPTION 'Arrete mensuel uniquement (fin de mois attendue) : %', p_date_arrete
            USING ERRCODE = '22023';
    END IF;
    SELECT e.exercice, e.periode INTO v_ex, v_per FROM clean_data.exercice_periode_stjn(p_date_arrete) e;

    RETURN QUERY
    WITH lig AS (
        SELECT h.numero_projet, h.projet, max(h.projet_libelle) AS projet_libelle,
               h.element_otp, max(h.otp_libelle) AS otp_libelle,
               max(h.nature) AS nature, max(h.nature_source) AS nature_source,
               max(h.abreviation_activite) AS abrev,
               COALESCE(sum(h.reel) FILTER (
                   WHERE h.annee < v_ex
                      OR (h.annee = v_ex AND h.periode <= v_per)
                      OR (h.annee = v_ex AND v_per = 12)), 0) AS montant
        FROM clean_data.v_historique_cout_projet h
        WHERE h.a_migrer
        GROUP BY h.numero_projet, h.projet, h.element_otp
    ),
    activite_rep AS (
        SELECT pa.project_id, pa.short_name, min(pa.activity_seq) AS seq, count(*) AS n
        FROM clean_data.project_activity pa
        WHERE pa.short_name ~ '\.(20|30)\.REP$'
        GROUP BY pa.project_id, pa.short_name
    ),
    res0 AS (
        SELECT l.*, COALESCE(c.project_id_ifs, l.numero_projet) AS pid,
               CASE WHEN c.project_id_ifs IS NOT NULL THEN 'SAISIE' ELSE 'N_PROJET' END AS pid_source,
               CASE l.nature WHEN 'CAPEX' THEN c.activity_seq_capex
                             WHEN 'OPEX' THEN c.activity_seq_opex END AS seq_saisie,
               p.pspnr, p.mandt
        FROM lig l
        LEFT JOIN clean_data.reprise_cout_projet_ifs c ON c.numero_projet = l.numero_projet
        LEFT JOIN raw_data.prps p ON p.posid = l.element_otp AND p.pbukr = 'STJN'
    ),
    res AS (
        SELECT r.*, ar.n AS n_rep,
               COALESCE(r.seq_saisie, CASE WHEN ar.n = 1 THEN ar.seq END) AS seq,
               CASE WHEN r.seq_saisie IS NOT NULL THEN 'SAISIE'
                    WHEN ar.n = 1 THEN 'ABREVIATION' END AS seq_source
        FROM res0 r
        LEFT JOIN activite_rep ar ON ar.project_id = r.pid AND ar.short_name = r.abrev
    ),
    enfants AS (
        SELECT par.element_otp, sum(enf.montant) AS montant, count(*) FILTER (WHERE enf.montant <> 0) AS n
        FROM res par
        JOIN raw_data.prhi ph ON ph.mandt = par.mandt AND ph.up = par.pspnr
        JOIN res enf ON enf.mandt = ph.mandt AND enf.pspnr = ph.posnr
        GROUP BY par.element_otp
    ),
    ano AS (
        SELECT r.*, array_remove(ARRAY[
            CASE WHEN r.nature IS NULL AND r.montant <> 0 THEN 'NATURE_A_QUALIFIER' END,
            CASE WHEN r.seq IS NULL AND r.n_rep > 1 AND r.montant <> 0 THEN 'SEQUENCE_AMBIGUE' END,
            CASE WHEN NOT EXISTS (SELECT 1 FROM clean_data.project_base pb WHERE pb.project_id = r.pid)
                 THEN 'PROJET_IFS_INCONNU' END,
            CASE WHEN r.seq IS NOT NULL AND NOT EXISTS (
                     SELECT 1 FROM clean_data.project_activity a WHERE a.project_id = r.pid AND a.activity_seq = r.seq)
                 THEN 'SEQUENCE_INCONNUE' END,
            CASE WHEN count(*) OVER (PARTITION BY r.element_otp) > 1 THEN 'OTP_EN_DOUBLE' END,
            CASE WHEN r.pid IN (SELECT x.pid FROM res x GROUP BY x.pid HAVING count(DISTINCT x.numero_projet) > 1)
                 THEN 'PROJET_IFS_PARTAGE' END,
            CASE WHEN e.n > 0 AND r.montant <> 0 AND r.montant = e.montant THEN 'CUMUL_PARENT_ENFANTS' END
        ], NULL) AS anomalies
        FROM res r
        LEFT JOIN enfants e ON e.element_otp = r.element_otp
    )
    SELECT a.numero_projet, a.projet, a.projet_libelle, a.element_otp, a.otp_libelle,
           a.nature, a.nature_source, v_ex, v_per, a.montant,
           a.pid, a.pid_source, a.seq, a.seq_source, a.abrev,
           a.anomalies,
           a.montant <> 0 AND cardinality(a.anomalies) = 0
    FROM ano a
    ORDER BY a.numero_projet, a.element_otp;
END;
$$;
