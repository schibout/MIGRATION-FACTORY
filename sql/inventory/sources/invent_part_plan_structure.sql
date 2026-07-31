-- ============================================================================
-- Table invent_part_plan
-- Schema: clean_data
-- Role dans le module INVENTORY: CIBLE (TRUNCATE + INSERT)
-- ============================================================================

CREATE TABLE IF NOT EXISTS clean_data.invent_part_plan (
    contract VARCHAR(5),
    part_no VARCHAR(25),
    carry_rate NUMERIC(20,0),
    last_activity_date TIMESTAMP,
    lot_size NUMERIC(20,0),
    lot_size_auto VARCHAR(4000),
    lot_size_auto_db VARCHAR(1),
    maxweek_supply NUMERIC(20,0),
    max_order_qty NUMERIC(20,0),
    min_order_qty NUMERIC(20,0),
    mul_order_qty NUMERIC(20,0),
    order_point_qty NUMERIC(20,0),
    order_point_qty_auto VARCHAR(4000),
    order_point_qty_auto_db VARCHAR(1),
    order_trip_date TIMESTAMP,
    safety_stock NUMERIC(20,0),
    safety_lead_time NUMERIC(20,0),
    safety_stock_auto VARCHAR(4000),
    safety_stock_auto_db VARCHAR(1),
    service_rate NUMERIC(20,0),
    setup_cost NUMERIC(20,0),
    shrinkage_fac NUMERIC(20,0),
    std_order_size NUMERIC(20,0),
    order_requisition VARCHAR(4000),
    order_requisition_db VARCHAR(1),
    qty_predicted_consumption NUMERIC(20,0),
    planning_method VARCHAR(1),
    proposal_release VARCHAR(4000),
    proposal_release_db VARCHAR(20),
    percent_manufactured NUMERIC(20,0),
    percent_acquired NUMERIC(20,0),
    split_manuf_acquired VARCHAR(4000),
    split_manuf_acquired_db VARCHAR(20),
    acquired_supply_type VARCHAR(4000),
    acquired_supply_type_db VARCHAR(20),
    manuf_supply_type VARCHAR(4000),
    manuf_supply_type_db VARCHAR(20),
    planning_method_auto VARCHAR(4000),
    planning_method_auto_db VARCHAR(20),
    sched_capacity VARCHAR(4000),
    sched_capacity_db VARCHAR(20)
);
