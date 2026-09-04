-- =====================================================================
-- Date d'arrete du fichier de selection fournisseurs
--
-- clean_data.alimenter_ifs_fournisseurs() (sql/supplier/01_...) reprend les
-- fournisseurs du fichier de selection, plus ceux crees dans SAP APRES l'arret
-- du fichier. Le seuil etait code en dur (DATE '2025-10-07') : il devient un
-- parametre de l'ecran /configuration/valeurs-defaut, le metier pouvant
-- avancer la date d'arrete a chaque nouveau fichier sans passer par le code.
--
-- Type DATE cote appelant : get_default_value renvoie TEXT, le script fait le
-- cast ::DATE. La valeur doit donc rester au format YYYY-MM-DD.
--
-- INSERT ... ON CONFLICT DO NOTHING : rejouable, ne remplace jamais une valeur
-- deja ajustee depuis l'ecran.
-- =====================================================================

BEGIN;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.ifs_fournisseurs', 'date_arrete', 'STANDARD', 'CONSTANTE', '2025-09-01',
        'Date d''arrete du fichier de selection : les fournisseurs crees dans SAP a partir de cette date sont repris meme s''ils sont absents du fichier (format YYYY-MM-DD)',
        'migration_065')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

COMMIT;
