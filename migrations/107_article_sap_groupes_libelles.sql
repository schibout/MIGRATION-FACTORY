-- 107 : clean_data.article_sap -- codes SAP supplementaires et leur libelle
-- (demande du 2026-10-09). Alimentees par clean_data.alimenter_article_sap().
-- Libelles absents faute de table extraite : gestionnaire (T024D), type de
-- planification (T438T), statut article (T141T).
ALTER TABLE clean_data.article_sap
    ADD COLUMN IF NOT EXISTS "U/M Stock Description" text,
    ADD COLUMN IF NOT EXISTS "Groupe d'achat" text,
    ADD COLUMN IF NOT EXISTS "Groupe d'achat Description" text,
    ADD COLUMN IF NOT EXISTS "Hiérarchie produit" text,
    ADD COLUMN IF NOT EXISTS "Hiérarchie produit Description" text,
    ADD COLUMN IF NOT EXISTS "Type approvisionnement" text,
    ADD COLUMN IF NOT EXISTS "Type approvisionnement Description" text,
    ADD COLUMN IF NOT EXISTS "Type de planification" text,
    ADD COLUMN IF NOT EXISTS "Point de commande" text,
    ADD COLUMN IF NOT EXISTS "Ancien numéro article" text;
