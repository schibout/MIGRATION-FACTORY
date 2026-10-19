CREATE OR REPLACE FUNCTION clean_data.alimenter_equipment_serial()
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
    v_count_total INTEGER := 0;
    v_start_time  TIMESTAMP;
    v_contract    VARCHAR := 'SJ';
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    RAISE NOTICE 'Début de l''alimentation EQUIPMENT_SERIAL - %', v_start_time;

    TRUNCATE TABLE clean_data.equipment_serial;

    -- ============================================================
    -- SOURCE UNIQUE : clean_data.maintenance_object (EQUIPMENT actifs), comme
    -- equipment_functional. UNIQUEMENT des equipements : ni poste technique
    -- (-> equipment_functional) ni article / ligne de nomenclature.
    --
    -- Perimetre :
    --   ancres = equipements dont le parent est un POSTE TECHNIQUE
    --          + equipements portant un code article (attributes.matnr)
    --   puis descente recursive dans les equipements enfants.
    -- Exclusion des equipements ARCHIVES (statut SAP actif INAK=I0320 /
    -- suppression=I0076 dans raw_data.jest) : on ne descend pas sous eux.
    --
    -- Ordre : niveau recalcule DANS le perimetre (racine = equipement dont le
    -- parent n'est pas exporte) -> parents toujours avant enfants.
    -- sup_mch_code = code du parent s'il est exporte (poste technique de
    -- equipment_functional ou equipement du perimetre), sinon NULL.
    -- ============================================================
    WITH RECURSIVE archive AS MATERIALIZED (
        SELECT o.id
        FROM clean_data.maintenance_object o
        JOIN raw_data.equi q ON q.equnr = o.sap_key
        WHERE o.object_type = 'EQUIPMENT'
          AND EXISTS (SELECT 1 FROM raw_data.jest j
                      WHERE j.objnr = q.objnr
                        AND j.stat IN ('I0320', 'I0076')
                        AND (j.inact IS NULL OR TRIM(j.inact) <> 'X'))
    ),
    perim AS (
        SELECT e.id, ARRAY[e.id] AS chemin
        FROM clean_data.maintenance_object e
        LEFT JOIN clean_data.maintenance_object p ON p.id = e.parent_id
        WHERE e.object_type = 'EQUIPMENT' AND e.is_active
          AND e.id NOT IN (SELECT id FROM archive)
          AND (p.object_type = 'FUNC_LOC'
               OR NULLIF(LTRIM(TRIM(e.attributes->>'matnr'), '0'), '') IS NOT NULL)
        UNION ALL
        SELECT c.id, a.chemin || c.id
        FROM perim a
        JOIN clean_data.maintenance_object c
          ON c.parent_id = a.id AND c.object_type = 'EQUIPMENT' AND c.is_active
        WHERE c.id <> ALL (a.chemin)
          AND c.id NOT IN (SELECT id FROM archive)
    ),
    ens AS MATERIALIZED (SELECT DISTINCT id FROM perim),
    niv AS (
        SELECT o.id, 1 AS lvl
        FROM ens
        JOIN clean_data.maintenance_object o ON o.id = ens.id
        WHERE o.parent_id IS NULL OR o.parent_id NOT IN (SELECT id FROM ens)
        UNION ALL
        SELECT c.id, n.lvl + 1
        FROM niv n
        JOIN clean_data.maintenance_object c ON c.parent_id = n.id
        JOIN ens ON ens.id = c.id
    ),
    eq AS (
        SELECT o.id,
               CASE WHEN o.attributes->>'ansdt' ~ '^[0-9]{8}$' AND o.attributes->>'ansdt' <> '00000000'
                    THEN to_date(o.attributes->>'ansdt', 'YYYYMMDD') END AS purch_date,
               CASE WHEN o.attributes->>'gwlen' ~ '^[0-9]{8}$' AND o.attributes->>'gwlen' <> '00000000'
                    THEN to_date(o.attributes->>'gwlen', 'YYYYMMDD') END AS warr_exp,
               NULLIF(NULLIF(o.attributes->>'answt', ''), '0.0')::numeric AS purch_price,
               NULLIF(TRIM(o.attributes->>'herst'), '') AS manufacturer_no,
               NULLIF(TRIM(o.attributes->>'sernr'), '') AS serial_no,
               NULLIF(TRIM(o.attributes->>'typbz'), '') AS type,
               NULLIF(LTRIM(TRIM(o.attributes->>'matnr'), '0'), '') AS part_no,
               public.get_vendor_no_ifs(NULLIF(TRIM(o.attributes->>'elief'), '')) AS vendor_no
        FROM ens
        JOIN clean_data.maintenance_object o ON o.id = ens.id
    )
    INSERT INTO clean_data.equipment_serial (
        equipment_object_seq,
        contract, mch_code, mch_name, part_no, serial_no,
        manufacturer_no, vendor_no, type,
        purch_price, purch_date, warr_exp,
        sup_contract, sup_mch_code,
        company, ownership_db, location_id, safe_access_code_db,
        pm_prog_application_status, is_geographic_object, is_category_object,
        operational_status_db
    )
    SELECT
        ROW_NUMBER() OVER (ORDER BY n.lvl, o.sap_key),
        v_contract,
        o.code,                                                   -- mch_code (equnr sans zeros)
        SUBSTRING(COALESCE(o.designation, o.code), 1, 200),       -- mch_name
        SUBSTRING(eq.part_no, 1, 25),
        SUBSTRING(COALESCE(eq.serial_no, o.code), 1, 50),         -- obligatoire IFS : repli sur le code
        SUBSTRING(eq.manufacturer_no, 1, 20),
        eq.vendor_no,
        SUBSTRING(eq.type, 1, 30),
        eq.purch_price, eq.purch_date, eq.warr_exp,
        CASE WHEN sup.code IS NOT NULL THEN v_contract END,
        sup.code,                                                 -- sup_mch_code
        COALESCE(public.get_default_value('equipment_serial', 'company'), 'TRIMET'),
        COALESCE(public.get_default_value('equipment_serial', 'ownership_db'), 'COMPANY OWNED'),
        COALESCE(public.get_default_value('equipment_serial', 'location_id'), '1'),
        COALESCE(public.get_default_value('equipment_serial', 'safe_access_code_db'), 'NOT_REQUIRED'),
        COALESCE(public.get_default_value('equipment_serial', 'pm_prog_application_status'), 'FALSE'),
        'FALSE', 'FALSE',
        'IN_OPERATION'
    FROM niv n
    JOIN clean_data.maintenance_object o ON o.id = n.id
    JOIN eq ON eq.id = o.id
    LEFT JOIN clean_data.maintenance_object p ON p.id = o.parent_id
    LEFT JOIN LATERAL (
        SELECT p.code
        WHERE p.id IN (SELECT id FROM ens)
           OR (p.object_type = 'FUNC_LOC' AND p.is_active)
    ) sup ON TRUE;

    GET DIAGNOSTICS v_count_total = ROW_COUNT;
    RAISE NOTICE 'EQUIPMENT_SERIAL alimente depuis maintenance_object : % equipements (durée %)',
        v_count_total, CURRENT_TIMESTAMP - v_start_time;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERREUR EQUIPMENT_SERIAL — Code: % — Message: %', SQLSTATE, SQLERRM;
        RAISE;
END;
$function$;

COMMENT ON FUNCTION clean_data.alimenter_equipment_serial() IS
'Alimente EQUIPMENT_SERIAL depuis clean_data.maintenance_object (EQUIPMENT) — UNIQUEMENT
les equipements (ni postes techniques ni articles). Perimetre : equipements sous un poste
technique + equipements portant un code article, puis leurs equipements enfants
(recursif), hors equipements archives (jest I0320/I0076). Parents inseres avant enfants.
sup_mch_code = code du parent s''il est exporte, sinon NULL. serial_no = sernr, a defaut
le code de l''equipement (obligatoire IFS).';
