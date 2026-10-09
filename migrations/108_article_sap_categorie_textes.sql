-- 108 : clean_data.article_sap (demande du 2026-10-09)
--   - categorie article SAP (mara.mtart : IBAU, ERSA, HIBE...) : la colonne
--     existait sous le nom IFS "Groupe produit 2", renommee "Categorie article" ;
--   - "Notes" (texte de commande MATERIAL/BEST) renomme "Texte de commande" ;
--   - deux textes longs SAP (STXH/STXL, lus par RFC_READ_TEXT dans
--     raw_data.sap_long_text) : note interne (IVER) et texte de base (GRUN).
-- Rejouable.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'clean_data'
               AND table_name = 'article_sap' AND column_name = 'Groupe produit 2') THEN
        ALTER TABLE clean_data.article_sap RENAME COLUMN "Groupe produit 2" TO "Catégorie article";
        ALTER TABLE clean_data.article_sap RENAME COLUMN "Groupe produit 2 Description" TO "Catégorie article Description";
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'clean_data'
               AND table_name = 'article_sap' AND column_name = 'Notes') THEN
        ALTER TABLE clean_data.article_sap RENAME COLUMN "Notes" TO "Texte de commande";
    END IF;
END $$;

ALTER TABLE clean_data.article_sap
    ADD COLUMN IF NOT EXISTS "Note interne" text,
    ADD COLUMN IF NOT EXISTS "Texte de base" text;
