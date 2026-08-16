# PM Actions — objets équipements orphelins (ORA-20105)

## Symptôme IFS

Lors de l'intégration des PM Actions, IFS peut retourner :

`ORA-20105: PmAction.INVMAINTOBJECT: The Equipment Object does not exist.`

Ce message indique que la PM Action référence un objet équipement inexistant côté IFS. Sur migration-Factory, le chargement PM Action repose principalement sur :

- `clean_data.pm_action.mch_code_contract` = site/contract, typiquement `SJ`
- `clean_data.pm_action.mch_code` = code objet équipement

`equipment_object_seq` peut rester NULL ; l'intégration contrôle surtout le couple contract/code objet.

## Diagnostic SQL

```sql
SELECT
  p.pm_no,
  p.pm_revision,
  p.mch_code_contract,
  p.mch_code,
  p.description
FROM clean_data.pm_action p
WHERE p.mch_code IS NULL
   OR btrim(p.mch_code) = ''
   OR NOT EXISTS (
      SELECT 1
      FROM clean_data.equipment_functional ef
      WHERE ef.contract = p.mch_code_contract
        AND ef.mch_code = btrim(p.mch_code)
   )
ORDER BY p.pm_no;
```

Contrôler aussi les enfants qui partiraient sans parent valide :

```sql
SELECT count(*) AS work_steps_sans_parent
FROM clean_data.pm_action_work_step ws
WHERE NOT EXISTS (
  SELECT 1
  FROM clean_data.pm_action p
  WHERE p.pm_no = ws.pm_no
    AND p.pm_revision = ws.pm_revision
);
```

## Correction loader recommandée

1. Toujours normaliser le poste technique source :

```sql
NULLIF(btrim(min(s.poste_technique)), '') AS mch_code
```

2. Exclure du chargement `clean_data.pm_action` les PM Actions dont l'objet est vide ou introuvable dans `clean_data.equipment_functional` pour le site.

3. Stocker ces exclusions dans une table de rejet, par exemple :

```sql
CREATE TABLE IF NOT EXISTS clean_data.pm_action_reject (
    rejection_reason varchar(2000),
    pm_no numeric,
    pm_revision varchar(6),
    mch_code_contract varchar(5),
    mch_code varchar(100),
    description varchar(2000),
    source_raw_ids varchar(2000),
    rejected_at timestamp without time zone
);
```

Motifs utiles :

- `Objet équipement non renseigné`
- `Objet équipement inexistant dans clean_data.equipment_functional pour le site <site>`

4. Charger les tables filles PM (`pm_action_work_step`, `pm_action_resource`, `pm_action_role`, etc.) en joignant `clean_data.pm_action` sur `(pm_no, pm_revision)` afin de ne conserver que les enfants de PM Actions valides :

```sql
FROM clean_data.v_pm_source s
JOIN clean_data.pm_action p
  ON p.pm_no = s.pm_no
 AND p.pm_revision = v_pm_revision
```

Pour `pm_action_work_step`, reprendre `p.mch_code` plutôt que le poste technique source brut, afin de propager le code trimé.

## Vérifications après `CALL clean_data.populate_all_pm_actions()`

```sql
SELECT count(*) AS total,
       count(*) FILTER (WHERE mch_code IS NULL OR btrim(mch_code)='') AS empty_mch,
       count(*) FILTER (WHERE mch_code<>btrim(mch_code)) AS trailing,
       count(*) FILTER (WHERE NOT EXISTS (
           SELECT 1 FROM clean_data.equipment_functional ef
           WHERE ef.contract=pm_action.mch_code_contract
             AND ef.mch_code=pm_action.mch_code
       )) AS orphan
FROM clean_data.pm_action;
```

Attendu : `empty_mch = 0`, `trailing = 0`, `orphan = 0`.

```sql
SELECT count(*) total,
       count(*) FILTER (WHERE rejection_reason ILIKE '%non renseigné%') empty_mch,
       count(*) FILTER (WHERE rejection_reason ILIKE '%inexistant%') orphan_mch
FROM clean_data.pm_action_reject;
```

La table de rejet permet ensuite de décider métier : créer les objets équipements manquants ou exclure définitivement les PM Actions concernées.

## Remarque d'accès base

Si le MCP PostgreSQL est en lecture seule, appliquer le SQL via une connexion PostgreSQL en écriture (`uv run --with 'psycopg[binary]' python ...` ou `psql` si disponible). Ne jamais utiliser le compte `demo`; utiliser le compte projet disponible ou le DSN fourni par l'utilisateur.