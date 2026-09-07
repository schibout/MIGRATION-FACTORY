CREATE OR REPLACE FUNCTION clean_data.alimenter_activity()
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

    RAISE NOTICE 'Début de l''alimentation des activités (ACTIVITY) depuis v_portes_detail - %', v_start_time;

    TRUNCATE TABLE clean_data.activity RESTART IDENTITY;
    RAISE NOTICE 'Table activity vidée';

    ---------------------------------------------------------------------------
    -- Activités de type PORTE uniquement.
    -- Source : clean_data.v_portes_detail, pas raw_data.sharepoint_porte et plus
    -- de CROSS JOIN fixe P0/P0bis/P0ter/... pour tous les projets.
    --
    -- On conserve seulement les jalons dont le libellé correspond à une vraie
    -- porte IFS : P0..P6, P0bis..P6bis, P0ter..P6ter(s).
    -- Les jalons métier non-porte comme "Point L. Maenner", "P1 Fermée",
    -- "P4 batch 1", etc. sont exclus.
    ---------------------------------------------------------------------------
    INSERT INTO clean_data.activity (
        activity_seq,
        project_id,
        activity_no,
        description,
        sub_project_id,
        progress_method,
        progress_method_db,
        planned_cost_driver,
        planned_cost_driver_db,
        exclude_periodical_cap,
        exclude_periodical_cap_db,
        exclude_resource_progress,
        exclude_resource_progress_db,
        exclude_from_integrations,
        exclude_from_integrations_db,
        node_type,
        node_type_db,
        mandatory_invoice_comment,
        mandatory_invoice_comment_db,
        early_start,
        early_finish,
        activity_responsible
    )
    SELECT
        ROW_NUMBER() OVER (ORDER BY src.project_id, src.activity_source, src.milestone_id) AS activity_seq,
        src.project_id,
        SUBSTRING(
            COALESCE(
                public.get_transcodification('Activity', src.activity_source, 'ASAP', 'IFS'),
                src.activity_source
            ),
            1, 10
        ) AS activity_no,
        SUBSTRING('Porte ' || src.activity_source, 1, 200) AS description,
        public.get_default_value('clean_data.activity', 'sub_project_id') AS sub_project_id,
        public.get_default_value('clean_data.activity', 'progress_method') AS progress_method,
        public.get_default_value('clean_data.activity', 'progress_method_db') AS progress_method_db,
        public.get_default_value('clean_data.activity', 'planned_cost_driver') AS planned_cost_driver,
        public.get_default_value('clean_data.activity', 'planned_cost_driver_db') AS planned_cost_driver_db,
        public.get_default_value('clean_data.activity', 'exclude_periodical_cap') AS exclude_periodical_cap,
        public.get_default_value('clean_data.activity', 'exclude_periodical_cap_db') AS exclude_periodical_cap_db,
        public.get_default_value('clean_data.activity', 'exclude_resource_progress') AS exclude_resource_progress,
        public.get_default_value('clean_data.activity', 'exclude_resource_progress_db') AS exclude_resource_progress_db,
        public.get_default_value('clean_data.activity', 'exclude_from_integrations') AS exclude_from_integrations,
        public.get_default_value('clean_data.activity', 'exclude_from_integrations_db') AS exclude_from_integrations_db,
        public.get_default_value('clean_data.activity', 'node_type') AS node_type,
        public.get_default_value('clean_data.activity', 'node_type_db') AS node_type_db,
        public.get_default_value('clean_data.activity', 'mandatory_invoice_comment') AS mandatory_invoice_comment,
        public.get_default_value('clean_data.activity', 'mandatory_invoice_comment_db') AS mandatory_invoice_comment_db,
        src.activity_date AS early_start,
        src.activity_date AS early_finish,
        COALESCE(pm_user.person_id, pb.manager) AS activity_responsible
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

    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;

    RAISE NOTICE 'Alimentation des activités terminée avec succès';
    RAISE NOTICE 'Nombre d''enregistrements traités: %', v_count_inserted;
    RAISE NOTICE 'Durée d''exécution: %', v_duration;
    RAISE NOTICE 'Début: %, Fin: %', v_start_time, v_end_time;

EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;

        RAISE NOTICE 'ERREUR lors de l''alimentation des activités';
        RAISE NOTICE 'Code d''erreur: %', SQLSTATE;
        RAISE NOTICE 'Message d''erreur: %', SQLERRM;
        RAISE NOTICE 'Durée avant erreur: %', v_duration;
        RAISE;
END;
$function$
