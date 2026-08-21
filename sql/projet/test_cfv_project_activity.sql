-- ============================================================================
-- FONCTION DE TEST ISOLÉE — ne modifie AUCUNE table.
-- Objectif : générer les activités CFV pour project_activity SANS valeur fixe,
-- en reproduisant la logique de l'onglet "Commissions Feu Vert" du détail
-- projet (backend/api/data.py, route /projets/<site_id>/commissions-cfv) :
--   - source  : raw_data.sharepoint_statut_cfv
--   - grain   : dernier enregistrement par (projet, title) via modified DESC
--   - phases  : les 'title' réellement présents dans les données (pas de liste
--               en dur — aujourd'hui : Conception / Mise en service /
--               Achèvement industriel)
--   - état    : raw_data->>'State'  -> transco catégorie 'CFV' (0..4)
--   - date    : raw_data->>'Date1' (seule date métier du JSON ; l'endpoint de
--               l'onglet lit 'Forecast'/'Baseline' qui N'EXISTENT PAS dans le
--               JSON -> toujours NULL, la carte n'affiche jamais "Prévue :")
--   - libellé : transco catégorie 'ACTIVITY_TASK' (title -> 'CFV - ...'),
--               lookup insensible à la casse (l'entrée transco dit
--               'Mise en Service' alors que la donnée dit 'Mise en service')
--   - activity_no : transco catégorie 'Activity' sur le title si elle existe
--               (aucune entrée aujourd'hui -> fallback libellé transcodé) ;
--               à piloter en ajoutant les lignes dans la transco, pas en dur
--
-- Test :   SELECT * FROM clean_data.test_cfv_project_activity() LIMIT 50;
--          SELECT cfv_state_source, cfv_status_transco, COUNT(*)
--          FROM clean_data.test_cfv_project_activity() GROUP BY 1,2 ORDER BY 2;
-- Nettoyage : DROP FUNCTION clean_data.test_cfv_project_activity();
-- ============================================================================

CREATE OR REPLACE FUNCTION clean_data.test_cfv_project_activity()
RETURNS TABLE (
    project_id            VARCHAR,
    phase                 TEXT,      -- title brut SharePoint (= phase de l'onglet)
    activity_no           VARCHAR,
    description           VARCHAR,
    activity_responsible  VARCHAR,
    cfv_date              DATE,      -- Date1 du dernier statut (date de la commission)
    cfv_state_source      TEXT,      -- état brut SharePoint (State)
    cfv_status_transco    VARCHAR,   -- état transcodé via transco 'CFV' (0..4)
    cfv_modified          TIMESTAMP  -- date du dernier statut retenu
)
LANGUAGE sql
STABLE
AS $function$
    SELECT
        pb.project_id,
        cfv.title AS phase,
        COALESCE(
            public.get_transcodification('Activity', cfv.title, 'ASAP', 'IFS'),
            tk.target_value,
            cfv.title
        )::VARCHAR AS activity_no,
        COALESCE(tk.target_value, 'CFV - ' || cfv.title)::VARCHAR AS description,
        COALESCE(pm_user.person_id, pb.manager)::VARCHAR AS activity_responsible,
        NULLIF(TRIM(cfv.date1), '')::TIMESTAMPTZ::DATE AS cfv_date,
        cfv.state AS cfv_state_source,
        public.get_transcodification('CFV', COALESCE(TRIM(cfv.state), ''), 'ASAP', 'IFS') AS cfv_status_transco,
        cfv.modified
    FROM clean_data.project_base pb
    JOIN raw_data.sharepoint_projets sp
        ON pb.project_id = SUBSTRING(COALESCE(sp.project_number, sp.code), 1, 10)
    LEFT JOIN raw_data.sharepoint_users pm_user
        ON pm_user.sharepoint_user_id = sp.pm_id
    -- Même grain que l'onglet Commissions Feu Vert : dernier statut par phase,
    -- phases = les titles présents dans les données (aucune liste en dur)
    JOIN LATERAL (
        SELECT DISTINCT ON (c.title)
            c.title,
            c.raw_data->>'State' AS state,
            c.raw_data->>'Date1' AS date1,
            c.modified
        FROM raw_data.sharepoint_statut_cfv c
        WHERE c.site_id = sp.sharepoint_id::TEXT
        ORDER BY c.title, c.modified DESC NULLS LAST
    ) cfv ON TRUE
    -- Libellé via transco 'ACTIVITY_TASK', insensible à la casse
    -- (entrée 'Mise en Service' vs donnée 'Mise en service')
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
    ORDER BY pb.project_id, cfv.title;
$function$;
