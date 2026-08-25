CREATE OR REPLACE FUNCTION clean_data.alimenter_project_activity()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_count_inserted INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;

    RAISE NOTICE 'Début de l''alimentation des project_activity depuis v_portes_detail - %', v_start_time;

    TRUNCATE TABLE clean_data.project_activity RESTART IDENTITY;
    RAISE NOTICE 'Table project_activity vidée';

    ---------------------------------------------------------------------------
    -- Activités projet de type PORTE uniquement.
    -- Source : clean_data.v_portes_detail, pas raw_data.sharepoint_porte.
    --
    -- On conserve uniquement les jalons dont le libellé correspond à une porte
    -- IFS transcodifiable : P0..P6, P0bis..P6bis, P0ter..P6ter(s).
    -- Les jalons non-porte présents dans SharePoint (ex. "Point L. Maenner",
    -- "P1 Fermée", "P4 batch 1") sont exclus.
    ---------------------------------------------------------------------------
    INSERT INTO clean_data.project_activity (
        activity_seq,
        project_id,
        sub_project_id,
        activity_no,
        description,
        activity_responsible,
        early_start,
        early_finish,
        actual_start,
        actual_finish,
        task_id,
        progress_method_db,
        planned_cost_driver_db,
        exclude_periodical_cap_db,
        exclude_resource_progress_db,
        exclude_from_integrations_db,
        node_type_db,
        mandatory_invoice_comment_db
    )
    SELECT
        ROW_NUMBER() OVER (ORDER BY src.project_id, src.activity_source, src.milestone_id) AS activity_seq,
        src.project_id,
        '10' AS sub_project_id,
        COALESCE(
            public.get_transcodification('Activity', src.activity_source, 'ASAP', 'IFS'),
            src.activity_source
        ) AS activity_no,
        SUBSTRING('Porte ' || src.activity_source, 1, 200) AS description,
        COALESCE(pm_user.person_id, pb.manager) AS activity_responsible,
        src.activity_date AS early_start,
        src.activity_date AS early_finish,
        src.activity_date AS actual_start,
        src.activity_date AS actual_finish,
        NULL::NUMERIC AS task_id,
        'ALL_CONNECTED_OBJECTS' AS progress_method_db,
        'CONNECTED_OBJECTS' AS planned_cost_driver_db,
        'INCLUDE' AS exclude_periodical_cap_db,
        'FALSE' AS exclude_resource_progress_db,
        'FALSE' AS exclude_from_integrations_db,
        'ACTIVITY' AS node_type_db,
        'INHERIT' AS mandatory_invoice_comment_db
    FROM (
        SELECT DISTINCT ON (x.project_id, x.activity_source)
            x.*
        FROM (
            SELECT
                SUBSTRING(vd.project_number, 1, 10) AS project_id,
                vd.site_id,
                vd.milestone_id,
                CASE
                    WHEN UPPER(TRIM(vd.gate)) ~ '^P[0-6]$'
                     AND regexp_replace(lower(COALESCE(NULLIF(TRIM(vd.porte_libelle), ''), vd.gate)), '\s+', '', 'g') = lower(TRIM(vd.gate))
                        THEN UPPER(TRIM(vd.gate))
                    WHEN UPPER(TRIM(vd.gate)) ~ '^P[0-6]$'
                     AND regexp_replace(lower(COALESCE(vd.porte_libelle, '')), '\s+', '', 'g') = lower(TRIM(vd.gate)) || 'bis'
                        THEN UPPER(TRIM(vd.gate)) || 'bis'
                    WHEN UPPER(TRIM(vd.gate)) ~ '^P[0-6]$'
                     AND regexp_replace(lower(COALESCE(vd.porte_libelle, '')), '\s+', '', 'g') IN (lower(TRIM(vd.gate)) || 'ter', lower(TRIM(vd.gate)) || 'ters')
                        THEN UPPER(TRIM(vd.gate)) || 'ter'
                    ELSE NULL
                END AS activity_source,
                COALESCE(vd.date_realisee, vd.date_prevue)::DATE AS activity_date,
                vd.date_etat_source
            FROM clean_data.v_portes_detail vd
            WHERE vd.project_number IS NOT NULL
        ) x
        WHERE x.activity_source IS NOT NULL
        ORDER BY x.project_id, x.activity_source, x.date_etat_source DESC NULLS LAST, x.milestone_id
    ) src
    JOIN clean_data.project_base pb
        ON pb.project_id = src.project_id
    LEFT JOIN raw_data.sharepoint_projets sp
        ON sp.sharepoint_id::TEXT = src.site_id
    LEFT JOIN raw_data.sharepoint_users pm_user
        ON pm_user.sharepoint_user_id = sp.pm_id
    ORDER BY src.project_id, src.activity_source, src.milestone_id;

    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;
    RAISE NOTICE 'Activités projet de type porte insérées: %', v_count_inserted;

    ---------------------------------------------------------------------------
    -- Enrichissement depuis les états d'avancement (dernier état par projet)
    ---------------------------------------------------------------------------
    UPDATE clean_data.project_activity pa
    SET
        estimated_progress = (last_ea.percent_completed * 100)::NUMERIC,
        note = SUBSTRING(
            regexp_replace(last_ea.update_text, '<[^>]*>', '', 'g'),
            1, 2000
        )
    FROM (
        SELECT DISTINCT ON (sp.project_number)
            SUBSTRING(COALESCE(sp.project_number, sp.code), 1, 10) AS project_id,
            ea.percent_completed,
            ea.update_text
        FROM raw_data.sharepoint_etats_avancement ea
        JOIN raw_data.sharepoint_projets sp ON ea.site_id = sp.sharepoint_id::TEXT
        WHERE sp.project_number IS NOT NULL
        ORDER BY sp.project_number, ea.status_date DESC
    ) last_ea
    WHERE pa.project_id = last_ea.project_id;

    RAISE NOTICE 'Enrichissement depuis états d''avancement terminé';

    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;

    RAISE NOTICE 'Alimentation project_activity terminée';
    RAISE NOTICE 'Enregistrements insérés: %', v_count_inserted;
    RAISE NOTICE 'Durée: %', v_duration;

EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;

        RAISE NOTICE 'ERREUR lors de l''alimentation project_activity';
        RAISE NOTICE 'Code: %', SQLSTATE;
        RAISE NOTICE 'Message: %', SQLERRM;
        RAISE NOTICE 'Durée avant erreur: %', v_duration;
        RAISE;
END;
$function$
