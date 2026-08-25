CREATE OR REPLACE FUNCTION clean_data.alimenter_project_activity_class()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_count_portes INTEGER := 0;
    v_count_cfv    INTEGER := 0;
    v_start_time   TIMESTAMP;
    v_end_time     TIMESTAMP;
    v_duration     INTERVAL;
    rec            RECORD;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;

    RAISE NOTICE 'Début de l''alimentation des activity_class (PROJECT_ACTIVITY_CLASS) - %', v_start_time;

    TRUNCATE TABLE clean_data.project_activity_class RESTART IDENTITY;
    RAISE NOTICE 'Table project_activity_class vidée';

    ---------------------------------------------------------------------------
    -- 1) ACTIVITÉS PORTES -> classes PORTE / STATUT_PORTE / QUAL_PORTE
    ---------------------------------------------------------------------------
    INSERT INTO clean_data.project_activity_class (
        project_id, sub_project_id, activity_no, value, activity_class_id
    )
    SELECT
        src.project_id,
        src.sub_project_id,
        src.activity_no,
        CASE cls.activity_class_id
            -- PORTE : valeur via transco 'PORTE' (P0->0 / P1->1 / ... / P6->6), fallback suffixe
            WHEN 'PORTE' THEN
                COALESCE(
                    public.get_transcodification('PORTE', split_part(src.activity_no, '-', 2), 'ASAP', 'IFS'),
                    split_part(src.activity_no, '-', 2)
                )
            -- STATUT_PORTE : le CLASSEMENT de la porte (v_portes_detail.classement)
            --                transcodé en numérique (vide=0 / Fait=1 / Vigilance=2)
            WHEN 'STATUT_PORTE' THEN
                COALESCE(
                    public.get_transcodification('Classement', COALESCE(TRIM(src.classement), ''), 'ASAP', 'IFS'),
                    '0'
                )
            -- QUAL_PORTE : la NOTE de la porte (v_portes_detail.note) ; 'A définir' si vide
            WHEN 'QUAL_PORTE' THEN
                COALESCE(
                    NULLIF(TRIM(src.note), ''),
                    public.get_transcodification('Note', '', 'ASAP', 'IFS')
                )
        END AS value,
        cls.activity_class_id
    FROM (
        SELECT
            pa.project_id,
            pa.sub_project_id,
            pa.activity_no,
            v.note        AS note,        -- Mark de la porte  -> QUAL_PORTE
            v.classement  AS classement   -- Ranking de la porte -> STATUT_PORTE
        FROM clean_data.project_activity pa
        -- Note + classement LES PLUS RÉCENTS depuis clean_data.v_portes_detail.
        -- Jointure par MILESTONE exact : on recalcule l'activity_no dérivé du libellé
        -- (P3 bis -> P3bis -> 0035-P3) pour que bis/ter aient LEUR note/classement.
        LEFT JOIN clean_data.v_portes_detail v
            ON SUBSTRING(v.project_number, 1, 10) = pa.project_id
           AND COALESCE(
                 public.get_transcodification('Activity',
                     CASE WHEN v.porte_libelle ILIKE '%bis%' THEN v.gate || 'bis'
                          WHEN v.porte_libelle ILIKE '%ter%' THEN v.gate || 'ter'
                          ELSE v.gate END,
                     'ASAP', 'IFS'),
                 CASE WHEN v.porte_libelle ILIKE '%bis%' THEN v.gate || 'bis'
                      WHEN v.porte_libelle ILIKE '%ter%' THEN v.gate || 'ter'
                      ELSE v.gate END
               ) = pa.activity_no
        WHERE pa.activity_no NOT IN ('CFV1', 'CFV2', 'CFV3')   -- portes uniquement
          AND pa.project_id   IS NOT NULL
          AND pa.activity_seq IS NOT NULL
    ) src
    -- Structure des classes :
    --   * porte PRÉSENTE dans le modèle -> ses classes du modèle (PORTE/STATUT/QUAL)
    --   * porte ABSENTE du modèle (ex. bis/ter) -> 3 classes par défaut PORTE/STATUT/QUAL
    JOIN LATERAL (
        SELECT m.activity_class_id, m.sort_order
        FROM clean_data.ifs_model_project m
        WHERE m.node_type        = 'ACTIVITY_CLASS'
          AND m.activity_no       = src.activity_no
          AND m.activity_class_id IN ('PORTE', 'STATUT_PORTE', 'QUAL_PORTE')
        UNION ALL
        SELECT d.activity_class_id, d.sort_order
        FROM (VALUES ('PORTE', 1), ('STATUT_PORTE', 2), ('QUAL_PORTE', 3))
             AS d(activity_class_id, sort_order)
        WHERE NOT EXISTS (
            SELECT 1 FROM clean_data.ifs_model_project m2
            WHERE m2.node_type = 'ACTIVITY_CLASS' AND m2.activity_no = src.activity_no
        )
    ) cls ON TRUE
    ORDER BY src.project_id, src.sub_project_id, src.activity_no, cls.sort_order;

    GET DIAGNOSTICS v_count_portes = ROW_COUNT;
    RAISE NOTICE 'Classes portes insérées : % (= 3 × % portes)', v_count_portes, v_count_portes / 3;

    ---------------------------------------------------------------------------
    -- 2) ACTIVITÉS CFV (CFV1/CFV2/CFV3) -> classe CFV
    --    value = State du DERNIER statut_cfv du projet pour la phase (title),
    --    transcodé 'CFV' ; vide / pas de donnée -> 0.
    ---------------------------------------------------------------------------
    INSERT INTO clean_data.project_activity_class (
        project_id, sub_project_id, activity_no, value, activity_class_id
    )
    SELECT
        pa.project_id,
        pa.sub_project_id,
        -- activity_no rattaché à la PORTE correspondante (P3/P4/P6), pas à CFV1/2/3
        CASE pa.activity_no
            WHEN 'CFV1' THEN COALESCE(public.get_transcodification('Activity', 'P3', 'ASAP', 'IFS'), '003-P3')
            WHEN 'CFV2' THEN COALESCE(public.get_transcodification('Activity', 'P4', 'ASAP', 'IFS'), '004-P4')
            WHEN 'CFV3' THEN COALESCE(public.get_transcodification('Activity', 'P6', 'ASAP', 'IFS'), '006-P6')
        END AS activity_no,
        COALESCE(
            public.get_transcodification('CFV', last_cfv.state, 'ASAP', 'IFS'),
            '0'
        ) AS value,
        -- Nom de la classe = celui du projet modèle : CFV1 (P3) / CFV2 (P4) / CFV3 (P6)
        pa.activity_no AS activity_class_id
    FROM clean_data.project_activity pa
    LEFT JOIN LATERAL (
        SELECT c.raw_data->>'State' AS state
        FROM raw_data.sharepoint_statut_cfv c
        JOIN raw_data.sharepoint_projets sp ON c.site_id = sp.sharepoint_id::TEXT
        WHERE SUBSTRING(COALESCE(sp.project_number, sp.code), 1, 10) = pa.project_id
          AND sp.project_number IS NOT NULL
          AND c.title = CASE pa.activity_no
                            WHEN 'CFV1' THEN 'Conception'
                            WHEN 'CFV2' THEN 'Mise en service'
                            WHEN 'CFV3' THEN 'Achèvement industriel'
                        END
        ORDER BY c.modified DESC NULLS LAST
        LIMIT 1
    ) last_cfv ON TRUE
    WHERE pa.activity_no IN ('CFV1', 'CFV2', 'CFV3')
      AND pa.project_id   IS NOT NULL
      AND pa.activity_seq IS NOT NULL
    ORDER BY pa.project_id, pa.sub_project_id, pa.activity_no;

    GET DIAGNOSTICS v_count_cfv = ROW_COUNT;
    RAISE NOTICE 'Classes CFV insérées : %', v_count_cfv;

    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;

    RAISE NOTICE 'Alimentation project_activity_class terminée';
    RAISE NOTICE 'Total inséré : % (portes : % + CFV : %)',
        v_count_portes + v_count_cfv, v_count_portes, v_count_cfv;
    RAISE NOTICE 'Durée : %', v_duration;

    -- Répartition par activity_class_id
    RAISE NOTICE '';
    RAISE NOTICE '=== RÉPARTITION PAR ACTIVITY_CLASS_ID ===';
    FOR rec IN (
        SELECT activity_class_id, COUNT(*) AS nb
        FROM clean_data.project_activity_class
        GROUP BY activity_class_id
        ORDER BY activity_class_id
    ) LOOP
        RAISE NOTICE '  - % : % lignes', rec.activity_class_id, rec.nb;
    END LOOP;

EXCEPTION
    WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := v_end_time - v_start_time;
        RAISE NOTICE 'ERREUR lors de l''alimentation project_activity_class';
        RAISE NOTICE 'Code : %', SQLSTATE;
        RAISE NOTICE 'Message : %', SQLERRM;
        RAISE NOTICE 'Durée avant erreur : %', v_duration;
        RAISE;
END;
$function$
