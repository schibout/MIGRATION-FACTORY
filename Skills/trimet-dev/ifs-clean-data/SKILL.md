---
name: ifs-clean-data
description: >
  Schéma cible clean_data du projet migration-Factory (côté IFS ERP).
  Utiliser pour toute question sur les tables clean_data, les fonctions
  loader alimenter_*, le pattern des colonnes _db IFS, les types canoniques
  des clés de jointure, ou les catégories de transcodification.
---

# clean_data — schéma cible IFS (état introspecté le 2026-07-08)

`clean_data` est la couche de transformation vers IFS ERP : tables miroir des
specs IFS, alimentées depuis `raw_data` par des fonctions `alimenter_*`.
Toujours ré-introspecter avant de générer — cet inventaire peut être périmé :

```sql
SELECT column_name, data_type, character_maximum_length, ordinal_position
FROM information_schema.columns
WHERE table_schema = 'clean_data' AND table_name = '<table>'
ORDER BY ordinal_position;
```

## Domaines fonctionnels (128+ tables + vues)

- **Articles / parts** : part_catalog (52 col), inventory_part (158),
  inventory_part_in_stock, invent_part_plan, purchase_part (55),
  purchase_part_supplier (79), sales_part (69), manuf_part_attribute (71),
  part_gtin, part_gtin_unit_meas, part_catalog_alternative, routing_head,
  assortment_node, ifs_article, ifs_article_maitre,
  mapping_codification_articles, mapping_codification_roh.
- **Clients / ventes** : cust_ord_customer (109), customer_info*,
  customer_tax_info (40), customer_agreement, customer_credit_info,
  cus_* (payment/invoice/comm), identity_invoice_info (107),
  identity_pay_info, payment_address, ifs_customer, ifs_clients.
- **Fournisseurs** : supplier (122), supplier_ifs (141), supplier_info_*
  (general/address/address_type/contact/our_id), supplier_tax_info,
  supplier_address, ifs_fournisseurs.
- **Projets** : project_base (60), project_activity (68),
  project_activity_class, project_margin_matrix (58), project_role,
  project_role_assignment, project_site_ext, sub_project, activity (68),
  ifs_model_project.
- **Maintenance préventive (PM)** : pm_action (93), pm_action_calendar_plan
  (64), pm_action_criteria, pm_action_job, pm_action_planning,
  pm_action_resource, pm_action_role, pm_action_spare_part,
  pm_action_work_step. Les procédures `populate_pm_action*` existent pour le chargement PM ; pour les erreurs IFS d'objet équipement inexistant (`ORA-20105: PmAction.INVMAINTOBJECT`), voir `migration-factory/references/pm-action-orphan-equipment.md`.
- **Maintenance corrective / opérations** : jt_task (169 col) — opération/tâche
  de bon de travail IFS issue de `Lot11_Maintenance_Opérations_V2.0.xlsx` ;
  voir `references/jt-task.md` pour les champs clés et la méthode de création.
- **Équipements** : equipment_functional (66), equipment_object_spare,
  equipment_spare_structure, maintenance_object, technical_spec_alphanum,
  technical_spec_numeric, technical_specification_both,
  technical_object_reference.
- **Ressources** : maint_person_resource, resource_availability,
  resource_connection, resource_detail_file, resource_parent,
  work_time_calendar, ifs_person.
- **Taxes / référentiels** : tax_*, intrastat_exempt_type, address_type,
  comm_method, party_type, delivery_route, ship_via,
  ref_composants_chimiques, ref_formes_codification.
- **Vues** (préfixe `v_`) : v_article*, v_fournisseurs*, v_donnees_*,
  v_resource_*, v_pays, v_portes_detail, v_fl_nomenclature,
  v_codification_resume, v_supplier_tax_alerts — lecture seule, à ne jamais
  cibler dans un loader.
- **Technique** : etl_log (journal des loaders).

## Types canoniques des clés (vérifiés en base)

| Colonne | Type canonique | Divergences connues |
|---|---|---|
| contract | VARCHAR(5) | aucune (12 tables) |
| part_no | VARCHAR(25) | aucune (15 tables) |
| customer_no | VARCHAR(20) | aucune |
| supplier_id | VARCHAR(20) | aucune (14 tables) |
| pm_no | NUMERIC | aucune (9 tables PM) |
| activity_seq | NUMERIC | aucune |
| equipment_object_seq | NUMERIC (3 tables) | VARCHAR(100) dans 1 table — vérifier avant JOIN |
| project_id | VARCHAR(10) (8 tables) | VARCHAR(20) et VARCHAR(100) dans 2 tables — vérifier avant JOIN |

Règle : avant toute jointure sur ces clés, confirmer le type dans LES DEUX
tables ; caster explicitement si divergence.

## Pattern IFS des colonnes doubles `x` / `x_db`

Les specs IFS exposent souvent une valeur client (libellé, VARCHAR(4000))
et une valeur base (`_db`, code court). Les deux colonnes existent dans
clean_data (ex. `leadtime_source` + `leadtime_source_db`). Le loader remplit
en priorité la `_db` ; certaines `_db` restent NULL en attente de décision
métier (cas connu manuf_part_attribute : issue_type_db, leadtime_source_db,
overhaul_scrap_rule_db).

## Création d'une table clean_data depuis une spec IFS Excel

Quand l'utilisateur demande de créer une table `clean_data.<table>` à partir du
modèle IFS Excel :

1. Charger aussi `ifs-data-model-excel` et `migration-factory`.
2. Introspecter d'abord `information_schema` pour vérifier si la table existe
   déjà et comparer les tables sœurs du domaine.
3. Filtrer `/opt/data/ifs_model_analysis/ifs_fields_catalog.csv` sur
   `target_table` et, si plusieurs fichiers exposent la table, choisir la ligne
   `ifs_migration_objects.csv` en périmètre et marquée `à renseigner`.
4. Générer un DDL `CREATE TABLE IF NOT EXISTS clean_data.<table>` en snake_case,
   sans PK/DEFAULT/NOT NULL ni colonnes ETL, conformément aux conventions
   `clean_data`. Conversion type : `VARCHAR2(n)->varchar(n)`, `NUMBER(n)->numeric(n,0)`,
   `DATE->timestamp without time zone`, `ROWID->varchar(10)`.
5. Sauvegarder le SQL généré dans `/opt/data/ifs_model_analysis/` avant
   exécution, puis exécuter en base et vérifier avec `information_schema.columns`.
6. Ajouter des `COMMENT ON TABLE/COLUMN` courts depuis les libellés/descriptions
   Excel quand disponibles.

Exemple déjà créé : `clean_data.jt_task` (169 colonnes) depuis
`Lot11_Maintenance_Opérations_V2.0.xlsx` / `JT_TASK`; script généré :
`/opt/data/ifs_model_analysis/create_clean_data_jt_task.sql`.

## Loaders existants (clean_data.alimenter_*)

Articles : alimenter_part_catalog[_phl|_refonte|_saint_jean],
alimenter_inventory_part[_phl|_planning|_refonte|_saint_jean],
alimenter_purchase_part[_phl], alimenter_purchase_part_supplier,
alimenter_sales_part[_phl], alimenter_manuf_part_attribute_phl,
alimenter_ifs_article[_phl], alimenter_all_phl (orchestrateur PHL).
Projets : alimenter_ifs_project_base, alimenter_project_activity,
alimenter_project_activity_class, alimenter_ifs_project_margin_matrix,
alimenter_ifs_project_role[_assignment], alimenter_ifs_project_site_ext,
alimenter_sub_project, alimenter_activity.

### Piège projet_activity — jalons SharePoint P3 bis / P3 ter

Pour `clean_data.alimenter_project_activity`, ne pas dédupliquer les portes SharePoint seulement par `(project_id, gate)`. Dans `clean_data.v_portes_detail`, un même gate peut avoir plusieurs jalons métier, par exemple `P3` et `P3 bis` pour le projet `22.079`. Une déduplication `DISTINCT ON (project, gate)` supprime `P3 bis` et empêche l’activité IFS `0035-P3` d’être chargée.

Diagnostic recommandé : comparer `clean_data.project_activity` avec `clean_data.v_portes_detail` pour le projet concerné, puis vérifier `public."TranscodificationTable"` catégorie `Activity` (`P3 -> 003-P3`, `P3bis -> 0035-P3`, `P3ter -> 0036-P3`).

Correction de loader : calculer un `activity_source` depuis le libellé de porte normalisé et ne conserver que les jalons de type porte réelle : libellé vide/égal au `gate` `P0..P6` => `P<n>`, `P<n> bis` => `P<n>bis`, `P<n> ter`/`P<n> Ters` => `P<n>ter`; sinon `NULL` et la ligne est exclue (ex. `Point L. Maenner`, `P1 Fermée`, `P4 batch 1`). Faire le `DISTINCT ON` sur `(project_id, activity_source)`, utiliser `activity_source` pour `get_transcodification('Activity', ..., 'ASAP', 'IFS')`, et alimenter les dates depuis `clean_data.v_portes_detail` (`COALESCE(date_realisee, date_prevue)::date`) sans joindre `raw_data.sharepoint_porte`. Même principe pour `clean_data.alimenter_activity()` : plus de `CROSS JOIN` fixe, uniquement les activités de type porte présentes dans `v_portes_detail`. Vérification attendue après `SELECT clean_data.alimenter_activity(); SELECT clean_data.alimenter_project_activity();` : pour `21.067`, les lignes `001-P1`, `002-P2`, `003-P3`, `0035-P3`, `004-P4`, `006-P6` doivent exister, sans `Point L. Maenner` ni CFV ; contrôler aussi que les compteurs CFV sont à 0 si la règle métier demandée est « portes uniquement ». 

Fournisseurs : alimenter_ifs_fournisseurs, alimenter_supplier_address,
alimenter_supplier_info_general[_address|_our_id].
Autres : alimenter_comm_method, alimenter_equipment_functional.

Lire une définition : `pg_get_functiondef(p.oid)` via JOIN
pg_proc/pg_namespace (jamais le cast `::regprocedure`). Chercher dans les
corps : `p.prosrc ILIKE '%terme%'`.

Squelette obligatoire pour tout nouveau loader :
```sql
CREATE OR REPLACE FUNCTION clean_data.alimenter_<table>() RETURNS void
LANGUAGE plpgsql AS $$
DECLARE v_nb INT; v_debut TIMESTAMP := clock_timestamp();
BEGIN
  INSERT INTO clean_data.<table> (...)
  SELECT DISTINCT ON (<cles>) ...
  FROM raw_data.<source> s
  WHERE NOT EXISTS (SELECT 1 FROM clean_data.<table> c WHERE <cles>);
  GET DIAGNOSTICS v_nb = ROW_COUNT;
  RAISE NOTICE '[%] alimenter_<table> : % lignes en %',
    clock_timestamp(), v_nb, clock_timestamp() - v_debut;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'ERREUR alimenter_<table> : % (%)', SQLERRM, SQLSTATE;
  RAISE;
END $$;
```

## Transcodification (catégories actives en base)

`public."TranscodificationTable"` (CamelCase double-quoté obligatoire),
unicité `(category, source_system, target_system, source_value)`.
Fonction : `get_transcodification(category, source_value, source_system,
target_system)` — il existe aussi `get_transcodified_value`.

Catégories : COUNTRY (SAP→IFS, 236), LANGUAGE (38), UOM (20),
ObjectLevel (8) ; ASAP→IFS : Activity (21), PORTE (7), CATEGORIE_1 (6),
CFV (6), Classement (3), ACTIVITY_TASK (3), Note (1).