-- 110 : clean_data.article_sap -- auteurs SAP (demande du 2026-10-09) :
-- "Créé par" (mara.ernam) et "Dernière modification par" (mara.aenam).
ALTER TABLE clean_data.article_sap
    ADD COLUMN IF NOT EXISTS "Créé par" text,
    ADD COLUMN IF NOT EXISTS "Dernière modification par" text;
