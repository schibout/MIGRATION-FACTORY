-- =====================================================================
-- Compte PostgreSQL LECTURE SEULE pour l'accès MCP de l'IA
-- A exécuter en tant que superutilisateur (postgres) sur sap_migration_db :
--   psql -h 10.190.100.58 -U postgres -d sap_migration_db -f create_mcp_readonly_user.sql
--
-- IMPORTANT : remplacer 'CHANGE_ME' par un mot de passe fort,
-- identique à PG_PASSWORD dans le fichier .env.
-- =====================================================================

-- 1. Création du rôle (ne plante pas s'il existe déjà)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mcp_ro') THEN
        CREATE ROLE mcp_ro LOGIN PASSWORD 'CHANGE_ME';
    END IF;
END
$$;

-- 2. Connexion à la base
GRANT CONNECT ON DATABASE sap_migration_db TO mcp_ro;

-- 3. Accès en lecture seule aux schémas applicatifs
GRANT USAGE ON SCHEMA raw_data, clean_data, public TO mcp_ro;

GRANT SELECT ON ALL TABLES IN SCHEMA raw_data  TO mcp_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA clean_data TO mcp_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA public     TO mcp_ro;

-- 4. Appliquer aussi aux tables/vues créées plus tard
ALTER DEFAULT PRIVILEGES IN SCHEMA raw_data   GRANT SELECT ON TABLES TO mcp_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA clean_data GRANT SELECT ON TABLES TO mcp_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA public     GRANT SELECT ON TABLES TO mcp_ro;

-- 5. Garantir l'absence de droits d'écriture (sécurité)
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA raw_data   FROM mcp_ro;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA clean_data FROM mcp_ro;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public     FROM mcp_ro;
