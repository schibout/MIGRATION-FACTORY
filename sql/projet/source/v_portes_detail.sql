-- =====================================================================
-- Vue : clean_data.v_portes_detail
-- ---------------------------------------------------------------------
-- Détail des portes (jalons) de chaque projet, avec la note et le
-- classement LES PLUS RÉCENTS (issus du dernier état d'avancement).
--
-- Grain : 1 ligne par (projet, milestone) — distingue P3 / P3 bis / P3 Ters.
--
-- Sources :
--   raw_data.sharepoint_statut_jalons  (note/classement par état)
--   raw_data.sharepoint_etats_avancement (pour dater : jointure (site_id, title))
--   raw_data.sharepoint_jalons_ref     (libellé de la porte + StartDate/DueDate/Status référentiel)
--   raw_data.sharepoint_phases         (nom de la phase via PhaseId)
--   raw_data.sharepoint_projets        (numéro + intitulé du projet)
--
-- "le plus récent" = valeur de l'état d'avancement au status_date max
-- (ROW_NUMBER rn=1). Robuste sans status_report_fk (jointure par titre).
--
-- FULL JOIN statuts <-> référentiel (2026-09-29) : une porte créée dans ASAP
-- APRÈS le dernier état d'avancement (ex. 24.033 / P3 bis, créée le
-- 03/08/2026, dernier état au 30/04/2026) n'existe que dans jalons_ref ; elle
-- sort alors sans note/classement ni date d'état. À l'inverse, les statuts
-- dont le jalon a disparu du référentiel restent (porte_libelle NULL).
-- =====================================================================
CREATE OR REPLACE VIEW clean_data.v_portes_detail AS
WITH ranked AS (
    SELECT
        sj.site_id,
        NULLIF(sj.raw_data->>'MilestoneId', '')::int      AS milestone_id,
        -- Les statuts de l'ancien modèle ASAP (2020-2021, ex. 22.034) n'ont pas de
        -- Gate : on la reprend du jalon du référentiel
        COALESCE(sj.raw_data->>'Gate', jr0.raw_data->>'Gate') AS gate,
        sj.raw_data->>'Mark'                              AS note,
        sj.raw_data->>'Ranking'                           AS classement,
        NULLIF(sj.raw_data->>'Actual',   '')::timestamptz AS date_realisee,
        NULLIF(sj.raw_data->>'Baseline', '')::timestamptz AS date_baseline,
        NULLIF(sj.raw_data->>'Forecast', '')::timestamptz AS date_prevue,
        sj.sharepoint_id                                  AS statut_jalon_id,
        sj.modified                                       AS statut_jalon_modifie,
        ea.sharepoint_id                                  AS etat_id,
        ea.status_date                                    AS date_etat_source,
        ea.title                                          AS etat_title,
        -- Nombre d'états dans lesquels cette porte apparaît (profondeur d'historique)
        COUNT(*) OVER (
            PARTITION BY sj.site_id, NULLIF(sj.raw_data->>'MilestoneId', '')::int
        )                                                 AS nb_etats,
        -- Sélection du plus récent
        ROW_NUMBER() OVER (
            PARTITION BY sj.site_id, NULLIF(sj.raw_data->>'MilestoneId', '')::int
            ORDER BY ea.status_date DESC NULLS LAST,
                     ea.sharepoint_id DESC,          -- même départage que v_dernier_etat_avancement
                     sj.modified     DESC NULLS LAST,
                     sj.sharepoint_id DESC
        )                                                 AS rn
    FROM raw_data.sharepoint_statut_jalons sj
    JOIN raw_data.sharepoint_etats_avancement ea
      ON ea.site_id = sj.site_id
     AND ea.title   = sj.title
    LEFT JOIN raw_data.sharepoint_jalons_ref jr0
      ON jr0.site_id = sj.site_id
     AND jr0.sharepoint_id = NULLIF(sj.raw_data->>'MilestoneId', '')::int
    WHERE COALESCE(sj.raw_data->>'Gate', jr0.raw_data->>'Gate') IS NOT NULL
)
SELECT
    -- Projet
    sp.project_number,
    sp.title                                              AS projet,
    COALESCE(r.site_id, jr.site_id)                       AS site_id,
    -- Porte
    COALESCE(r.gate, jr.raw_data->>'Gate')                AS gate,
    COALESCE(r.milestone_id, jr.sharepoint_id)            AS milestone_id,
    jr.title                                              AS porte_libelle,       -- P3 / P3 bis / P3 Ters
    (jr.raw_data->>'PhaseId')::int                        AS phase_id,
    ph.title                                              AS phase,               -- ex. "Phase de préparation"
    -- Note & classement LES PLUS RÉCENTS
    r.note,
    r.classement,
    -- Dates de la porte (état le plus récent)
    r.date_realisee,
    r.date_baseline,
    -- porte sans état d'avancement : échéance du référentiel
    CASE WHEN r.site_id IS NULL THEN NULLIF(jr.raw_data->>'DueDate', '')::timestamptz
         ELSE r.date_prevue END                           AS date_prevue,
    -- Référentiel (jalons_ref)
    jr.raw_data->>'Status'                                AS statut_referentiel,
    jr.raw_data->>'PercentComplete'                       AS avancement_referentiel,
    jr.raw_data->>'StartDate'                             AS ref_date_debut,
    jr.raw_data->>'DueDate'                               AS ref_date_echeance,
    -- Traçabilité de la source
    r.date_etat_source,                                   -- date de l'état d'où viennent note/classement
    r.etat_id,
    r.etat_title,
    r.nb_etats,                                           -- profondeur d'historique de la porte
    r.statut_jalon_id,
    r.statut_jalon_modifie
FROM (SELECT * FROM ranked WHERE rn = 1) r
FULL JOIN raw_data.sharepoint_jalons_ref jr
       ON jr.site_id = r.site_id AND jr.sharepoint_id = r.milestone_id
LEFT JOIN raw_data.sharepoint_projets   sp ON sp.sharepoint_id::text = COALESCE(r.site_id, jr.site_id)
LEFT JOIN raw_data.sharepoint_phases    ph ON ph.site_id = COALESCE(r.site_id, jr.site_id) AND ph.sharepoint_id = (jr.raw_data->>'PhaseId')::int
-- jalon du référentiel sans statut : seulement s'il porte une porte (Gate)
WHERE r.site_id IS NOT NULL OR jr.raw_data->>'Gate' IS NOT NULL
ORDER BY sp.project_number, 4, jr.title;

COMMENT ON VIEW clean_data.v_portes_detail IS
'Détail des portes/jalons par projet avec note + classement les plus récents (dernier état d''avancement). 1 ligne par (projet, milestone). Enrichi : projet, libellé porte, phase, dates, référentiel, profondeur d''historique.';

-- Exemples :
-- SELECT * FROM clean_data.v_portes_detail WHERE project_number = '21.009' ORDER BY gate;
-- SELECT project_number, gate, note, classement, phase FROM clean_data.v_portes_detail
--   WHERE classement = 'Fait' ORDER BY project_number;
