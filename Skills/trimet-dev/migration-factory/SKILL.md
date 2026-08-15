---
name: migration-factory
description: >
  Conventions ETL du projet migration-Factory (SAP ECC 6.0 -> IFS, PostgreSQL).
  Utiliser pour toute requête SQL, DDL, fonction loader, introspection de schéma,
  transcodification, ou question sur les schémas raw_data / clean_data / public.
---

# migration-Factory — conventions ETL

Plateforme ETL Flask + React/TypeScript + PostgreSQL migrant SAP ECC 6.0 vers IFS.
Trois schémas : `raw_data` (staging), `clean_data` (transformation), `public` (référentiel partagé).

## Règle n°1 : introspecter AVANT de générer

Ne jamais écrire de DDL ou de loader sans avoir interrogé la base :

```sql
SELECT table_name, column_name, data_type, character_maximum_length, ordinal_position
FROM information_schema.columns
WHERE table_schema = 'clean_data'
  AND table_name IN ('table_cible', 'table_soeur')
ORDER BY table_name, ordinal_position;
```

- Vérifier la cohérence de type des clés de jointure sur les tables sœurs
  (ex. `equipment_object_seq`, `contract` vs `equipment_functional`).
- Corps de fonction : `p.prosrc ILIKE '%terme%'` (plus fiable que
  `pg_get_functiondef` sur objets non-plpgsql). Pour la définition complète :
  `pg_get_functiondef()` via JOIN `pg_proc`/`pg_namespace` — jamais le cast
  `::regprocedure`.
- DDIC : `raw_data.dd02l` / `dd02t` utilisables ; `dd03l` / `dd03t` VIDES —
  l'introspection champ par champ vient des fichiers de spec IFS (Excel).

## Conventions raw_data

- Toutes colonnes `TEXT` ; `raw_id BIGINT GENERATED ALWAYS AS IDENTITY`
  (aucun trigger nécessaire) ; colonnes de provenance `source_file` + `loaded_at` ;
  `CREATE TABLE IF NOT EXISTS`.
- PostgreSQL ne peut pas insérer une colonne à une position arbitraire :
  réordonnancement = DROP + RECREATE (acceptable, tables de staging rechargées).

## Conventions clean_data

- snake_case, identifiants non quotés, tout NULLABLE, pas de PK, pas de DEFAULT,
  pas de colonnes de provenance ETL.
- Mapping types : `VARCHAR2(n)->VARCHAR(n)`, `NUMBER(n)->NUMERIC(n,0)`,
  `DATE->DATE`, `VARCHAR2(0)->VARCHAR(4000)`.
- Colonnes `IN_SCOPE=NO` : incluses mais commentées.

## Pattern des fonctions loader (alimenter_*)

`RETURNS void` plpgsql avec :
1. Déduplication `DISTINCT ON`
2. Garde d'idempotence `NOT EXISTS`
3. `GET DIAGNOSTICS` pour le comptage de lignes
4. `RAISE NOTICE` avec horodatage et durée
5. Bloc `EXCEPTION` complet avec `SQLSTATE` / `SQLERRM`

Quand l'utilisateur demande de « compiler » une procédure loader, appliquer réellement le `CREATE OR REPLACE FUNCTION` en base active, pas seulement modifier le fichier SQL. Procédure recommandée :
1. Introspecter `pg_proc` / `information_schema.columns` pour confirmer l'état avant action.
2. Appliquer le fichier `.sql` via une connexion PostgreSQL en écriture (`psql` si disponible, sinon `uv run --with 'psycopg[binary]' python ...`). Pour une procédure ou un loader explicitement demandé par l'utilisateur, exécuter réellement le `CALL`/`SELECT`, puis conserver le statut et le nombre de lignes traité.
3. Lire le DSN depuis `/opt/data/config.yaml` si nécessaire ; pour les chargements en écriture, tenter d'abord le login projet `schibout` plutôt que `demo`. Si l'authentification de `schibout` échoue mais qu'un compte PostgreSQL de référence documenté fonctionne, utiliser ce compte de repli et signaler clairement le compte effectivement utilisé ; ne jamais prétendre avoir utilisé `schibout` sans vérification.
4. Vérifier après compilation avec `pg_proc.prosrc ILIKE` sur les marqueurs attendus (`mach_code`, table source, table de transcodification, etc.) et vérifier que les colonnes cibles existent.
5. Après exécution d'un loader, contrôler les résultats métier : `COUNT(*)`, puis pour chaque champ obligatoire compter les valeurs non nulles/non vides avec `NULLIF(BTRIM(colonne), '')`, ainsi que les valeurs manquantes. Pour une procédure qui tronque/recharge une table, comparer le nombre inséré au total final et distinguer explicitement « exécuté » de « compilé ».
6. Ne relancer le loader (`SELECT clean_data.alimenter_*()`) que si l'utilisateur l'a demandé explicitement ; distinguer clairement « compilé » de « rejoué ».

## Transcodification

- `public."TranscodificationTable"` : TOUJOURS en CamelCase double-quoté.
- Clé d'unicité : `(category, source_system, target_system, source_value)`.
- Fonction : `get_transcodification(category TEXT, source_value TEXT,
  source_system TEXT, target_system TEXT)`.

## Profilage des fichiers sources (avant tout DDL)

- Encodage souvent cp1252/latin-1 (exports ERP français) ; CSV : module `csv`
  Python avec `encoding='latin-1'`, `delimiter=';'`.
- Excel : `pandas.read_excel(sheet_name=None, header=None)` avec `df.iloc[0]`
  comme en-têtes ; arrêt sur `FIELD_NAME == 'Sample Data'` ou lignes `^\d+$`.
- En-têtes dupliqués : dict `seen` avec suffixe `_2` à la 2e occurrence
  (convention existante en base, cf. `phl_article.DIAMETRE_2`).
- Profiler : taux de NULL, distributions de types, longueurs max.

## Livrables

Toujours produire des livrables concrets : fichiers .sql, scripts, artefacts
téléchargeables — pas de discussion abstraite. Répondre en français.

## Références métier SAP/raw_data

- `references/maintenance-operations-sap-rawdata.md` : périmètre des tables SAP d'opérations de maintenance et méthode de comparaison SAP DD02L/DD02T vs API Extraction vs `raw_data`.
- `references/jt-task-resource-sap-mapping.md` : mapping `JT_TASK_RESOURCE` depuis SAP (`AFVC`/`AFKO`/`CRHD`) vers IFS, avec lecture des commentaires `ifs_field_catalog`, constantes, champs à ne pas alimenter, et piège de transcodification `CRHD.ARBPL -> RESOURCE_DETAIL`.
- `references/maint-material-req-line-sap-mapping.md` : mapping `MAINT_MATERIAL_REQ_LINE` depuis SAP `RESB` vers IFS, tables de contexte (`AUFK`/`AFKO`/`AFVC`/`AFVV`/`PLMZ`), règles `task_seq`, champs calculés et vérifications.
- `references/pm-action-orphan-equipment.md` : diagnostic et correction loader pour les erreurs IFS `ORA-20105: PmAction.INVMAINTOBJECT`, avec trim de `mch_code`, table de rejet `pm_action_reject`, et filtrage des tables filles sur les PM Actions valides.
- `references/jt-task-mach-code.md` : étude et chemin recommandé pour ajouter `MACH_CODE` dans `JT_TASK` depuis SAP PM, avec nécessité de charger `AFIH` et mapping `AFIH.EQUNR -> maintenance_object.code`.
- `references/phl-articles.md` : table `raw_data.phl_article`, colonnes utiles, requêtes de liste, répartitions et pièges pour les demandes « articles PHL », y compris les champs PHL à forcer dans les tables propriétaires (`part_catalog`, `manuf_part_attribute`) même lorsque l'utilisateur cite le loader `alimenter_inventory_part_phl`.
- `references/sap-article-selection-part-catalog.md` : sélection des articles SAP réellement utilisés pour filtrer MARA avant chargement IFS `part_catalog`, avec table `clean_data.selection_articles_utilises`, procédure `alimenter_selection_articles_utilises()`, sources d'usage MARC/MARD/EKPO/RESB/MAST/STPO, et piège performance `UNION + GROUP BY` plutôt que `EXISTS` corrélés.
- `references/phl-inventory-part-custom-fields.md` : règles custom PHL pour `clean_data.inventory_part`, notamment `c_spire_code = 'S'`, mapping diamètre/poids/etc., et piège INSERT-only vs UPDATE des lignes existantes.
- `references/phl-density-and-ifs-forced-fields.md` : règles PHL/IFS pour forcer `part_catalog.condition_code_usage_db = NOT_ALLOW_COND_CODE`, laisser `inventory_part.intrastat_conv_factor` à `NULL`, et alimenter les densités `inventory_part.c_density` / `manuf_part_attribute.density` depuis `raw_data.phl_article_densite`; inclut procédures à patcher et requêtes de contrôle anti-régression.
- `references/sharepoint-portes-project-activity.md` : diagnostic des portes SharePoint et des activités projet : distinguer `raw_data.sharepoint_porte`, `clean_data.activity`, `clean_data.project_activity` et `clean_data.v_portes_detail`; piège des portes bis/ter générées artificiellement par `alimenter_activity()`; cause fréquente d'absence de `project_activity` quand `v_portes_detail` élimine un projet faute de `sharepoint_etats_avancement` correspondant.
- `references/sap-fixed-assets-csv-export.md` : export CSV lisible des immobilisations SAP (`ANLA`/`ANLB`/`ANLC`/`ANKT`) pour migration IFS, avec libellés métier, calcul VNC/cumul amortissements/date fin d'amortissement, choix de zone de valorisation et colonnes techniques à éviter.
- `references/sap-fixed-assets-accounting-fields.md` : notes FI-AA pour exports immos : sens de `ANLA-AKTIV`, VNC vs valeurs `ANLC`, zones `T093/T093T`, détermination comptable `ANLA-KTOGR` via `T095/T095T/T095B`, et libellés CSV métier.
- `references/customer-group-geography.md` : règle métier groupe client IFS selon pays du siège (`0` France, `1` UE, `2` hors UE) et procédures à patcher (`ifs_customer.customer_group`, `cust_ord_customer.cust_grp`).

## Extractions CSV depuis PostgreSQL

Quand l'utilisateur demande d'extraire des données SAP/IFS, produire un vrai fichier CSV local plutôt que de coller un gros résultat SQL dans la réponse :

### Immobilisations FI-AA : cohérence des zones et des comptes

Pour un export d'immobilisations, ne jamais mélanger la zone de détermination des comptes avec la zone de valorisation des montants :

- Les comptes FI-AA demandés en zone statutaire doivent être joints à `raw_data.t095` avec `afabe = '02'` explicitement ; ne jamais utiliser un `DISTINCT ON` qui préfère implicitement 01, 03 ou une autre zone.
- Les durées et règles d'amortissement (`ANLB`) peuvent être sélectionnées selon la zone métier validée ; si la reprise exige la zone 02, filtrer 02 et signaler les immobilisations absentes.
- Les valeurs comptables (`ANLC`) doivent être contrôlées avant l'export : compter les lignes par `afabe`, vérifier que la zone requise existe, et arrêter ou signaler clairement si la table est vide. Ne pas livrer un CSV où les montants/VNC sont silencieusement vides.
- Conserver la zone effectivement utilisée dans une colonne de contrôle et vérifier que les comptes et les valeurs ne sont pas présentés comme provenant de la même zone lorsqu'ils ne le sont pas.
- Les comptes SAP peuvent contenir des zéros de présentation ; supprimer les zéros de tête uniquement pour l'affichage, jamais pour la jointure. Ne pas forcer artificiellement un compte à commencer par 46 : produire une liste d'exceptions par clé `KTOGR` et faire valider les comptes hors 46 par les métiers.
- Avant de conclure, contrôler le nombre d'immobilisations, le nombre de comptes renseignés, la répartition des zones ANLC, le nombre de comptes hors préfixe attendu et la présence des valeurs acquisition/amortissements/VNC.

Voir `references/sap-fixed-assets-accounting-fields.md` et `references/sap-fixed-assets-csv-export.md` pour le mapping FI-AA et les contrôles.

1. Introspecter les tables/colonnes et compter les lignes avant export.
2. Si le résultat est volumineux, éviter `mcp__postgres__query` pour le contenu final car la sortie peut être tronquée ; l'utiliser pour découverte/validation uniquement.
3. Récupérer l'URI PostgreSQL depuis la configuration Hermes si nécessaire, puis utiliser Python avec `psycopg` et `COPY (...) TO STDOUT WITH (FORMAT CSV, HEADER true, DELIMITER ';', ENCODING 'UTF8')` vers `/opt/data/exports/`. Pour un export métier, privilégier un script Python reproductible qui écrit le CSV en UTF-8 avec BOM, séparateur `;`, et convertit les valeurs `Decimal` de `.` vers `,` uniquement à la sortie.
4. Avant tout filtre société, vérifier les valeurs distinctes de `ANLA-BUKRS` : une inversion typographique du code demandé (par ex. `STNJ` au lieu de `STJN`) peut produire zéro ligne alors que le périmètre existe. Confirmer le code réellement présent et le signaler.
5. Les colonnes SAP numériques peuvent être typées `numeric` dans `raw_data`, même si le reste des colonnes est `text` : ne jamais appliquer `trim()` directement à un champ numérique ; utiliser `COALESCE(col,0)::numeric` ou `col::text` selon le besoin.
6. Pour un fichier synthétique à une ligne par immobilisation, sélectionner une seule ligne ANLC par `(bukrs, anln1, anln2)` avec une priorité de zone explicitement documentée (`03`, `73`, `02`, `60`, `01`) puis l'exercice le plus récent. Les comptes de détermination restent joints séparément sur `T095-AFABE='02'` si le métier demande la zone comptable 02 ; ne jamais présenter cette zone de comptes comme la zone des valeurs si elles diffèrent.
7. Quand l'utilisateur fournit une liste exacte de colonnes, produire exactement cette liste et cet ordre, sans ajouter de copie ou colonnes supplémentaires non demandées. Pour les livrables de migration en français, conserver les libellés métier demandés et vérifier l'en-tête au caractère près.
4. Ouvrir le fichier en binaire pour écrire les chunks COPY (`bytes(data)`) afin d'éviter les erreurs `memoryview`.
5. Vérifier l'export en relisant le CSV avec `csv.DictReader(..., delimiter=';')` et comparer au `COUNT(*)` source avant de répondre.

Pour les fournisseurs SAP : source principale `raw_data.lfa1` (`lifnr` = numéro fournisseur). La sélection projet peut venir de `public.fournisseurs_a_conserver.vendor_no` jointe à `raw_data.lfa1.lifnr`, ou de `raw_data.selection_fournisseurs` selon le périmètre demandé.