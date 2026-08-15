# Veille — migration SAP ECC vers IFS Cloud

Synthèse issue d'une veille web réalisée le 2026-07-10 sur les bonnes pratiques et actualités utiles aux migrations SAP ECC -> IFS Cloud.

## Points durables à réutiliser

1. **Piloter la migration par les Migration Objects IFS plutôt que par les tables SAP**
   - IFS Data Migration Manager (DMM) structure le flux autour de : migration project, environments, legacy source, migration sprints, migration objects, target table scope/definition, mapping, transformation, validation, duplication control, deployment, scheduling.
   - Pratique recommandée : définir d'abord les objets cibles IFS et leurs dépendances, puis mapper les tables SAP ECC vers ces objets.
   - Sources :
     - https://docs.ifs.com/ifsclouddocs/25r2/lang/en/ProcessModels/Process_Model/DataMigrationManager.htm
     - https://docs.ifs.com/ifsclouddocs/25r2/lang/en/ProcessModels/Process_Model/DefineMapofLegacyTablestoMigrationObjects.htm

2. **Charger les Basic Data, Company et Site/Contract avant les objets métier**
   - Les Basic Data Enterprise couvrent notamment pays, adresses, taxes, branches, personnes par company, company group et sites.
   - La création d'un Site requiert qu'une Company existe déjà ; un site peut ensuite porter des usages supply chain via calendriers et paramètres de distribution.
   - Implication SAP : cadrer et charger les correspondances organisationnelles SAP (`BUKRS`, `WERKS`, `LGORT`, `EKORG`, etc.) avant articles, stocks, achats, maintenance et transactions.
   - Sources :
     - https://docs.ifs.com/ifsclouddocs/25r2/lang/en/ProcessModels/Process_Model/setupbasicdataenterprise.htm
     - https://docs.ifs.com/ifsclouddocs/25r2/lang/en/DefineFinancialsBasics/ActivityDefineSites.htm

3. **Centraliser les transcodifications SAP -> IFS**
   - DMM documente des règles de transformation : Conversion List, DECODE, NVL/null value, REPLACE, Substring, règles multiples.
   - Utiliser ces règles ou une table ETL équivalente pour les unités, pays, statuts, types articles, groupes achats, catégories équipement, codes maintenance, etc.
   - Sources :
     - https://docs.ifs.com/ifsclouddocs/25r2/lang/en/ProcessModels/Process_Model/DefineTransformationRuleConversionList.htm
     - https://docs.ifs.com/ifsclouddocs/25r2/lang/en/ProcessModels/Process_Model/BDRforSDMTransformationRules.htm

4. **Installer des quality gates avant déploiement**
   - Le flux DMM sépare validation input container, duplication control, transfert/transformation vers output, validation output container, puis deployment.
   - À reproduire côté ETL : détecter avant chargement final les doublons, clés manquantes, valeurs non transcodées, longueurs dépassées et références Basic Data absentes.
   - Sources :
     - https://docs.ifs.com/ifsclouddocs/25r2/lang/en/ProcessModels/Process_Model/ValidateDatainInputContainer.htm
     - https://docs.ifs.com/ifsclouddocs/25r2/lang/en/ProcessModels/Process_Model/PerformDuplicationControl.htm
     - https://docs.ifs.com/ifsclouddocs/25r2/lang/en/ProcessModels/Process_Model/ValidateDatainOutputContainer.htm
     - https://docs.ifs.com/ifsclouddocs/25r2/lang/en/ProcessModels/Process_Model/DeployDatatoTargetEnvironment.htm

5. **Actualité IFS : qualité des données pour IA industrielle / supply chain**
   - IFS Cloud est présenté comme plateforme unifiée ERP/EAM/SCM/FSM avec IA industrielle intégrée.
   - Les annonces 2025 mettent l'accent sur l'agentic AI, Nexus Black, TheLoops, et l'acquisition de 7bridges pour l'optimisation supply chain par IA.
   - Implication migration : ne pas réduire la reprise à un strict minimum ; les données articles, actifs, maintenance, fournisseurs, supply chain et historiques doivent être suffisamment propres et structurées pour les usages d'optimisation/IA futurs.
   - Sources :
     - https://www.ifs.com/fr/ifs-cloud
     - https://www.ifs.com/fr/insights/news/ifs-surges-ahead-in-h1-2025
     - https://www.ifs.com/fr/insights/news/ifs-acquires-7bridges-to-transform-supply-chains-with-ai
     - https://www.ifs.com/fr/insights/news/industrial-ai-reaches-tipping-point

## Addendum veille 2026-07-10

Points nouveaux utiles repérés lors d'une veille cron 2026-07-10 :

1. **IFS Cloud / Industrial AI 2026 renforce l'exigence de qualité de données**
   - IFS met en avant l'Industrial AI dans IFS Cloud : opérations, actifs, service, EAM, ERP, FSM et données opérationnelles unifiées.
   - Implication migration SAP ECC -> IFS Cloud : reprendre des données suffisamment riches et reliées (articles, actifs, maintenance, fournisseurs, supply chain, historiques, émissions) pour servir les usages IA/EAM/supply chain, pas seulement le minimum nécessaire au go-live.
   - Sources :
     - https://www.ifs.com/fr/ifs-cloud
     - https://www.ifs.com/en/insights/news/ifs-q1-2026-financial-results

2. **Partenariat Siemens / IFS annoncé le 2026-06-29**
   - Objectif annoncé : connecter conception, production et performance des actifs via l'Industrial AI ; combler les silos entre production, maintenance, données supply chain et performance terrain.
   - Implication migration : préserver les liens entre actifs, équipements, nomenclatures, articles, ordres de maintenance, plans préventifs et données de production lorsque SAP ECC est la source.
   - Source : https://www.ifs.com/en/insights/news/siemens-and-ifs-announce-industrial-ai-partnership

3. **IFS Loops Agent Studio annoncé le 2026-04-23**
   - IFS insiste sur des Digital Workers configurables/gouvernés avec contexte métier, workflows et contrôles de sécurité.
   - Implication migration : documenter les règles de transformation et les contrôles qualité de façon exploitable ; les futurs agents IA auront besoin de données gouvernées et d'un lineage clair entre SAP source, ETL et objets IFS.
   - Source : https://www.ifs.com/en/insights/news/ifs-loops-launches-agent-studio

4. **IFS Zero annoncé le 2026-05-27**
   - Solution d'émissions Scope 1/2/3 pour industries asset-intensive, en complément de Sustainability Management.
   - Implication migration : pour les périmètres industriels, ne pas négliger sites, actifs, consommations, transport/logistique, fournisseurs et catégories nécessaires au reporting ESG/carbone.
   - Source : https://www.ifs.com/en/insights/news/ifs-launches-ifs-zero

5. **Technique de veille utile**
   - Les pages docs.ifs.com ProcessModels peuvent rendre surtout des titres/diagrammes dans le snapshot navigateur ; un fallback par extraction HTML simple peut tout de même confirmer les titres, la version documentaire et la liste des sous-processus DMM.
   - Ne pas conclure que la documentation est vide si le snapshot accessibilité est pauvre ; croiser avec les URLs directes des sous-processus et les notes de recherche internes.

## Format utile pour les veilles futures

Répondre en français avec 5 points actionnables, chacun contenant : titre orienté décision, implication concrète pour SAP ECC -> IFS Cloud, et liens directs vers sources IFS/docs/actualités. Éviter de lister seulement des résultats de recherche ; transformer en recommandations de migration.