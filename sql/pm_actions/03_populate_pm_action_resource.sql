CREATE OR REPLACE PROCEDURE clean_data.populate_pm_action_resource()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_pm_revision     VARCHAR := public.get_default_value('clean_data.pm_action_resource', 'pm_revision');
    v_demand_type     VARCHAR := public.get_default_value('clean_data.pm_action_resource', 'demand_type');
    v_demand_type_db  VARCHAR := public.get_default_value('clean_data.pm_action_resource', 'demand_type_db');
    v_count INTEGER := 0;
BEGIN
    TRUNCATE TABLE clean_data.pm_action_resource;
    INSERT INTO clean_data.pm_action_resource (
        pm_no,
        pm_revision,
        pm_action_resource_seq,
        demand_type,
        demand_type_db,
        resource_group,
        planned_hours,
        planned_quantity
    )
    SELECT
        s.pm_no,
        v_pm_revision,
        row_number() OVER (ORDER BY s.pm_no, s.raw_id)  AS pm_action_resource_seq,
        v_demand_type,
        v_demand_type_db,
        -- Groupe ressources : deduit du Type PE Tools (MEC -> MM, ELEC -> ME, migration 087)
        t.groupe_ressources                             AS resource_group,
        clean_data.pe_num(s.charge)                     AS planned_hours,     -- colonne "Charge"
        clean_data.pe_num(s.nb_intervenants)            AS planned_quantity   -- colonne "Nombre intervenants"
    FROM clean_data.v_pm_source s
    JOIN raw_data.pe_tools t ON t.raw_id = s.raw_id
    JOIN clean_data.pm_action p
      ON p.pm_no = s.pm_no
     AND p.pm_revision = v_pm_revision;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'pm_action_resource: % lignes insérées', v_count;
END;
$procedure$
;
