-- Migration 105 : transcodification des centres de couts SAP -> IFS
-- (categorie COST_CENTER, systeme source SAP, systeme cible IFS).
--
-- Source : sql/commandeAchat/docs/centredecouts.csv (206 lignes, cp1252, sans en-tete :
-- CC SAP ; libelle SAP ; CC IFS ; libelle IFS ; site ; secteur).
-- REMPLACE les valeurs existantes (dont les 77 deduites du fichier Lot11 V2 par la
-- migration 104) : DELETE de la categorie puis INSERT.
-- Lue par clean_data.alimenter_purchase_order() (PRE_ACCOUNTING_ID des commandes
-- d'achat, pre-imputation CENTRE_COUT=<cc>) : relancer « Recalculer » sur l'ecran
-- Finance > Commandes d'achat pour l'appliquer.
--
-- Un code SAP ne peut avoir qu'un code IFS (contrainte unique_transcodification).
-- Le fichier en eclate deux ; regle retenue : le code IFS identique au code SAP
-- s'il existe, sinon le premier du fichier. Ecartes :
--   92E210900 -> 92E210960
--   92E310900 -> 92E310920
--   92E310900 -> 92E310930
--   92E310900 -> 92E310940
-- A arbitrer par le metier si ces centres doivent ventiler vers un autre code IFS.

BEGIN;

DELETE FROM public."TranscodificationTable"
WHERE category = 'COST_CENTER' AND source_system = 'SAP' AND target_system = 'IFS';

INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '903028', '903028', 'Fond. Fil Mec. St.CS -> FOND. FIL MECAL CS (Castel / Castel)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '903050', '903050', 'Rebuts -> REBUTS CASTEL (Castel / Castel)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '903095', '903095', 'Crasses -> CRASSES CASTEL (Castel / Castel)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '921001', '921001', 'SJ Alumine -> SJ ALUMINE (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '922001', '922001', 'Anodes SJ -> ANODES SJ (Saint-Jean-de-Maurienne / Carbone)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '923011', '923011', 'Fond. Plq.  Alu SJ -> FOND. PLQ. 1000 SJ (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '923012', '923012', 'Fond. Plq. 3000 SJ -> FOND. PLQ. 3000 SJ (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '923013', '923013', 'Fond. Plq. 5000 SJ -> FOND. PLQ. 5000 SJ (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '923016', '923016', 'Fond. Plq. 8000 SJ -> FOND. PLQ. 8000 SJ (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '923022', '923022', 'Fond. Fil Conduct.SJ -> FOND. FIL CONDUCTAL.SJ (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '923023', '923023', 'Fond. Fil Almelec SJ -> FOND. FIL ALMELEC SJ (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '923024', '923024', 'Fond. Fil Mecal SJ -> FOND. FIL MECAL SJ (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '923030', '923030', 'Fonderie Tés SJ -> FONDERIE TÉS SJ (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '923050', '923050', 'Rebuts -> REBUTS (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '923071', '923071', 'Fond Lingots 1000 SJ -> FOND LINGOTS 1000 SJ (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '923072', '923072', 'Fond Ling alliés SJ -> FOND LING ALLIÉS SJ (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '923095', '923095', 'Crasses -> CRASSES (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '90A230010', '90A230010', 'M.O  à répartir -> M.O Castelsarrasin (Castel / Castel)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92A230015', '90A230015', 'ETT  Fonderie -> ETT  Castelsarrasin (Castel / Castel)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '90A996060', '90A996060', 'Energie électrique -> Achat électricité pour production CS (Castel / Castel)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '90S131100', '90C130000', 'Assurances -> Finances production Cs (Castel / Castel)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '90D995050', '90C139999', 'Prime Interessement -> Finances hors production CS (Castel / Castel)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '90S240010', '90C240010', 'Laboratoire -> Laboratoire (Castel / Castel)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '90E230000', '90E230000', 'Maint. Ch. Géné. FO -> Maintenance Castelsarrasin (Castel / Castel)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '90G598230', '90G598230', 'Territoire Castel -> Territoire Castel (Castel / Castel)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '90G909000', '90G909000', 'Projets exploitat CS -> Projets OPEX Castel (Castel / Castel)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '90S110000', '90S110000', 'Frais de Site -> Frais Communs Castelsarrasin (Castel / Castel)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '90S230000', '90S230000', 'Char. Gen. Fonderie -> Charges Fonderie Castelsarrasin (Castel / Castel)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '90S252000', '90S252000', 'Environnement Déchet -> Environnement Déchets Castelsarrasin (Castel / Castel)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '90S310000', '90S310000', 'Maintenance -> Maintenance Castel (Castel / Castel)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '90V300028', '90V300028', 'Trans/Ventes Fil Mec -> Transport sur Ventes Castel (Castel / Castel)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92A210020', '92A210020', 'M.O  Carbone -> Rémunération Opérateurs (Saint-Jean-de-Maurienne / Carbone)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92A210025', '92A210025', 'ETT  Carbone -> ETT  Carbone (Saint-Jean-de-Maurienne / Carbone)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92A220030', '92A220030', 'M.O  Electrolyse -> M.O  Electrolyse (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92A220035', '92A220035', 'ETT  Electrolyse -> ETT  Electrolyse (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92A230010', '92A230010', 'M.O  Fonderie -> M.O  Fonderie (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92A239000', '92A239000', 'M.O  Controleurs FO -> M.O  Controleurs FO (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92A250010', '92A250010', 'M.O  Captation -> M.O  Captation (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92A250015', '92A250015', 'ETT  Captation -> ETT  Captation (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92A310030', '92A310030', 'M.O  Maintenance -> M.O  Maintenance (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S110000', '92C110000', 'Direction -> Direction (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S120000', '92C120000', 'Relations Sociales -> Relations Sociales (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S120050', '92C120050', 'Groupe de travail énergie -> Groupe de travail énergie (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S120060', '92C120060', 'Comite d''Entreprise -> Comite d''Entreprise (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S120080', '92C120080', 'Recrutement -> Recrutement (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S120100', '92C120100', 'Serv. intér. -> Services intérieurs (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S120120', '92C120120', 'Juridique -> Juridique (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S120130', '92C120130', 'Vestiaires Douches -> Vestiaires Douches (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S120150', '92C120150', 'Paie -> Paie (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S120155', '92C120155', 'Standard Téléphone -> Téléphone (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S121020', '92C121020', 'Frais & Prestations annexes -> Frais & Prestations annexes (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S123010', '92C123010', 'Formation -> Formation (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S123020', '92C123020', 'SIRH & projets -> SIRH & Projets (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S131000', '92C130000', 'Impots taxes loc. -> Finances production (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92D995050', '92C139999', 'Prime Interessement -> Finances hors production (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S140000', '92C140000', 'Informatique -> Informatique (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S150000', '92C150000', 'Prévention + RHP -> Prévention + RHP (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S150010', '92C150010', 'Prévention -> Prévention (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S150020', '92C150020', 'Qualité -> Qualité (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S151010', '92C151010', 'Surveillance -> Surveillance (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S160000', '92C160000', 'Médecine du Travail -> Médecine du Travail (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S180000', '92C180000', 'Améliorat. continue -> Améliorat. continue (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S238000', '92C238030', 'Assurance Quali. Pro -> Controle Qualité Produits finis (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S240010', '92C240010', 'Laboratoire -> Laboratoire (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S240020', '92C240020', 'Développement produit -> Developpement Produit (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S252000', '92C252000', 'Frais Commun Environ -> Frais Communs Environnement (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S252010', '92C252010', 'Rej. Gazeux  + Liq. -> Rej. Gazeux  + Liq. (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S252020', '92C252020', 'Dechets Solides -> Dechets Solides (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S252040', '92C252040', 'Indemnisations -> Indemnisations (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S311010', '92C311010', 'Bureau d''etudes -> Bureau d''etudes (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S319000', '92C319000', 'Réseau Air -> Réseau Air (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S319100', '92C319100', 'Réseau Eau Potable -> Réseau Eau Potable (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S319150', '92C319150', 'Réseau Eau Industrielle -> Réseau Eau Industrielle (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S330010', '92C330010', 'Achats -> Achats (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S330020', '92C330020', 'Magasin general -> Magasin général (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92D220100', '92D220100', 'Provision ARO démantelement SJ -> Provision ARO démantelement SJ (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92D993100', '92D993100', 'Ventes prest. divers -> Ventes prest. divers (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E120110', '92E120100', 'Batiments généraux -> Services Généraux (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E120140', '92E120140', 'Véhicules maintenance -> Engins maintenance (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E120150', '92E120150', 'Téléphone -> Telecom (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210025', '92E210025', 'Conc. Recyclés Ano. -> Concassage recyclés (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E210310', '92E210030', 'Batiments électricit -> Tour à Pate (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E210420', '92E210040', 'alimentation evacuat -> Cuisson (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E210501', '92E210050', 'Petit outillage GAZ. -> Gazetterie (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E210644', '92E210060', 'convoyeurs aeriens -> Scellement anodes (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E210800', '92E210800', 'Engins loc carbone -> Engins carbone (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E210900', '92E210900', 'Gros Entretien Carbo -> Gros Entretiens Carbone (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E220172', '92E220010', 'depotage alumine -> Frais Communs Electrolyse (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E220500', '92E220050', 'batiments - electric -> Electrolyse Série F (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E220660', '92E220060', 'Cuves G  (DPAA) -> Electrolyse Série G (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E220732', '92E220070', 'cribles et broyeurs -> Traitement Bain (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E220130', '92E220100', 'arrivees edf -> SOUS-STATION (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E210387', '92E220110', 'informatique tap -> MAIR (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E220631', '92E220800', 'cometto 1 -> Engins electrolyse (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E220900', '92E220900', 'Gros Entretien Elect -> Gros Entretiens Electrolyse (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E221000', '92E221000', 'batiments-electricit -> Brasquages F + G (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E230000', '92E230000', 'batiments-elec-secur -> Charges Générales Fonderie (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E230900', '92E230900', 'Gros Entretien Fonde -> Gros Entretiens Fonderie (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E231000', '92E231000', 'fours 10 et 11 -> Fours à Plaques + Tés + RFI (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E231523', '92E231050', 'fours 0 -> Fours à Fils (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E231800', '92E231800', 'Engins loc Fonderie -> Engins fonderie (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E232000', '92E232000', 'c.c.v -> CCV Plaques + Tés (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E232200', '92E232020', 'metier b -> CCV Tés Fosse B (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E232070', '92E232070', 'Machine à lingots -> Machine à lingots (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E232071', '92E232071', 'Fours chaîne lingots -> Four Chaîne à lingots + Table élévatrice (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E233393', '92E233030', 'injecteurs m 81 -> Ligne à Fil M 81 (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E233410', '92E233040', 'Train à fil M 98 -> Ligne à Fil M 98 (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E233190', '92E233050', 'roules de coulee m02 -> Ligne à Fil P 02 (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E234200', '92E234020', 'mixal -> Mixal + écrémeuse (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E234400', '92E234040', 'four stein -> Four Stein (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E235000', '92E235000', 'parachevement -> Finition Plaques + Tés + Compacteuse (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E235102', '92E235010', 'condit. chaine emba. -> Finition Fils (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S239000', '92E239000', 'F M D Communs -> Expéditions (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E240100', '92E240010', 'entretien laboratoir -> Laboratoire (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E250310', '92E250030', 'filtres-ventilateurs -> Captation F (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E250400', '92E250040', 'automat-communs-secu -> Captation G (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E250501', '92E250050', 'automat-communs-secu -> Captation F. à cuire (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E310000', '92E310000', 'fc maintenance -> FCSM Communs (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E310900', '92E310910', 'Gros Entretien Maint -> Gros Entretiens ATC (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E331016', '92E311000', 'entretien toitures -> Entretien toitures usine (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E331112', '92E311100', 'Entretien clim usine -> Entretien clim usine (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E331110', '92E311200', 'entretien locotracte -> Entretien portes usine (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E312005', '92E312005', 'controle -> FCSM Métrologie (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E312010', '92E312010', 'MAIR -> FCSM MAIR (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E312020', '92E312020', 'maconnerie -> FCSM ATC (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E312030', '92E312030', 'atelier élec. -> FCSM SST (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E312040', '92E312040', 'garage -> FCSM Garage (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E312045', '92E312045', 'Commun Astreinte -> FCSM Astreinte (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E312050', '92E312050', 'carbone -> FCSM Carbone (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E312060', '92E312060', 'scellement -> FCSM Scellement (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E312070', '92E312070', 'electrolyse -> FCSM Electrolyse (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E312080', '92E312080', 'fonderie -> FCSM Fonderie (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E319000', '92E319000', 'entretien reseau air -> Air Comprimé (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E311010', '92E321000', 'Métrologie Périodique et curatif -> Métrologie périodique et curatif (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E220160', '92E321100', 'Contrôles règlementaires -> Contrôles réglementaires (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E330020', '92E330020', 'entretien magasin ge -> Rénovables (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92E331000', '92E331000', 'entretien embranchem -> Manutention (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92G598234', '92G598234', 'Refact & Subventions -> Refact & Subventions (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92G599901', '92G599901', 'Projet ERP -> Projet ERP (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92G909001', '92G909001', 'Projets exploitat FO -> Projets OPEX Fonderie (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92G909002', '92G909002', 'Projets exploitat EL -> Projets OPEX Electrolyse (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92G909003', '92G909003', 'Projet expl.Labo&Cap -> Projets OPEX Labo&Captation (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92G909004', '92G909004', 'Projet expl.Carbone -> Projets OPEX Carbone (Saint-Jean-de-Maurienne / Carbone)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92G909005', '92G909005', 'Projet expl.Autres -> Projets OPEX Commun (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92G909008', '92G909008', 'Réparation cuves -> Réparation cuves (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92G909011', '92G909011', 'Territoire Fonderie -> Territoire Fonderie (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92G909012', '92G909012', 'Territoire Electroly -> Territoire Electrolyse (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92G909014', '92G909014', 'Territoire Carbone -> Territoire Carbone (Saint-Jean-de-Maurienne / Carbone)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92G909015', '92G909015', 'Territoire Autres -> Territoire Autres (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92H330741', '92H330800', 'LRF EXPLOIT.  PROTOS -> LRF MAGASIN DIRECT (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S110100', '92S110100', 'Communication -> Communication (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S120160', '92S120160', 'Restaur.Entreprise -> Restaurant d''entreprise (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S121000', '92S121000', 'Foyer -> Foyer (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S130000', '92S130000', 'Comptabilité -> Comptabilité (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210000', '92S210000', 'Frais Commun Carbone -> Frais Communs Carbone (Saint-Jean-de-Maurienne / Carbone)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210020', '92S210020', 'Manut recyclés -> Manutention recyclés (Saint-Jean-de-Maurienne / Carbone)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210030', '92S210030', 'TAP -> TAP (Saint-Jean-de-Maurienne / Carbone)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210040', '92S210040', 'FAC -> FAC (Saint-Jean-de-Maurienne / Carbone)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210050', '92S210050', 'Gazetterie -> Gazetterie (Saint-Jean-de-Maurienne / Carbone)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210060', '92S210060', 'Scellement -> Scellt Anodes Usine (Saint-Jean-de-Maurienne / Carbone)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210061', '92S210061', 'Tiges et pattes F -> Tiges F (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210062', '92S210062', 'Tiges et pattes G -> Tiges G (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210200', '92S210200', 'Logistique coke BP -> Coût logis.Coke Gand (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210201', '92S210201', 'Logistique coke OMV -> Log. coke Burghausen (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210202', '92S210202', 'Logistique coke Ghent -> Log. coke Commun (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210590', '92S210500', 'Gazetterie Mastiq. -> Gazetterie Cloisons (Saint-Jean-de-Maurienne / Carbone)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210990', '92S210990', 'Dechets Solides Carb -> Dechets Solides Carbone (Saint-Jean-de-Maurienne / Carbone)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S319300', '92S220010', 'Sous Station Energie -> Frais Communs Electrolyse (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S220020', '92S220020', 'Tuyaux de coulée -> Tuyaux de coulée (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S220030', '92S220030', 'Capots triangles -> Capots (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S220040', '92S220040', 'Goulottes alumine -> Goulottes alumine (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S220050', '92S220050', 'Série F -> Séries F & G (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S220070', '92S220070', 'Traitement Bain -> Traitement Bain (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S220090', '92S220090', 'Casse Engins -> Casse Engins (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S220099', '92S220099', 'PC + Amélioration -> Masques / MDA (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S220100', '92S220100', 'Formation -> Formation Electrolyse (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S220200', '92S220200', 'Logistique Alumine -> Log. Alumine Trains (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S220201', '92S220201', 'Log. Alumine P14 -> Log. Alumine P14 (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S220202', '92S220202', 'Surestaries Alumine -> Transp Amont Alumine (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S220990', '92S220990', 'Dechets Solides Elec -> Dechets Solides Elec (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S210070', '92S221000', 'Scellt Cathodes Usin -> Brasquages F + G (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S221200', '92S221200', 'Debrasquage/Nettoyage ss sol -> Debrasquage/Nettoyage ss-sol (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S230000', '92S230000', 'Char. Gen. Fonderie -> Charges Générales Fonderie (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S230090', '92S230090', 'Chariots : accidents -> Chariots, portes, casses engins (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S231000', '92S232000', 'Fours Plaques + Tés -> CCV Plaques + Tés (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S232020', '92S232001', 'CCV  Tés Fosse B -> CCV  Tés Fosse B (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S232070', '92S232070', 'Machine à lingots -> Machine à lingots (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S233030', '92S233030', 'Ligne à Fil M 81 -> Ligne à Fil M 81 (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S231050', '92S233035', 'Fours à Fils -> Ligne à fil commune (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S233040', '92S233040', 'Ligne à Fil M 98 -> Ligne à Fil M 98 (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S233050', '92S233050', 'Ligne à Fil P 02 -> Ligne à Fil P 02 (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S235010', '92S235010', 'Finition Fils -> Finition Fils (palettes) (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S239100', '92S239100', 'Crasses -> Crasses (logisitique) (Saint-Jean-de-Maurienne / Fonderie)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S250020', '92S250020', 'Frais Commun Capt. -> Frais Communs Captation (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S250030', '92S250030', 'Frais Captation F -> Frais Captation F (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S250040', '92S250040', 'Frais Captation G -> Frais Captation G (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S250050', '92S250050', 'Frais Captation FAC -> Frais Captation FAC (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S251000', '92S251000', 'Traitement Brasques -> Traitement Brasques (Saint-Jean-de-Maurienne / Electrolyse)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S252030', '92S252030', 'Dechets Solides à répartir -> Dechets Solides à répartir (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S310000', '92S310000', 'Maintenance -> Maintenance (Saint-Jean-de-Maurienne / Maintenance)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92S350000', '92S350000', 'Administration des ventes -> Administration des ventes (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
VALUES ('COST_CENTER', 'SAP', 'IFS', '92V300022', '92V300022', 'Trans/Ventes Fnium -> Transport sur Ventes (Saint-Jean-de-Maurienne / Communs)', 'migration_105', true);

-- Controle : une ligne par code SAP du fichier
SELECT count(*) AS centres_de_couts FROM public."TranscodificationTable"
WHERE category = 'COST_CENTER' AND source_system = 'SAP' AND target_system = 'IFS';

COMMIT;
