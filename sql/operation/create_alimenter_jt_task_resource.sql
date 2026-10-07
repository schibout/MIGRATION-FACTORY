CREATE OR REPLACE FUNCTION clean_data.alimenter_jt_task_resource()
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
    v_count_inserted integer := 0;
    v_start_time timestamp := clock_timestamp();
    v_end_time timestamp;
    v_duration interval;
BEGIN
    RAISE NOTICE 'Début alimentation JT_TASK_RESOURCE depuis SAP AFVC/AFKO/CRHD - %', v_start_time;

    TRUNCATE TABLE clean_data.jt_task_resource;
    RAISE NOTICE 'Table clean_data.jt_task_resource vidée';

    INSERT INTO clean_data.jt_task_resource (
        task_seq,
        task_resource_seq,
        planned_quantity,
        "offset",
        demand_type_db,
        resource_seq,
        resource_group_seq,
        wo_no,
        sourcing_option_db,
        crew_time_invoicing
    )
    WITH src AS (
        SELECT DISTINCT ON (v.mandt, v.aufpl, v.aplzl)
            v.mandt,
            v.aufpl,
            v.aplzl,
            v.anzma,
            k.aufnr,
            c.arbpl,
            rd.resource_seq AS resource_group_seq,
            rd.resource_type_db
        FROM raw_data.afvc v
        LEFT JOIN raw_data.afko k
            ON k.mandt = v.mandt
           AND k.aufpl = v.aufpl
        LEFT JOIN raw_data.crhd c
            ON c.mandt = v.mandt
           AND c.objid = v.arbid
           AND (c.werks = v.werks OR c.werks IS NULL OR v.werks IS NULL)
        LEFT JOIN LATERAL (
            SELECT r.resource_seq, r.resource_type_db
            FROM clean_data.resource_detail_file r
            WHERE upper(trim(r.resource_id)) = upper(coalesce(
                    nullif(public.get_transcodification('RESOURCE_GROUP', c.arbpl, 'SAP', 'IFS'), ''),
                    nullif(public.get_transcodification('ARBPL', c.arbpl, 'SAP', 'IFS'), ''),
                    case
                        when nullif(trim(c.arbpl), '') is not null and position('.' in trim(c.arbpl)) > 0
                        then 'SJ-' || split_part(trim(c.arbpl), '.', 2)
                        else trim(c.arbpl)
                    end
                ))
            ORDER BY r.resource_seq
            LIMIT 1
        ) rd ON TRUE
        WHERE v.aufpl IS NOT NULL
          AND v.aplzl IS NOT NULL
          AND trim(v.aufpl) ~ '^[0-9]+$'
          AND trim(v.aplzl) ~ '^[0-9]+$'
          AND (v.loekz IS NULL OR trim(v.loekz) = '')
          -- Operations en cours ou futures uniquement : en-tete d'ordre present
          -- (une operation sans AFKO n'a pas de bon de travail) et ordre non
          -- clos (cf. clean_data.v_sap_ordre_clos, 00_operation_helpers.sql).
          AND k.aufnr IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM clean_data.v_sap_ordre_clos oc
              WHERE oc.mandt = k.mandt AND oc.aufnr = k.aufnr
          )
        ORDER BY v.mandt, v.aufpl, v.aplzl, v.vornr
    ), mapped AS (
        SELECT
            trim(aufpl)::numeric * 100000000 + trim(aplzl)::numeric AS task_seq,
            row_number() OVER (ORDER BY mandt, trim(aufpl)::numeric, trim(aplzl)::numeric)::numeric AS task_resource_seq,
            CASE
                WHEN nullif(trim(anzma), '') ~ '^[0-9]+([.,][0-9]+)?$'
                 AND replace(trim(anzma), ',', '.')::numeric > 0
                    THEN replace(trim(anzma), ',', '.')::numeric
                ELSE 1::numeric
            END AS planned_quantity,
            -- clean_data.jt_task_resource."offset" est NUMERIC et
            -- get_default_value() renvoie du TEXT : PostgreSQL n'a aucun cast
            -- implicite, d'ou l'erreur 42804 sans le ::numeric. Le NULLIF est
            -- indispensable : une valeur laissee vide dans l'ecran des valeurs
            -- par defaut ferait echouer ''::numeric (22P02) et casserait tout
            -- le chargement.
            NULLIF(public.get_default_value('clean_data.jt_task_resource', 'offset_value'), '')::numeric AS offset_value,
            CASE
                WHEN upper(coalesce(resource_type_db, '')) = 'EQUIPMENT' THEN 'EQUIPMENT'
                ELSE 'PERSON'
            END AS demand_type_db,
            resource_group_seq,
            CASE WHEN trim(coalesce(aufnr, '')) ~ '^[0-9]+$' THEN trim(aufnr)::numeric END AS wo_no,
            public.get_default_value('clean_data.jt_task_resource', 'sourcing_option_db') AS sourcing_option_db,
            public.get_default_value('clean_data.jt_task_resource', 'crew_time_invoicing') AS crew_time_invoicing
        FROM src
    )
    SELECT
        m.task_seq,
        m.task_resource_seq,
        m.planned_quantity,
        m.offset_value,
        m.demand_type_db,
        -- RESOURCE_SEQ : organisation de maintenance de la tache (SJ-MATC...),
        -- deja transcodee dans jt_task (demande explicite 2026-10-07, migration 101).
        t.organization_id,
        m.resource_group_seq,
        m.wo_no,
        m.sourcing_option_db,
        m.crew_time_invoicing
    FROM mapped m
    -- jt_task.task_seq unique par construction : la jointure ne duplique pas.
    JOIN clean_data.jt_task t ON t.task_seq = m.task_seq;

    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;
    v_end_time := clock_timestamp();
    v_duration := v_end_time - v_start_time;

    INSERT INTO clean_data.etl_log (
        procedure_name, mode, start_ts, end_ts, status,
        nb_inserted, nb_updated, nb_deleted, nb_rejected, message
    ) VALUES (
        'clean_data.alimenter_jt_task_resource', 'FULL', v_start_time, v_end_time, 'SUCCESS',
        v_count_inserted, 0, 0, 0,
        'Alimentation JT_TASK_RESOURCE depuis raw_data.afvc + afko + crhd ; resource_group_seq via clean_data.resource_detail_file et transcodification RESOURCE_GROUP/ARBPL si disponible'
    );

    RAISE NOTICE 'Alimentation JT_TASK_RESOURCE terminée avec succès';
    RAISE NOTICE 'Nombre de lignes insérées: %', v_count_inserted;
    RAISE NOTICE 'Durée: %', v_duration;

EXCEPTION WHEN OTHERS THEN
    v_end_time := clock_timestamp();
    v_duration := v_end_time - v_start_time;

    BEGIN
        INSERT INTO clean_data.etl_log (
            procedure_name, mode, start_ts, end_ts, status,
            nb_inserted, nb_updated, nb_deleted, nb_rejected, message
        ) VALUES (
            'clean_data.alimenter_jt_task_resource', 'FULL', v_start_time, v_end_time, 'ERROR',
            coalesce(v_count_inserted, 0), 0, 0, 0,
            SQLSTATE || ' - ' || SQLERRM
        );
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RAISE NOTICE 'ERREUR alimentation JT_TASK_RESOURCE';
    RAISE NOTICE 'Code: %', SQLSTATE;
    RAISE NOTICE 'Message: %', SQLERRM;
    RAISE NOTICE 'Durée avant erreur: %', v_duration;
    RAISE;
END;
$function$;
