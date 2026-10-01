-- Migration 089 : transcodification ACTION (PE_TOOLS -> IFS)
--
-- Types d'action PE Tools -> code IFS, source : sql/pm_actions/Files/Actiontype.xlsx.
-- Modifiable ensuite dans l'ecran Transcodification. Non branchee dans les procedures PM.
-- Le fichier porte VGP deux fois (VGP et REQ) : la cle unique (category, source_system,
-- target_system, source_value) n'en garde qu'une, VGP -> VGP ; VGP -> REQ est ignoree.

BEGIN;

INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('ACTION', 'PE_TOOLS', 'IFS', 'Nettoyage', 'NET', 'Nettoyage', 'migration_089')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('ACTION', 'PE_TOOLS', 'IFS', 'Graissage', 'GRA', 'Graissage', 'migration_089')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('ACTION', 'PE_TOOLS', 'IFS', 'TOUR', 'TOU', 'Tournée', 'migration_089')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('ACTION', 'PE_TOOLS', 'IFS', 'CHANG MEC', 'CHM', 'Changement méca', 'migration_089')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('ACTION', 'PE_TOOLS', 'IFS', 'CTRL MEC', 'CTM', 'Contrôle méca', 'migration_089')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('ACTION', 'PE_TOOLS', 'IFS', 'CTRL ELEC', 'CTE', 'Contrôle élec', 'migration_089')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('ACTION', 'PE_TOOLS', 'IFS', 'REGL MEC', 'REM', 'Réglage méca', 'migration_089')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('ACTION', 'PE_TOOLS', 'IFS', 'REGL ELEC', 'REE', 'Réglage élec', 'migration_089')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('ACTION', 'PE_TOOLS', 'IFS', 'EXPLOIT', 'EXP', 'Exploitation', 'migration_089')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('ACTION', 'PE_TOOLS', 'IFS', 'GR', 'GRE', 'Gros Entretien', 'migration_089')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('ACTION', 'PE_TOOLS', 'IFS', 'PROD', 'PRO', 'Production', 'migration_089')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('ACTION', 'PE_TOOLS', 'IFS', 'VGP', 'VGP', 'VGP', 'migration_089')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('ACTION', 'PE_TOOLS', 'IFS', 'VGP', 'REQ', 'Requalification', 'migration_089')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('ACTION', 'PE_TOOLS', 'IFS', 'CTRL MEC / ELEC', 'CME', 'Contrôle méca / élec', 'migration_089')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('ACTION', 'PE_TOOLS', 'IFS', 'CTRL REGL', 'CTR', 'Contrôle réglementaire', 'migration_089')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('ACTION', 'PE_TOOLS', 'IFS', 'ENTRETIEN', 'ENT', 'Entretien', 'migration_089')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('ACTION', 'PE_TOOLS', 'IFS', 'TEST MMR', 'MMR', 'Test MMR', 'migration_089')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('ACTION', 'PE_TOOLS', 'IFS', 'CTRL INFO', 'CIN', 'Contrôle info', 'migration_089')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;

COMMIT;
