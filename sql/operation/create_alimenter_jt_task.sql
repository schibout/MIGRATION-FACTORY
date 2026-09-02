-- Conversion date + heure SAP (textes YYYYMMDD + HHMMSS) en timestamp.
-- to_timestamp('...240000', 'YYYYMMDDHH24MISS') plante car SAP utilise l'heure
-- 240000 (fin de journée) : on convertit la date seule puis on AJOUTE l'heure
-- en intervalle -> '20260131' + '240000' donne 2026-02-01 00:00:00.
-- Retourne NULL si la date est absente/invalide ('00000000' inclus).
CREATE OR REPLACE FUNCTION clean_data.sap_datetime(p_date text, p_time text)
RETURNS timestamp
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE
        WHEN NULLIF(TRIM(COALESCE(p_date, '')), '') ~ '^[0-9]{8}$'
         AND TRIM(p_date) <> '00000000'
        THEN to_date(TRIM(p_date), 'YYYYMMDD')::timestamp
             + make_interval(
                   hours => LEFT(t.hms, 2)::int,
                   mins  => SUBSTRING(t.hms, 3, 2)::int,
                   secs  => RIGHT(t.hms, 2)::int)
    END
    FROM (SELECT LPAD(REGEXP_REPLACE(COALESCE(p_time, ''), '[^0-9]', '', 'g'), 6, '0') AS hms) t
$$;

CREATE OR REPLACE FUNCTION clean_data.alimenter_jt_task()
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

    RAISE NOTICE 'Début alimentation JT_TASK depuis SAP PM/AFVC - %', v_start_time;

    TRUNCATE TABLE clean_data.jt_task;
    RAISE NOTICE 'Table clean_data.jt_task vidée';

    INSERT INTO clean_data.jt_task (
        task_seq,
        order_no,
        wo_no,
        site,
        company,
        organization_site,
        organization_id,
        priority_id,
        work_type_id,
        description,
        long_description,
        prepared_by,
        reported_by,
        reported_date,
        mpb_latest_update,
        planned_start,
        planned_finish,
        duration,
        actual_start,
        actual_finish,
        earliest_start,
        latest_start,
        latest_finish,
        fixed_start,
        exclude_from_scheduling,
        exclude_from_scheduling_db,
        adjusted_duration,
        remark,
        action_taken,
        cancel_cause,
        vendor_no,
        currency_code,
        authorize_code,
        reference_no,
        cost_code,
        external_id,
        appointment_required,
        remotely_fulfilled,
        scheduled_manually,
        state,
        objtype,
        objversion,
        objid
    )
    WITH afru_last_op AS (
        -- Dernière confirmation AFRU par opération (mandt, aufpl, aplzl), pré-agrégée
        -- en UN SEUL parcours de la table. Remplace l'ancien LATERAL avec OR sur
        -- (aufpl, aplzl) non indexé (PK afru = mandt, rueck, rmzhl) qui déclenchait
        -- un seq scan d'afru par opération -> la fonction ne se terminait jamais.
        SELECT DISTINCT ON (r1.mandt, r1.aufpl, r1.aplzl) r1.*
        FROM raw_data.afru r1
        ORDER BY r1.mandt, r1.aufpl, r1.aplzl,
                 NULLIF(r1.ersda, '') DESC NULLS LAST,
                 NULLIF(r1.erzet, '') DESC NULLS LAST,
                 r1.rmzhl DESC NULLS LAST
    ), src AS (
        SELECT DISTINCT ON (v.mandt, v.aufpl, v.aplzl)
            v.mandt,
            v.aufpl,
            v.aplzl,
            v.vornr,
            v.werks,
            v.steus,
            v.ltxa1,
            v.ltxa2,
            v.afnam,
            v.lifnr,
            v.waers,
            v.sakto,
            v.objnr,
            v.rueck,
            v.rmzhl,
            v.updated_at AS afvc_updated_at,
            k.aufnr,
            k.aprio,
            k.gstrp,
            k.gsuzp,
            k.gltrp,
            k.gluzp,
            w.fsavd,
            w.fsavz,
            w.fsedd,
            w.fsedz,
            w.ssavd,
            w.ssavz,
            w.fssbd,
            w.fssbz,
            w.fssld,
            w.fsslz,
            w.dauno,
            w.arbei,
            w.isdd AS afvv_isdd,
            w.isdz AS afvv_isdz,
            w.iedd AS afvv_iedd,
            w.iedz AS afvv_iedz,
            r.ernam,
            r.ersda,
            r.erzet,
            r.isdd,
            r.isdz,
            r.iedd,
            r.iedz,
            r.ltxa1 AS afru_ltxa1,
            r.grund,
            c.arbpl,
            js.stat AS active_status
        FROM raw_data.afvc v
        LEFT JOIN raw_data.afko k
            ON k.mandt = v.mandt
           AND k.aufpl = v.aufpl
        LEFT JOIN raw_data.afvv w
            ON w.mandt = v.mandt
           AND w.aufpl = v.aufpl
           AND w.aplzl = v.aplzl
        -- Candidat 1 : dernière confirmation de l'opération (hash join sur la CTE pré-agrégée)
        LEFT JOIN afru_last_op ro
            ON ro.mandt = v.mandt
           AND ro.aufpl = v.aufpl
           AND ro.aplzl = v.aplzl
        -- Candidat 2 : confirmation pointée par AFVC (rueck, rmzhl) = PK d'afru (index lookup)
        LEFT JOIN raw_data.afru rr
            ON rr.mandt = v.mandt
           AND rr.rueck = v.rueck
           AND rr.rmzhl = v.rmzhl
        -- On garde la plus récente des deux (mêmes critères de tri que l'ancien LATERAL)
        LEFT JOIN LATERAL (
            SELECT c.ernam, c.ersda, c.erzet, c.isdd, c.isdz, c.iedd, c.iedz, c.ltxa1, c.grund
            FROM (
                SELECT ro.ernam, ro.ersda, ro.erzet, ro.rmzhl, ro.isdd, ro.isdz, ro.iedd, ro.iedz, ro.ltxa1, ro.grund
                WHERE ro.mandt IS NOT NULL
                UNION ALL
                SELECT rr.ernam, rr.ersda, rr.erzet, rr.rmzhl, rr.isdd, rr.isdz, rr.iedd, rr.iedz, rr.ltxa1, rr.grund
                WHERE rr.mandt IS NOT NULL
            ) c
            ORDER BY NULLIF(c.ersda, '') DESC NULLS LAST,
                     NULLIF(c.erzet, '') DESC NULLS LAST,
                     c.rmzhl DESC NULLS LAST
            LIMIT 1
        ) r ON TRUE
        LEFT JOIN raw_data.crhd c
            ON c.mandt = v.mandt
           AND c.objid = v.arbid
           AND (c.werks = v.werks OR c.werks IS NULL OR v.werks IS NULL)
        LEFT JOIN LATERAL (
            SELECT j.stat
            FROM raw_data.jest j
            WHERE j.mandt = v.mandt
              AND j.objnr = v.objnr
              AND (j.inact IS NULL OR TRIM(j.inact) <> 'X')
            ORDER BY j.stat
            LIMIT 1
        ) js ON TRUE
        WHERE v.aufpl IS NOT NULL
          AND v.aplzl IS NOT NULL
          AND (v.loekz IS NULL OR TRIM(v.loekz) = '')
          -- Ne reprendre QUE les donnees de 2026 : ordres dont la date de debut
          -- de base (AFKO.GSTRP, format SAP texte YYYYMMDD) tombe sur l'annee 2026.
          AND TRIM(k.gstrp) ~ '^[0-9]{8}$'
          AND LEFT(TRIM(k.gstrp), 4) = '2026'
        ORDER BY v.mandt, v.aufpl, v.aplzl, v.vornr
    ), mapped AS (
        SELECT
            CASE
                WHEN TRIM(aufpl) ~ '^[0-9]+$' AND TRIM(aplzl) ~ '^[0-9]+$'
                THEN (TRIM(aufpl)::numeric * 100000000 + TRIM(aplzl)::numeric)
            END AS task_seq,
            CASE WHEN TRIM(COALESCE(aufnr, '')) ~ '^[0-9]+$' THEN TRIM(aufnr)::numeric END AS order_no,
            CASE WHEN TRIM(COALESCE(aufnr, '')) ~ '^[0-9]+$' THEN TRIM(aufnr)::numeric END AS wo_no,
            SUBSTRING(COALESCE(NULLIF(TRIM(werks), ''), 'SJM'), 1, 5) AS site,
            public.get_default_value('clean_data.jt_task', 'company') AS company,
            SUBSTRING(COALESCE(NULLIF(TRIM(werks), ''), 'SJM'), 1, 5) AS organization_site,
            SUBSTRING(NULLIF(TRIM(arbpl), ''), 1, 8) AS organization_id,
            SUBSTRING(NULLIF(TRIM(aprio), ''), 1, 10) AS priority_id,
            SUBSTRING(NULLIF(TRIM(steus), ''), 1, 20) AS work_type_id,
            SUBSTRING(COALESCE(NULLIF(TRIM(ltxa1), ''), 'Opération SAP ' || COALESCE(vornr, aplzl)), 1, 200) AS description,
            SUBSTRING(NULLIF(TRIM(ltxa2), ''), 1, 4000) AS long_description,
            SUBSTRING(NULLIF(TRIM(afnam), ''), 1, 20) AS prepared_by,
            SUBSTRING(COALESCE(NULLIF(TRIM(ernam), ''), 'KAPEIFS'), 1, 20) AS reported_by,
            clean_data.sap_datetime(ersda, erzet) AS reported_date,
            afvc_updated_at::timestamp AS mpb_latest_update,
            COALESCE(
                clean_data.sap_datetime(fsavd, fsavz),
                clean_data.sap_datetime(gstrp, gsuzp)
            ) AS planned_start,
            COALESCE(
                clean_data.sap_datetime(fsedd, fsedz),
                clean_data.sap_datetime(gltrp, gluzp)
            ) AS planned_finish,
            CASE
                WHEN NULLIF(TRIM(dauno), '') ~ '^[0-9]+([.,][0-9]+)?$' THEN ROUND(REPLACE(TRIM(dauno), ',', '.')::numeric)
                WHEN NULLIF(TRIM(arbei), '') ~ '^[0-9]+([.,][0-9]+)?$' THEN ROUND(REPLACE(TRIM(arbei), ',', '.')::numeric)
            END AS duration,
            COALESCE(
                clean_data.sap_datetime(isdd, isdz),
                clean_data.sap_datetime(afvv_isdd, afvv_isdz)
            ) AS actual_start,
            COALESCE(
                clean_data.sap_datetime(iedd, iedz),
                clean_data.sap_datetime(afvv_iedd, afvv_iedz)
            ) AS actual_finish,
            clean_data.sap_datetime(ssavd, ssavz) AS earliest_start,
            clean_data.sap_datetime(fssbd, fssbz) AS latest_start,
            clean_data.sap_datetime(fssld, fsslz) AS latest_finish,
            public.get_default_value('clean_data.jt_task', 'fixed_start')::timestamp AS fixed_start,
            public.get_default_value('clean_data.jt_task', 'exclude_from_scheduling') AS exclude_from_scheduling,
            public.get_default_value('clean_data.jt_task', 'exclude_from_scheduling_db') AS exclude_from_scheduling_db,
            public.get_default_value('clean_data.jt_task', 'adjusted_duration') AS adjusted_duration,
            SUBSTRING(NULLIF(TRIM(afru_ltxa1), ''), 1, 2000) AS remark,
            SUBSTRING(NULLIF(TRIM(afru_ltxa1), ''), 1, 4000) AS action_taken,
            SUBSTRING(NULLIF(TRIM(grund), ''), 1, 10) AS cancel_cause,
            SUBSTRING(NULLIF(TRIM(lifnr), ''), 1, 20) AS vendor_no,
            SUBSTRING(NULLIF(TRIM(waers), ''), 1, 3) AS currency_code,
            SUBSTRING(NULLIF(TRIM(afnam), ''), 1, 20) AS authorize_code,
            SUBSTRING(CONCAT_WS('-', NULLIF(TRIM(aufnr), ''), NULLIF(TRIM(vornr), '')), 1, 25) AS reference_no,
            SUBSTRING(NULLIF(TRIM(sakto), ''), 1, 50) AS cost_code,
            SUBSTRING('SAP_AFVC_' || TRIM(aufpl) || '_' || TRIM(aplzl), 1, 500) AS external_id,
            public.get_default_value('clean_data.jt_task', 'appointment_required') AS appointment_required,
            public.get_default_value('clean_data.jt_task', 'remotely_fulfilled') AS remotely_fulfilled,
            public.get_default_value('clean_data.jt_task', 'scheduled_manually') AS scheduled_manually,
            SUBSTRING(NULLIF(TRIM(active_status), ''), 1, 4000) AS state,
            public.get_default_value('clean_data.jt_task', 'objtype') AS objtype,
            public.get_default_value('clean_data.jt_task', 'objversion') AS objversion,
            SUBSTRING(MD5('SAP_AFVC_' || TRIM(aufpl) || '_' || TRIM(aplzl)), 1, 10) AS objid
        FROM src
    )
    SELECT
        task_seq,
        order_no,
        wo_no,
        site,
        company,
        organization_site,
        organization_id,
        priority_id,
        work_type_id,
        description,
        long_description,
        prepared_by,
        reported_by,
        reported_date,
        mpb_latest_update,
        planned_start,
        planned_finish,
        duration,
        actual_start,
        actual_finish,
        earliest_start,
        latest_start,
        latest_finish,
        fixed_start,
        exclude_from_scheduling,
        exclude_from_scheduling_db,
        adjusted_duration,
        remark,
        action_taken,
        cancel_cause,
        vendor_no,
        currency_code,
        authorize_code,
        reference_no,
        cost_code,
        external_id,
        appointment_required,
        remotely_fulfilled,
        scheduled_manually,
        state,
        objtype,
        objversion,
        objid
    FROM mapped
    WHERE task_seq IS NOT NULL
      AND description IS NOT NULL;

    GET DIAGNOSTICS v_count_inserted = ROW_COUNT;

    INSERT INTO clean_data.etl_log (
        procedure_name, mode, start_ts, end_ts, status,
        nb_inserted, nb_updated, nb_deleted, nb_rejected, message
    ) VALUES (
        'clean_data.alimenter_jt_task', 'FULL', v_start_time, CURRENT_TIMESTAMP, 'SUCCESS',
        v_count_inserted, 0, 0, 0,
        'Alimentation JT_TASK depuis raw_data.afvc avec enrichissements afko/afvv/afru/crhd/jest disponibles'
    );

    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;

    RAISE NOTICE 'Alimentation JT_TASK terminée avec succès';
    RAISE NOTICE 'Nombre de lignes insérées: %', v_count_inserted;
    RAISE NOTICE 'Durée: %', v_duration;

EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;

        BEGIN
            INSERT INTO clean_data.etl_log (
                procedure_name, mode, start_ts, end_ts, status,
                nb_inserted, nb_updated, nb_deleted, nb_rejected, message
            ) VALUES (
                'clean_data.alimenter_jt_task', 'FULL', v_start_time, v_end_time, 'ERROR',
                COALESCE(v_count_inserted, 0), 0, 0, 0,
                SQLSTATE || ' - ' || SQLERRM
            );
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;

        RAISE NOTICE 'ERREUR alimentation JT_TASK';
        RAISE NOTICE 'Code: %', SQLSTATE;
        RAISE NOTICE 'Message: %', SQLERRM;
        RAISE NOTICE 'Durée avant erreur: %', v_duration;
        RAISE;
END;
$function$;
