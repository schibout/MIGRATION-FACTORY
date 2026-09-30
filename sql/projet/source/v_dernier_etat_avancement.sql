-- =====================================================================
-- Vue : clean_data.v_dernier_etat_avancement
-- ---------------------------------------------------------------------
-- L'état d'avancement LE PLUS RÉCENT de chaque projet : 1 ligne par projet.
-- Règle unique pour tout le module projet (2026-09-30, demande explicite) :
-- portes, dates, note/classement, CFV et avancement de project_activity /
-- project_activity_class viennent de CET état et d'aucun autre, même s'il n'a
-- aucun statut de jalon extrait (le projet n'a alors pas de porte).
--
-- "le plus récent" = status_date max, puis sharepoint_id max (égalité de date).
-- status_report_fk : GUID reliant l'état à ses listes filles (statut_jalons /
-- statut_cfv / statut_couts via raw_data->>'Status_x0020_Report'). La migration
-- 011 ne l'a matérialisé qu'une fois : repli sur le GUID des coûts / jalons du
-- même (site_id, title), comme son backfill.
-- =====================================================================
CREATE OR REPLACE VIEW clean_data.v_dernier_etat_avancement AS
SELECT DISTINCT ON (SUBSTRING(COALESCE(sp.project_number, sp.code), 1, 10))
    SUBSTRING(COALESCE(sp.project_number, sp.code), 1, 10) AS project_id,
    ea.site_id,
    ea.sharepoint_id                                        AS etat_id,
    ea.title                                                AS etat_title,
    ea.status_date,
    ea.percent_completed,
    ea.update_text,
    COALESCE(ea.status_report_fk, (
        SELECT x.fk
        FROM (SELECT site_id, title, raw_data->>'Status_x0020_Report' AS fk
              FROM raw_data.sharepoint_statut_couts
              UNION ALL
              SELECT site_id, title, raw_data->>'Status_x0020_Report'
              FROM raw_data.sharepoint_statut_jalons) x
        WHERE x.site_id = ea.site_id AND x.title = ea.title AND x.fk IS NOT NULL
        ORDER BY x.fk
        LIMIT 1
    ))                                                      AS status_report_fk
FROM raw_data.sharepoint_etats_avancement ea
JOIN raw_data.sharepoint_projets sp
  ON sp.sharepoint_id::TEXT = ea.site_id
WHERE sp.project_number IS NOT NULL
ORDER BY SUBSTRING(COALESCE(sp.project_number, sp.code), 1, 10),
         ea.status_date DESC NULLS LAST,
         ea.sharepoint_id DESC;

COMMENT ON VIEW clean_data.v_dernier_etat_avancement IS
'État d''avancement le plus récent de chaque projet (status_date max, puis sharepoint_id). Source unique de project_activity / project_activity_class.';
