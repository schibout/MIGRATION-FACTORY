# JT_TASK_RESOURCE — mapping SAP vers IFS

Contexte : objet IFS `JT_TASK_RESOURCE` (Lot11 Maintenance opérations). Pour ce type de demande, relire d'abord `public.ifs_field_catalog.comments` pour respecter les champs à ne pas renseigner et les constantes métier.

## Sources SAP utiles

- `raw_data.afvc` : source principale des opérations/lignes de travail. Champs utiles : `mandt`, `aufpl`, `aplzl`, `vornr`, `arbid`, `anzma`, `loekz`.
- `raw_data.afko` : en-tête ordre, à joindre sur `afko.mandt = afvc.mandt` et `afko.aufpl = afvc.aufpl`; champ utile : `aufnr` pour `WO_NO`.
- `raw_data.crhd` : poste de travail / centre de charge, à joindre sur `crhd.mandt = afvc.mandt` et `crhd.objid = afvc.arbid`; champ utile : `arbpl` pour retrouver le groupe ressource IFS.
- `raw_data.resource_detail_file` : référentiel IFS des ressources/groupes, champs utiles : `resource_seq`, `resource_id`, `resource_type_db`, `description`.

À vérifier à chaque session par `COUNT(*)` : `raw_data.afvv` et `raw_data.afru` peuvent exister mais être vides, donc ne pas construire le mapping principal dessus sans contrôle.

## Correspondances principales

- `TASK_SEQ` : reprendre exactement la clé de `clean_data.jt_task`.
  - Règle utilisée dans le loader JT_TASK : `afvc.aufpl::numeric * 100000000 + afvc.aplzl::numeric`.
- `TASK_RESOURCE_SEQ` : séquence technique de ligne ressource. Si une seule ligne ressource par opération, utiliser une séquence déterministe (`row_number() over(order by mandt, aufpl, aplzl)`), à valider métier.
- `PLANNED_QUANTITY` : commentaire IFS « Quantité ressource » ; source proposée `raw_data.afvc.anzma`, avec défaut à valider si valeur vide ou 0.
- `DEMAND_TYPE_DB` : commentaire IFS « PERSON ou EQUIPMENT ». Déduire depuis le type de ressource IFS (`resource_detail_file.resource_type_db`) ; pour les centres de travail SAP CRHD, défaut probable `PERSON`/groupe personnel sauf transcodification équipement.
- `RESOURCE_GROUP_SEQ` : commentaire IFS indique que l'info est dans `RESOURCE_DETAIL`.
  - Chaîne : `AFVC.ARBID -> CRHD.OBJID -> CRHD.ARBPL -> transcodification -> RESOURCE_DETAIL_FILE.RESOURCE_SEQ`.
  - Les codes SAP peuvent être du type `7.MFIE`, `7.MELY`, `7.MCAR`, alors que les ressources IFS peuvent être `SJ-MFIE`, `SJ-MFIE-MECA`, `SJ-MFIE-ELEC`; prévoir une table de transcodification `ARBPL -> RESOURCE_ID` plutôt qu'une jointure texte naïve.
- `WO_NO` : reprendre `JT_TASK.WO_NO`, lui-même issu de `raw_data.afko.aufnr` via `AFKO.AUFPL = AFVC.AUFPL`.

## Constantes / champs à ne pas alimenter selon `ifs_field_catalog.comments`

- `OFFSET` = `0`.
- `SOURCING_OPTION_DB` = `INTERNALLY_SOURCED`.
- `CREW_TIME_INVOICING` = `FALSE`.
- Ne pas alimenter : `PLANNED_HOURS`, `REMARK`, `CREATED_BY`, `CREATED_DATE`, `RESOURCE_SEQ`, `TASK_PLAN_LINE_SEQ`, `PLAN_LINE_NO`, `MODIFIED_BY`, `MODIFIED_DATE`, `SOURCING_OPTION`, `RENTAL_*`, `QUOTATION_*`, `QUO_*`, `POOL_ALLOCATED_QTY`.
- `OBJVERSION` et `OBJID` sont des champs techniques IFS ; ne pas alimenter même si le catalogue contient des descriptions/commentaires incohérents.

## Loader clean_data.alimenter_jt_task_resource

Quand l'utilisateur demande de créer le loader pour charger `JT_TASK_RESOURCE`, produire un script SQL concret dans `/opt/data/ifs_model_analysis/create_alimenter_jt_task_resource.sql` contenant à la fois le `CREATE TABLE IF NOT EXISTS clean_data.jt_task_resource` et `CREATE OR REPLACE FUNCTION clean_data.alimenter_jt_task_resource()`.

Pattern validé :

- Créer toutes les colonnes IFS issues de `public.ifs_field_catalog`, mais n'alimenter dans l'INSERT que les champs utiles/commentés comme renseignables.
- Utiliser `TRUNCATE TABLE clean_data.jt_task_resource` pour rester cohérent avec le loader existant `clean_data.alimenter_jt_task` qui fonctionne en mode FULL.
- Source principale : `raw_data.afvc v`.
- Jointure ordre : `raw_data.afko k ON k.mandt = v.mandt AND k.aufpl = v.aufpl`.
- Jointure centre de charge : `raw_data.crhd c ON c.mandt = v.mandt AND c.objid = v.arbid AND (c.werks = v.werks OR c.werks IS NULL OR v.werks IS NULL)`.
- Filtrer les opérations supprimées : `(v.loekz IS NULL OR trim(v.loekz) = '')`.
- Garder seulement les clés numériques : `trim(v.aufpl) ~ '^[0-9]+$'` et `trim(v.aplzl) ~ '^[0-9]+$'`.
- Insérer seulement les lignes qui existent déjà dans `clean_data.jt_task` via `EXISTS (SELECT 1 FROM clean_data.jt_task t WHERE t.task_seq = m.task_seq)`.

Mappings à coder dans le loader :

- `task_seq = trim(v.aufpl)::numeric * 100000000 + trim(v.aplzl)::numeric`.
- `task_resource_seq = row_number() over (order by mandt, trim(aufpl)::numeric, trim(aplzl)::numeric)::numeric`.
- `planned_quantity = AFVC.ANZMA` si numérique et strictement > 0, sinon `1`. Les exports SAP observés peuvent contenir beaucoup de `0.00`; ne pas charger `0` comme quantité ressource par défaut.
- `offset = 0` ; attention le nom SQL doit être quoté : `"offset"`.
- `demand_type_db = 'EQUIPMENT'` seulement si `resource_detail_file.resource_type_db = 'EQUIPMENT'`, sinon `'PERSON'`.
- `resource_group_seq` depuis `clean_data.resource_detail_file.resource_seq` en résolvant le `resource_id` par priorité : `get_transcodification('RESOURCE_GROUP', c.arbpl, 'SAP', 'IFS')`, puis `get_transcodification('ARBPL', c.arbpl, 'SAP', 'IFS')`, puis fallback mécanique `7.MFIE -> SJ-MFIE` (`'SJ-' || split_part(c.arbpl, '.', 2)`).
- `wo_no = AFKO.AUFNR` si numérique.
- `sourcing_option_db = 'INTERNALLY_SOURCED'`.
- `crew_time_invoicing = 'FALSE'`.
- Laisser NULL les champs indiqués « ne pas renseigner » : `planned_hours`, `remark`, `created_by`, `created_date`, `demand_type`, `resource_seq`, `task_plan_line_seq`, `plan_line_no`, `modified_*`, `sourcing_option`, `rental_*`, `quotation_*`, `quo_*`, `pool_allocated_qty`, `external_id`, `objversion`, `objid`.

Vérification légère avant exécution écriture : utiliser une requête SELECT sur un échantillon pour contrôler que `CRHD.ARBPL` se résout vers `resource_group_seq`. Exemple observé : `7.MFIE -> SJ-MFIE -> resource_group_seq = 6`, `demand_type_db = PERSON`.

Si l'outil PostgreSQL MCP est read-only, ne pas s'arrêter à l'échec du `CREATE`; livrer le fichier SQL et donner la commande d'exécution avec l'utilisateur projet `schibout` :

```bash
psql -h 10.190.100.58 -U schibout -d sap_migration_db -f /opt/data/ifs_model_analysis/create_alimenter_jt_task_resource.sql
psql -h 10.190.100.58 -U schibout -d sap_migration_db -c "SELECT clean_data.alimenter_jt_task_resource();"
```

## Pièges

- `public.ifs_field_catalog` peut contenir des lignes de sample data importées comme pseudo-champs (`Sample Data set`, `1`, `2`, etc.). Filtrer aux vrais champs IFS avant de produire le mapping.
- Ne pas supposer une correspondance directe entre `CRHD.ARBPL` et `RESOURCE_DETAIL.resource_id`; utiliser une transcodification contrôlée, puis seulement un fallback mécanique `7.X -> SJ-X` si aucune transcodification n'existe.
- Pour tout loader, introspecter les colonnes existantes et réutiliser la logique validée de `clean_data.alimenter_jt_task` pour `TASK_SEQ`/`WO_NO` au lieu de recalculer différemment.
- Les tests d'écriture via MCP peuvent échouer car le serveur Postgres MCP est read-only ; c'est un mode d'accès, pas une erreur SQL. Dans ce cas, sauvegarder le SQL dans `/opt/data/ifs_model_analysis/` et fournir la commande `psql` à exécuter avec `schibout`.