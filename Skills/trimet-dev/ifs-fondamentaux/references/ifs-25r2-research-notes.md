# Notes de recherche IFS Cloud 25R2 — fondamentaux

Contexte : notes condensées issues de la création du skill `ifs-fondamentaux` pour migration SAP ECC 6.0 -> IFS. Elles ne remplacent pas docs.ifs.com ; elles indiquent quelles pages ont servi de base et quels points restent à vérifier.

## Méthode de recherche

Sources autorisées par l'utilisateur :
1. `https://docs.ifs.com/techdocs/25r2/`
2. `https://docs.ifs.com/ifsclouddocs/25r2/lang/en/`
3. `https://community.ifs.com` uniquement en complément.

La documentation fonctionnelle 25R2 expose un serveur Solr déclaré dans `OnlineDocSettings/local/general.xml` :
`https://ifs-docs-clouddocs-25r2-prod-byapbtgad2a9cne0.westeurope-01.azurewebsites.net/solr/ifsdoc_en/`.
Version fonctionnelle relevée : `doc_version` 2026-07-02.

Techdocs 25R2 a été consulté en priorité, mais la page a renvoyé une vérification navigateur. Aucune affirmation du skill ne s'appuie sur une page techdocs non lue.

## Requêtes couvertes

Les 8 thèmes utilisateur ont été couverts avec des recherches ciblées :
- architecture IFS Cloud, Company/Site/Contract, Logical Unit ;
- Basic Data / BDR ;
- Company et Site setup ;
- Part Catalog, Inventory Part, Purchase Part, Sales Part ;
- Project, Sub Project, Activity ;
- PM Action et preventive maintenance ;
- Customers et Suppliers basic data ;
- Data Migration Manager et migration jobs.

## Pages utilisées et contenu retenu

- `DefineFinancialsBasics/ActivityEnterpActivateInactivateLU.htm` : une Logical Unit peut être active/inactive dans les processus Company Template ; impact sur Create Company, Update Company, Create Company Template, Export Company Template.
- `DefineFinancialsBasics/ActivityEnterpCreateCompanyInAllComponents.htm` : création Company depuis template ou Company existante ; composants et Logical Units actifs appliquent les données ; erreurs journalisées sans arrêt global du processus.
- `DefineFinancialsBasics/ActivityDefineSites.htm` : un Site dépend d'une Company ; peut servir aux physical counts puis aux processus Supply Chain si distribution site.
- `ProcessModels/Process_Model/setupbasicdataenterprise.htm` : référentiels Enterprise Basic Data listés : country/address/tax/branch/company group/persons per company/site.
- `MaintainInventory/ActivityPartCaEnterPartData.htm` : Part Catalog crée une Part sans site, prérequis UoM, Part Main Group, utilisable ensuite comme inventory/purchase/sales part.
- `MaintainInventory/AboutCentralPart.htm` : description centralisée Part Catalog/Inventory/Purchase/Sales selon paramétrage du site et langue.
- `MaintainInventory/ActivityInventEnterPurchInvPartDataAcq.htm` : Inventory Part acquisition data couvre supply, lead times, customs/statistical data et prérequis basic data.
- `Sales/ActivityOrderEnterSalesPart.htm` : Sales Part obligatoire avant customer order ; types inventory registered/services/package ; création possible d'un Inventory Part minimal.
- `ProjectManagement/AboutProjects.htm` : statuts Project et condition d'approbation avec Company, manager, customer, pre-posting.
- `ProjectManagement/AboutSubProjects.htm` : WBS, parent unique, données Sub Project ID/Description/Manager/Department, coûts/revenus résumables.
- `ProjectManagement/AboutActivities.htm` : Activity comme unité de planification/exécution, liens ressources/work tasks/shop orders, remontée coûts/revenus/heures/progress.
- `PMProcessing/ActivityCreateNewPMARevision.htm` : PM Action Revision Preliminary depuis Active/Obsolete ; nouveaux changements majeurs nécessitent une nouvelle revision.
- `PMProcessing/ActivityActivatePMARevision.htm` : activation PM Action Revision après préparation/planning ; génération work orders ; ancienne revision active devient Obsolete.
- `CustomerPayments/ActivityQryCustomerBasicData.htm` et `SupplierPayments/ActivityQrySupplierBasicData.htm` : champs de consultation basic data clients/fournisseurs : association number, country, currency, payment information.
- `SupplierInvoicing/AboutBDRforReceiveElectronicXMLInvoiceProcess.htm` : e-invoice supplier/company/person/document management/party identification.
- `ProcessModels/Process_Model/DataMigrationManager.htm` : étapes DMM : Migration Project, environnements, legacy source, migration objects, transformations, containers, validation, duplication control, deployment, schedule migration job.

## Points explicitement non documentés dans les pages consultées

- Architecture technique détaillée IFS Cloud depuis techdocs : non retenue car page techdocs bloquée.
- Définition officielle de `Contract` comme synonyme exact de Site : le skill indique seulement son usage courant côté données, à vérifier si besoin dans docs.ifs.com.
- Détail complet Purchase Part : recherche fonctionnelle insuffisante dans les pages lues ; ne pas extrapoler.
- Paramétrage détaillé de schedule migration job DMM : mentionné dans le process model mais non détaillé dans les pages lues.

## Règle de prudence pour futures mises à jour

Pour tout ajout au skill, conserver le style carte conceptuelle : 5 à 15 lignes par thème, termes IFS officiels en anglais, implications migration explicites, et marquer `non documenté — vérifier sur docs.ifs.com` plutôt que supposer.
