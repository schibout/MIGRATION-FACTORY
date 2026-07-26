CREATE OR REPLACE FUNCTION clean_data.alimenter_equipment_functional()
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
    v_count_total INTEGER := 0;
    v_start_time  TIMESTAMP;
    v_end_time    TIMESTAMP;
    v_duration    INTERVAL;
    v_contract    VARCHAR := 'SJ';
BEGIN
    v_start_time := CURRENT_TIMESTAMP;

    RAISE NOTICE 'Début de l''alimentation EQUIPMENT_FUNCTIONAL - %', v_start_time;

    -- Tracabilite : niveau SAP d'origine (colonne interne, non IFS). Idempotent.
    ALTER TABLE clean_data.equipment_functional
        ADD COLUMN IF NOT EXISTS sap_object_level varchar;

    TRUNCATE TABLE clean_data.equipment_functional;
    RAISE NOTICE 'Table equipment_functional vidée';

    -- ============================================================
    -- SOURCE UNIQUE : clean_data.maintenance_object (FUNC_LOC)
    -- La hierarchie, le code (mch_code=code), la designation
    -- (mch_name=designation) et le parent (sup_mch_code) proviennent
    -- desormais de la table editable IH02 -> les modifications faites
    -- dans l'ecran se propagent a cet export IFS.
    --
    -- Filtre : is_active (soft delete UI) + exclusion defensive des objets
    -- ARCHIVES (statut SAP courant INAK=I0320 / suppression=I0076, via
    -- raw_data.jest — table de STATUT, utilisee en referentiel lecture seule).
    -- NB : aujourd'hui 0 poste technique n'est archive (les objets archives
    -- sont des equipements) -> le filtre jest est defensif/futur.
    --
    -- obj_level (IFS) = public.get_transcodification('ObjectLevel', profondeur 1..8).
    -- Insertion en une passe : ORDER BY niveau garantit parents avant enfants ;
    -- equipment_object_seq est une simple sequence interne (le rattachement aval
    -- se fait par mch_code, pas par le seq).
    -- ============================================================
    WITH RECURSIVE tree AS (
        SELECT o.id, o.parent_id, 0 AS lvl
        FROM clean_data.maintenance_object o
        WHERE o.object_type = 'FUNC_LOC' AND o.parent_id IS NULL AND o.is_active
        UNION ALL
        SELECT c.id, c.parent_id, t.lvl + 1
        FROM clean_data.maintenance_object c
        JOIN tree t ON c.parent_id = t.id
        WHERE c.object_type = 'FUNC_LOC' AND c.is_active
    )
    INSERT INTO clean_data.equipment_functional (
        equipment_object_seq,
        contract, mch_code, mch_name, obj_level, sap_object_level,
        sup_contract, sup_mch_code,
        group_id, mch_type,
        category_id, item_class_id, cluster_id,
        cost_center,
        is_category_object, is_geographic_object,
        note, operational_status_db
    )
    SELECT
        ROW_NUMBER() OVER (ORDER BY t.lvl, o.code),
        v_contract,
        o.code,                                                   -- mch_code
        SUBSTRING(COALESCE(o.designation, o.code), 1, 200),       -- mch_name
        public.get_transcodification('ObjectLevel', (LEAST(t.lvl + 1, 8))::varchar),
        (t.lvl + 1)::varchar,                                     -- sap_object_level
        CASE WHEN o.parent_id IS NOT NULL THEN v_contract ELSE NULL END,
        p.code,                                                   -- sup_mch_code (code du parent)
        NULL,
        NULL,                                                     -- mch_type : non alimente (volontaire)
        NULL, NULL, NULL,
        NULL,                                                     -- cost_center : non alimente (volontaire)
        'FALSE', 'FALSE',
        NULL,
        'IN_OPERATION'
    FROM tree t
    JOIN clean_data.maintenance_object o ON o.id = t.id
    LEFT JOIN clean_data.maintenance_object p ON p.id = o.parent_id
    WHERE NOT EXISTS (
        SELECT 1
        FROM raw_data.iflot il
        JOIN raw_data.jest j ON j.objnr = il.objnr
        WHERE il.tplnr = o.sap_key
          AND j.stat IN ('I0320', 'I0076')
          AND (j.inact IS NULL OR TRIM(j.inact) <> 'X')
    );

    GET DIAGNOSTICS v_count_total = ROW_COUNT;
    RAISE NOTICE 'EQUIPMENT_FUNCTIONAL alimente depuis maintenance_object : % postes techniques', v_count_total;

    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;

    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Alimentation EQUIPMENT_FUNCTIONAL terminée';
    RAISE NOTICE 'Total enregistrements: %  |  Durée: %', v_count_total, v_duration;
    RAISE NOTICE '====================================================';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERREUR EQUIPMENT_FUNCTIONAL — Code: % — Message: %', SQLSTATE, SQLERRM;
        RAISE;
END;
$function$;

COMMENT ON FUNCTION clean_data.alimenter_equipment_functional() IS
'Alimente EQUIPMENT_FUNCTIONAL depuis clean_data.maintenance_object (FUNC_LOC) —
SOURCE UNIQUE editable de l''ecran IH02. UNIQUEMENT les POSTES TECHNIQUES.

Mapping :
  - mch_code      = maintenance_object.code       (forme lisible strno)
  - mch_name      = maintenance_object.designation (repercute les modifs ecran)
  - sup_mch_code  = code du parent (parent_id)
  - obj_level     = get_transcodification(ObjectLevel, profondeur 1..8)
  - sap_object_level = profondeur SAP (1 = racine)

Hierarchie via parent_id (CTE recursif). Filtre is_active (soft delete UI) +
exclusion defensive des objets archives (raw_data.jest, statut referentiel ;
0 FL concerne aujourd''hui). cost_center / group_id / category_id / mch_type
non alimentes (NULL, volontaire).';
