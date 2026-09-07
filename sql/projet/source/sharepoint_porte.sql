CREATE OR REPLACE VIEW raw_data.sharepoint_porte AS
SELECT DISTINCT ON (p.project_number, (jr.raw_data ->> 'Gate'))
    p.id                                               AS projet_id,
    p.sharepoint_id                                    AS projet_sharepoint_id,
    p.guid                                             AS projet_guid,
    sj.id                                              AS statut_jalon_id,
    sj.sharepoint_id                                   AS statut_jalon_sharepoint_id,
    jr.id                                              AS jalon_ref_id,
    jr.sharepoint_id                                   AS jalon_ref_sharepoint_id,
    (jr.raw_data ->> 'ID')::integer                   AS jalon_ref_item_id,
    (sj.raw_data ->> 'MilestoneId')::integer           AS milestone_id,
    jr.site_id                                         AS site_id,   -- ← vient de jr, pas sj (null-safe)
    p.project_number                                   AS numero_projet,
    p.title                                            AS intitule_projet,
    p.global_status                                    AS statut_projet,
    jr.raw_data ->> 'Gate'                             AS porte,
    sj.raw_data ->> 'Mark'                             AS note,
    sj.raw_data ->> 'Ranking'                          AS classement,
    (jr.raw_data ->> 'StartDate')::date                AS date_debut,
    (jr.raw_data ->> 'DueDate')::date                  AS date_fin,
    (sj.raw_data ->> 'Forecast')::date                 AS date_prevue,
    (sj.raw_data ->> 'Baseline')::date                 AS date_baseline,
    sj.modified                                        AS derniere_maj
FROM raw_data.sharepoint_jalons_ref jr
JOIN raw_data.sharepoint_projets p
    ON p.sharepoint_id::text = jr.site_id
LEFT JOIN raw_data.sharepoint_statut_jalons sj          -- ← LEFT JOIN (plus d'INNER)
    ON sj.site_id = jr.site_id
   AND (sj.raw_data ->> 'MilestoneId')::integer = (jr.raw_data ->> 'ID')::integer
                                                        -- ← filtre Mark/Ranking SUPPRIMÉ
WHERE jr.raw_data ->> 'Gate' IS NOT NULL
ORDER BY p.project_number,
         jr.raw_data ->> 'Gate',
         sj.modified DESC NULLS LAST;                   -- jalons sans statut remontent quand même