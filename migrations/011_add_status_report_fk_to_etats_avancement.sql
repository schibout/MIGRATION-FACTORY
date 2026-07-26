-- =====================================================
-- Migration: Ajout de la cle FK status_report_fk dans sharepoint_etats_avancement
-- Description: Le champ Status_x0020_Report des tables filles
--              (sharepoint_statut_jalons, sharepoint_statut_cfv, sharepoint_statut_couts)
--              est un GUID SharePoint qui ne correspond PAS au champ GUID de l'item
--              parent dans sharepoint_etats_avancement. Cette colonne materialise
--              le bon FK pour permettre la jointure parent <-> enfants.
--
--              Backfill : on resout le FK depuis les tables filles (jalons / couts)
--              qui ont a la fois 'Status_x0020_Report' et 'title' du parent.
-- Date: 2026-05-28
-- =====================================================

-- 1. Ajout de la colonne (UUID stocke comme TEXT pour rester aligne avec raw_data->>...)
ALTER TABLE raw_data.sharepoint_etats_avancement
    ADD COLUMN IF NOT EXISTS status_report_fk TEXT;

COMMENT ON COLUMN raw_data.sharepoint_etats_avancement.status_report_fk IS
    'GUID utilise par les listes filles (jalons/CFV/couts) dans raw_data->>''Status_x0020_Report''. Different du GUID interne de l''item.';

-- Index pour acceler la jointure parent -> enfants
CREATE INDEX IF NOT EXISTS idx_sharepoint_etats_avancement_status_report_fk
    ON raw_data.sharepoint_etats_avancement(site_id, status_report_fk);


-- 2. Backfill : agreger les FK distincts des jalons ET coûts par (site_id, title)
--    Si un (site_id, title) a plusieurs etats parents (doublons de titre - 132 cas
--    sur ~10 000 etats), on garde le premier sharepoint_id.
WITH fk_resolved AS (
    SELECT site_id, title, raw_data->>'Status_x0020_Report' AS fk
    FROM raw_data.sharepoint_statut_jalons
    WHERE raw_data->>'Status_x0020_Report' IS NOT NULL
      AND title IS NOT NULL

    UNION

    SELECT site_id, title, raw_data->>'Status_x0020_Report' AS fk
    FROM raw_data.sharepoint_statut_couts
    WHERE raw_data->>'Status_x0020_Report' IS NOT NULL
      AND title IS NOT NULL
),
fk_dedup AS (
    SELECT DISTINCT ON (site_id, title)
        site_id, title, fk
    FROM fk_resolved
    ORDER BY site_id, title, fk
)
UPDATE raw_data.sharepoint_etats_avancement ea
SET status_report_fk = fk_dedup.fk
FROM fk_dedup
WHERE ea.site_id = fk_dedup.site_id
  AND ea.title   = fk_dedup.title
  AND ea.status_report_fk IS DISTINCT FROM fk_dedup.fk;


-- 3. Verification : compter les etats avec / sans FK resolu
SELECT
    COUNT(*) FILTER (WHERE status_report_fk IS NOT NULL) AS etats_avec_fk,
    COUNT(*) FILTER (WHERE status_report_fk IS NULL)     AS etats_sans_fk,
    COUNT(*)                                              AS total_etats
FROM raw_data.sharepoint_etats_avancement;
