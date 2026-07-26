-- Migration: Création du système d'import de fichiers
-- Date: 2025-01-26
-- Description: Tables pour gérer l'import de fichiers CSV/Excel avec suivi granulaire
-- Version: 1.0 - Création initiale du système d'import

-- ===============================================
-- Table: import_jobs
-- Description: Suivi global des imports
-- ===============================================
CREATE TABLE IF NOT EXISTS import_jobs (
    id SERIAL PRIMARY KEY,
    job_uuid UUID NOT NULL DEFAULT gen_random_uuid(),
    user_id INTEGER NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    file_path TEXT NOT NULL,
    file_size BIGINT NOT NULL,
    file_type VARCHAR(50) NOT NULL, -- 'customers', 'products', 'orders'
    file_format VARCHAR(10) NOT NULL, -- 'csv', 'xlsx', 'xls'
    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- 'pending', 'processing', 'completed', 'completed_with_errors', 'failed', 'cancelled'
    total_rows INTEGER DEFAULT 0,
    processed_rows INTEGER DEFAULT 0,
    success_rows INTEGER DEFAULT 0,
    error_rows INTEGER DEFAULT 0,
    progress_percent DECIMAL(5,2) DEFAULT 0.00,
    started_at TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,
    estimated_completion TIMESTAMP NULL,
    error_message TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100) DEFAULT 'system',
    updated_by VARCHAR(100) DEFAULT 'system',
    
    -- Contraintes
    CONSTRAINT chk_import_jobs_status CHECK (status IN ('pending', 'processing', 'completed', 'completed_with_errors', 'failed', 'cancelled')),
    CONSTRAINT chk_import_jobs_file_type CHECK (file_type IN ('customers', 'products', 'orders')),
    CONSTRAINT chk_import_jobs_file_format CHECK (file_format IN ('csv', 'xlsx', 'xls')),
    CONSTRAINT chk_import_jobs_progress CHECK (progress_percent >= 0.00 AND progress_percent <= 100.00),
    CONSTRAINT unique_job_uuid UNIQUE (job_uuid)
);

-- ===============================================
-- Table: import_details  
-- Description: Suivi ligne par ligne des imports
-- ===============================================
CREATE TABLE IF NOT EXISTS import_details (
    id SERIAL PRIMARY KEY,
    import_job_id INTEGER NOT NULL REFERENCES import_jobs(id) ON DELETE CASCADE,
    row_number INTEGER NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- 'pending', 'processing', 'success', 'error', 'skipped'
    original_data JSONB NOT NULL, -- Données originales de la ligne
    transformed_data JSONB NULL, -- Données après transformation
    target_table VARCHAR(100) NULL, -- Table de destination
    target_record_id INTEGER NULL, -- ID de l'enregistrement créé
    error_message TEXT NULL,
    error_code VARCHAR(50) NULL,
    validation_errors JSONB NULL, -- Détail des erreurs de validation
    processed_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Contraintes  
    CONSTRAINT chk_import_details_status CHECK (status IN ('pending', 'processing', 'success', 'error', 'skipped')),
    CONSTRAINT chk_import_details_row_number CHECK (row_number > 0)
);

-- ===============================================
-- Table: file_type_configs
-- Description: Configuration des types de fichiers supportés
-- ===============================================
CREATE TABLE IF NOT EXISTS file_type_configs (
    id SERIAL PRIMARY KEY,
    file_type VARCHAR(50) NOT NULL UNIQUE, -- 'customers', 'products', 'orders'
    display_name VARCHAR(100) NOT NULL,
    description TEXT,
    target_table VARCHAR(100) NOT NULL,
    target_schema VARCHAR(50) NOT NULL DEFAULT 'public',
    required_columns JSONB NOT NULL, -- ['name', 'email'] pour customers
    optional_columns JSONB DEFAULT '[]'::jsonb,
    column_mappings JSONB NOT NULL, -- {"name": "customer_name", "email": "email_address"}
    validation_rules JSONB DEFAULT '{}'::jsonb, -- {"email": {"type": "email"}, "price": {"type": "numeric", "min": 0}}
    transformation_rules JSONB DEFAULT '{}'::jsonb, -- Règles de transformation
    is_active BOOLEAN DEFAULT true,
    max_file_size BIGINT DEFAULT 52428800, -- 50MB en bytes
    supported_formats JSONB DEFAULT '["csv", "xlsx", "xls"]'::jsonb,
    sample_file_url VARCHAR(500) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100) DEFAULT 'system',
    updated_by VARCHAR(100) DEFAULT 'system',
    
    -- Contraintes
    CONSTRAINT chk_file_type_configs_file_type CHECK (file_type IN ('customers', 'products', 'orders')),
    CONSTRAINT chk_file_type_configs_max_size CHECK (max_file_size > 0)
);

-- ===============================================
-- Table: import_logs
-- Description: Logs détaillés des opérations d'import
-- ===============================================
CREATE TABLE IF NOT EXISTS import_logs (
    id SERIAL PRIMARY KEY,
    import_job_id INTEGER NOT NULL REFERENCES import_jobs(id) ON DELETE CASCADE,
    log_level VARCHAR(20) NOT NULL DEFAULT 'INFO', -- 'DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'
    message TEXT NOT NULL,
    details JSONB NULL, -- Détails additionnels en JSON
    module VARCHAR(100) NULL, -- Module/composant qui a généré le log
    function_name VARCHAR(100) NULL, -- Fonction qui a généré le log
    line_number INTEGER NULL, -- Numéro de ligne associé (si applicable)
    execution_time_ms INTEGER NULL, -- Temps d'exécution en millisecondes
    memory_usage_mb DECIMAL(10,2) NULL, -- Utilisation mémoire en MB
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Contraintes
    CONSTRAINT chk_import_logs_level CHECK (log_level IN ('DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'))
);

-- ===============================================
-- Table: import_statistics
-- Description: Métriques et statistiques des imports
-- ===============================================
CREATE TABLE IF NOT EXISTS import_statistics (
    id SERIAL PRIMARY KEY,
    import_job_id INTEGER NOT NULL REFERENCES import_jobs(id) ON DELETE CASCADE,
    metric_name VARCHAR(100) NOT NULL, -- 'processing_speed', 'memory_peak', 'file_validation_time', etc.
    metric_value DECIMAL(15,4) NOT NULL,
    metric_unit VARCHAR(20) NOT NULL, -- 'rows/sec', 'MB', 'ms', 'seconds', etc.
    metric_type VARCHAR(50) NOT NULL DEFAULT 'performance', -- 'performance', 'quality', 'resource', 'business'
    measurement_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    details JSONB NULL, -- Métadonnées additionnelles
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Contraintes
    CONSTRAINT chk_import_stats_metric_type CHECK (metric_type IN ('performance', 'quality', 'resource', 'business'))
);

-- ===============================================
-- CRÉATION DES INDEX POUR OPTIMISATION
-- ===============================================

-- Index pour import_jobs
CREATE INDEX IF NOT EXISTS idx_import_jobs_status ON import_jobs(status);
CREATE INDEX IF NOT EXISTS idx_import_jobs_user_id ON import_jobs(user_id);
CREATE INDEX IF NOT EXISTS idx_import_jobs_file_type ON import_jobs(file_type);
CREATE INDEX IF NOT EXISTS idx_import_jobs_created_at ON import_jobs(created_at);
CREATE INDEX IF NOT EXISTS idx_import_jobs_uuid ON import_jobs(job_uuid);
CREATE INDEX IF NOT EXISTS idx_import_jobs_composite ON import_jobs(user_id, status, file_type);

-- Index pour import_details
CREATE INDEX IF NOT EXISTS idx_import_details_job_id ON import_details(import_job_id);
CREATE INDEX IF NOT EXISTS idx_import_details_status ON import_details(status);
CREATE INDEX IF NOT EXISTS idx_import_details_row_number ON import_details(import_job_id, row_number);
CREATE INDEX IF NOT EXISTS idx_import_details_target_table ON import_details(target_table);
CREATE INDEX IF NOT EXISTS idx_import_details_target_record ON import_details(target_table, target_record_id);

-- Index pour file_type_configs
CREATE INDEX IF NOT EXISTS idx_file_type_configs_active ON file_type_configs(is_active);
CREATE INDEX IF NOT EXISTS idx_file_type_configs_target_table ON file_type_configs(target_table);

-- Index pour import_logs
CREATE INDEX IF NOT EXISTS idx_import_logs_job_id ON import_logs(import_job_id);
CREATE INDEX IF NOT EXISTS idx_import_logs_level ON import_logs(log_level);
CREATE INDEX IF NOT EXISTS idx_import_logs_created_at ON import_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_import_logs_module ON import_logs(module);

-- Index pour import_statistics
CREATE INDEX IF NOT EXISTS idx_import_stats_job_id ON import_statistics(import_job_id);
CREATE INDEX IF NOT EXISTS idx_import_stats_metric_name ON import_statistics(metric_name);
CREATE INDEX IF NOT EXISTS idx_import_stats_metric_type ON import_statistics(metric_type);
CREATE INDEX IF NOT EXISTS idx_import_stats_measurement_time ON import_statistics(measurement_time);

-- ===============================================
-- INSERTION DES CONFIGURATIONS PAR DÉFAUT
-- ===============================================

-- Configuration pour le type 'customers'
INSERT INTO file_type_configs (
    file_type, 
    display_name, 
    description, 
    target_table, 
    target_schema,
    required_columns, 
    optional_columns,
    column_mappings, 
    validation_rules,
    transformation_rules
) VALUES (
    'customers',
    'Clients',
    'Import de fichiers clients avec validation email et téléphone optionnel',
    'customers',
    'public',
    '["name", "email"]'::jsonb,
    '["phone", "address", "city", "country"]'::jsonb,
    '{
        "name": "customer_name",
        "email": "email_address", 
        "phone": "phone_number",
        "address": "address_line",
        "city": "city",
        "country": "country_code"
    }'::jsonb,
    '{
        "email": {"type": "email", "required": true},
        "phone": {"type": "phone", "required": false},
        "name": {"type": "string", "required": true, "min_length": 2, "max_length": 100}
    }'::jsonb,
    '{
        "email": {"lowercase": true, "trim": true},
        "name": {"trim": true, "title_case": true},
        "phone": {"format": "international"}
    }'::jsonb
) ON CONFLICT (file_type) DO NOTHING;

-- Configuration pour le type 'products'  
INSERT INTO file_type_configs (
    file_type,
    display_name,
    description,
    target_table,
    target_schema,
    required_columns,
    optional_columns, 
    column_mappings,
    validation_rules,
    transformation_rules
) VALUES (
    'products',
    'Produits',
    'Import de fichiers produits avec validation prix numérique et code unique',
    'products',
    'public',
    '["code", "name", "price"]'::jsonb,
    '["description", "category", "brand", "weight", "dimensions"]'::jsonb,
    '{
        "code": "product_code",
        "name": "product_name",
        "price": "unit_price",
        "description": "description",
        "category": "category_name",
        "brand": "brand_name",
        "weight": "weight_kg",
        "dimensions": "dimensions"
    }'::jsonb,
    '{
        "code": {"type": "string", "required": true, "unique": true, "max_length": 50},
        "name": {"type": "string", "required": true, "min_length": 2, "max_length": 200},
        "price": {"type": "numeric", "required": true, "min": 0, "decimal_places": 2}
    }'::jsonb,
    '{
        "code": {"uppercase": true, "trim": true},
        "name": {"trim": true, "title_case": true},
        "price": {"round": 2}
    }'::jsonb
) ON CONFLICT (file_type) DO NOTHING;

-- Configuration pour le type 'orders'
INSERT INTO file_type_configs (
    file_type,
    display_name, 
    description,
    target_table,
    target_schema,
    required_columns,
    optional_columns,
    column_mappings,
    validation_rules,
    transformation_rules
) VALUES (
    'orders',
    'Commandes',
    'Import de fichiers commandes avec validation montant positif et numéro unique',
    'orders',
    'public', 
    '["order_number", "customer_id", "total"]'::jsonb,
    '["order_date", "status", "shipping_address", "notes"]'::jsonb,
    '{
        "order_number": "order_number",
        "customer_id": "customer_id", 
        "total": "total_amount",
        "order_date": "order_date",
        "status": "order_status",
        "shipping_address": "shipping_address",
        "notes": "notes"
    }'::jsonb,
    '{
        "order_number": {"type": "string", "required": true, "unique": true, "max_length": 50},
        "customer_id": {"type": "integer", "required": true, "min": 1},
        "total": {"type": "numeric", "required": true, "min": 0, "decimal_places": 2},
        "order_date": {"type": "date", "required": false}
    }'::jsonb,
    '{
        "order_number": {"uppercase": true, "trim": true},
        "total": {"round": 2},
        "order_date": {"format": "YYYY-MM-DD"}
    }'::jsonb
) ON CONFLICT (file_type) DO NOTHING;

-- ===============================================
-- CRÉATION DES TRIGGERS POUR AUTO-UPDATE
-- ===============================================

-- Fonction pour mettre à jour automatiquement updated_at
CREATE OR REPLACE FUNCTION update_import_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers pour auto-update des timestamps
CREATE TRIGGER update_import_jobs_updated_at 
    BEFORE UPDATE ON import_jobs
    FOR EACH ROW 
    EXECUTE FUNCTION update_import_updated_at_column();

CREATE TRIGGER update_file_type_configs_updated_at
    BEFORE UPDATE ON file_type_configs  
    FOR EACH ROW
    EXECUTE FUNCTION update_import_updated_at_column();

-- ===============================================
-- VUES UTILES POUR REPORTING
-- ===============================================

-- Vue pour statistiques globales d'import
CREATE OR REPLACE VIEW import_summary_stats AS
SELECT 
    DATE(created_at) as import_date,
    file_type,
    COUNT(*) as total_jobs,
    COUNT(*) FILTER (WHERE status = 'completed') as completed_jobs,
    COUNT(*) FILTER (WHERE status = 'completed_with_errors') as completed_with_errors,
    COUNT(*) FILTER (WHERE status = 'failed') as failed_jobs,
    COUNT(*) FILTER (WHERE status = 'cancelled') as cancelled_jobs,
    SUM(total_rows) as total_rows_processed,
    SUM(success_rows) as total_success_rows,
    SUM(error_rows) as total_error_rows,
    ROUND(AVG(progress_percent), 2) as avg_progress,
    ROUND(
        CASE 
            WHEN SUM(total_rows) > 0 
            THEN (SUM(success_rows)::DECIMAL / SUM(total_rows) * 100) 
            ELSE 0 
        END, 2
    ) as success_rate_percent
FROM import_jobs 
GROUP BY DATE(created_at), file_type
ORDER BY import_date DESC, file_type;

-- Vue pour les imports récents avec détails
CREATE OR REPLACE VIEW recent_imports_detailed AS  
SELECT 
    ij.id,
    ij.job_uuid,
    ij.user_id,
    ij.file_name,
    ij.file_type,
    ftc.display_name as file_type_display,
    ij.status,
    ij.total_rows,
    ij.processed_rows, 
    ij.success_rows,
    ij.error_rows,
    ij.progress_percent,
    ij.created_at,
    ij.started_at,
    ij.completed_at,
    CASE 
        WHEN ij.completed_at IS NOT NULL AND ij.started_at IS NOT NULL
        THEN EXTRACT(EPOCH FROM (ij.completed_at - ij.started_at))
        ELSE NULL
    END as processing_duration_seconds,
    CASE
        WHEN ij.status = 'processing' AND ij.started_at IS NOT NULL
        THEN EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - ij.started_at))
        ELSE NULL
    END as current_processing_duration_seconds
FROM import_jobs ij
LEFT JOIN file_type_configs ftc ON ij.file_type = ftc.file_type
ORDER BY ij.created_at DESC;

-- ===============================================
-- COMMENTAIRES ET DOCUMENTATION
-- ===============================================

COMMENT ON TABLE import_jobs IS 'Table principale pour le suivi des tâches d''import de fichiers';
COMMENT ON TABLE import_details IS 'Détails ligne par ligne du traitement des imports';
COMMENT ON TABLE file_type_configs IS 'Configuration des types de fichiers supportés pour l''import';
COMMENT ON TABLE import_logs IS 'Logs détaillés des opérations d''import pour debugging';
COMMENT ON TABLE import_statistics IS 'Métriques et statistiques de performance des imports';

COMMENT ON COLUMN import_jobs.job_uuid IS 'UUID unique pour identifier le job publiquement';
COMMENT ON COLUMN import_jobs.progress_percent IS 'Pourcentage de progression (0.00 à 100.00)';
COMMENT ON COLUMN import_details.original_data IS 'Données brutes du fichier en format JSON';
COMMENT ON COLUMN import_details.transformed_data IS 'Données après application des règles de transformation';
COMMENT ON COLUMN file_type_configs.validation_rules IS 'Règles de validation au format JSON';
COMMENT ON COLUMN file_type_configs.transformation_rules IS 'Règles de transformation au format JSON';

-- ===============================================
-- FINALISATION
-- ===============================================

-- Log de la migration
DO $$
BEGIN
    RAISE NOTICE '✅ Migration 004_create_import_system_tables.sql appliquée avec succès';
    RAISE NOTICE '📊 Tables créées: import_jobs, import_details, file_type_configs, import_logs, import_statistics';
    RAISE NOTICE '🔧 Index créés pour optimisation des performances';
    RAISE NOTICE '⚙️ Configurations par défaut insérées pour customers, products, orders';
    RAISE NOTICE '📈 Vues de reporting créées: import_summary_stats, recent_imports_detailed';
END $$; 