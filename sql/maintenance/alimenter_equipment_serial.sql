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
    -- Perimetre (regle du 2026-11-17) : les equipements de la structure, dont
    -- la chaine des parents remonte a un poste technique exporte dans
    -- equipment_functional (a alimenter avant), ou SANS PARENT dans IH02
    -- (objet serie racine, sup_mch_code NULL), QUI ONT UN ARTICLE.
    -- Article = meme regle que l'ecran Maintenance > Equipements
    -- (api/equipment_browser.py, article_lie) : n° article saisi dans IH02
    -- (attributes.matnr), sinon equi.matnr, sinon type de construction de la
    -- periode EQUZ courante (equz.submt).
    -- Hierarchie reproduite telle quelle : un equipement SANS article coupe la
    -- branche -> ni lui ni ses descendants ne sont envoyes (regle du 2026-11-17).
    -- Exclusion des equipements ARCHIVES (statut SAP actif INAK=I0320 /
    -- suppression=I0076 dans raw_data.jest) : on ne descend pas sous eux.
    --
    -- sup_mch_code = parent direct (poste technique ou equipement exporte).
    -- Ordre : profondeur reelle -> parents toujours avant enfants.
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
    art AS MATERIALIZED (
        SELECT o.id,
               COALESCE(NULLIF(LTRIM(TRIM(COALESCE(o.attributes->>'matnr', q.matnr)), '0'), ''),
                        z.construction) AS part_no
        FROM clean_data.maintenance_object o
        LEFT JOIN raw_data.equi q ON q.mandt = '700' AND q.equnr = o.sap_key
        LEFT JOIN (SELECT DISTINCT ON (equnr) equnr,
                          NULLIF(LTRIM(TRIM(submt), '0'), '') AS construction
                   FROM raw_data.equz WHERE mandt = '700'
                   ORDER BY equnr, datbi DESC) z ON z.equnr = o.sap_key
        WHERE o.object_type = 'EQUIPMENT' AND o.is_active
    ),
    structure AS (
        SELECT e.id, e.code, ar.part_no,
               p.code AS sup_code, 1 AS lvl, ARRAY[e.id] AS chemin
        FROM clean_data.maintenance_object e
        LEFT JOIN clean_data.maintenance_object p ON p.id = e.parent_id
        JOIN art ar ON ar.id = e.id
        WHERE e.object_type = 'EQUIPMENT' AND e.is_active
          AND ar.part_no IS NOT NULL
          AND e.id NOT IN (SELECT id FROM archive)
          AND (
                -- sous un poste technique exporte
                (p.object_type = 'FUNC_LOC'
                 AND EXISTS (SELECT 1 FROM clean_data.equipment_functional ef WHERE ef.mch_code = p.code))
                -- ou sans parent dans IH02 : objet serie racine (sup_mch_code NULL)
                OR e.parent_id IS NULL
              )
        UNION ALL
        SELECT c.id, c.code, ar.part_no, a.code,
               a.lvl + 1, a.chemin || c.id
        FROM structure a
        JOIN clean_data.maintenance_object c
          ON c.parent_id = a.id AND c.object_type = 'EQUIPMENT' AND c.is_active
        JOIN art ar ON ar.id = c.id
        WHERE c.id <> ALL (a.chemin)
          AND ar.part_no IS NOT NULL            -- sans article : branche coupee
          AND c.id NOT IN (SELECT id FROM archive)
    ),
    eq AS (
        SELECT s.id, s.part_no, s.sup_code, s.lvl,
               CASE WHEN o.attributes->>'ansdt' ~ '^[0-9]{8}$' AND o.attributes->>'ansdt' <> '00000000'
                    THEN to_date(o.attributes->>'ansdt', 'YYYYMMDD') END AS purch_date,
               CASE WHEN o.attributes->>'gwlen' ~ '^[0-9]{8}$' AND o.attributes->>'gwlen' <> '00000000'
                    THEN to_date(o.attributes->>'gwlen', 'YYYYMMDD') END AS warr_exp,
               NULLIF(NULLIF(o.attributes->>'answt', ''), '0.0')::numeric AS purch_price,
               NULLIF(TRIM(o.attributes->>'sernr'), '') AS serial_no,
               NULLIF(TRIM(o.attributes->>'typbz'), '') AS type,
               public.get_vendor_no_ifs(NULLIF(TRIM(o.attributes->>'elief'), '')) AS vendor_no
        FROM structure s
        JOIN clean_data.maintenance_object o ON o.id = s.id
    )
    INSERT INTO clean_data.equipment_serial (
        equipment_object_seq,
        contract, mch_code, mch_name, part_no, serial_no,
        vendor_no, type,                                      -- manufacturer_no non alimente (regle 2026-11-18)
        purch_price, purch_date, warr_exp,
        sup_contract, sup_mch_code,
        company, ownership_db, location_id, safe_access_code_db,
        pm_prog_application_status, is_geographic_object, is_category_object,
        operational_status_db,
        criticality, area_id, c_org_code, mch_loc
    )
    SELECT
        ROW_NUMBER() OVER (ORDER BY eq.lvl, o.sap_key),
        v_contract,
        o.code,                                                   -- mch_code (equnr sans zeros)
        SUBSTRING(COALESCE(o.designation, o.code), 1, 200),       -- mch_name
        SUBSTRING(eq.part_no, 1, 25),
        SUBSTRING(COALESCE(eq.serial_no, o.code), 1, 50),         -- obligatoire IFS : repli sur le code
        eq.vendor_no,
        SUBSTRING(eq.type, 1, 30),
        eq.purch_price, eq.purch_date, eq.warr_exp,
        v_contract,
        eq.sup_code,                                              -- sup_mch_code
        COALESCE(public.get_default_value('equipment_serial', 'company'), 'TRIMET'),
        COALESCE(public.get_default_value('equipment_serial', 'ownership_db'), 'COMPANY OWNED'),
        COALESCE(public.get_default_value('equipment_serial', 'location_id'), '1'),
        COALESCE(public.get_default_value('equipment_serial', 'safe_access_code_db'), 'NOT_REQUIRED'),
        COALESCE(public.get_default_value('equipment_serial', 'pm_prog_application_status'), 'FALSE'),
        'FALSE', 'FALSE',
        'IN_OPERATION',
        SUBSTRING(o.risk_factor, 1, 10),                          -- criticality = facteur de risque
        SUBSTRING(o.zone, 1, 100),                                -- area_id = zone
        -- c_org_code = poste responsable (equz.gewrk, 7.MATC) transcode en SJ-MATC.
        SUBSTRING(public.get_transcodification('Organization',
            NULLIF(TRIM(split_part(o.resp_work_center, ' - ', 1)), '')), 1, 8),
        sal.msgrp                                                 -- mch_loc = salle (ILOA-MSGRP)
    FROM eq
    JOIN clean_data.maintenance_object o ON o.id = eq.id
    -- Salle de l'equipement : localisation (ILOA) de la periode EQUZ courante.
    LEFT JOIN (
        SELECT z.equnr, SUBSTRING(TRIM(l.msgrp), 1, 60) AS msgrp
        FROM (SELECT DISTINCT ON (equnr) mandt, equnr, iloan
              FROM raw_data.equz ORDER BY equnr, datbi DESC) z
        JOIN raw_data.iloa l ON l.mandt = z.mandt AND l.iloan = z.iloan
        WHERE TRIM(l.msgrp) <> ''
    ) sal ON sal.equnr = o.sap_key;

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
les equipements (ni postes techniques ni articles). Perimetre : les equipements avec article sous
la structure (chaine de parents jusqu''a un poste technique de equipment_functional, a
alimenter avant) ou sans parent dans IH02, QUI ONT UN ARTICLE (saisie IH02, sinon equi.matnr, sinon equz.submt,
comme l''ecran Maintenance > Equipements), hors equipements archives (jest I0320/I0076)
et leurs descendants. Un equipement sans article
coupe la branche (ni lui ni ses descendants). Parents inseres avant enfants.
sup_mch_code = parent direct. serial_no = sernr, a defaut le code de
l''equipement (obligatoire IFS).';
