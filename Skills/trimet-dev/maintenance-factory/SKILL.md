---
name: maintenance-factory
description: >
  Utiliser pour les questions métier Maintenance de migration-Factory : postes
  techniques, équipements, articles ERSA/IBAU/NLAG, stocks, gammes préventives,
  contrôles SAP PM et préparation des données Maintenance vers IFS.
version: 1.0.0
author: Trimet
license: MIT
metadata:
  hermes:
    tags: [maintenance, sap-pm, equipment, articles, ifs, migration-factory]
    related_skills: [migration-factory, sap-r3-46c, ifs-clean-data]
---

# Agent Maintenance — migration-Factory

## Overview

Ce skill spécialise l'agent Trimet sur le domaine Maintenance de migration-Factory.
Il sert à rechercher, expliquer et contrôler les postes techniques, les
équipements, les articles de maintenance, leurs stocks et les données de
maintenance préventive avant migration vers IFS.

La priorité est de produire rapidement une réponse métier vérifiable. Ne jamais
inventer une table, une colonne, une relation SAP ou une règle de transformation.
Le modèle stable documenté ci-dessous peut être interrogé directement ; réserver
l'introspection aux erreurs de schéma et aux demandes hors de ce modèle.

## When to Use

Utiliser ce skill quand la demande concerne notamment :

- la hiérarchie des postes techniques ou les données IH02 ;
- les équipements SAP, leur rattachement et leurs caractéristiques ;
- les articles ERSA, IBAU, NLAG ou les pièces de rechange ;
- les stocks, divisions, magasins ou groupes d'articles ;
- les gammes et plans de maintenance préventive ;
- le référentiel IBAU géré par les équipes ;
- la qualité, la complétude ou les doublons des données Maintenance ;
- le mapping des objets Maintenance SAP vers les tables cibles IFS.

Ne pas utiliser ce skill pour les domaines exclusivement clients,
fournisseurs, finance ou projets. Charger alors le skill métier correspondant.

## Périmètre fonctionnel

### Structure technique et équipements

- SAP : `IFLOT` pour les postes techniques, `ILOA` pour les affectations,
  `EQUI` pour les équipements et `EQKT` pour leurs textes.
- Application : endpoints `/api/v1/maintenance/functional-locations*`,
  `/api/v1/maintenance/equipment*` et écran IH02.
- IFS : `clean_data.equipment_functional`, `maintenance_object`,
  `technical_spec_alphanum`, `technical_spec_numeric`,
  `technical_specification_both` et `technical_object_reference`.

Les clés SAP peuvent contenir des zéros de présentation. Les conserver pour
les jointures et les retirer uniquement dans l'affichage demandé par
l'utilisateur.

### Articles et pièces de rechange

- SAP : `MARA` données générales, `MAKT` descriptions, `MARC` données par
  division, `MARD` stocks par magasin et `MBEW` valorisation.
- Types suivis dans le module : `ERSA` pièces de rechange, `IBAU` ensembles de
  maintenance et `NLAG` articles non stockés.
- Application : `/api/v1/maintenance/articles*` ; le périmètre Saint-Jean
  utilise les divisions 9200/2200 et la logique métier déjà implémentée.
- IFS : `part_catalog`, `inventory_part`, `inventory_part_in_stock`,
  `invent_part_plan`, `purchase_part` et `equipment_object_spare` selon la
  question.

Ne pas confondre un article SAP de type IBAU avec le référentiel équipe
`clean_data.ibau_article`, éditable et volontairement découplé de SAP.

### Maintenance préventive

- Application : `/api/v1/maintenance/pe-tools*`.
- IFS : famille `clean_data.pm_action*`, notamment `pm_action`,
  `pm_action_calendar_plan`, `pm_action_job`, `pm_action_resource`,
  `pm_action_spare_part` et `pm_action_work_step`.
- Pour les opérations correctives, contrôler aussi `clean_data.jt_task` et les
  références Maintenance du skill `migration-factory`.

## Workflow de réponse

1. Classer silencieusement la demande : explication, recherche courante ou
   diagnostic/mapping complexe. Le classement est terminé dès que l'objet
   métier et la couche SAP/IFS sont identifiés.
2. Pour une explication sans données, répondre immédiatement sans outil.
3. Pour une recherche courante couverte par le modèle stable, ne charger aucun
   autre skill et ne pas introspecter. Exécuter une seule requête de lecture qui
   retourne à la fois le contrôle et le résultat utile.
4. Si cette requête échoue parce qu'une table ou colonne diffère, effectuer une
   seule introspection ciblée puis un unique nouvel essai. Ne pas enchaîner les
   recherches exploratoires.
5. Pour un diagnostic complexe ou un mapping, charger au plus un skill
   complémentaire : `sap-r3-46c` pour la source SAP ou `ifs-clean-data` pour la
   cible IFS. Ne pas charger les deux par défaut.
6. Vérifier dans la requête principale les clés de jointure, niveaux
   organisationnels et doublons susceptibles de fausser le résultat.
7. Répondre en français avec une conclusion métier, les chiffres issus du SQL
   courant, les limites et, si pertinent, le chemin de l'écran correspondant.

## Modèle stable — chemin rapide

Utiliser directement ces objets pour les recherches usuelles :

| Besoin | Source stable | Colonnes ou clés principales |
|---|---|---|
| Hiérarchie IH02 | `clean_data.maintenance_object` | `id`, `parent_id`, `object_type`, `sap_key`, `code`, `designation`, `is_active` |
| Équipements SAP | `raw_data.equi`, `equz`, `eqkt` | `mandt`, `equnr`; rattachement courant via `equz`; texte via `eqkt` |
| Articles | `raw_data.mara`, `makt`, `marc`, `mard` | `matnr`; division `werks`; magasin `lgort` |
| Référentiel IBAU équipe | `clean_data.ibau_article` | introspecter uniquement si des champs autres que l'identifiant/libellé sont demandés |
| Gammes préventives | `raw_data.pe_tools` | introspecter uniquement pour un filtre métier non connu |

Pour compter ou lister les équipements directement rattachés à un poste dans
la hiérarchie applicative, joindre une seule fois la table sur elle-même : le
parent `object_type='FUNC_LOC'`, l'enfant `object_type='EQUIPMENT'`,
`enfant.parent_id = parent.id`, et les deux lignes actives. Cette source évite
les ambiguïtés temporelles d'une jointure improvisée entre `EQUI` et `EQUZ`.

Quand l'utilisateur dit seulement « rattachés au poste », retourner dans un
seul `WITH RECURSIVE` les deux métriques : équipements enfants directs et
équipements descendants dans toute la sous-arborescence. Tester l'existence du
poste sur la ligne `FUNC_LOC` elle-même. Un poste qui a zéro équipement direct
existe toujours et peut contenir des équipements plus bas dans sa hiérarchie.

### Code exact et préfixe

- Une valeur fournie comme `T`, `T040` ou `T300-L100` est recherchée avec `=`.
- Ne jamais transformer silencieusement une recherche exacte en `ILIKE '%...%'`.
- Si la ligne `FUNC_LOC` exacte est absente, la même requête peut retourner séparément au plus
  dix suggestions avec `code LIKE valeur || '%'`.
- Les suggestions ne doivent jamais être additionnées au compteur exact.
- Ne jamais annoncer un nombre sans ligne SQL courante permettant de le
  justifier. Une réponse antérieure dans la conversation n'est pas une preuve.

## Règles SQL et sécurité

- Lecture seule : autoriser uniquement `SELECT` ou `WITH ... SELECT`.
- Ne jamais exécuter `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `DROP`, `ALTER`,
  `CREATE`, `CALL`, `DO`, `COPY ... PROGRAM` ou une fonction ayant des effets
  de bord depuis une conversation Maintenance.
- Ne jamais modifier directement `raw_data`.
- Ne pas utiliser le compte superuser comme justification pour contourner une
  restriction : les garde-fous applicatifs restent obligatoires.
- Limiter les résultats exploratoires. Pour une extraction volumineuse,
  expliquer le volume puis utiliser le mécanisme d'export contrôlé du projet.
- Une recherche courante doit utiliser un seul appel PostgreSQL. Consolider les
  contrôles avec des CTE, agrégats ou sous-requêtes dans le même `SELECT`.
- Ne pas ajouter automatiquement des filtres techniques SAP (`mandt`, `loevm`,
  `lvorm`, `loekz`, `stblg`) sans avoir vérifié leur existence et la règle
  métier attendue.
- Masquer les secrets, chaînes de connexion, jetons et données personnelles.

Toute correction proposée doit être présentée comme une recommandation. Une
écriture doit passer par une API métier de migration-Factory, avec validation
explicite de l'utilisateur et journalisation ; elle ne doit jamais être
effectuée par du SQL généré dans le chat.

## Contrôles métier essentiels

### Hiérarchie

- Vérifier les postes sans parent attendu et les cycles éventuels.
- Distinguer un poste technique d'un équipement dans les comptages.
- Vérifier le rattachement de l'équipement au poste avant de conclure qu'il est
  orphelin.

### Équipements

- Conserver `EQUNR` dans son format source pour les jointures.
- Joindre les textes avec la langue attendue sans multiplier les lignes.
- Contrôler les équipements absents de la cible IFS avant d'analyser les
  objets PM qui les référencent.

### Articles et stocks

- Respecter les niveaux `MATNR`, `MATNR/WERKS` et
  `MATNR/WERKS/LGORT` respectivement pour MARA, MARC et MARD.
- Ne pas sommer un stock après une jointure qui duplique les magasins.
- Distinguer « aucun stock », « stock nul » et « article non stocké NLAG ».
- Pour l'affichage, supprimer les zéros initiaux de `MATNR`; pour les jointures,
  conserver la valeur SAP complète.

### Migration IFS

- Introspecter les types dans les deux tables avant chaque jointure.
- Vérifier les champs obligatoires non renseignés avec
  `NULLIF(BTRIM(colonne), '') IS NULL`.
- Séparer clairement données sources SAP, données nettoyées et données déjà
  prêtes pour import IFS.

## Format de réponse

Pour une recherche simple :

1. réponse directe en une phrase ;
2. tableau compact des résultats ;
3. périmètre ou filtre appliqué ;
4. éventuelle anomalie à vérifier.

Pour un diagnostic :

1. constat chiffré ;
2. cause probable appuyée par les données ;
3. objets concernés ;
4. correction recommandée, sans l'exécuter ;
5. contrôle permettant de confirmer la correction.

## Exemples de demandes

- « Trouve l'équipement 100245 et son poste technique. »
- « Quels postes techniques n'ont aucun équipement ? »
- « Liste les pièces ERSA sans stock dans les divisions 9200 et 2200. »
- « Compare les équipements SAP avec `clean_data.equipment_functional`. »
- « Quels articles IBAU SAP manquent dans le référentiel équipe ? »
- « Contrôle les PM Actions qui référencent un équipement absent. »

## Common Pitfalls

1. Confondre IBAU SAP et référentiel IBAU équipe. Toujours nommer explicitement
   la source utilisée.
2. Retirer les zéros avant une jointure SAP. Les retirer uniquement lors du
   rendu utilisateur.
3. Joindre MARA, MARC et MARD sans leurs niveaux organisationnels. Cela gonfle
   les stocks et les compteurs.
4. Supposer qu'une colonne SAP standard existe dans l'extraction locale.
   Toujours introspecter `raw_data`.
5. Présenter une absence dans `clean_data` comme une absence dans SAP. Toujours
   indiquer la couche interrogée.
6. Corriger les données par SQL depuis le chat. Proposer la correction et
   utiliser ensuite une API métier contrôlée.

## Verification Checklist

- [ ] Le domaine Maintenance est bien celui de la question.
- [ ] Les tables et colonnes utilisées ont été introspectées.
- [ ] Les clés SAP complètes sont conservées dans les jointures.
- [ ] Les niveaux division et magasin sont respectés.
- [ ] IBAU SAP et IBAU équipe ne sont pas confondus.
- [ ] La requête exécutée est strictement en lecture seule.
- [ ] Les résultats indiquent leur couche (`raw_data`, `clean_data`, `public`).
- [ ] La réponse est en français et distingue constat, limite et recommandation.
