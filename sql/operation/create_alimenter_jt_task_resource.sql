CREATE TABLE IF NOT EXISTS clean_data.jt_task_resource (
    task_seq numeric,
    task_resource_seq numeric,
    planned_hours numeric,
    planned_quantity numeric,
    "offset" numeric,
    remark varchar(2000),
    created_by varchar(30),
    created_date timestamp without time zone,
    demand_type varchar(4000),
    demand_type_db varchar(20),
    resource_seq numeric,
    resource_group_seq numeric,
    wo_no numeric,
    task_plan_line_seq numeric,
    plan_line_no numeric,
    modified_by varchar(30),
    modified_date timestamp without time zone,
    sourcing_option varchar(4000),
    sourcing_option_db varchar(20),
    rental_supply_option varchar(4000),
    rental_supply_option_db varchar(20),
    rental_site varchar(5),
    rental_part_no varchar(25),
    quotation_no varchar(12),
    quotation_rev numeric,
    quo_task_seq numeric,
    quo_task_res_seq numeric,
    pool_allocated_qty numeric,
    crew_time_invoicing varchar(20),
    external_id varchar(500),
    objversion varchar(14),
    objid varchar(10)
);

COMMENT ON TABLE clean_data.jt_task_resource IS 'IFS JT_TASK_RESOURCE - demandes ressources des tâches de bon de travail, alimentées depuis SAP AFVC/AFKO/CRHD.';
COMMENT ON COLUMN clean_data.jt_task_resource.task_seq IS 'Reprendre N° de la table JT_TASK';
COMMENT ON COLUMN clean_data.jt_task_resource.task_resource_seq IS 'No incrémental';
COMMENT ON COLUMN clean_data.jt_task_resource.planned_hours IS 'ne pas renseigner ; champ calculé';
COMMENT ON COLUMN clean_data.jt_task_resource.planned_quantity IS 'Quantité ressource';
COMMENT ON COLUMN clean_data.jt_task_resource."offset" IS '0';
COMMENT ON COLUMN clean_data.jt_task_resource.remark IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.created_by IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.created_date IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.demand_type IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.demand_type_db IS 'PERSON ou EQUIPMENT';
COMMENT ON COLUMN clean_data.jt_task_resource.resource_seq IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.resource_group_seq IS 'Resource_Group_seq = groupe ressource ; info dans RESOURCE_DETAIL';
COMMENT ON COLUMN clean_data.jt_task_resource.wo_no IS '= No BT de JT_TASK';
COMMENT ON COLUMN clean_data.jt_task_resource.task_plan_line_seq IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.plan_line_no IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.modified_by IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.modified_date IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.sourcing_option IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.sourcing_option_db IS 'INTERNALLY_SOURCED';
COMMENT ON COLUMN clean_data.jt_task_resource.rental_supply_option IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.rental_supply_option_db IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.rental_site IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.rental_part_no IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.quotation_no IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.quotation_rev IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.quo_task_seq IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.quo_task_res_seq IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.pool_allocated_qty IS 'ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.crew_time_invoicing IS 'FALSE';
COMMENT ON COLUMN clean_data.jt_task_resource.external_id IS 'ne pas renseigner selon catalogue ; laissé NULL dans le loader';
COMMENT ON COLUMN clean_data.jt_task_resource.objversion IS 'champ technique IFS - ne pas renseigner';
COMMENT ON COLUMN clean_data.jt_task_resource.objid IS 'champ technique IFS - ne pas renseigner';

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
          -- Ne reprendre QUE les donnees de 2026 : ordres dont la date de debut
          -- de base (AFKO.GSTRP, format SAP texte YYYYMMDD) tombe sur l'annee 2026.
          AND trim(k.gstrp) ~ '^[0-9]{8}$'
          AND left(trim(k.gstrp), 4) = '2026'
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
            public.get_default_value('clean_data.jt_task_resource', 'offset_value', '0') AS offset_value,
            CASE
                WHEN upper(coalesce(resource_type_db, '')) = 'EQUIPMENT' THEN 'EQUIPMENT'
                ELSE 'PERSON'
            END AS demand_type_db,
            resource_group_seq,
            CASE WHEN trim(coalesce(aufnr, '')) ~ '^[0-9]+$' THEN trim(aufnr)::numeric END AS wo_no,
            public.get_default_value('clean_data.jt_task_resource', 'sourcing_option_db', 'INTERNALLY_SOURCED') AS sourcing_option_db,
            public.get_default_value('clean_data.jt_task_resource', 'crew_time_invoicing', 'FALSE') AS crew_time_invoicing
        FROM src
    )
    SELECT
        task_seq,
        task_resource_seq,
        planned_quantity,
        offset_value,
        demand_type_db,
        resource_group_seq,
        wo_no,
        sourcing_option_db,
        crew_time_invoicing
    FROM mapped m
    WHERE task_seq IS NOT NULL
      AND EXISTS (
          SELECT 1
          FROM clean_data.jt_task t
          WHERE t.task_seq = m.task_seq
      );

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
