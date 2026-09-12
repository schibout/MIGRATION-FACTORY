-- ============================================================================
-- Requete d'export Commandes d'achat dans etl_export_queries
-- Description : enregistre clean_data.commande_achat_ifs pour l'export
--               dynamique (categorie "Commande Achat"), utilisee par la page
--               frontend Export Commandes d'achat (/export/commandes-achat).
--               Table alimentee par le module ETL etl_commande_achat.py.
-- Idempotent : supprime puis reinsere les entrees de la categorie.
-- ============================================================================

DELETE FROM public.etl_export_queries WHERE category = 'Commande Achat';

INSERT INTO public.etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by)
VALUES (
    'commande_achat_ifs',
    'clean_data',
    'Commandes d''achat SAP ouvertes (format IFS)',
    'site, societe_sap, num_commande_sap, num_ligne_sap, fournisseur_sap, fournisseur_ifs, nom_fournisseur, fournisseur_facturation_sap, fournisseur_facturation_ifs, type_ligne_ifs, article_sap, designation, qte_commandee, qte_restant_livrer, qte_restant_facturer, unite_achat, prix_net_unitaire, montant_restant_livrer, montant_restant_facturer, devise, taux_change, date_creation, date_livraison_planifiee, date_reception_souhaitee, date_livraison_promise, acheteur_sap, condition_paiement, condition_livraison, mode_expedition, adresse_livraison, code_postal_livraison, ville_livraison, pays_livraison, pre_imputation_projet',
    'Commandes d''achat SAP ouvertes (reliquat a livrer > 0) au format de reprise IFS : une ligne par poste EKPO avec fournisseur IFS (fichier de selection), quantites commandees / restant a livrer / restant a facturer, prix net, dates de livraison (EKET) et de reception (EKBE), adresse de livraison et pre-imputation (EKKN). Snapshot recharge par le module ETL Commandes d''achat.',
    'Commande Achat',
    true,
    'ETL_SYSTEM',
    'ETL_SYSTEM'
);

SELECT id, table_name, display_name, category, is_active
FROM public.etl_export_queries
WHERE category = 'Commande Achat';
