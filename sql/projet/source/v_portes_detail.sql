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
-- =====================================================================
CREATE OR REPLACE VIEW clean_data.v_portes_detail AS
WITH ranked AS (
    SELECT
        sj.site_id,
        NULLIF(sj.raw_data->>'MilestoneId', '')::int      AS milestone_id,
        sj.raw_data->>'Gate'                              AS gate,
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
                     sj.modified     DESC NULLS LAST,
                     sj.sharepoint_id DESC
        )                                                 AS rn
    FROM raw_data.sharepoint_statut_jalons sj
    JOIN raw_data.sharepoint_etats_avancement ea
      ON ea.site_id = sj.site_id
     AND ea.title   = sj.title
    WHERE sj.raw_data->>'Gate' IS NOT NULL
)
SELECT
    -- Projet
    sp.project_number,
    sp.title                                              AS projet,
    r.site_id,
    -- Porte
    r.gate,
    r.milestone_id,
    jr.title                                              AS porte_libelle,       -- P3 / P3 bis / P3 Ters
    (jr.raw_data->>'PhaseId')::int                        AS phase_id,
    ph.title                                              AS phase,               -- ex. "Phase de préparation"
    -- Note & classement LES PLUS RÉCENTS
    r.note,
    r.classement,
    -- Dates de la porte (état le plus récent)
    r.date_realisee,
    r.date_baseline,
    r.date_prevue,
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
FROM ranked r
LEFT JOIN raw_data.sharepoint_projets   sp ON sp.sharepoint_id::text = r.site_id
LEFT JOIN raw_data.sharepoint_jalons_ref jr ON jr.site_id = r.site_id AND jr.sharepoint_id = r.milestone_id
LEFT JOIN raw_data.sharepoint_phases    ph ON ph.site_id = r.site_id AND ph.sharepoint_id = (jr.raw_data->>'PhaseId')::int
WHERE r.rn = 1
ORDER BY sp.project_number, r.gate, jr.title;

COMMENT ON VIEW clean_data.v_portes_detail IS
'Détail des portes/jalons par projet avec note + classement les plus récents (dernier état d''avancement). 1 ligne par (projet, milestone). Enrichi : projet, libellé porte, phase, dates, référentiel, profondeur d''historique.';

-- Exemples :
-- SELECT * FROM clean_data.v_portes_detail WHERE project_number = '21.009' ORDER BY gate;
-- SELECT project_number, gate, note, classement, phase FROM clean_data.v_portes_detail
--   WHERE classement = 'Fait' ORDER BY project_number;
