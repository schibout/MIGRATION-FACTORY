# clean_data.jt_task — opération/tâche de maintenance IFS

Source projet : `/opt/data/ifs_files/Lot11_Maintenance_Opérations_V2.0.xlsx`, feuille/table `JT_TASK`.
Catalogue analysé : `/opt/data/ifs_model_analysis/ifs_fields_catalog.csv`.
Script DDL généré : `/opt/data/ifs_model_analysis/create_clean_data_jt_task.sql`.

Statut : table `clean_data.jt_task` créée avec 169 colonnes, structure uniquement.

## Sens fonctionnel

`JT_TASK` représente une tâche/opération de maintenance IFS, généralement rattachée à un bon de travail (`WO_NO`). Côté SAP PM, c'est l'équivalent le plus proche d'une opération d'ordre (`AFVC` / `AFVV`) rattachée à l'ordre (`AUFK` / `AFIH`).

## Périmètre Excel

Dans les fichiers IFS, `JT_TASK` apparaît dans plusieurs lots. Pour la migration des opérations, utiliser `Lot11_Maintenance_Opérations_V2.0.xlsx`, où l'objet est marqué `à renseigner`. Les apparitions dans `Lot11_Maintenance_BonDeTravail_V2.0.xlsx` sont indiquées comme doublon de `MAINTENANCE_OPERATION`; celles de `Lot08_Maintenance_EquipementOutils_V2.0.xlsx` sont indiquées comme alimentées par système.

## Champs clés / obligatoires repérés

- `task_seq` : identifiant technique de la tâche, clé primaire dans la spec Excel.
- `wo_no` : numéro du bon de travail rattaché.
- `site` : site IFS, obligatoire.
- `description` : description de l'opération, obligatoire.
- `exclude_from_scheduling_db` : code base d'exclusion planification, obligatoire.
- `appointment_required` : rendez-vous requis, obligatoire.
- `remotely_fulfilled` : exécution à distance, obligatoire.
- `scheduled_manually` : planification manuelle, obligatoire.

Autres champs structurants : `organization_site`, `organization_id`, `priority_id`, `work_type_id`, dates planifiées/réelles (`planned_start`, `planned_finish`, `actual_start`, `actual_finish`), objet déclaré/réel (`reported_*`, `actual_*`), défauts (`error_*`), client/fournisseur (`customer_no`, `vendor_no`), projet (`project_id`, `activity_seq`).

## Loader créé

Fonction créée et testée : `clean_data.alimenter_jt_task()`.

Script source : `/opt/data/ifs_model_analysis/create_alimenter_jt_task.sql`.

Comportement :
- `TRUNCATE clean_data.jt_task`, puis alimentation complète depuis `raw_data.afvc`.
- Déduplication par `(MANDT, AUFPL, APLZL)`.
- `TASK_SEQ` stable = `AUFPL::numeric * 100000000 + APLZL::numeric`.
- Enrichissements prévus par jointures `AFKO`, `AFVV`, `AFRU`, `CRHD`, `JEST` quand ces tables contiennent des lignes.
- Valeurs obligatoires IFS par défaut : `exclude_from_scheduling_db='FALSE'`, `appointment_required='FALSE'`, `remotely_fulfilled='FALSE'`, `scheduled_manually='FALSE'`, `reported_by='KAPEIFS'` si confirmation absente.
- Log dans `clean_data.etl_log` avec `procedure_name='clean_data.alimenter_jt_task'`.

Dernier test au moment de création : 661 389 lignes insérées depuis `AFVC`; `AFKO`, `AFVV`, `AFRU` étaient vides, donc `WO_NO`, dates AFVV/AFRU et confirmations restent NULL jusqu'au chargement de ces sources.

Point d'attention : le loader conserve actuellement `AFVC.WERKS` dans `site`/`organization_site` faute de transcodification site SAP→IFS disponible (`2200`, `9200`, etc.). Si le métier valide `2200→SJM`, `9200→...`, patcher le mapping dans la fonction.

## Tables proches à considérer ensuite

- `JT_TASK_RESOURCE` : ressources affectées à la tâche, à renseigner.
- `MAINT_MATERIAL_REQ_LINE` : besoins matières / pièces de rechange, à renseigner.
- `JT_TASK_PLANNING`, `JT_TASK_COST_LINE`, `JT_TASK_CACHED_DATA` : plutôt alimentées par système selon les specs.
