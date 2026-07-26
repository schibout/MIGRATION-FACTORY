-- Structure de la table part_catalog selon les règles de gestion IFS
-- Basée sur les spécifications fournies avec tous les champs obligatoires et énumérations

CREATE TABLE clean_data.part_catalog (
    -- Champs obligatoires (MANDATORY = TRUE)
    part_no VARCHAR(25) NOT NULL,
    description VARCHAR(200) NOT NULL,
    std_name_id NUMERIC(10) NOT NULL,
    unit_code VARCHAR(30) NOT NULL,
    lot_tracking_code_db VARCHAR(30) NOT NULL,
    serial_rule_db VARCHAR(20) NOT NULL,
    serial_tracking_code_db VARCHAR(30) NOT NULL,
    eng_serial_tracking_code_db VARCHAR(20) NOT NULL,
    configurable_db VARCHAR(20) NOT NULL,
    condition_code_usage_db VARCHAR(20) NOT NULL,
    sub_lot_rule_db VARCHAR(20) NOT NULL,
    lot_quantity_rule_db VARCHAR(20) NOT NULL,
    position_part_db VARCHAR(20) NOT NULL,
    catch_unit_enabled_db VARCHAR(5) NOT NULL,
    multilevel_tracking_db VARCHAR(20) NOT NULL,
    component_lot_rule_db VARCHAR(20) NOT NULL,
    stop_arrival_issued_serial_db VARCHAR(5) NOT NULL,
    allow_as_not_consumed_db VARCHAR(5) NOT NULL,
    receipt_issue_serial_track_db VARCHAR(20) NOT NULL,
    stop_new_serial_in_rma_db VARCHAR(20) NOT NULL,
    
    -- Champs optionnels (MANDATORY = FALSE)
    language_description VARCHAR(4000),
    info_text VARCHAR(2000),
    
    -- Champs d'énumération (valeurs client)
    lot_tracking_code VARCHAR(4000),
    serial_rule VARCHAR(4000),
    serial_tracking_code VARCHAR(4000),
    eng_serial_tracking_code VARCHAR(4000),
    configurable VARCHAR(4000),
    condition_code_usage VARCHAR(4000),
    sub_lot_rule VARCHAR(4000),
    lot_quantity_rule VARCHAR(4000),
    position_part VARCHAR(4000),
    catch_unit_enabled VARCHAR(4000),
    multilevel_tracking VARCHAR(4000),
    component_lot_rule VARCHAR(4000),
    stop_arrival_issued_serial VARCHAR(4000),
    allow_as_not_consumed VARCHAR(4000),
    receipt_issue_serial_track VARCHAR(4000),
    stop_new_serial_in_rma VARCHAR(4000),
    product_type_classif VARCHAR(4000),
    
    -- Champs optionnels divers
    part_main_group VARCHAR(20),
    cust_warranty_id NUMERIC(20),
    sup_warranty_id NUMERIC(20),
    input_unit_meas_group_id VARCHAR(30),
    weight_net NUMERIC(20),
    uom_for_weight_net VARCHAR(30),
    volume_net NUMERIC(20),
    uom_for_volume_net VARCHAR(30),
    freight_factor NUMERIC(20),
    technical_drawing_no VARCHAR(25),
    product_type_classif_db VARCHAR(35),
    cest_code VARCHAR(7),
    fci_code VARCHAR(36),
    
    -- Contraintes de clé primaire
    PRIMARY KEY (part_no)
);

-- Index pour optimiser les performances
CREATE INDEX idx_part_catalog_std_name_id ON clean_data.part_catalog (std_name_id);
CREATE INDEX idx_part_catalog_unit_code ON clean_data.part_catalog (unit_code);
CREATE INDEX idx_part_catalog_part_main_group ON clean_data.part_catalog (part_main_group);

-- Contraintes de validation des énumérations
-- Lot/Batch Tracking
ALTER TABLE clean_data.part_catalog 
ADD CONSTRAINT chk_lot_tracking_code_db 
CHECK (lot_tracking_code_db IN ('LOT TRACKING', 'NOT LOT TRACKING', 'ORDER BASED'));

-- Serial Rule
ALTER TABLE clean_data.part_catalog 
ADD CONSTRAINT chk_serial_rule_db 
CHECK (serial_rule_db IN ('MANUAL', 'AUTOMATIC'));

-- Serial Tracking
ALTER TABLE clean_data.part_catalog 
ADD CONSTRAINT chk_serial_tracking_code_db 
CHECK (serial_tracking_code_db IN ('SERIAL TRACKING', 'NOT SERIAL TRACKING'));

-- Eng Serial Tracking
ALTER TABLE clean_data.part_catalog 
ADD CONSTRAINT chk_eng_serial_tracking_code_db 
CHECK (eng_serial_tracking_code_db IN ('SERIAL TRACKING', 'NOT SERIAL TRACKING'));

-- Configurable
ALTER TABLE clean_data.part_catalog 
ADD CONSTRAINT chk_configurable_db 
CHECK (configurable_db IN ('CONFIGURED', 'NOT CONFIGURED'));

-- Condition Code Usage
ALTER TABLE clean_data.part_catalog 
ADD CONSTRAINT chk_condition_code_usage_db 
CHECK (condition_code_usage_db IN ('ALLOW_COND_CODE', 'NOT_ALLOW_COND_CODE'));

-- Sub Lot Rule
ALTER TABLE clean_data.part_catalog 
ADD CONSTRAINT chk_sub_lot_rule_db 
CHECK (sub_lot_rule_db IN ('YES_SUBLOTS', 'NO_SUBLOTS'));

-- Lot Quantity Rule
ALTER TABLE clean_data.part_catalog 
ADD CONSTRAINT chk_lot_quantity_rule_db 
CHECK (lot_quantity_rule_db IN ('ONE_LOT', 'MULTI_LOTS'));

-- Position Part
ALTER TABLE clean_data.part_catalog 
ADD CONSTRAINT chk_position_part_db 
CHECK (position_part_db IN ('POSITION PART', 'NOT POSITION PART'));

-- Catch Unit Enabled
ALTER TABLE clean_data.part_catalog 
ADD CONSTRAINT chk_catch_unit_enabled_db 
CHECK (catch_unit_enabled_db IN ('FALSE', 'TRUE'));

-- Multilevel Tracking
ALTER TABLE clean_data.part_catalog 
ADD CONSTRAINT chk_multilevel_tracking_db 
CHECK (multilevel_tracking_db IN ('TRACKING_ON', 'TRACKING_OFF'));

-- Component Lot Rule
ALTER TABLE clean_data.part_catalog 
ADD CONSTRAINT chk_component_lot_rule_db 
CHECK (component_lot_rule_db IN ('MANY_LOTS_ALLOWED', 'ONE_LOT_ALLOWED'));

-- Stop Arrival Issued Serial
ALTER TABLE clean_data.part_catalog 
ADD CONSTRAINT chk_stop_arrival_issued_serial_db 
CHECK (stop_arrival_issued_serial_db IN ('FALSE', 'TRUE'));

-- Allow As Not Consumed
ALTER TABLE clean_data.part_catalog 
ADD CONSTRAINT chk_allow_as_not_consumed_db 
CHECK (allow_as_not_consumed_db IN ('FALSE', 'TRUE'));

-- Receipt Issue Serial Track
ALTER TABLE clean_data.part_catalog 
ADD CONSTRAINT chk_receipt_issue_serial_track_db 
CHECK (receipt_issue_serial_track_db IN ('FALSE', 'TRUE'));

-- Stop New Serial In RMA
ALTER TABLE clean_data.part_catalog 
ADD CONSTRAINT chk_stop_new_serial_in_rma_db 
CHECK (stop_new_serial_in_rma_db IN ('FALSE', 'TRUE'));

-- Product Type Classification (optionnel mais avec contrainte si présent)
ALTER TABLE clean_data.part_catalog 
ADD CONSTRAINT chk_product_type_classif_db 
CHECK (product_type_classif_db IS NULL OR product_type_classif_db IN (
    'FOR PRODUCT', 'FOR MERCHANDISE', 'NO RESTRICTION', 'SERVICE', 
    'FEEDSTOCK', 'FIXED ASSETS', 'PACKAGING', 'PRODUCT IN PROCESS', 'SUBPRODUCT'
));

-- Commentaires sur la table et les colonnes
COMMENT ON TABLE clean_data.part_catalog IS 'Catalogue des pièces IFS conforme aux règles de gestion. Contient tous les champs obligatoires et optionnels avec leurs contraintes d''énumération.';

COMMENT ON COLUMN clean_data.part_catalog.part_no IS 'Numéro de pièce - Identifiant unique (VARCHAR2 25, OBLIGATOIRE)';
COMMENT ON COLUMN clean_data.part_catalog.description IS 'Description de la pièce (VARCHAR2 200, OBLIGATOIRE)';
COMMENT ON COLUMN clean_data.part_catalog.std_name_id IS 'ID standard (NUMBER 10, OBLIGATOIRE)';
COMMENT ON COLUMN clean_data.part_catalog.unit_code IS 'Code unité de mesure (VARCHAR2 30, OBLIGATOIRE)';
COMMENT ON COLUMN clean_data.part_catalog.lot_tracking_code_db IS 'Gestion des lots - Valeur DB (LOT TRACKING, NOT LOT TRACKING, ORDER BASED)';
COMMENT ON COLUMN clean_data.part_catalog.serial_rule_db IS 'Règle de numérotation série - Valeur DB (MANUAL, AUTOMATIC)';
COMMENT ON COLUMN clean_data.part_catalog.serial_tracking_code_db IS 'Suivi des numéros de série - Valeur DB (SERIAL TRACKING, NOT SERIAL TRACKING)';
COMMENT ON COLUMN clean_data.part_catalog.eng_serial_tracking_code_db IS 'Suivi série engineering - Valeur DB (SERIAL TRACKING, NOT SERIAL TRACKING)';
COMMENT ON COLUMN clean_data.part_catalog.configurable_db IS 'Pièce configurable - Valeur DB (CONFIGURED, NOT CONFIGURED)';
COMMENT ON COLUMN clean_data.part_catalog.condition_code_usage_db IS 'Usage code condition - Valeur DB (ALLOW_COND_CODE, NOT_ALLOW_COND_CODE)';
COMMENT ON COLUMN clean_data.part_catalog.sub_lot_rule_db IS 'Règle sous-lot - Valeur DB (YES_SUBLOTS, NO_SUBLOTS)';
COMMENT ON COLUMN clean_data.part_catalog.lot_quantity_rule_db IS 'Règle quantité lot - Valeur DB (ONE_LOT, MULTI_LOTS)';
COMMENT ON COLUMN clean_data.part_catalog.position_part_db IS 'Pièce position - Valeur DB (POSITION PART, NOT POSITION PART)';
COMMENT ON COLUMN clean_data.part_catalog.catch_unit_enabled_db IS 'Unité catch activée - Valeur DB (FALSE, TRUE)';
COMMENT ON COLUMN clean_data.part_catalog.multilevel_tracking_db IS 'Suivi multi-niveau - Valeur DB (TRACKING_ON, TRACKING_OFF)';
COMMENT ON COLUMN clean_data.part_catalog.component_lot_rule_db IS 'Règle lot composant - Valeur DB (MANY_LOTS_ALLOWED, ONE_LOT_ALLOWED)';
COMMENT ON COLUMN clean_data.part_catalog.stop_arrival_issued_serial_db IS 'Arrêt série arrivée - Valeur DB (FALSE, TRUE)';
COMMENT ON COLUMN clean_data.part_catalog.allow_as_not_consumed_db IS 'Autoriser non consommé - Valeur DB (FALSE, TRUE)';
COMMENT ON COLUMN clean_data.part_catalog.receipt_issue_serial_track_db IS 'Suivi série réception/émission - Valeur DB (FALSE, TRUE)';
COMMENT ON COLUMN clean_data.part_catalog.stop_new_serial_in_rma_db IS 'Arrêt nouvelle série RMA - Valeur DB (FALSE, TRUE)';
