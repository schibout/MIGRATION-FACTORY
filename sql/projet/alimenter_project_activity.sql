CREATE OR REPLACE FUNCTION clean_data.alimenter_project_activity()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_count_inserted INTEGER := 0;
    v_count_cfv INTEGER := 0;
    v_count_asap INTEGER := 0;
    v_max_seq NUMERIC := 0;
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
    -- Seules les portes du DERNIER état d'avancement du projet, avec ses dates.
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
        late_start,
        late_finish,
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
        public.get_default_value('clean_data.project_activity', 'sub_project_id') AS sub_project_id,
        COALESCE(
            public.get_transcodification('Activity', src.activity_source, 'ASAP', 'IFS'),
            src.activity_source
        ) AS activity_no,
        SUBSTRING('Porte ' || src.activity_source, 1, 200) AS description,
        COALESCE(pm_user.person_id, pb.manager) AS activity_responsible,
        src.activity_date AS early_start,
        src.activity_date AS early_finish,
        src.activity_date AS late_start,
        src.activity_date AS late_finish,
        src.activity_date AS actual_start,
        src.activity_date AS actual_finish,
        public.get_default_value('clean_data.project_activity', 'task_id')::numeric AS task_id,
        public.get_default_value('clean_data.project_activity', 'progress_method_db') AS progress_method_db,
        public.get_default_value('clean_data.project_activity', 'planned_cost_driver_db') AS planned_cost_driver_db,
        public.get_default_value('clean_data.project_activity', 'exclude_periodical_cap_db') AS exclude_periodical_cap_db,
        public.get_default_value('clean_data.project_activity', 'exclude_resource_progress_db') AS exclude_resource_progress_db,
        public.get_default_value('clean_data.project_activity', 'exclude_from_integrations_db') AS exclude_from_integrations_db,
        public.get_default_value('clean_data.project_activity', 'node_type_db') AS node_type_db,
        public.get_default_value('clean_data.project_activity', 'mandatory_invoice_comment_db') AS mandatory_invoice_comment_db
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
                -- « Fin / Échéance » de l'état (Actual, heure de Paris), puis Forecast
                (COALESCE(vd.date_realisee, vd.date_prevue) AT TIME ZONE 'Europe/Paris')::DATE AS activity_date,
                vd.date_etat_source
            FROM clean_data.v_portes_detail vd
            -- Portes ET dates de l'état d'avancement le plus récent du projet QUI PORTE
            -- des statuts de jalon, et d'aucun autre. Le dernier état tout court ne
            -- convient pas : 75 projets (ex. 23.063, état du 29/05/2026) ont un dernier
            -- état sans aucun statut de jalon et perdaient toutes leurs portes.
            -- v_portes_detail porte, par jalon, son état le plus récent : le plus
            -- récent de ces états est donc le dernier état renseignant des jalons.
            JOIN (
                SELECT DISTINCT ON (SUBSTRING(p.project_number, 1, 10)) p.site_id, p.etat_id
                FROM clean_data.v_portes_detail p
                WHERE p.etat_id IS NOT NULL
                  AND p.project_number IS NOT NULL
                ORDER BY SUBSTRING(p.project_number, 1, 10), p.date_etat_source DESC NULLS LAST, p.etat_id DESC
            ) de
                ON de.site_id = vd.site_id
               AND de.etat_id = vd.etat_id
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
    -- Dates des portes P0..P6 : le fichier ASAP « projets à reprendre »
    -- (raw_data.sharepoint_project_to_save, écran /projets/a-reprendre) fait foi
    -- (demande métier 2026-10-06). Il porte la DERNIÈRE date de chaque porte
    -- (replanification bis/ter comprise) ; v_portes_detail ne garde que la porte
    -- d'origine du dernier état -> 118 dates divergentes, 142 portes absentes.
    -- Les portes bis/ter et P5 (absentes du fichier) gardent leur date d'état.
    ---------------------------------------------------------------------------
    DROP TABLE IF EXISTS tmp_porte_asap;
    CREATE TEMP TABLE tmp_porte_asap ON COMMIT DROP AS
    SELECT DISTINCT ON (SUBSTRING(t."Numéro du projet", 1, 10), g.gate)
        SUBSTRING(t."Numéro du projet", 1, 10) AS project_id,
        g.gate,
        TO_DATE(TRIM(g.d), 'DD/MM/YYYY') AS gate_date
    FROM raw_data.sharepoint_project_to_save t
    CROSS JOIN LATERAL (VALUES ('P0', t."P0"), ('P1', t."P1"), ('P2', t."P2"),
                               ('P3', t."P3"), ('P4', t."P4"), ('P6', t."P6")) g(gate, d)
    WHERE TRIM(g.d) ~ '^\d{2}/\d{2}/\d{4}$'
    ORDER BY SUBSTRING(t."Numéro du projet", 1, 10), g.gate, t.loaded_at DESC NULLS LAST;

    UPDATE clean_data.project_activity pa
    SET early_start = a.gate_date, early_finish = a.gate_date,
        late_start = a.gate_date, late_finish = a.gate_date,
        actual_start = a.gate_date, actual_finish = a.gate_date
    FROM tmp_porte_asap a
    WHERE pa.project_id = a.project_id
      AND pa.description = 'Porte ' || a.gate
      AND pa.early_start IS DISTINCT FROM a.gate_date;
    GET DIAGNOSTICS v_count_asap = ROW_COUNT;
    RAISE NOTICE 'Dates de portes réalignées sur le fichier ASAP: %', v_count_asap;

    SELECT COALESCE(MAX(activity_seq), 0) INTO v_max_seq FROM clean_data.project_activity;

    INSERT INTO clean_data.project_activity (
        activity_seq, project_id, sub_project_id, activity_no, description, activity_responsible,
        early_start, early_finish, late_start, late_finish, actual_start, actual_finish,
        task_id, progress_method_db, planned_cost_driver_db, exclude_periodical_cap_db,
        exclude_resource_progress_db, exclude_from_integrations_db, node_type_db,
        mandatory_invoice_comment_db
    )
    SELECT
        v_max_seq + ROW_NUMBER() OVER (ORDER BY a.project_id, a.gate),
        a.project_id,
        public.get_default_value('clean_data.project_activity', 'sub_project_id'),
        COALESCE(public.get_transcodification('Activity', a.gate, 'ASAP', 'IFS'), a.gate),
        'Porte ' || a.gate,
        COALESCE(pm.person_id, pb.manager),
        a.gate_date, a.gate_date, a.gate_date, a.gate_date, a.gate_date, a.gate_date,
        public.get_default_value('clean_data.project_activity', 'task_id')::numeric,
        public.get_default_value('clean_data.project_activity', 'progress_method_db'),
        public.get_default_value('clean_data.project_activity', 'planned_cost_driver_db'),
        public.get_default_value('clean_data.project_activity', 'exclude_periodical_cap_db'),
        public.get_default_value('clean_data.project_activity', 'exclude_resource_progress_db'),
        public.get_default_value('clean_data.project_activity', 'exclude_from_integrations_db'),
        public.get_default_value('clean_data.project_activity', 'node_type_db'),
        public.get_default_value('clean_data.project_activity', 'mandatory_invoice_comment_db')
    FROM tmp_porte_asap a
    JOIN clean_data.project_base pb ON pb.project_id = a.project_id
    LEFT JOIN LATERAL (
        SELECT u.person_id
        FROM raw_data.sharepoint_projets sp
        JOIN raw_data.sharepoint_users u ON u.sharepoint_user_id = sp.pm_id
        WHERE SUBSTRING(sp.project_number, 1, 10) = a.project_id
        ORDER BY sp.sharepoint_id
        LIMIT 1
    ) pm ON TRUE
    WHERE NOT EXISTS (
        SELECT 1 FROM clean_data.project_activity pa
        WHERE pa.project_id = a.project_id AND pa.description = 'Porte ' || a.gate
    );
    GET DIAGNOSTICS v_count_asap = ROW_COUNT;
    v_count_inserted := v_count_inserted + v_count_asap;
    RAISE NOTICE 'Portes du fichier ASAP ajoutées (absentes du dernier état): %', v_count_asap;

    ---------------------------------------------------------------------------
    -- Activités CFV : les Commissions Feu Vert deviennent des activités projet.
    --   Conception            -> CFV1  (commission de la porte P3)
    --   Mise en service       -> CFV2  (porte P4)
    --   Achèvement industriel -> CFV3  (porte P6)
    -- Même correspondance que clean_data.alimenter_project_activity_class(),
    -- qui consomme ces lignes pour produire les classes CFV1/CFV2/CFV3.
    --
    -- Source : raw_data.sharepoint_statut_cfv de l'état d'avancement LE PLUS RÉCENT
    -- du projet (clean_data.v_dernier_etat_avancement, rattachement par le GUID
    -- Status_x0020_Report). GUID non résolu -> pas d'activité CFV.
    -- Aucune phase en dur côté sortie : une activité n'est créée que si la phase
    -- est présente dans les données du projet.
    ---------------------------------------------------------------------------
    SELECT COALESCE(MAX(activity_seq), 0) INTO v_max_seq FROM clean_data.project_activity;

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
        v_max_seq + ROW_NUMBER() OVER (ORDER BY cfv.project_id, cfv.activity_no) AS activity_seq,
        cfv.project_id,
        public.get_default_value('clean_data.project_activity', 'sub_project_id') AS sub_project_id,
        cfv.activity_no,
        SUBSTRING(COALESCE(tk.target_value, 'CFV - ' || cfv.title), 1, 200) AS description,
        cfv.activity_responsible,
        cfv.cfv_date AS early_start,
        cfv.cfv_date AS early_finish,
        -- Commission réellement tenue (Vert / Orange / Rouge -> 1 / 2 / 3) : on date
        -- le réalisé. « Prévue » (0), « pas nécessaire (NA) » (4) ou état vide (0)
        -- restent sans date réelle, sinon l'activité partirait terminée dans IFS.
        CASE WHEN cfv.cfv_status IN ('1', '2', '3') THEN cfv.cfv_date END AS actual_start,
        CASE WHEN cfv.cfv_status IN ('1', '2', '3') THEN cfv.cfv_date END AS actual_finish,
        public.get_default_value('clean_data.project_activity', 'task_id')::numeric AS task_id,
        public.get_default_value('clean_data.project_activity', 'progress_method_db') AS progress_method_db,
        public.get_default_value('clean_data.project_activity', 'planned_cost_driver_db') AS planned_cost_driver_db,
        public.get_default_value('clean_data.project_activity', 'exclude_periodical_cap_db') AS exclude_periodical_cap_db,
        public.get_default_value('clean_data.project_activity', 'exclude_resource_progress_db') AS exclude_resource_progress_db,
        public.get_default_value('clean_data.project_activity', 'exclude_from_integrations_db') AS exclude_from_integrations_db,
        public.get_default_value('clean_data.project_activity', 'node_type_db') AS node_type_db,
        public.get_default_value('clean_data.project_activity', 'mandatory_invoice_comment_db') AS mandatory_invoice_comment_db
    FROM (
        -- Un seul statut retenu par (projet, phase) : le plus récent.
        -- Le DISTINCT ON dédoublonne aussi les projets portés par deux sites
        -- SharePoint (même project_number).
        SELECT DISTINCT ON (x.project_id, x.activity_no)
            x.*
        FROM (
            SELECT
                pb.project_id,
                ph.activity_no,
                c.title,
                COALESCE(pm_user.person_id, pb.manager) AS activity_responsible,
                -- Date1 est stocké en UTC (minuit Paris -> 23:00Z la veille) :
                -- on repasse en heure locale avant de tronquer, sinon la date recule d'un jour.
                (NULLIF(TRIM(c.raw_data->>'Date1'), '')::TIMESTAMPTZ
                     AT TIME ZONE 'Europe/Paris')::DATE AS cfv_date,
                public.get_transcodification(
                    'CFV', COALESCE(TRIM(c.raw_data->>'State'), ''), 'ASAP', 'IFS'
                ) AS cfv_status,
                c.modified
            FROM clean_data.project_base pb
            JOIN raw_data.sharepoint_projets sp
                ON pb.project_id = SUBSTRING(COALESCE(sp.project_number, sp.code), 1, 10)
            LEFT JOIN raw_data.sharepoint_users pm_user
                ON pm_user.sharepoint_user_id = sp.pm_id
            JOIN raw_data.sharepoint_statut_cfv c
                ON c.site_id = sp.sharepoint_id::TEXT
            JOIN clean_data.v_dernier_etat_avancement de
                ON de.project_id = pb.project_id
               AND de.site_id = c.site_id
               AND de.status_report_fk = c.raw_data->>'Status_x0020_Report'
            CROSS JOIN LATERAL (
                SELECT CASE lower(TRIM(c.title))
                           WHEN 'conception'            THEN 'CFV1'
                           WHEN 'mise en service'       THEN 'CFV2'
                           WHEN 'achèvement industriel' THEN 'CFV3'
                       END AS activity_no
            ) ph
            WHERE ph.activity_no IS NOT NULL
        ) x
        ORDER BY x.project_id, x.activity_no, x.modified DESC NULLS LAST
    ) cfv
    -- Libellé via la transco 'ACTIVITY_TASK', insensible à la casse
    -- (l'entrée dit « Mise en Service », la donnée « Mise en service »)
    LEFT JOIN LATERAL (
        SELECT tt.target_value
        FROM public."TranscodificationTable" tt
        WHERE tt.category = 'ACTIVITY_TASK'
          AND tt.source_system = 'ASAP'
          AND tt.target_system = 'IFS'
          AND tt.is_active
          AND LOWER(tt.source_value) = LOWER(cfv.title)
        LIMIT 1
    ) tk ON TRUE
    ORDER BY cfv.project_id, cfv.activity_no;

    GET DIAGNOSTICS v_count_cfv = ROW_COUNT;
    RAISE NOTICE 'Activités projet de type CFV insérées: %', v_count_cfv;

    ---------------------------------------------------------------------------
    -- Enrichissement depuis l'état d'avancement le plus récent du projet
    -- (l'ancien ORDER BY status_date DESC plaçait les dates NULL en tête)
    ---------------------------------------------------------------------------
    UPDATE clean_data.project_activity pa
    SET
        estimated_progress = (last_ea.percent_completed * 100)::NUMERIC,
        note = SUBSTRING(
            -- ';' -> '-' : séparateur du CSV d'export IFS
            REPLACE(regexp_replace(last_ea.update_text, '<[^>]*>', '', 'g'), ';', '-'),
            1, 2000
        )
    FROM clean_data.v_dernier_etat_avancement last_ea
    WHERE pa.project_id = last_ea.project_id;

    RAISE NOTICE 'Enrichissement depuis états d''avancement terminé';

    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;

    RAISE NOTICE 'Alimentation project_activity terminée';
    RAISE NOTICE 'Enregistrements insérés: % (portes : % + CFV : %)',
        v_count_inserted + v_count_cfv, v_count_inserted, v_count_cfv;
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
