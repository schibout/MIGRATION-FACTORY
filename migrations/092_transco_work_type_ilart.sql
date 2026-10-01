-- Migration 092 : transcodification WORK_TYPE (SAP -> IFS)
--
-- Type d'activite de maintenance SAP (AFIH.ILART, libelles T353I_T) -> type de
-- travail IFS = 'MP' || ILART (21 -> MP21). Les 21 codes presents dans
-- raw_data.afih sont seedes, y compris 15 et 61 absents du perimetre IW39 actuel.
-- Modifiable ensuite dans l'ecran Transcodification. Destinee a
-- clean_data.jt_task.work_type_id (create_alimenter_jt_task.sql).

BEGIN;

INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('WORK_TYPE', 'SAP', 'IFS', '11', 'MP11', 'Dépannage', 'migration_092')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('WORK_TYPE', 'SAP', 'IFS', '12', 'MP12', 'Dommages', 'migration_092')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('WORK_TYPE', 'SAP', 'IFS', '13', 'MP13', 'Réparation (réactif)', 'migration_092')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('WORK_TYPE', 'SAP', 'IFS', '14', 'MP14', 'Assistance Product. /non panne', 'migration_092')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('WORK_TYPE', 'SAP', 'IFS', '15', 'MP15', 'Marche dégradée', 'migration_092')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('WORK_TYPE', 'SAP', 'IFS', '21', 'MP21', 'Préventif systématique', 'migration_092')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('WORK_TYPE', 'SAP', 'IFS', '22', 'MP22', 'Préventif conditionnel', 'migration_092')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('WORK_TYPE', 'SAP', 'IFS', '23', 'MP23', 'Entretien légal/Assu. Qualité', 'migration_092')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('WORK_TYPE', 'SAP', 'IFS', '24', 'MP24', 'Réparation issue du préventif', 'migration_092')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('WORK_TYPE', 'SAP', 'IFS', '25', 'MP25', 'Réparation issue du prédicitif', 'migration_092')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('WORK_TYPE', 'SAP', 'IFS', '31', 'MP31', 'Modification Maintenance', 'migration_092')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('WORK_TYPE', 'SAP', 'IFS', '32', 'MP32', 'Support', 'migration_092')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('WORK_TYPE', 'SAP', 'IFS', '41', 'MP41', 'Modification Production', 'migration_092')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('WORK_TYPE', 'SAP', 'IFS', '42', 'MP42', 'Sécurité', 'migration_092')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('WORK_TYPE', 'SAP', 'IFS', '43', 'MP43', 'Progrès Continu', 'migration_092')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('WORK_TYPE', 'SAP', 'IFS', '51', 'MP51', 'Rénovables', 'migration_092')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('WORK_TYPE', 'SAP', 'IFS', '61', 'MP61', 'Outils de fabrication', 'migration_092')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('WORK_TYPE', 'SAP', 'IFS', '71', 'MP71', 'Gros entretien', 'migration_092')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('WORK_TYPE', 'SAP', 'IFS', '72', 'MP72', 'Modification Maintenance (TOP)', 'migration_092')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('WORK_TYPE', 'SAP', 'IFS', '73', 'MP73', 'Mise au point installation', 'migration_092')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('WORK_TYPE', 'SAP', 'IFS', 'MA', 'MPMA', 'Manutention', 'migration_092')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;

COMMIT;
