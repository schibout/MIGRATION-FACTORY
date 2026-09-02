# -*- coding: utf-8 -*-
"""
Générateur du dataset texte→SQL pour l'assistant IA local (Migration Factory).
Produit dataset_sap_ia.jsonl au format chat (system/user/assistant), 1 exemple par ligne.
Le SQL est conforme au schéma RÉEL de sap_migration (vérifié par introspection le 2026-06-11).
Usage : python build_dataset.py  (nécessite ai_system_prompt.py dans le même dossier ou le PYTHONPATH)
"""
import json
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ai_system_prompt import SYSTEM_PROMPT

A = "AND (loevm IS NULL OR loevm = '')"          # fournisseur/client actif
M = "mandt = '700'"

# (question, sql, explication)
EXEMPLES = [
# ============ FOURNISSEURS ============
("Combien y a-t-il de fournisseurs actifs ?",
 f"SELECT COUNT(*) AS nb_fournisseurs FROM raw_data.lfa1 WHERE {M} {A}",
 "Compte les fournisseurs non supprimés (loevm vide) du mandant 700."),

("Top 10 des pays par nombre de fournisseurs actifs",
 f"SELECT l.land1, t.landx AS pays, COUNT(*) AS nb FROM raw_data.lfa1 l LEFT JOIN raw_data.t005t t ON t.land1 = l.land1 AND t.spras = 'F' AND t.mandt = '700' WHERE l.{M} AND (l.loevm IS NULL OR l.loevm = '') GROUP BY l.land1, t.landx ORDER BY nb DESC LIMIT 10",
 "Répartition des fournisseurs actifs par pays avec le nom français du pays via t005t."),

("Liste des fournisseurs français sans numéro SIRET",
 f"SELECT lifnr, name1, ort01 FROM raw_data.lfa1 WHERE {M} {A} AND land1 = 'FR' AND (stcd1 IS NULL OR stcd1 = '') ORDER BY name1",
 "Fournisseurs actifs France dont le champ stcd1 (SIRET) est vide."),

("Quels fournisseurs n'ont pas de numéro de TVA intracommunautaire ?",
 f"SELECT lifnr, name1, land1, ort01 FROM raw_data.lfa1 WHERE {M} {A} AND (stceg IS NULL OR stceg = '') ORDER BY land1, name1",
 "Fournisseurs actifs sans TVA intracom (stceg vide)."),

("Fournisseurs actifs sans aucun numéro de téléphone",
 f"SELECT lifnr, name1, ort01, land1 FROM raw_data.lfa1 WHERE {M} {A} AND (telf1 IS NULL OR telf1 = '') AND (telf2 IS NULL OR telf2 = '') ORDER BY name1",
 "Fournisseurs actifs avec telf1 et telf2 vides."),

("Quels fournisseurs actifs n'ont pas d'adresse email ?",
 f"SELECT l.lifnr, l.name1, l.ort01 FROM raw_data.lfa1 l LEFT JOIN raw_data.adr6 a ON a.addrnumber = l.adrnr WHERE l.{M} AND (l.loevm IS NULL OR l.loevm = '') AND (a.smtp_addr IS NULL OR a.smtp_addr = '') ORDER BY l.name1",
 "Jointure lfa1.adrnr vers adr6 (emails) ; les lignes sans smtp_addr n'ont pas d'email."),

("Détecte les doublons de fournisseurs (même raison sociale et même ville)",
 f"SELECT UPPER(TRIM(name1)) AS raison_sociale, ort01, COUNT(*) AS nb, STRING_AGG(lifnr, ', ') AS comptes FROM raw_data.lfa1 WHERE {M} {A} GROUP BY UPPER(TRIM(name1)), ort01 HAVING COUNT(*) > 1 ORDER BY nb DESC",
 "Groupes de fournisseurs actifs partageant name1 normalisé (majuscules, sans espaces de bord) et la même ville."),

("Quels fournisseurs sont bloqués pour les achats ?",
 f"SELECT lifnr, name1, ort01, land1 FROM raw_data.lfa1 WHERE {M} {A} AND sperm = 'X' ORDER BY name1",
 "Fournisseurs actifs avec blocage achats (sperm = 'X')."),

("Fournisseurs bloqués en comptabilité",
 f"SELECT lifnr, name1, ort01 FROM raw_data.lfa1 WHERE {M} {A} AND sperr = 'X' ORDER BY name1",
 "Fournisseurs actifs avec blocage comptable (sperr = 'X')."),

("Donne le taux de complétude des champs principaux des fournisseurs",
 f"SELECT COUNT(*) AS total, ROUND(100.0*COUNT(*) FILTER (WHERE name1 IS NOT NULL AND name1 <> '')/COUNT(*),1) AS pct_nom, ROUND(100.0*COUNT(*) FILTER (WHERE ort01 IS NOT NULL AND ort01 <> '')/COUNT(*),1) AS pct_ville, ROUND(100.0*COUNT(*) FILTER (WHERE pstlz IS NOT NULL AND pstlz <> '')/COUNT(*),1) AS pct_code_postal, ROUND(100.0*COUNT(*) FILTER (WHERE stras IS NOT NULL AND stras <> '')/COUNT(*),1) AS pct_rue, ROUND(100.0*COUNT(*) FILTER (WHERE telf1 IS NOT NULL AND telf1 <> '')/COUNT(*),1) AS pct_telephone, ROUND(100.0*COUNT(*) FILTER (WHERE stcd1 IS NOT NULL AND stcd1 <> '')/COUNT(*),1) AS pct_siret FROM raw_data.lfa1 WHERE {M} {A}",
 "Pourcentage de remplissage des champs critiques via COUNT FILTER sur les fournisseurs actifs."),

("Répartition des conditions de paiement côté achats",
 f"SELECT zterm AS condition_paiement, COUNT(*) AS nb FROM raw_data.lfm1 WHERE {M} {A} GROUP BY zterm ORDER BY nb DESC",
 "Fréquence des conditions de paiement (zterm) dans les fiches achats lfm1 actives."),

("Combien de fournisseurs par devise de commande ?",
 f"SELECT waers AS devise, COUNT(DISTINCT lifnr) AS nb_fournisseurs FROM raw_data.lfm1 WHERE {M} {A} GROUP BY waers ORDER BY nb_fournisseurs DESC",
 "Devises de commande déclarées dans lfm1, comptage distinct par fournisseur."),

("Combien de fournisseurs ont des coordonnées bancaires dans SAP ?",
 "SELECT COUNT(DISTINCT lifnr) AS nb_fournisseurs_avec_banque FROM raw_data.lfbk WHERE mandt = '700'",
 "Comptage distinct des fournisseurs présents dans lfbk (coordonnées bancaires)."),

("Y a-t-il des fournisseurs retenus pour la migration qui n'existent pas dans SAP ?",
 "SELECT f.vendor_no FROM public.fournisseurs_a_conserver f LEFT JOIN raw_data.lfa1 l ON l.lifnr = f.vendor_no AND l.mandt = '700' WHERE l.lifnr IS NULL",
 "Contrôle d'intégrité : numéros de fournisseurs_a_conserver introuvables dans lfa1."),

("Répartition des fournisseurs de la table de travail par statut de validation",
 "SELECT statut_validation, COUNT(*) AS nb FROM raw_data.selection_fournisseurs GROUP BY statut_validation ORDER BY nb DESC",
 "Avancement du nettoyage : comptage par statut_validation dans selection_fournisseurs."),

("Quels fournisseurs ont été ajoutés depuis SAP après la sélection ?",
 "SELECT numero_compte_fournisseur, numero_compte_ifs, nom_1, cle_pays, date_creation_sap FROM clean_data.ifs_fournisseurs WHERE source = 'SAP_NOUVEAU' ORDER BY date_creation_sap DESC",
 "Fournisseurs de ifs_fournisseurs absents du fichier de sélection, repris depuis SAP (colonne source)."),

("Combien de fournisseurs ont été créés dans SAP en 2023 ?",
 f"SELECT COUNT(*) AS nb FROM raw_data.lfa1 WHERE {M} {A} AND erdat LIKE '2023%'",
 "Dates SAP au format varchar YYYYMMDD : filtre LIKE '2023%' sur erdat."),

("Délai de livraison moyen par groupe d'acheteurs",
 f"SELECT ekgrp AS groupe_acheteurs, ROUND(AVG(NULLIF(plifz,'')::numeric),1) AS delai_moyen_jours, COUNT(*) AS nb_fournisseurs FROM raw_data.lfm1 WHERE {M} {A} GROUP BY ekgrp ORDER BY delai_moyen_jours DESC NULLS LAST",
 "Moyenne du délai prévu plifz (varchar casté en numeric, vides neutralisés par NULLIF) par groupe d'acheteurs."),

("Liste des banques des fournisseurs retenus pour la migration",
 "SELECT b.lifnr, l.name1 AS fournisseur, b.bankl, k.banka AS banque, k.swift FROM raw_data.lfbk b JOIN public.fournisseurs_a_conserver f ON f.vendor_no = b.lifnr JOIN raw_data.lfa1 l ON l.lifnr = b.lifnr AND l.mandt = '700' LEFT JOIN raw_data.bnka k ON k.banks = b.banks AND k.bankl = b.bankl AND k.mandt = '700' WHERE b.mandt = '700' ORDER BY l.name1",
 "Coordonnées bancaires (lfbk) des fournisseurs du périmètre, enrichies du nom de banque et du SWIFT via bnka."),

("Fournisseurs retenus pour la migration sans aucune coordonnée bancaire",
 "SELECT f.vendor_no, l.name1, l.ort01 FROM public.fournisseurs_a_conserver f JOIN raw_data.lfa1 l ON l.lifnr = f.vendor_no AND l.mandt = '700' LEFT JOIN raw_data.lfbk b ON b.lifnr = f.vendor_no AND b.mandt = '700' WHERE b.lifnr IS NULL ORDER BY l.name1",
 "Anti-jointure sur lfbk : fournisseurs du périmètre de migration sans ligne bancaire."),

# ============ ARTICLES / STOCKS ============
("Nombre d'articles actifs par type d'article",
 "SELECT mtart AS type_article, COUNT(*) AS nb FROM raw_data.mara WHERE mandt = '700' AND (lvorm IS NULL OR lvorm = '') GROUP BY mtart ORDER BY nb DESC",
 "Répartition des articles actifs (lvorm vide) par type SAP (ROH, FERT, HALB...)."),

("Répartition des articles par division",
 "SELECT spart AS division, COUNT(*) AS nb FROM raw_data.mara WHERE mandt = '700' AND (lvorm IS NULL OR lvorm = '') GROUP BY spart ORDER BY nb DESC",
 "Comptage des articles actifs par division (spart)."),

("Combien d'articles actifs dans les divisions 2200 et 9200 ?",
 "SELECT spart, COUNT(*) AS nb FROM raw_data.mara WHERE mandt = '700' AND (lvorm IS NULL OR lvorm = '') AND spart IN ('2200','9200') GROUP BY spart",
 "Volumétrie du périmètre projet (divisions 2200 et 9200)."),

("Articles actifs sans désignation en français",
 "SELECT LTRIM(m.matnr,'0') AS article, m.mtart, m.matkl FROM raw_data.mara m LEFT JOIN raw_data.makt k ON k.matnr = m.matnr AND k.spras = 'F' AND k.mandt = '700' WHERE m.mandt = '700' AND (m.lvorm IS NULL OR m.lvorm = '') AND k.matnr IS NULL ORDER BY m.matkl",
 "Anti-jointure sur makt en langue F : articles sans texte français."),

("Top 10 des groupes de marchandises par nombre d'articles, avec leur libellé",
 "SELECT m.matkl, t.wgbez AS libelle, COUNT(*) AS nb FROM raw_data.mara m LEFT JOIN raw_data.t023t t ON t.matkl = m.matkl AND t.spras = 'F' AND t.mandt = '700' WHERE m.mandt = '700' AND (m.lvorm IS NULL OR m.lvorm = '') GROUP BY m.matkl, t.wgbez ORDER BY nb DESC LIMIT 10",
 "Groupes de marchandises les plus peuplés, libellés français via t023t."),

("Stock libre total par site et magasin",
 "SELECT werks AS site, lgort AS magasin, SUM(NULLIF(labst,'')::numeric) AS stock_libre FROM raw_data.mard WHERE mandt = '700' AND (lvorm IS NULL OR lvorm = '') GROUP BY werks, lgort ORDER BY stock_libre DESC NULLS LAST",
 "Somme du stock à utilisation libre (labst, varchar casté) par site/magasin."),

("Quels articles ont du stock bloqué ?",
 "SELECT LTRIM(d.matnr,'0') AS article, k.maktx, d.werks, d.lgort, NULLIF(d.speme,'')::numeric AS stock_bloque FROM raw_data.mard d LEFT JOIN raw_data.makt k ON k.matnr = d.matnr AND k.spras = 'F' AND k.mandt = '700' WHERE d.mandt = '700' AND (d.lvorm IS NULL OR d.lvorm = '') AND NULLIF(d.speme,'')::numeric > 0 ORDER BY stock_bloque DESC LIMIT 50",
 "Lignes de mard avec stock bloqué (speme) positif, avec désignation française."),

("Top 20 des articles par valeur de stock",
 "SELECT LTRIM(b.matnr,'0') AS article, k.maktx AS designation, b.bwkey AS site, SUM(NULLIF(b.salk3,'')::numeric) AS valeur FROM raw_data.mbew b LEFT JOIN raw_data.makt k ON k.matnr = b.matnr AND k.spras = 'F' AND k.mandt = '700' WHERE b.mandt = '700' AND (b.lvorm IS NULL OR b.lvorm = '') GROUP BY b.matnr, k.maktx, b.bwkey ORDER BY valeur DESC NULLS LAST LIMIT 20",
 "Classement par valeur de stock (salk3) avec désignation, par article et site de valorisation."),

("Prix moyen pondéré moyen des articles valorisés au PMP, par site",
 "SELECT bwkey AS site, COUNT(*) AS nb_articles, ROUND(AVG(NULLIF(verpr,'')::numeric),2) AS pmp_moyen FROM raw_data.mbew WHERE mandt = '700' AND (lvorm IS NULL OR lvorm = '') AND vprsv = 'V' GROUP BY bwkey ORDER BY bwkey",
 "Articles en contrôle de prix V (PMP) : moyenne du verpr par site de valorisation."),

("Combien d'articles ont un code EAN ?",
 "SELECT COUNT(*) AS nb_avec_ean FROM raw_data.mara WHERE mandt = '700' AND (lvorm IS NULL OR lvorm = '') AND ean11 IS NOT NULL AND ean11 <> ''",
 "Articles actifs avec ean11 renseigné."),

("Articles qui ont un ancien numéro d'article renseigné",
 "SELECT LTRIM(matnr,'0') AS article, bismt AS ancien_code, mtart FROM raw_data.mara WHERE mandt = '700' AND (lvorm IS NULL OR lvorm = '') AND bismt IS NOT NULL AND bismt <> '' ORDER BY article LIMIT 100",
 "Champ bismt non vide : utile pour la reprise des correspondances anciens codes."),

# ============ CODIFICATION IFS ============
("Répartition des articles du mapping de codification par catégorie",
 "SELECT categorie, COUNT(*) AS nb FROM clean_data.mapping_codification_articles GROUP BY categorie ORDER BY nb DESC",
 "Comptage par catégorie dans la table de mapping de codification."),

("Combien de codifications ont été faites manuellement ?",
 "SELECT COUNT(*) AS nb_manuelles FROM clean_data.mapping_codification_articles WHERE codification_manuelle IS TRUE",
 "Codifications avec le flag booléen codification_manuelle à vrai."),

("Quel est le taux de codification IFS des articles des divisions 2200 et 9200 ?",
 "SELECT m.spart, COUNT(*) AS nb_articles, COUNT(*) FILTER (WHERE c.codification_ifs IS NOT NULL AND c.codification_ifs <> '') AS nb_codifies, ROUND(100.0*COUNT(*) FILTER (WHERE c.codification_ifs IS NOT NULL AND c.codification_ifs <> '')/COUNT(*),1) AS taux_pct FROM raw_data.mara m LEFT JOIN clean_data.mapping_codification_articles c ON c.matnr = m.matnr WHERE m.mandt = '700' AND (m.lvorm IS NULL OR m.lvorm = '') AND m.spart IN ('2200','9200') GROUP BY m.spart",
 "Pour chaque division du périmètre : nombre d'articles, codifiés, et taux de codification IFS."),

("Articles de la division 2200 sans codification IFS",
 "SELECT LTRIM(m.matnr,'0') AS article, k.maktx AS designation, m.matkl FROM raw_data.mara m LEFT JOIN raw_data.makt k ON k.matnr = m.matnr AND k.spras = 'F' AND k.mandt = '700' LEFT JOIN clean_data.mapping_codification_articles c ON c.matnr = m.matnr WHERE m.mandt = '700' AND (m.lvorm IS NULL OR m.lvorm = '') AND m.spart = '2200' AND (c.codification_ifs IS NULL OR c.codification_ifs = '') ORDER BY m.matkl, article",
 "Reste à codifier : articles actifs 2200 sans codification_ifs dans le mapping."),

("Dernières codifications modifiées et par qui",
 "SELECT matnr, designation_sap, codification_ifs, modifie_par, date_modification FROM clean_data.mapping_codification_articles WHERE date_modification IS NOT NULL ORDER BY date_modification DESC LIMIT 20",
 "Audit : 20 dernières modifications de la table de codification."),

# ============ ACHATS ============
("Nombre de commandes d'achat par année",
 "SELECT SUBSTRING(aedat,1,4) AS annee, COUNT(*) AS nb_commandes FROM raw_data.ekko WHERE mandt = '700' AND aedat IS NOT NULL AND aedat <> '' GROUP BY SUBSTRING(aedat,1,4) ORDER BY annee",
 "Dates SAP en varchar YYYYMMDD : extraction de l'année par SUBSTRING sur aedat."),

("Top 10 des fournisseurs par montant commandé",
 "SELECT k.lifnr, l.name1, SUM(NULLIF(p.netwr,'')::numeric) AS montant FROM raw_data.ekko k JOIN raw_data.ekpo p ON p.ebeln = k.ebeln AND p.mandt = k.mandt LEFT JOIN raw_data.lfa1 l ON l.lifnr = k.lifnr AND l.mandt = '700' WHERE k.mandt = '700' AND (p.loekz IS NULL OR p.loekz = '') GROUP BY k.lifnr, l.name1 ORDER BY montant DESC NULLS LAST LIMIT 10",
 "Somme des valeurs nettes de postes (ekpo.netwr) par fournisseur d'entête de commande (ekko)."),

("Nombre de fiches info-achat actives par organisation d'achats",
 "SELECT ekorg, COUNT(*) AS nb_fiches FROM raw_data.eine WHERE mandt = '700' AND (loekz IS NULL OR loekz = '') GROUP BY ekorg ORDER BY nb_fiches DESC",
 "Fiches info-achat (eine) non supprimées, par organisation d'achats."),

("Combien de sources d'approvisionnement sont valides aujourd'hui, par site ?",
 "SELECT werks AS site, COUNT(*) AS nb_sources FROM raw_data.eord WHERE mandt = '700' AND (notkz IS NULL OR notkz = '') AND vdatu <= TO_CHAR(CURRENT_DATE,'YYYYMMDD') AND bdatu >= TO_CHAR(CURRENT_DATE,'YYYYMMDD') GROUP BY werks ORDER BY nb_sources DESC",
 "Sources eord non bloquées dont la fenêtre de validité (vdatu/bdatu, varchar YYYYMMDD) couvre la date du jour."),

("Quels articles ont plusieurs fournisseurs référencés ?",
 "SELECT LTRIM(e.matnr,'0') AS article, COUNT(DISTINCT e.lifnr) AS nb_fournisseurs FROM raw_data.eina e WHERE e.mandt = '700' AND (e.loekz IS NULL OR e.loekz = '') AND e.matnr IS NOT NULL AND e.matnr <> '' GROUP BY e.matnr HAVING COUNT(DISTINCT e.lifnr) > 1 ORDER BY nb_fournisseurs DESC LIMIT 50",
 "Articles multi-sourcés : plus d'un fournisseur distinct dans les fiches info-achat eina."),

("Délai d'approvisionnement moyen par fournisseur (top 20 des plus longs)",
 "SELECT a.lifnr, l.name1, ROUND(AVG(NULLIF(e.aplfz,'')::numeric),1) AS delai_moyen_jours FROM raw_data.eine e JOIN raw_data.eina a ON a.infnr = e.infnr AND a.mandt = e.mandt LEFT JOIN raw_data.lfa1 l ON l.lifnr = a.lifnr AND l.mandt = '700' WHERE e.mandt = '700' AND (e.loekz IS NULL OR e.loekz = '') GROUP BY a.lifnr, l.name1 ORDER BY delai_moyen_jours DESC NULLS LAST LIMIT 20",
 "Moyenne du délai prévu aplfz des fiches info-achat, rattachée au fournisseur via eina."),

("Postes de commandes non encore livrés depuis début 2024, par site",
 "SELECT p.werks AS site, COUNT(*) AS nb_postes_ouverts FROM raw_data.ekpo p JOIN raw_data.ekko k ON k.ebeln = p.ebeln AND k.mandt = p.mandt WHERE p.mandt = '700' AND (p.loekz IS NULL OR p.loekz = '') AND (p.elikz IS NULL OR p.elikz = '') AND k.aedat >= '20240101' GROUP BY p.werks ORDER BY nb_postes_ouverts DESC",
 "Postes ekpo sans indicateur de livraison finale (elikz vide) sur les commandes créées depuis 2024."),

("Fiches info-achat sans référence article fournisseur",
 "SELECT a.lifnr, l.name1, COUNT(*) AS nb_fiches_sans_ref FROM raw_data.eina a LEFT JOIN raw_data.lfa1 l ON l.lifnr = a.lifnr AND l.mandt = '700' WHERE a.mandt = '700' AND (a.loekz IS NULL OR a.loekz = '') AND (a.idnlf IS NULL OR a.idnlf = '') GROUP BY a.lifnr, l.name1 ORDER BY nb_fiches_sans_ref DESC LIMIT 30",
 "Qualité de données achats : fiches eina sans idnlf (référence de l'article chez le fournisseur)."),

("Fournisseurs ayant reçu des commandes depuis 2024 mais non retenus pour la migration",
 "SELECT DISTINCT k.lifnr, l.name1, l.ort01 FROM raw_data.ekko k LEFT JOIN public.fournisseurs_a_conserver f ON f.vendor_no = k.lifnr LEFT JOIN raw_data.lfa1 l ON l.lifnr = k.lifnr AND l.mandt = '700' WHERE k.mandt = '700' AND k.aedat >= '20240101' AND f.vendor_no IS NULL ORDER BY l.name1",
 "Contrôle de périmètre : fournisseurs actifs commercialement absents de fournisseurs_a_conserver."),

# ============ MAINTENANCE ============
("Nombre d'équipements actifs par type",
 "SELECT eqtyp AS type_equipement, COUNT(*) AS nb FROM raw_data.equi WHERE mandt = '700' AND (lvorm IS NULL OR lvorm = '') GROUP BY eqtyp ORDER BY nb DESC",
 "Équipements non supprimés par catégorie eqtyp."),

("Équipements sans désignation en français",
 "SELECT e.equnr, e.eqtyp, e.herst AS fabricant FROM raw_data.equi e LEFT JOIN raw_data.eqkt t ON t.equnr = e.equnr AND t.spras = 'F' AND t.mandt = '700' WHERE e.mandt = '700' AND (e.lvorm IS NULL OR e.lvorm = '') AND t.equnr IS NULL ORDER BY e.equnr",
 "Anti-jointure sur eqkt langue F : équipements sans texte court français."),

("Liste des postes techniques racine de la hiérarchie",
 "SELECT i.tplnr, x.pltxt AS designation, i.iwerk AS site FROM raw_data.iflot i LEFT JOIN raw_data.iflotx x ON x.tplnr = i.tplnr AND x.spras = 'F' AND x.mandt = '700' WHERE i.mandt = '700' AND (i.lvorm IS NULL OR i.lvorm = '') AND (i.tplma IS NULL OR i.tplma = '') ORDER BY i.tplnr",
 "Postes techniques sans parent (tplma vide) = sommets de la hiérarchie, avec libellé français."),

("Nombre de postes techniques par site de maintenance",
 "SELECT iwerk AS site_maintenance, COUNT(*) AS nb_postes FROM raw_data.iflot WHERE mandt = '700' AND (lvorm IS NULL OR lvorm = '') GROUP BY iwerk ORDER BY nb_postes DESC",
 "Volumétrie des postes techniques actifs par site (iwerk)."),

("Top 10 des fabricants d'équipements",
 "SELECT herst AS fabricant, COUNT(*) AS nb_equipements FROM raw_data.equi WHERE mandt = '700' AND (lvorm IS NULL OR lvorm = '') AND herst IS NOT NULL AND herst <> '' GROUP BY herst ORDER BY nb_equipements DESC LIMIT 10",
 "Fabricants les plus représentés dans le parc équipements."),

("Combien d'équipements sont rattachés à un article ?",
 "SELECT COUNT(*) AS nb_equipements_avec_article FROM raw_data.equi WHERE mandt = '700' AND (lvorm IS NULL OR lvorm = '') AND matnr IS NOT NULL AND matnr <> ''",
 "Équipements actifs liés à un article (matnr renseigné), utile pour les pièces sérialisées."),

# ============ CLIENTS ============
("Combien de clients actifs ?",
 f"SELECT COUNT(*) AS nb_clients FROM raw_data.kna1 WHERE {M} {A}",
 "Clients non supprimés du mandant 700."),

("Répartition des clients actifs par pays",
 f"SELECT k.land1, t.landx AS pays, COUNT(*) AS nb FROM raw_data.kna1 k LEFT JOIN raw_data.t005t t ON t.land1 = k.land1 AND t.spras = 'F' AND t.mandt = '700' WHERE k.{M} AND (k.loevm IS NULL OR k.loevm = '') GROUP BY k.land1, t.landx ORDER BY nb DESC LIMIT 10",
 "Top pays des clients actifs avec nom de pays en français."),

("Clients français sans SIRET",
 f"SELECT kunnr, name1, ort01 FROM raw_data.kna1 WHERE {M} {A} AND land1 = 'FR' AND (stcd1 IS NULL OR stcd1 = '') ORDER BY name1",
 "Clients France avec stcd1 vide."),

# ============ DICTIONNAIRE DE DONNEES ============
("À quoi sert la table EORD ?",
 "SELECT tabname, ddtext AS description FROM raw_data.dd02t WHERE tabname ILIKE 'EORD' AND ddlanguage = 'F'",
 "Description française de la table depuis le dictionnaire SAP dd02t."),

("Quels sont les champs obligatoires de la table MARC ?",
 "SELECT field_name, field_text, data_type, length FROM public.sap_table_fields WHERE table_name ILIKE 'MARC' AND mandatory IS TRUE ORDER BY position",
 "Champs avec mandatory à vrai dans le dictionnaire des champs extraits (libellés français)."),

("Liste les champs clés de la table EKKO avec leur signification",
 "SELECT field_name, field_text, data_type, length FROM public.sap_table_fields WHERE table_name ILIKE 'EKKO' AND key_flag IS TRUE ORDER BY position",
 "Champs clés (key_flag booléen vrai) de EKKO depuis sap_table_fields."),

("Quelles tables extraites de SAP concernent les fournisseurs ?",
 "SELECT table_name, description FROM public.sap_table_properties WHERE description ILIKE '%fournisseur%' ORDER BY table_name",
 "Recherche plein texte dans les descriptions françaises de sap_table_properties."),

# ============ QUALITE DE DONNEES ============
("Fournisseurs français avec un code postal invalide",
 f"SELECT lifnr, name1, pstlz, ort01 FROM raw_data.lfa1 WHERE {M} {A} AND land1 = 'FR' AND (pstlz IS NULL OR pstlz !~ '^[0-9]{{5}}$') ORDER BY name1 LIMIT 100",
 "Codes postaux France ne respectant pas le format 5 chiffres (regex PostgreSQL !~), vides inclus."),

("Emails invalides dans la table de travail fournisseurs",
 "SELECT numero_compte_sap, denomination_sociale, email FROM raw_data.selection_fournisseurs WHERE email IS NOT NULL AND email <> '' AND email NOT LIKE '%@%' ORDER BY denomination_sociale",
 "Emails renseignés mais sans arobase dans selection_fournisseurs."),

("IBAN français de longueur incorrecte dans la table de travail",
 "SELECT numero_compte_sap, denomination_sociale, iban_paiement, LENGTH(REPLACE(iban_paiement,' ','')) AS longueur FROM raw_data.selection_fournisseurs WHERE iban_paiement LIKE 'FR%' AND LENGTH(REPLACE(iban_paiement,' ','')) <> 27 ORDER BY denomination_sociale",
 "Un IBAN FR fait 27 caractères : détection des anomalies après suppression des espaces."),
]


def build(chemin_sortie: str = "dataset_sap_ia.jsonl") -> int:
    """Écrit le dataset JSONL au format chat. Retourne le nombre d'exemples."""
    with open(chemin_sortie, "w", encoding="utf-8") as f:
        for question, sql, explication in EXEMPLES:
            ligne = {
                "messages": [
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": question},
                    {"role": "assistant", "content": json.dumps(
                        {"sql": sql, "explication": explication}, ensure_ascii=False)}
                ]
            }
            f.write(json.dumps(ligne, ensure_ascii=False) + "\n")
    return len(EXEMPLES)


if __name__ == "__main__":
    n = build()
    print(f"{n} exemples ecrits dans dataset_sap_ia.jsonl")
