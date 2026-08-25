CREATE OR REPLACE PROCEDURE clean_data.populate_pm_action()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    -- Constantes de configuration IFS (ajuster avant le run réel)
    v_org_contract        VARCHAR := 'SJ';
    v_org_code            VARCHAR := 'FR_MAINT';
    v_pm_revision         VARCHAR := '1';
    v_connection_type     VARCHAR := 'Functional Object';
    v_connection_type_db  VARCHAR := 'FUNCTIONAL';
    v_count INTEGER := 0;
    v_reject_count INTEGER := 0;
BEGIN
    TRUNCATE TABLE clean_data.pm_action;
    TRUNCATE TABLE clean_data.pm_action_reject;
    WITH src AS (
        SELECT * FROM clean_data.v_pm_source
    ),
    agg AS (
        SELECT
            s.pm_no,
            NULLIF(btrim(min(s.poste_technique)), '') AS mch_code,
            min(s.freq_norm)       AS freq_norm,
            left(string_agg(DISTINCT s.raw_id::text, ',' ORDER BY s.raw_id::text), 2000) AS source_raw_ids
        FROM src s
        GROUP BY s.pm_no
    ),
    rep AS (
        SELECT DISTINCT ON (s.pm_no)
            s.pm_no,
            s.designation
        FROM src s
        ORDER BY s.pm_no, clean_data.pe_num(s.compteur_de_gamme) NULLS LAST, s.raw_id
    ),
    invalid AS (
        SELECT
            a.pm_no,
            v_pm_revision AS pm_revision,
            v_org_contract AS mch_code_contract,
            a.mch_code,
            left(r.designation, 2000) AS description,
            a.source_raw_ids,
            CASE
                WHEN a.mch_code IS NULL THEN 'Objet équipement non renseigné'
                ELSE 'Objet équipement inexistant dans clean_data.equipment_functional pour le site ' || v_org_contract
            END AS rejection_reason
        FROM agg a
        LEFT JOIN rep r ON r.pm_no = a.pm_no
        WHERE a.mch_code IS NULL
           OR NOT EXISTS (
                SELECT 1
                FROM clean_data.equipment_functional ef
                WHERE ef.contract = v_org_contract
                  AND ef.mch_code = a.mch_code
           )
    )
    INSERT INTO clean_data.pm_action_reject (
        rejection_reason,
        pm_no,
        pm_revision,
        mch_code_contract,
        mch_code,
        description,
        source_raw_ids,
        rejected_at
    )
    SELECT
        rejection_reason,
        pm_no,
        pm_revision,
        mch_code_contract,
        mch_code,
        description,
        source_raw_ids,
        CURRENT_TIMESTAMP
    FROM invalid;
    GET DIAGNOSTICS v_reject_count = ROW_COUNT;
    -- Une ligne de raw_data.pe_tools = une OPERATION, pas une pm_action :
    -- un plan d'entretien s'étale sur plusieurs lignes (gammes / groupes de gamme).
    -- On agrège donc par pm_no ; le détail ligne à ligne est conservé dans pm_action_work_step.
    INSERT INTO clean_data.pm_action (
        pm_no,
        pm_revision,
        mch_code_contract,
        mch_code,
        org_contract,
        org_code,
        connection_type,
        connection_type_db,
        "interval",
        pm_interval_unit,
        pm_interval_unit_db,
        description,
        note,
        latest_pm,
        last_changed
    )
    WITH src AS (
        SELECT * FROM clean_data.v_pm_source
    ),
    agg AS (
        SELECT
            s.pm_no,
            NULLIF(btrim(min(s.poste_technique)), '') AS mch_code,
            min(s.freq_norm)       AS freq_norm
        FROM src s
        GROUP BY s.pm_no
    ),
    valid AS (
        SELECT a.*
        FROM agg a
        WHERE a.mch_code IS NOT NULL
          AND EXISTS (
                SELECT 1
                FROM clean_data.equipment_functional ef
                WHERE ef.contract = v_org_contract
                  AND ef.mch_code = a.mch_code
          )
    ),
    rep AS (
        SELECT DISTINCT ON (s.pm_no)
            s.pm_no,
            s.designation
        FROM src s
        ORDER BY s.pm_no, clean_data.pe_num(s.compteur_de_gamme) NULLS LAST, s.raw_id
    ),
    notes AS (
        SELECT
            d.pm_no,
            left(string_agg(d.designation, ' | ' ORDER BY d.ordre, d.designation), 2000) AS note
        FROM (
            SELECT
                s.pm_no,
                btrim(s.designation)                                          AS designation,
                min(COALESCE(clean_data.pe_num(s.compteur_de_gamme), 999999))  AS ordre
            FROM src s
            WHERE btrim(COALESCE(s.designation, '')) <> ''
            GROUP BY s.pm_no, btrim(s.designation)
        ) d
        GROUP BY d.pm_no
    )
    SELECT
        a.pm_no,
        v_pm_revision,
        v_org_contract,
        a.mch_code,
        v_org_contract,
        v_org_code,
        v_connection_type,
        v_connection_type_db,
        NULLIF(left(regexp_replace(COALESCE(a.freq_norm, ''), '\D', '', 'g'), 4), '')  AS "interval",
        CASE right(a.freq_norm, 1)
            WHEN 'S' THEN 'Semaines'
            WHEN 'M' THEN 'Mois'
            WHEN 'A' THEN 'Années'
            WHEN 'H' THEN 'Heures'
            ELSE NULL
        END,
        CASE right(a.freq_norm, 1)
            WHEN 'S' THEN 'WEEKS'
            WHEN 'M' THEN 'MONTHS'
            WHEN 'A' THEN 'YEARS'
            WHEN 'H' THEN 'HOURS'
            ELSE NULL
        END,
        left(r.designation, 2000),
        n.note,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    FROM valid a
    LEFT JOIN rep   r ON r.pm_no = a.pm_no
    LEFT JOIN notes n ON n.pm_no = a.pm_no;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'pm_action: % lignes insérées, % lignes rejetées', v_count, v_reject_count;
END;
$procedure$
;
