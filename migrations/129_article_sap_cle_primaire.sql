-- 129 : clean_data.article_sap -- le N° article devient l'identifiant unique
-- (demande du 2026-11-05, ecran Finance > Articles). Echoue si un doublon existe.
BEGIN;

ALTER TABLE clean_data.article_sap
    ADD CONSTRAINT article_sap_pkey PRIMARY KEY ("N° article");

COMMIT;
