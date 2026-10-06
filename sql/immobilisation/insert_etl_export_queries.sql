-- ============================================================================
-- Requete d'export Immobilisations dans etl_export_queries
-- Description : enregistre clean_data.immobilisation pour l'export dynamique
--               (categorie "Immobilisation"), page /export/immobilisations.
--               Table alimentee par le module ETL etl_immobilisation.py.
-- Idempotent : supprime puis reinsere les entrees de la categorie.
-- ============================================================================

DELETE FROM public.etl_export_queries WHERE category = 'Immobilisation';

INSERT INTO public.etl_export_queries (table_name, table_schema, display_name, column_list, description, category, is_active, created_by, updated_by)
VALUES (
    'immobilisation',
    'clean_data',
    'Immobilisations SAP (format metiers)',
    'societe_sap, num_immobilisation, sous_numero, cle_immobilisation, libelle, libelle_complementaire, classe_immo, famille_immo, indicateur_suppression, numero_serie, pays, groupe_evaluation_1, groupe_evaluation_2, groupe_evaluation_3, groupe_evaluation_4, projet, cle_comptes_immo, libelle_cle_comptes_immo, compte_immobilisation, compte_amort_cumule, compte_dotation_amort, date_acquisition, date_premiere_acquisition, date_debut_amort, date_fin_amort_estimee, duree_amort_annees, duree_amort_periodes, duree_amort_totale_mois, zone_amortissement, type_amortissement, libelle_type_amortissement, taux_amort_estime, centre_cout, libelle_centre_cout, site_sap, secteur_sap, libelle_secteur, emplacement, immo_origine, sous_numero_origine, date_origine, numero_inventaire, fabricant, type_modele, fournisseur, quantite, unite, ordre_investissement, zone_valorisation, exercice_valorisation, valeur_acq_debut_exercice, mouvements_acq_exercice, sorties_exercice, valeur_acq_fin_exercice, amort_cumules, vnc, dotation_annuelle, blocage_comptabilisation, date_sortie, date_desactivation, reprise_ifs, motif_exclusion, compte_immobilisation_ifs, compte_amort_cumule_ifs, object_group_id, site_ifs, element_otp, libelle_otp',
    'Immobilisations SAP STJN au format de l''extraction transmise aux metiers : une ligne par immobilisation, comptes T095 zone 02, parametres d''amortissement ANLB, imputation ANLZ, valeurs statutaires zone 02 a l''ouverture de l''exercice (acquisition, amortissements cumules, VNC). Colonnes de reprise IFS (statut, comptes IFS, groupe objet, site, OTP) calculees depuis le classeur metier (migration 098). Snapshot recharge par le module ETL Immobilisations.',
    'Immobilisation',
    true,
    'ETL_SYSTEM',
    'ETL_SYSTEM'
);

SELECT id, table_name, display_name, category, is_active
FROM public.etl_export_queries
WHERE category = 'Immobilisation';
