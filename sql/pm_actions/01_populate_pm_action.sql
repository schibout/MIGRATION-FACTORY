CREATE OR REPLACE PROCEDURE clean_data.populate_pm_action()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    -- Constantes de configuration IFS : paramétrables depuis l'écran
    -- Configuration > Valeurs par défaut (public.get_default_value) ; le 3e argument
    -- reste l'ancienne valeur codée en dur, donc comportement inchangé sans paramétrage.
    v_org_contract        VARCHAR := public.get_default_value('clean_data.pm_action', 'org_contract');
    v_org_code            VARCHAR := public.get_default_value('clean_data.pm_action', 'org_code');
    v_pm_revision         VARCHAR := public.get_default_value('clean_data.pm_action', 'pm_revision');
    -- connection_type_db doit appartenir au domaine IFS (EQUIPMENT, VIM, CATEGORY,
    -- PLD, CMPUNT, LINAST, TOOLEQ, PRJWORKPACKAGE, MODEL) ; le libelle client en est
    -- derive et la procedure s'arrete sur une valeur hors domaine (migration 080).
    v_connection_type_db  VARCHAR := public.get_default_value('clean_data.pm_action', 'connection_type_db');
    v_connection_type     VARCHAR := clean_data.pm_connection_type_client(v_connection_type_db);
    v_count INTEGER := 0;
    v_reject_count INTEGER := 0;
    v_multi_org INTEGER := 0;
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
            min(s.freq_norm)       AS freq_norm,
            -- Organisation IFS du fichier importe (migration 077). min() ignore
            -- les NULL (lignes historiques) ; si un pm_no venait de plusieurs
            -- fichiers, la plus petite valeur est retenue et un WARNING est
            -- emis ci-dessous.
            min(s.organisation_maintenance)           AS org_code_fichier
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
        COALESCE(a.org_code_fichier, v_org_code),
        v_connection_type,
        v_connection_type_db,
        -- INTERVAL est obligatoire cote IFS : '0' quand la frequence est vide
        COALESCE(NULLIF(left(regexp_replace(COALESCE(a.freq_norm, ''), '\D', '', 'g'), 4), ''), '0')  AS "interval",
        -- PM_INTERVAL_UNIT (libelle) : volontairement vide, seul le code _db est charge
        NULL::varchar                                                                                   AS pm_interval_unit,
        -- PM_INTERVAL_UNIT_DB : derniere lettre de la frequence PE Tools (S/M/A/H)
        -- via la transcodification PM_INTERVAL_UNIT (PETOOLS -> IFS, migration 080),
        -- sans repli : lettre inconnue ou frequence vide -> NULL
        public.get_transcodification('PM_INTERVAL_UNIT', right(a.freq_norm, 1), 'PETOOLS', 'IFS')     AS pm_interval_unit_db,
        left(r.designation, 2000),
        n.note,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    FROM valid a
    LEFT JOIN rep   r ON r.pm_no = a.pm_no
    LEFT JOIN notes n ON n.pm_no = a.pm_no;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    -- Garde : un pm_no alimente par plusieurs fichiers PE Tools (donc plusieurs
    -- organisations) est ambigu ; min() en a retenu une, on le signale.
    SELECT count(*) INTO v_multi_org
    FROM (
        SELECT pm_no
        FROM clean_data.v_pm_source
        GROUP BY pm_no
        HAVING count(DISTINCT organisation_maintenance) > 1
    ) x;
    IF v_multi_org > 0 THEN
        RAISE WARNING 'pm_action: % pm_no avec plusieurs organisations (min() retenue)', v_multi_org;
    END IF;
    RAISE NOTICE 'pm_action: % lignes insérées, % lignes rejetées', v_count, v_reject_count;
END;
$procedure$
;
