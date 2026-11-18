-- =====================================================
-- Migration 136 : commandes d'achat, date de bascule en valeur par defaut
--   purchase_order.date_bascule (AAAA-MM-JJ, ecran Valeurs par defaut,
--   module commandeAchat) devient la seule date de bascule :
--     - ORDER_DATE de toutes les commandes IFS ;
--     - borne de creation : seules les commandes SAP creees AVANT cette date
--       sont reprises (sql/commandeAchat/02_*) ;
--     - point de depart de la fenetre purchase_order.mois_anteriorite (04_*).
--   Elle remplace :
--     - la valeur par defaut purchase_order.order_date (migration 104), reprise
--       ici avec sa valeur courante puis supprimee ;
--     - la borne date_fin = 2026-08-31 saisie en base dans module_params
--       (sans ecran), retiree.
-- Idempotent.
-- =====================================================
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
SELECT 'commandeAchat', 'clean_data.purchase_order', 'date_bascule', 'STANDARD', 'CONSTANTE',
       COALESCE((SELECT valeur FROM public.etl_default_values
                  WHERE table_cible = 'clean_data.purchase_order' AND colonne = 'order_date' AND variante = 'STANDARD'),
                '2026-09-01'),
       'Date de bascule (AAAA-MM-JJ) : ORDER_DATE des commandes IFS, seules les commandes SAP creees avant cette date sont reprises, debut de la fenetre mois_anteriorite. Source : sql/commandeAchat/02_* et 04_*',
       'migration_136'
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

DELETE FROM public.etl_default_values
 WHERE table_cible = 'clean_data.purchase_order' AND colonne = 'order_date';

UPDATE public.etl_target_tables
   SET module_params = module_params - 'date_fin', last_modified = CURRENT_TIMESTAMP
 WHERE python_module = 'etl_commande_achat.py' AND module_params ? 'date_fin';

UPDATE public.etl_target_tables
   SET module_params = NULL
 WHERE python_module = 'etl_commande_achat.py' AND module_params = '{}'::jsonb;
