---
name: ifs-data-model-excel
description: >
  Modèle de données IFS issu des fichiers Excel déposés dans /opt/data/ifs_files.
  Utiliser quand l'utilisateur pose des questions sur les tables/champs IFS, objets de migration,
  domaines fonctionnels, clés, champs obligatoires, mapping source SAP/legacy vers IFS.
---

# Modèle de données IFS — fichiers Excel projet

## Source analysée

Dossier source : `/opt/data/ifs_files`

Analyse réalisée sur 61 fichiers `.xlsx`.
Artefacts générés dans : `/opt/data/ifs_model_analysis`

Fichiers utiles :

- `/opt/data/ifs_model_analysis/README.md` : synthèse globale.
- `/opt/data/ifs_model_analysis/ifs_excel_index.md` : index humain des workbooks et feuilles.
- `/opt/data/ifs_model_analysis/ifs_tables_catalog.csv` : une ligne par table/feuille IFS.
- `/opt/data/ifs_model_analysis/ifs_fields_catalog.csv` : une ligne par champ IFS avec type, libellé, flags, source système/table/champ quand renseignée.
- `/opt/data/ifs_model_analysis/ifs_migration_objects.csv` : structure des objets de migration, séquence, parent, in_scope, notes, jobs.
- Versions JSON disponibles : `ifs_fields_catalog.json`, `ifs_tables_catalog.json`, `ifs_excel_index.json`.

## Volumétrie extraite

- 488 tables/feuilles métier IFS.
- 21 766 champs catalogués.
- 524 lignes d'objets de migration.
- Domaine Maintenance : 128 tables, 4 899 champs.
- Domaine Production : 76 tables, 5 300 champs.
- Domaine VenteTransport / Vente-Transport : 119 tables, 4 908 champs.
- Domaine AchatAppro / Achat-Appro : 78 tables, 3 770 champs.
- Domaine Projet : 47 tables, 1 855 champs.

## Colonnes principales du catalogue champs

Dans `ifs_fields_catalog.csv` :

- `file` : fichier Excel source.
- `domain` : domaine déduit du nom de fichier.
- `target_table` : nom de la feuille/table IFS.
- `target_id` : TARGET_ID quand présent.
- `field_name` : nom technique du champ IFS.
- `field_label`, `field_label_fr` : libellés.
- `description` : description métier.
- `source_system`, `source_table`, `source_field`, `source_type` : mapping source quand renseigné dans Excel.
- `data_type`, `data_length` : type et longueur IFS.
- `mandatory`, `insertable`, `updatable`, `primary_key`, `lov`, `default_value`, `in_scope` : flags IFS quand présents.

Séparateur CSV : point-virgule `;`, encodage UTF-8.

## Méthode de réponse recommandée

1. Pour une question sur une table précise, chercher d'abord dans `ifs_tables_catalog.csv` et `ifs_fields_catalog.csv`.
2. Pour une question sur un domaine, filtrer `domain` ou le nom du fichier source.
3. Pour une question d'ordre de chargement/hiérarchie, consulter `ifs_migration_objects.csv` : `structure_seq`, `parent_seq`, `target_id`, `in_scope`.
4. Pour une demande de chargement en base PostgreSQL de `public.ifs_field_catalog`, utiliser le guide `references/load-ifs-field-catalog-postgres.md` : partir du CSV consolidé, respecter la contrainte unique `(lot_id, entity, field_name)`, ne pas fournir `catalog_id`, et vérifier les volumes après upsert.
5. Pour une question fonctionnelle, croiser avec le skill `ifs-fondamentaux`.
6. Pour une question ETL/mapping SAP vers IFS, croiser avec le skill `migration-factory`.

## Commandes pratiques

Lister les tables d'un domaine :

`python3 - <<'PY'
import csv
with open('/opt/data/ifs_model_analysis/ifs_tables_catalog.csv', encoding='utf-8') as f:
    for r in csv.DictReader(f, delimiter=';'):
        if r['domain'].lower() == 'maintenance':
            print(r['target_table'], r['field_count'], r['file'])
PY`

Afficher les champs d'une table :

`python3 - <<'PY'
import csv
TABLE='PM_ACTION'
with open('/opt/data/ifs_model_analysis/ifs_fields_catalog.csv', encoding='utf-8') as f:
    for r in csv.DictReader(f, delimiter=';'):
        if r['target_table'].upper() == TABLE:
            print(r['field_name'], r['data_type'], r['data_length'], r['mandatory'], r['primary_key'], r['field_label_fr'] or r['field_label'])
PY`

Rechercher une table ou un champ : utiliser `search_files` sur `/opt/data/ifs_model_analysis/ifs_fields_catalog.csv` ou `/opt/data/ifs_model_analysis/ifs_tables_catalog.csv`.

## Points d'attention

- Plusieurs fichiers existent en doublon ou variantes (`Final`, `(1)`, versions V2/V3). Toujours citer le fichier source dans la réponse.
- Les onglets Excel correspondent généralement aux tables/objets cibles IFS.
- Les lignes `Migration Object Definitions` ne sont pas des tables métier ; elles décrivent la hiérarchie et le périmètre de migration.
- Certains champs source SAP/legacy peuvent être vides : ne pas inventer le mapping, signaler qu'il n'est pas renseigné dans Excel.
- Les colonnes et flags varient selon les fichiers : vérifier dans le catalogue avant de répondre.
