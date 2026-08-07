-- DROP FUNCTION clean_data.alimenter_project_activity();

CREATE OR REPLACE FUNCTION clean_data.alimenter_project_activity()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_count_inserted INTEGER := 0;
    v_count_errors INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;

    RAISE NOTICE 'Début de l''alimentation des project_activity - %', v_start_time;

    TRUNCATE TABLE clean_data.project_activity RESTART IDENTITY;
    RAISE NOTICE 'Table project_activity vidée';

    ---------------------------------------------------------------------------
    -- Deux sources d'activités, en UNION ALL (activity_seq global) :
    --   1) PORTES : data-driven depuis clean_data.v_portes_detail (portes
    --      réellement présentes, 1 par milestone P3 / P3 bis / P3 Ters),
    --      restreint aux projets de clean_data.project_base (INNER JOIN).
    --      activity_no via transcodif 'Activity' du code ASAP déduit du
    --      libellé (P3 bis -> P3bis -> 0035-P3, P3 Ters -> P3ter -> 0036-P3).
    --      Dates depuis raw_data.sharepoint_porte pour les gates principaux
    --      (+ fallback dates de la vue, seule source pour les bis/ter).
    --   2) CFV : inchangé — CFV1/2/3 depuis raw_data.sharepoint_projets
    --      (état conception / mise en service / achèvement ≠ 'pas nécessaire (NA)').
    --
    -- PRÉREQUIS : la vue clean_data.v_portes_detail doit exister (v_portes_detail.sql).
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
        task_id,
        -- Colonnes obligatoires avec valeurs par défaut
        progress_method_db,
        planned_cost_driver_db,
        exclude_periodical_cap_db,
        exclude_resource_progress_db,
        exclude_from_integrations_db,
        node_type_db,
        mandatory_invoice_comment_db
    )
    SELECT
        ROW_NUMBER() OVER (ORDER BY src.project_id, src.bloc, src.tri, src.activity_no) AS activity_seq,
        src.project_id,
        '10' AS sub_project_id,
        src.activity_no,
        src.description,
        src.activity_responsible,
        src.early_start,
        src.early_finish,
        src.task_id,
        -- Valeurs par défaut constantes (variantes _db uniquement)
        'ALL_CONNECTED_OBJECTS',
        'CONNECTED_OBJECTS',
        'INCLUDE',
        'FALSE',
        'FALSE',
        'ACTIVITY',
        'INHERIT'
    FROM (
        -----------------------------------------------------------------------
        -- 1) PORTES depuis v_portes_detail (∈ project_base)
        -----------------------------------------------------------------------
        SELECT
            pb.project_id,
            1            AS bloc,
            v.gate_key   AS tri,
            -- 1 activité par (gate, variante) : P3 -> 003-P3, P3 bis -> 0035-P3,
            -- P3 Ters -> 0036-P3 (via transcodif 'Activity' sur la clé ASAP normalisée)
            COALESCE(
                public.get_transcodification('Activity', v.gate_key, 'ASAP', 'IFS'),
                v.gate_key
            ) AS activity_no,
            'Porte ' || COALESCE(NULLIF(TRIM(v.porte_libelle), ''), v.gate_key) AS description,
            COALESCE(pm_user.person_id, pb.manager) AS activity_responsible,
            COALESCE(spo.date_debut, v.date_baseline)::DATE                 AS early_start,
            COALESCE(spo.date_fin, v.date_prevue, v.date_realisee)::DATE    AS early_finish,
            NULL::NUMERIC AS task_id
        FROM (
            -- 1 seul milestone par (projet, CLÉ ASAP) : la clé intègre la variante
            -- bis/ter déduite du libellé, donc P3 et P3 bis donnent 2 activités
            -- distinctes. Au sein d'une même clé on préfère le milestone dont le
            -- libellé = la clé, sinon le plus récent -> pas de doublon d'activity_no.
            SELECT DISTINCT ON (SUBSTRING(x.project_number, 1, 10), x.gate_key) x.*
            FROM (
                SELECT vd.*,
                       -- Normalisation du libellé (casse, espaces, ponctuation, pluriel
                       -- "Ters") -> clé ASAP : 'P3', 'P3bis', 'P3ter'.
                       -- Les libellés hors nomenclature (P3.2, "P4 batch 2", "P2/P3"...)
                       -- retombent sur le gate principal.
                       CASE
                           WHEN regexp_replace(lower(COALESCE(vd.porte_libelle, '')), '[^a-z0-9]', '', 'g')
                                ~ ('^' || lower(vd.gate) || 'bis')   THEN vd.gate || 'bis'
                           WHEN regexp_replace(lower(COALESCE(vd.porte_libelle, '')), '[^a-z0-9]', '', 'g')
                                ~ ('^' || lower(vd.gate) || 'ters?') THEN vd.gate || 'ter'
                           ELSE vd.gate
                       END AS gate_key
                FROM clean_data.v_portes_detail vd
            ) x
            ORDER BY SUBSTRING(x.project_number, 1, 10), x.gate_key,
                     CASE WHEN x.porte_libelle = x.gate_key THEN 0 ELSE 1 END,
                     x.date_etat_source DESC NULLS LAST
        ) v
        JOIN clean_data.project_base pb
            ON pb.project_id = SUBSTRING(v.project_number, 1, 10)
        LEFT JOIN raw_data.sharepoint_projets sp
            ON sp.sharepoint_id::TEXT = v.site_id
        -- Responsable : person_id directement depuis raw_data.sharepoint_users (chef de projet = pm_id)
        LEFT JOIN raw_data.sharepoint_users pm_user
            ON pm_user.sharepoint_user_id = sp.pm_id
        -- Dates SAP/SharePoint : raw_data.sharepoint_porte ne connaît que les gates
        -- principaux (P0..P6). On ne l'applique donc PAS aux variantes bis/ter, sinon
        -- elles hériteraient des dates de la porte principale -> pour elles, on garde
        -- les dates propres du milestone (baseline / prévue / réalisée).
        LEFT JOIN raw_data.sharepoint_porte spo
            ON SUBSTRING(spo.numero_projet, 1, 10) = pb.project_id
           AND spo.porte = v.gate
           AND v.gate_key = v.gate

        UNION ALL

        -----------------------------------------------------------------------
        -- 2) CFV (inchangé)
        -----------------------------------------------------------------------
        SELECT
            pb.project_id,
            2            AS bloc,
            g.gate_code  AS tri,
            COALESCE(
                public.get_transcodification('Activity', g.gate_code, 'ASAP', 'IFS'),
                g.gate_code
            ) AS activity_no,
            g.description,
            COALESCE(pm_user.person_id, pb.manager) AS activity_responsible,
            NULL::DATE AS early_start,
            NULL::DATE AS early_finish,
            g.task_id
        FROM clean_data.project_base pb
        LEFT JOIN raw_data.sharepoint_projets sp
            ON pb.project_id = SUBSTRING(COALESCE(sp.project_number, sp.code), 1, 10)
        -- Responsable : person_id directement depuis raw_data.sharepoint_users (chef de projet = pm_id)
        LEFT JOIN raw_data.sharepoint_users pm_user
            ON pm_user.sharepoint_user_id = sp.pm_id
        CROSS JOIN (
            VALUES
                ('CFV1', 'CFV Conception',            1.31, 'Conception'),
                ('CFV2', 'CFV Mise en Service',       1.41, 'Mise en service'),
                ('CFV3', 'CFV Achèvement Industriel', 1.61, 'Achèvement industriel')
        ) AS g(gate_code, description, task_id, phase_title)
        -- État de la commission = dernier statut_cfv du projet pour la phase
        -- (= les "Commissions Feu Vert" de la popup état d'avancement, pas sharepoint_projets)
        LEFT JOIN LATERAL (
            SELECT c.raw_data->>'State' AS state
            FROM raw_data.sharepoint_statut_cfv c
            WHERE c.site_id = sp.sharepoint_id::TEXT
              AND c.title   = g.phase_title
            ORDER BY c.modified DESC NULLS LAST
            LIMIT 1
        ) cfv ON TRUE
        -- Ne garder que les CFV "actives" (état renseigné ≠ 'pas nécessaire (NA)')
        WHERE NULLIF(TRIM(cfv.state), '') IS NOT NULL
          AND TRIM(cfv.state) <> 'pas nécessaire (NA)'
    ) src
    ORDER BY src.project_id, src.bloc, src.tri, src.activity_no;

    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;
    RAISE NOTICE 'Activités insérées: %', v_count_inserted;

    ---------------------------------------------------------------------------
    -- Enrichissement depuis les états d'avancement (dernier état par projet)
    -- On met à jour estimated_progress et note pour chaque projet
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
