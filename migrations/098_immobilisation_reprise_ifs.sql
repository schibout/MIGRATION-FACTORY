-- =====================================================
-- Migration 098 : reprise IFS des immobilisations
-- Source : classeur metier « Extrac Samir 20260818 sap_immobilisations_synthese
--          _STATUTAIRE.xlsx » (sql/immobilisation/source/), onglets
--          « Conversion cpte général » et « Travail ».
-- 1. Transcodification FA_ACCOUNT (SAP -> IFS) : compte PCG SAP de la fiche
--    (T095 zone 02) -> compte IFS 6 chiffres ; description = libelle + PCG FR.
--    3 comptes presents dans les fiches manquent au classeur (46112000,
--    46322100, 14141000) : a completer dans l'ecran Transcodification.
-- 2. FA_OBJECT_GROUP : classe d'immobilisation (ANLA-ANLKL) -> OBJECT_GROUP_ID,
--    groupe majoritaire de l'onglet Travail (16 classes, 21 groupes). Les classes sans
--    groupe dans le classeur (en-cours, amenagements electriques...) ne sont
--    pas seedees : a saisir par le metier.
-- 3. FA_OBJECT_GROUP_IMMO : exceptions fiche par fiche (numero d'immobilisation
--    -> groupe) pour les 4 classes a sous-groupes (00411000, 00451000,
--    00625000, 00641000). Prime sur FA_OBJECT_GROUP au chargement.
-- 4. Valeur par defaut date_bascule_ifs (2026-06-30) : une immobilisation
--    sortie a cette date ou avant est exclue de la reprise.
-- Lues par clean_data.alimenter_immobilisation() (sql/immobilisation/02_*).
-- Idempotent (ON CONFLICT DO NOTHING).
-- =====================================================

-- 1. Comptes PCG SAP -> IFS
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '45252100', '205010', 'LOGICIEL INFORMATIQUE (PCG FR 20552100)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '46111100', '211110', 'TERRAIN NU (PCG FR 21111100)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '46150000', '212010', 'AGENCEMENTS ET AMENAGEMENTS DE TERRAINS (PCG FR 21250000)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '46211000', '213110', 'BATIMENT ET CONSTRUCTION (PCG FR 21311000)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '46251000', '213510', 'INSTALL AMEN AGENC BATIMENTS (PCG FR 21351000)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '46311000', '215110', 'INSTALL TECHNIQUES - MAT & OUTILL INDUST (PCG FR 21511000)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '46312000', '215140', 'INSTALL TECHNIQUES - CUVES ELECTROLYSE (PCG FR 21511200)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '46317100', '215140', 'INSTALL TECHNIQUES - CUVES ELECTROLYSE (PCG FR 21514100)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '46351000', '215710', 'AGENC AMENAG MAT ET OUT INDUSTRIELS (PCG FR 21571000)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '46610000', '218200', 'MATERIEL DE TRANSPORT (PCG FR 21820000)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '46720000', '218320', 'MATERIEL DE BUREAU ET MATERIEL INFORMATIQUE (PCG FR 21832000)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '46810000', '218400', 'MOBILIER DE BUREAU (PCG FR 21840000)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '41531100', '231000', 'IMMOBILISATIONS CORPORELLES EN COURS (PCG FR 23181100)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '41532000', '231010', 'IMMOBILISATIONS CORPORELLES EN COURS - CUVES (PCG FR 23182000)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '21311100', '274310', 'PRETS DIVERS AU PERSONNEL (PCG FR 27432210)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '21331000', '275110', 'DEPOTS ET CAUTIONNEMENTS (PCG FR 27511000)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '45352100', '280501', 'AMORT AUTRES IMMO INCORP LOGICIELS (PCG FR 28055210)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '47116000', '281201', 'AMORT AGENCEMENTS AMENAGEMENTS TERRAINS (PCG FR 28116000)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '47211000', '281311', 'AMORT DES BATIMENTS ET CONSTRUCTIONS (PCG FR 28131000)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '47251000', '281351', 'AMORT INSTALL AMENAGTS AGENCTS BAT (PCG FR 28135100)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '47311000', '281351', 'AMORT INSTALL AMENAGTS AGENCTS BAT (PCG FR 28151100)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '47312000', '281511', 'AMORT INSTALL TECHNIQUES MAT ET OUTILLAGES INDUS (PCG FR 28151120)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '47317100', '281511', 'AMORT INSTALL TECHNIQUES MAT ET OUTILLAGES INDUS (PCG FR 28151410)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '47351000', '281571', 'AMORT AGENCTS AMENAGTS MAT ET OUT INDUSTRIELS (PCG FR 28157100)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '47610000', '281820', 'AMORT MATERIELS DE TRANSPORTS (PCG FR 28182000)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '47720000', '281832', 'AMORT MATERIEL DE BUREAU ET MATERIEL INFORMATIQUE (PCG FR 28183200)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '47810000', '281840', 'AMORT MOBILIER DE BUREAU (PCG FR 28184000)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_ACCOUNT', 'SAP', 'IFS', '19440000', '231000', 'En cours (sans compte PCG FR)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;

-- 2. Classe d'immobilisation -> groupe objet IFS
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP', 'SAP', 'IFS', '00250000', '250-001', 'Logiciels informatiques', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP', 'SAP', 'IFS', '00312000', '312-001', 'Terrains aménagés', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP', 'SAP', 'IFS', '00381000', '381-001', 'Agencement aménagement terrains industriels', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP', 'SAP', 'IFS', '00411000', '411-001', 'Bât industr lourds', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP', 'SAP', 'IFS', '00416000', '416-001', 'Travaux d''art', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP', 'SAP', 'IFS', '00451000', '451-001', 'Aménagement des bât. industriels sur sol propre', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP', 'SAP', 'IFS', '00453000', '451-001', 'Aménagement maisons', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP', 'SAP', 'IFS', '00501000', '501-001', 'Installations compl.séries', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP', 'SAP', 'IFS', '00505000', '505-001', 'Autres matériels électriques', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP', 'SAP', 'IFS', '00515000', '515-001', 'Matériel et outillage', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP', 'SAP', 'IFS', '00517100', '517-101', 'Brasquage statutaire', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP', 'SAP', 'IFS', '00581000', '581-001', 'Agencement Installation', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP', 'SAP', 'IFS', '00621000', '621-002', 'Voitures tourisme camionnettes', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP', 'SAP', 'IFS', '00625000', '625-003', 'Matériels de manutention & autres mat.de transport', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP', 'SAP', 'IFS', '00631000', '631-001', 'Matériels de bureau', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP', 'SAP', 'IFS', '00641000', '641-001', 'Matériel informatique et réseaux', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;

-- 3. Exceptions par numero d'immobilisation
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000000087', '451-004', 'Classe 00451000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000000201', '451-004', 'Classe 00451000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000002227', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000002254', '641-003', 'Classe 00641000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000002259', '641-002', 'Classe 00641000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000002260', '641-002', 'Classe 00641000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000002392', '641-003', 'Classe 00641000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000002503', '641-003', 'Classe 00641000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000002511', '641-003', 'Classe 00641000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000002751', '411-003', 'Classe 00411000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000002908', '411-003', 'Classe 00411000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000002909', '411-003', 'Classe 00411000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003035', '641-003', 'Classe 00641000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003036', '641-003', 'Classe 00641000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003037', '641-003', 'Classe 00641000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003371', '641-003', 'Classe 00641000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003372', '641-003', 'Classe 00641000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003373', '641-003', 'Classe 00641000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003463', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003464', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003465', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003466', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003467', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003468', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003469', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003470', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003612', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003613', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003614', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003615', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003616', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003617', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003618', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003626', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003627', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003628', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003629', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003630', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003631', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003634', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003635', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003636', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003637', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003638', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003639', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003640', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003641', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003642', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003656', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003657', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003658', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003659', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003660', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003661', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003662', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003663', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003664', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003665', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003666', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003667', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003668', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003679', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003850', '411-003', 'Classe 00411000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000003892', '411-003', 'Classe 00411000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000004205', '411-003', 'Classe 00411000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000004254', '411-003', 'Classe 00411000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000004395', '411-003', 'Classe 00411000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000004427', '411-003', 'Classe 00411000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000004690', '411-003', 'Classe 00411000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000004831', '411-003', 'Classe 00411000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000004832', '411-003', 'Classe 00411000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005593', '641-003', 'Classe 00641000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005724', '451-002', 'Classe 00451000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005747', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005748', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005749', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005750', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005751', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005752', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005753', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005754', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005755', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005756', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005757', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005758', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005759', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005760', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005761', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005762', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005763', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005764', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005765', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005766', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005767', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005796', '621-001', 'Classe 00625000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005801', '641-003', 'Classe 00641000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005802', '641-003', 'Classe 00641000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005982', '451-002', 'Classe 00451000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('FA_OBJECT_GROUP_IMMO', 'SAP', 'IFS', '240000005996', '451-002', 'Classe 00451000 : groupe choisi fiche par fiche (onglet Travail)', 'migration_098')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;

-- 4. Date de bascule IFS (ecran Valeurs par defaut)
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('immobilisation', 'clean_data.immobilisation', 'date_bascule_ifs', 'STANDARD', 'CONSTANTE', '2026-06-30', 'Date de bascule IFS (YYYY-MM-DD) : une immobilisation dont la date de sortie (ANLA-ABGDT) est <= cette date est exclue de la reprise ; apres, elle est reprise sans date de sortie. Source : 02_alimenter_immobilisation.sql', 'migration_098')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

SELECT category, count(*) FROM public."TranscodificationTable" WHERE category LIKE 'FA_%' GROUP BY 1 ORDER BY 1;
