-- 112 : clean_data.article_sap -- "Classe d'actifs" calculee (demande du
-- 2026-10-09) : classement de l'article (maintenance, magasin...) deduit de sa
-- categorie SAP (mara.mtart) par la transcodification ARTICLE_CLASSE_ACTIF
-- (SAP -> IFS), modifiable dans l'ecran Transcodification ; la description de
-- la ligne de transco donne "Classe d'actifs Description". Categorie absente
-- de la transco -> colonnes NULL (a completer dans l'ecran).
-- Ensuite : SELECT clean_data.alimenter_article_sap();
BEGIN;

ALTER TABLE clean_data.article_sap
    ADD COLUMN IF NOT EXISTS "Classe d'actifs" text,
    ADD COLUMN IF NOT EXISTS "Classe d'actifs Description" text;

DELETE FROM public."TranscodificationTable"
WHERE category = 'ARTICLE_CLASSE_ACTIF' AND source_system = 'SAP' AND target_system = 'IFS';

INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('ARTICLE_CLASSE_ACTIF', 'SAP', 'IFS', 'ERSA', 'MAINTENANCE', 'Article de maintenance', 'migration_112', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('ARTICLE_CLASSE_ACTIF', 'SAP', 'IFS', 'IBAU', 'MAINTENANCE', 'Article de maintenance', 'migration_112', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('ARTICLE_CLASSE_ACTIF', 'SAP', 'IFS', 'HIBE', 'MAGASIN', 'Article de magasin (consommable stocke)', 'migration_112', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('ARTICLE_CLASSE_ACTIF', 'SAP', 'IFS', 'DIEN', 'SERVICE', 'Prestation de service', 'migration_112', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('ARTICLE_CLASSE_ACTIF', 'SAP', 'IFS', 'NLAG', 'NON_STOCKE', 'Article non stocke', 'migration_112', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('ARTICLE_CLASSE_ACTIF', 'SAP', 'IFS', 'UNBW', 'NON_STOCKE', 'Article non stocke', 'migration_112', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('ARTICLE_CLASSE_ACTIF', 'SAP', 'IFS', 'FERT', 'PRODUCTION', 'Article de production', 'migration_112', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('ARTICLE_CLASSE_ACTIF', 'SAP', 'IFS', 'FER1', 'PRODUCTION', 'Article de production', 'migration_112', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('ARTICLE_CLASSE_ACTIF', 'SAP', 'IFS', 'HALB', 'PRODUCTION', 'Article de production', 'migration_112', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('ARTICLE_CLASSE_ACTIF', 'SAP', 'IFS', 'ROH', 'PRODUCTION', 'Article de production', 'migration_112', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('ARTICLE_CLASSE_ACTIF', 'SAP', 'IFS', 'HAWA', 'PRODUCTION', 'Article de production', 'migration_112', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('ARTICLE_CLASSE_ACTIF', 'SAP', 'IFS', 'PIPE', 'PRODUCTION', 'Article de production', 'migration_112', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('ARTICLE_CLASSE_ACTIF', 'SAP', 'IFS', 'PROC', 'PRODUCTION', 'Article de production', 'migration_112', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('ARTICLE_CLASSE_ACTIF', 'SAP', 'IFS', 'ZCRA', 'PRODUCTION', 'Article de production', 'migration_112', true);

COMMIT;
