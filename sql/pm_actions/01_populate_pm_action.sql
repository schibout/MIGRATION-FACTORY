CREATE OR REPLACE PROCEDURE clean_data.populate_pm_action()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    -- Constantes de configuration IFS (ajuster avant le run réel)
    v_org_contract        VARCHAR := 'SJ';                  -- site (idem module maintenance)
    v_org_code            VARCHAR := 'FR_MAINT';            -- ⚠️ org obligatoire, à confirmer
    v_pm_revision         VARCHAR := '1';
    v_connection_type     VARCHAR := 'Functional Object';
    v_connection_type_db  VARCHAR := 'FUNCTIONAL';          -- ⚠️ valeur _db IFS à vérifier
    v_count INTEGER := 0;
BEGIN
    TRUNCATE TABLE clean_data.pm_action;

    -- Une ligne de raw_data.pe_tools = une OPERATION, pas une pm_action :
    -- un plan d'entretien s'étale sur plusieurs lignes (gammes / groupes de gamme).
    -- On agrège donc par pm_no (voir clean_data.v_pm_source pour la règle de grain) ;
    -- le détail ligne à ligne est conservé dans pm_action_work_step.
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
        -- poste technique et fréquence sont uniques par pm_no par construction
        -- (le grain hybride éclate justement les plans qui n'ont pas cette propriété) ;
        -- min() sert de garde-fou si la source évolue.
        SELECT
            s.pm_no,
            min(s.poste_technique) AS mch_code,
            min(s.freq_norm)       AS freq_norm
        FROM src s
        GROUP BY s.pm_no
    ),
    rep AS (
        -- ligne représentative : première opération de la gamme
        SELECT DISTINCT ON (s.pm_no)
            s.pm_no,
            s.designation
        FROM src s
        ORDER BY s.pm_no, clean_data.pe_num(s.compteur_de_gamme) NULLS LAST, s.raw_id
    ),
    notes AS (
        -- note = désignations distinctes de toutes les opérations du plan
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
        -- interval : chiffres de tête de la fréquence, max 4 caractères
        NULLIF(left(regexp_replace(COALESCE(a.freq_norm, ''), '\D', '', 'g'), 4), '')  AS "interval",
        -- unité (display) selon le suffixe S/M/A/H (H = heures de fonctionnement, 12 lignes)
        CASE right(a.freq_norm, 1)
            WHEN 'S' THEN 'Semaines'
            WHEN 'M' THEN 'Mois'
            WHEN 'A' THEN 'Années'
            WHEN 'H' THEN 'Heures'
            ELSE NULL
        END,
        -- unité (_db)
        CASE right(a.freq_norm, 1)
            WHEN 'S' THEN 'WEEKS'
            WHEN 'M' THEN 'MONTHS'
            WHEN 'A' THEN 'YEARS'
            WHEN 'H' THEN 'HOURS'   -- ⚠️ valeur _db IFS à vérifier
            ELSE NULL
        END,
        left(r.designation, 2000),
        n.note,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    FROM agg a
    LEFT JOIN rep   r ON r.pm_no = a.pm_no
    LEFT JOIN notes n ON n.pm_no = a.pm_no;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'pm_action: % lignes insérées', v_count;
END;
$procedure$
;
