-- 111 : clean_data.article_sap -- nom complet des utilisateurs SAP (demande du
-- 2026-10-09) : usr21.bname -> adrp.name_text (sinon prenom + nom).
-- NULL pour un compte supprime de SAP (absent de usr21 : 163 des 202
-- utilisateurs cites par les articles au 2026-10-09).
ALTER TABLE clean_data.article_sap
    ADD COLUMN IF NOT EXISTS "Créé par Nom" text,
    ADD COLUMN IF NOT EXISTS "Dernière modification par Nom" text;
