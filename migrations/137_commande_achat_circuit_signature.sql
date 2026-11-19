-- =====================================================
-- Migration 137 : commandes d'achat, circuit de signature (demande metier
-- du 2026-11-19 : seules les commandes autorisees via le circuit de signature
-- sont reprises).
--   Lue par clean_data.alimenter_commande_achat_ifs() (sql/commandeAchat/02_*) :
--     - toujours exclues : commandes dont la liberation n'est pas terminee
--       (EKKO-FRGRL = 'X') ;
--     - reprendre_sans_circuit_signature = NON (defaut) : seules les commandes
--       passees par une strategie de liberation (EKKO-FRGSX renseignee) et
--       liberees sont reprises ; OUI : les commandes hors circuit (sous le seuil
--       de la strategie) sont reprises aussi.
--   Modifiable dans l'ecran Valeurs par defaut (module commandeAchat).
-- Idempotent (ON CONFLICT DO NOTHING).
-- =====================================================
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('commandeAchat', 'clean_data.commande_achat_ifs', 'reprendre_sans_circuit_signature', 'STANDARD', 'CONSTANTE', 'NON',
        'OUI / NON : reprendre aussi les commandes SAP hors circuit de signature (pas de strategie de liberation EKKO-FRGSX). Les commandes non liberees (EKKO-FRGRL = X) sont toujours exclues. Source : 02_alimenter_commande_achat_ifs.sql',
        'migration_137')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
