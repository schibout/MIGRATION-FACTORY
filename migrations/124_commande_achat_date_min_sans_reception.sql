-- =====================================================
-- Migration 124 : commandes d'achat, date de creation minimale des postes
-- SANS reception (regle metier du 2026-10-23)
--   Un poste avec une reception non facturee est repris quelle que soit sa
--   date ; un poste sans aucune reception n'est repris que s'il est cree a
--   partir de cette date. Lue par clean_data.alimenter_commande_achat_ifs()
--   (sql/commandeAchat/02_*), modifiable dans l'ecran Valeurs par defaut.
-- Idempotent (ON CONFLICT DO NOTHING).
-- =====================================================
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.commande_achat_ifs', 'date_creation_min_sans_reception', 'STANDARD', 'CONSTANTE', '2026-03-01', 'Date de creation minimale (YYYY-MM-DD, EKKO-AEDAT) d''un poste de commande SANS aucune reception pour etre repris. Les postes avec une reception non facturee sont repris quelle que soit leur date. Source : 02_alimenter_commande_achat_ifs.sql', 'migration_124')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
