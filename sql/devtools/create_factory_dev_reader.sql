-- A executer MANUELLEMENT par un administrateur sur une base de developpement.
-- Aucun changement du role postgres ou du compte IA applicatif.
-- Exemple : psql -X -v ON_ERROR_STOP=1 -d base_dev -f ce_fichier.sql
-- Puis, dans psql : \password factory_dev_reader
\set ON_ERROR_STOP on
BEGIN;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'factory_dev_reader') THEN
        CREATE ROLE factory_dev_reader LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE
            NOREPLICATION NOBYPASSRLS NOINHERIT;
    END IF;
    IF EXISTS (
        SELECT 1 FROM pg_roles
        WHERE rolname = 'factory_dev_reader'
          AND (rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls)
    ) OR EXISTS (
        SELECT 1 FROM pg_auth_members m JOIN pg_roles r ON r.oid = m.member
        WHERE r.rolname = 'factory_dev_reader'
    ) OR EXISTS (
        SELECT 1 FROM pg_class c JOIN pg_roles r ON r.oid = c.relowner
        WHERE r.rolname = 'factory_dev_reader'
    ) THEN
        RAISE EXCEPTION 'Le role existant a des privileges ou proprietes a examiner';
    END IF;
END $$;
ALTER ROLE factory_dev_reader SET default_transaction_read_only = on;
ALTER ROLE factory_dev_reader SET statement_timeout = '30s';
SELECT format('GRANT CONNECT ON DATABASE %I TO factory_dev_reader', current_database())
\gexec
GRANT USAGE ON SCHEMA raw_data, clean_data TO factory_dev_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA raw_data, clean_data TO factory_dev_reader;
-- public peut contenir utilisateurs et secrets : aucun GRANT SELECT global.
-- Ajouter les seules tables de configuration necessaires apres examen.
-- Les futures tables ne sont pas accordees implicitement : rejouer les GRANT
-- apres verification des objets. Examiner aussi les privileges herites de PUBLIC.
COMMIT;
