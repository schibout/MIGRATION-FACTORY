-- =====================================================
-- Migration: Création + alimentation de public.system_config
-- Description: Stocke les variables de configuration modifiables
--              depuis la page Paramètres (connexions DB, SAP,
--              SharePoint, SMTP, etc.). Surcharge les valeurs
--              du fichier .env au runtime.
-- Date: 2026-05-26
-- Idempotent: CREATE IF NOT EXISTS + INSERT ON CONFLICT DO NOTHING
-- =====================================================

-- ----------------------------------------------------
-- 1. Création de la table
-- ----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.system_config (
    key         VARCHAR(100) PRIMARY KEY,
    value       TEXT,
    category    VARCHAR(50)  NOT NULL,
    is_secret   BOOLEAN      NOT NULL DEFAULT FALSE,
    updated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by  VARCHAR(100)
);

CREATE INDEX IF NOT EXISTS idx_system_config_category
    ON public.system_config(category);

COMMENT ON TABLE  public.system_config            IS 'Variables de configuration modifiables via la page Paramètres';
COMMENT ON COLUMN public.system_config.key        IS 'Nom de la variable (ex: DB_HOST, SAP_EXTRACTION_API_URL)';
COMMENT ON COLUMN public.system_config.value      IS 'Valeur courante (peut écraser la valeur .env)';
COMMENT ON COLUMN public.system_config.category   IS 'database | sap | sharepoint | smtp | security | backup | redis | cors | logs | flask';
COMMENT ON COLUMN public.system_config.is_secret  IS 'Si TRUE, la valeur est masquée dans les réponses API';

-- ----------------------------------------------------
-- 2. Données initiales (à partir des valeurs .env courantes)
--    ON CONFLICT DO NOTHING : ne réécrit jamais une valeur
--    déjà modifiée via l'UI.
-- ----------------------------------------------------
INSERT INTO public.system_config (key, value, category, is_secret, updated_by) VALUES
-- ---------- Base de données PostgreSQL ----------
('DB_HOST',          '10.190.100.58',      'database',   FALSE, 'seed'),
('DB_PORT',          '5432',               'database',   FALSE, 'seed'),
('DB_NAME',          'sap_migration_db',   'database',   FALSE, 'seed'),
('DB_USER',          'postgres',           'database',   FALSE, 'seed'),
('DB_PASSWORD',      'trimet2025',         'database',   TRUE,  'seed'),
('PG_SCHEMA',        'clean_data',         'database',   FALSE, 'seed'),
('DB_POOL_SIZE',     '10',                 'database',   FALSE, 'seed'),
('DB_MAX_OVERFLOW',  '20',                 'database',   FALSE, 'seed'),
('DB_POOL_TIMEOUT',  '30',                 'database',   FALSE, 'seed'),
('DB_POOL_RECYCLE',  '1800',               'database',   FALSE, 'seed'),

-- ---------- SAP Extraction ----------
('SAP_EXTRACTION_API_URL', 'http://10.190.100.58:8000', 'sap', FALSE, 'seed'),
('SAP_EXTRACTION_PATH',    '/opt/sap_extraction',       'sap', FALSE, 'seed'),
('SAP_API_TIMEOUT',        '10',                        'sap', FALSE, 'seed'),

-- ---------- SharePoint / ASAP ----------
('SHAREPOINT_BASE_URL', 'http://asap.stjn.local', 'sharepoint', FALSE, 'seed'),
('SHAREPOINT_USER',     'stjn\samir.chibout',     'sharepoint', FALSE, 'seed'),
('SHAREPOINT_PASSWORD', 'M@lika1952',             'sharepoint', TRUE,  'seed'),

-- ---------- SMTP ----------
('SMTP_SERVER',           '',                  'smtp', FALSE, 'seed'),
('SMTP_PORT',             '587',               'smtp', FALSE, 'seed'),
('SMTP_USE_TLS',          'true',              'smtp', FALSE, 'seed'),
('SMTP_USERNAME',         '',                  'smtp', FALSE, 'seed'),
('SMTP_PASSWORD',         '',                  'smtp', TRUE,  'seed'),
('SMTP_FROM_EMAIL',       '',                  'smtp', FALSE, 'seed'),
('SMTP_FROM_NAME',        'Migration Factory', 'smtp', FALSE, 'seed'),
('PASSWORD_RESET_EXPIRY', '3600',              'smtp', FALSE, 'seed'),
('FRONTEND_URL',          'http://localhost:3000', 'smtp', FALSE, 'seed'),

-- ---------- Sécurité ----------
('SECRET_KEY',     'f81989cb04e89b1c3bf40a98f9fc1c817c7ded6f3290e5bfce8fd15aa67021c4', 'security', TRUE, 'seed'),
('JWT_SECRET_KEY', '92a5fe04dcc1c0fc2e180e4702d8cdc936c4a75207d6c4659db309051b4819a7', 'security', TRUE, 'seed'),

-- ---------- Backup automatique ----------
('BACKUP_ENABLED',        'true',     'backup', FALSE, 'seed'),
('BACKUP_DIR',            '/backups', 'backup', FALSE, 'seed'),
('BACKUP_HOUR',           '2',        'backup', FALSE, 'seed'),
('BACKUP_MINUTE',         '0',        'backup', FALSE, 'seed'),
('BACKUP_RETENTION_DAYS', '30',       'backup', FALSE, 'seed'),

-- ---------- Redis & Rate limit ----------
('REDIS_URL',          '',                   'redis', FALSE, 'seed'),
('RATE_LIMIT_DEFAULT', '200/day;50/hour',    'redis', FALSE, 'seed'),

-- ---------- CORS & Logs ----------
('CORS_ORIGINS',      'http://10.190.100.58:8080,https://10.190.100.58:8080', 'cors', FALSE, 'seed'),
('MAX_EXPORT_ROWS',   '100000', 'logs', FALSE, 'seed'),
('EXPORT_CHUNK_SIZE', '5000',   'logs', FALSE, 'seed'),
('LOG_LEVEL',         'DEBUG',  'logs', FALSE, 'seed'),

-- ---------- Flask / Runtime ----------
('FLASK_ENV', 'production', 'flask', FALSE, 'seed'),
('PORT',      '5000',       'flask', FALSE, 'seed')

ON CONFLICT (key) DO NOTHING;

-- ----------------------------------------------------
-- 3. Confirmation
-- ----------------------------------------------------
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM public.system_config;
    RAISE NOTICE 'Table public.system_config prête. % paramètre(s) en base.', v_count;
END $$;
