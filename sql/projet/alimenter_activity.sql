-- DROP FUNCTION clean_data.alimenter_activity();

CREATE OR REPLACE FUNCTION clean_data.alimenter_activity()
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

    RAISE NOTICE 'Début de l''alimentation des activités (ACTIVITY) - %', v_start_time;

    -- Vider la table cible avant insertion
    TRUNCATE TABLE clean_data.activity RESTART IDENTITY;
    RAISE NOTICE 'Table activity vidée';

    -- Insérer les activités basées sur les portes pour chaque projet
    -- Toutes les activités sont associées au sous-projet 10 (Suivi des portes)
    -- activity_no est calculé via la table de transcodification (catégorie 'Activity', SAP → IFS)
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
        ROW_NUMBER() OVER (ORDER BY pb.project_id, g.gate_order) AS activity_seq,
        pb.project_id,
        -- activity_no : transcodification SAP → IFS, fallback sur le code source
        SUBSTRING(
            COALESCE(
                public.get_transcodification('Activity', g.gate_code, 'ASAP', 'IFS'),
                g.gate_code
            ),
            1, 10
        ) AS activity_no,
        SUBSTRING(g.description, 1, 200) AS description,
        '10' AS sub_project_id,
        'ALL_CONNECTED_OBJECTS' AS progress_method,
        'ALL_CONNECTED_OBJECTS' AS progress_method_db,
        'CONNECTED_OBJECTS' AS planned_cost_driver,
        'CONNECTED_OBJECTS' AS planned_cost_driver_db,
        'INCLUDE' AS exclude_periodical_cap,
        'INCLUDE' AS exclude_periodical_cap_db,
        'FALSE' AS exclude_resource_progress,
        'FALSE' AS exclude_resource_progress_db,
        'FALSE' AS exclude_from_integrations,
        'FALSE' AS exclude_from_integrations_db,
        'ACTIVITY' AS node_type,
        'ACTIVITY' AS node_type_db,
        'INHERIT' AS mandatory_invoice_comment,
        'INHERIT' AS mandatory_invoice_comment_db,
        -- early_start / early_finish : date d'échéance de la porte côté ASAP
        CASE g.gate_code
            WHEN 'P0'    THEN sp.end_p0::DATE
            WHEN 'P0bis' THEN sp.end_p0::DATE
            WHEN 'P0ter' THEN sp.end_p0::DATE
            WHEN 'P1'    THEN sp.end_p1::DATE
            WHEN 'P1bis' THEN sp.end_p1::DATE
            WHEN 'P1ter' THEN sp.end_p1::DATE
            WHEN 'P2'    THEN sp.end_p2::DATE
            WHEN 'P3'    THEN sp.end_p3::DATE
            WHEN 'P4'    THEN sp.end_p4::DATE
            WHEN 'P5'    THEN sp.end_p5::DATE
            WHEN 'P6'    THEN sp.end_p6::DATE
            WHEN 'CFV1'  THEN sp.conception_date::DATE
            WHEN 'CFV2'  THEN sp.mise_en_service_date::DATE
            WHEN 'CFV3'  THEN sp.achevement_industriel_date::DATE
        END AS early_start,
        CASE g.gate_code
            WHEN 'P0'    THEN sp.end_p0::DATE
            WHEN 'P0bis' THEN sp.end_p0::DATE
            WHEN 'P0ter' THEN sp.end_p0::DATE
            WHEN 'P1'    THEN sp.end_p1::DATE
            WHEN 'P1bis' THEN sp.end_p1::DATE
            WHEN 'P1ter' THEN sp.end_p1::DATE
            WHEN 'P2'    THEN sp.end_p2::DATE
            WHEN 'P3'    THEN sp.end_p3::DATE
            WHEN 'P4'    THEN sp.end_p4::DATE
            WHEN 'P5'    THEN sp.end_p5::DATE
            WHEN 'P6'    THEN sp.end_p6::DATE
            WHEN 'CFV1'  THEN sp.conception_date::DATE
            WHEN 'CFV2'  THEN sp.mise_en_service_date::DATE
            WHEN 'CFV3'  THEN sp.achevement_industriel_date::DATE
        END AS early_finish,
        COALESCE(
            clean_data.get_person_id_from_sharepoint_user_id(sp.pm_id::TEXT),
            pb.manager
        ) AS activity_responsible
    FROM clean_data.project_base pb
    LEFT JOIN raw_data.sharepoint_projets sp
        ON pb.project_id = SUBSTRING(COALESCE(sp.project_number, sp.code), 1, 10)
    CROSS JOIN (
        VALUES
            -- Portes principales et intermédiaires
            ('P0',    'Porte P0 - Idée',                 1),
            ('P0bis', 'Porte P0bis',                     2),
            ('P0ter', 'Porte P0ter',                     3),
            ('P1',    'Porte P1 - Faisabilité',          4),
            ('P1bis', 'Porte P1bis',                     5),
            ('P1ter', 'Porte P1ter',                     6),
            ('P2',    'Porte P2 - Avant-Projet',         7),
            ('P3',    'Porte P3 - Conception',           8),
            ('P4',    'Porte P4 - Réalisation',          9),
            ('P5',    'Porte P5 - Mise en Service',     10),
            ('P6',    'Porte P6 - Clôture',             11),
            -- Tâches CFV
            ('CFV1',  'CFV Conception',                 12),
            ('CFV2',  'CFV Mise en Service',            13),
            ('CFV3',  'CFV Achèvement Industriel',      14)
    ) AS g(gate_code, description, gate_order)
    ORDER BY pb.project_id, g.gate_order;

    -- Compter les enregistrements insérés
    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;

    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;

    -- Log des résultats
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

        -- Relancer l'exception pour arrêter le processus ETL
        RAISE;
END;
$function$
;
