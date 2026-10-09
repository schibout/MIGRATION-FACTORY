-- 109 : clean_data.article_sap -- noms explicites des dates SAP (demande du
-- 2026-10-09) : "Créé" (mara.ersda) -> "Date de création", "Modifié"
-- (mara.laeda) -> "Date de dernière modification". Rejouable.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'clean_data'
               AND table_name = 'article_sap' AND column_name = 'Créé') THEN
        ALTER TABLE clean_data.article_sap RENAME COLUMN "Créé" TO "Date de création";
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'clean_data'
               AND table_name = 'article_sap' AND column_name = 'Modifié') THEN
        ALTER TABLE clean_data.article_sap RENAME COLUMN "Modifié" TO "Date de dernière modification";
    END IF;
END $$;
