---
name: ifs-fondamentaux
description: >
  Concepts et paramétrage de l'ERP IFS Cloud : company/site, basic data,
  parts, projets, maintenance préventive, clients/fournisseurs, migration.
  Utiliser pour comprendre le sens fonctionnel des tables IFS cibles.
---

# IFS Cloud — fondamentaux fonctionnels 25R2

## 1. Architecture générale IFS Cloud : Company, Site, Contract, Logical Unit
IFS Cloud organise une partie du paramétrage autour de la Company et des composants actifs.
La création d’une Company s’appuie sur une source : Company Template ou Company existante.
Les composants actifs exposent des Logical Units, utilisées pour copier/appliquer les données liées à la Company.
Une Logical Unit peut être activée ou désactivée pour les processus de Company Template.
Les processus concernés incluent Create Company, Update Company, Create Company Template et Export Company Template.
Un Site doit être rattaché à une Company existante ; il peut ensuite servir aux processus Supply Chain.
Dans IFS, le terme Contract est couramment utilisé côté données pour représenter le site opérationnel.
Composants techniques détaillés d’architecture IFS Cloud : non documenté — vérifier sur docs.ifs.com.
Implication migration : charger Company et Site/Contract avant les données dépendantes par site.

## 2. Basic Data : définition, rôle, ordre de mise en place
La documentation IFS utilise BDR pour Basic Data Required : données nécessaires avant d’exécuter un processus.
Le Basic Data sert à rendre possible l’usage des processus métier : finance, supply chain, projets, maintenance, etc.
Lors de la création d’une Company, IFS crée déjà des valeurs par défaut pour de nombreuses fonctions.
Ces valeurs peuvent être conservées ou ajustées selon les besoins métier.
Le processus Set Up Basic Data Enterprise liste les référentiels transverses : pays, adresses, taxes, branches, Company Group, personnes par Company, Site.
L’ordre typique est : référentiels globaux, Company, Site, puis Basic Data métier.
Implication migration : identifier les Basic Data prérequis évite de charger des objets transactionnels orphelins.

## 3. Paramétrage Company et Site
La Company porte les paramètres globaux et financiers : identité, modèle source, langues, informations détaillées.
La création Company propage les données via les composants actifs et leurs Logical Units.
Les erreurs de création Company sont journalisées ; le traitement continue sur les autres Logical Units.
Le Site se définit après existence de la Company à laquelle il est connecté.
Un Site peut servir aux physical counts, puis devenir distribution site pour customer orders et purchase orders.
Pour un distribution site, la documentation mentionne distribution calendar, manufacturing calendar et informations associées.
Le Site permet aussi de définir des physical locations.
Implication migration : les tables par contract/site dépendent d’une Company valide et d’un Site correctement typé.

## 4. Part Catalog, Inventory Part, Purchase Part, Sales Part
Part Catalog crée une Part sans site, avec un part number réutilisable ensuite comme Inventory, Purchase ou Sales Part.
La Part Catalog peut porter Unit of Measure, Part Main Group, descriptions, textes, poids et volume.
Inventory Part ajoute les données propres au site : supply, lead times, customs/statistical data, technical coordinator, supply chain part group.
Sales Part est obligatoire avant usage en customer order ; il définit les valeurs par défaut de vente.
Les Sales Parts peuvent être inventory registered, services/non-stored parts, ou package parts.
IFS peut créer automatiquement un Inventory Part minimal si un Sales Part inventory-registered est créé sans Inventory Part existant.
Purchase Part est documenté via les flux Purchase Order et description centralisée ; détail complet non documenté — vérifier sur docs.ifs.com.
Implication migration : charger d’abord Part Catalog, puis déclinaisons Inventory/Purchase/Sales par site et usage métier.

## 5. Paramétrage projets : Project, Sub Project, Activity
Un Project a des statuts : Initialized, Approved, Started, Completed, Closed ou Cancelled.
Pour passer en Approved, la documentation mentionne Company, manager, customer et pre-posting.
Un Sub Project sert à décomposer le Project en Work Breakdown Structure hiérarchique.
Un Sub Project peut être sous le Project ou sous un autre Sub Project ; il n’a qu’un seul parent.
Les données Sub Project incluent Sub Project ID, Description, Sub Project Manager et Department.
Les Activities sont les unités de planification et d’exécution : ressources, work tasks, shop orders et objets liés.
Les coûts, revenus, heures, earned value et progress remontent sur les Activities.
Implication migration : préserver la hiérarchie Project > Sub Project > Activity et charger les référentiels associés avant les liens.

## 6. Maintenance préventive : PM Action et objets liés
Une PM Action est préparée via des PM Action Revisions.
Une revision Active ne permet que des modifications restreintes si le revision control est activé.
Les changements majeurs, comme jobs, templates, criteria de maintenance plan ou maintenance organization, nécessitent une nouvelle revision.
Une nouvelle revision est créée en Preliminary depuis une revision Active ou Obsolete, s’il n’existe pas déjà de Preliminary.
L’activation d’une PM Action Revision se fait après préparation et planning.
Une revision Active permet de générer des work orders ; l’ancienne revision active devient Obsolete.
La documentation mentionne aussi material demand, purchase requisition, purchase order lines et part request lines liés.
Implication migration : charger PM Action, revisions, critères, jobs et besoins matière dans un état cohérent avant activation.

## 7. Customers et Suppliers : Basic Data associées
Customer Basic Data permet de consulter association number, country, default currency et default payment information.
Supplier Basic Data permet de consulter association number, country, invoice currency et default payment information.
Ces vues supposent que les détails Customer ou Supplier existent déjà dans les pages Customer/Supplier.
Pour les e-invoices, Supplier porte des paramètres de message et automatic approval.
Company porte aussi des paramètres documentaires pour invoice image et attachments.
Party Identification est clé : IFS identifie Company et Supplier à partir des informations présentes dans l’e-invoice.
La documentation liste aussi des Basic Data de credit management pour Customer.
Implication migration : charger identité tiers, adresses, pays, devises, paiements, taxes et paramètres invoice avant les flux AR/AP.

## 8. Data Migration IFS : migration jobs et prérequis Basic Data
Data Migration Manager couvre la création d’un Migration Project et la définition des environnements.
Le processus inclut legacy source, main process, migration sprints, code definitions et migration objects.
Les migration objects peuvent venir d’un template ou être définis manuellement.
Le flux prévoit import de données legacy, définition des mappings, transformation rules et validation.
Les données passent par input container, output container, duplication control, puis deployment vers target environment.
IFS documente aussi l’extraction, la validation et l’approbation de Basic Data.
Un schedule migration job existe dans le processus DMM, mais son paramétrage détaillé est non documenté — vérifier sur docs.ifs.com.
Implication migration : préparer Basic Data et règles de transcodification avant validation, transformation et déploiement final.

## Références internes complémentaires

- `references/ifs-25r2-research-notes.md` : notes de recherche détaillées sur IFS Cloud 25R2.
- `references/veille-migration-sap-ecc-ifs-cloud.md` : veille web synthétique sur bonnes pratiques SAP ECC -> IFS Cloud : DMM, Migration Objects, Basic Data, Company/Site, transcodifications, quality gates et actualités IFS Cloud/IA industrielle.

## Sources
Version consultée : IFS Cloud Documentation 25R2, doc_version 2026-07-02.
Techdocs 25R2 : https://docs.ifs.com/techdocs/25r2/ consulté, mais contenu bloqué par vérification navigateur ; aucune affirmation technique reprise.
https://docs.ifs.com/ifsclouddocs/25r2/lang/en/DefineFinancialsBasics/ActivityEnterpActivateInactivateLU.htm
https://docs.ifs.com/ifsclouddocs/25r2/lang/en/DefineFinancialsBasics/ActivityEnterpCreateCompanyInAllComponents.htm
https://docs.ifs.com/ifsclouddocs/25r2/lang/en/DefineFinancialsBasics/ActivityDefineSites.htm
https://docs.ifs.com/ifsclouddocs/25r2/lang/en/ProcessModels/Process_Model/setupbasicdataenterprise.htm
https://docs.ifs.com/ifsclouddocs/25r2/lang/en/MaintainInventory/ActivityPartCaEnterPartData.htm
https://docs.ifs.com/ifsclouddocs/25r2/lang/en/MaintainInventory/AboutCentralPart.htm
https://docs.ifs.com/ifsclouddocs/25r2/lang/en/MaintainInventory/ActivityInventEnterPurchInvPartDataAcq.htm
https://docs.ifs.com/ifsclouddocs/25r2/lang/en/Sales/ActivityOrderEnterSalesPart.htm
https://docs.ifs.com/ifsclouddocs/25r2/lang/en/ProjectManagement/AboutProjects.htm
https://docs.ifs.com/ifsclouddocs/25r2/lang/en/ProjectManagement/AboutSubProjects.htm
https://docs.ifs.com/ifsclouddocs/25r2/lang/en/ProjectManagement/AboutActivities.htm
https://docs.ifs.com/ifsclouddocs/25r2/lang/en/PMProcessing/ActivityCreateNewPMARevision.htm
https://docs.ifs.com/ifsclouddocs/25r2/lang/en/PMProcessing/ActivityActivatePMARevision.htm
https://docs.ifs.com/ifsclouddocs/25r2/lang/en/CustomerPayments/ActivityQryCustomerBasicData.htm
https://docs.ifs.com/ifsclouddocs/25r2/lang/en/SupplierPayments/ActivityQrySupplierBasicData.htm
https://docs.ifs.com/ifsclouddocs/25r2/lang/en/SupplierInvoicing/AboutBDRforReceiveElectronicXMLInvoiceProcess.htm
https://docs.ifs.com/ifsclouddocs/25r2/lang/en/ProcessModels/Process_Model/DataMigrationManager.htm
