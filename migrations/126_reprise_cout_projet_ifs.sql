-- ============================================================================
-- 126 : reprise des couts historiques des projets SAP vers IFS (OD de reprise,
-- ecran Finance > Historique des couts, onglet « Reprise IFS »).
-- Deux tables de SAISIE, jamais rechargees par un ETL (raw_data n'est pas touche) :
--   reprise_cout_otp_nature  nature CAPEX / OPEX des elements d'OTP dont le
--                            suffixe ne la donne pas (ni IM ni EX)
--   reprise_cout_projet_ifs  n° projet metier -> ID projet IFS (surcharge du
--                            n° projet SharePoint) et sequences d'activite IFS
--                            de reprise CAPEX / OPEX (aucune n'existe aujourd'hui
--                            dans clean_data.activity : a saisir, jamais deduites)
-- Auteur = identite JWT, date = horloge PostgreSQL.
-- Puis : cd sql/historiqueCoutProjet && ./compile.sh (vue + fonctions).
-- ============================================================================

CREATE TABLE IF NOT EXISTS clean_data.reprise_cout_otp_nature (
    element_otp   varchar(24) PRIMARY KEY,                 -- prps.posid
    nature        varchar(5)  NOT NULL CHECK (nature IN ('CAPEX', 'OPEX')),
    commentaire   text,
    qualifie_par  text        NOT NULL,
    qualifie_le   timestamp   NOT NULL DEFAULT current_timestamp
);

CREATE TABLE IF NOT EXISTS clean_data.reprise_cout_projet_ifs (
    numero_projet       text PRIMARY KEY,                  -- historique_cout_projet.numero_projet
    project_id_ifs      text,                     -- NULL = n° projet SharePoint
    activity_seq_capex  numeric,                           -- clean_data.activity.activity_seq
    activity_seq_opex   numeric,
    commentaire         text,
    saisi_par           text      NOT NULL,
    saisi_le            timestamp NOT NULL DEFAULT current_timestamp
);
