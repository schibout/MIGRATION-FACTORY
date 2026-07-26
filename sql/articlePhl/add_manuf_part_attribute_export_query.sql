-- Ajout de la table MANUF_PART_ATTRIBUTE dans etl_export_queries (export).
-- Table cible des articles fabriques PHL (alimentee par alimenter_manuf_part_attribute_phl()).
-- column_list = colonnes effectivement alimentees par la procedure.
-- Idempotent : ON CONFLICT sur la contrainte UNIQUE (table_schema, table_name).

INSERT INTO etl_export_queries (
    table_name,
    table_schema,
    display_name,
    column_list,
    description,
    category,
    is_active,
    created_by,
    updated_by
)
VALUES (
    'manuf_part_attribute',
    'clean_data',
    'Attributs articles fabriqués',
    'contract, part_no, backflush_part_db, engineering_info_db, structure_effectivity_db, routing_effectivity_db, promise_planned_db, configuration_usage_db, dop_pegged_so_update_flag_db, mrp_control_flag_db, prod_part_as_supply_in_mrp_db, use_theoritical_density_db, over_reporting_db, issue_planned_scrap_db, adjust_on_op_qty_deviation_db, issue_overreported_qty_db, plan_manuf_sup_on_due_date_db, ship_dirty_db, auto_replace_alt_comp_db, consider_lead_time_db, component_scrap, shrinkage_factor',
    'Attributs de fabrication IFS (MANUF_PART_ATTRIBUTE) pour les articles fabriqués (étend inventory_part)',
    'inventory',
    true,
    'phl_migration',
    'phl_migration'
)
ON CONFLICT (table_schema, table_name) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    column_list  = EXCLUDED.column_list,
    description  = EXCLUDED.description,
    category     = EXCLUDED.category,
    is_active    = EXCLUDED.is_active,
    updated_by   = EXCLUDED.updated_by,
    updated_at   = CURRENT_TIMESTAMP;

-- Verification
SELECT id, table_name, table_schema, display_name, category, is_active
FROM etl_export_queries
WHERE table_schema = 'clean_data' AND table_name = 'manuf_part_attribute';
