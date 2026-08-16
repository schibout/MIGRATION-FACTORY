# JT_TASK — étude d'alimentation de MACH_CODE

Contexte : pour ajouter le numéro d'équipement dans `clean_data.jt_task`, ne pas dériver l'équipement depuis les seules tables d'opérations `AFVC` / `AFKO` / `AUFK`.

## Constat durable

- `clean_data.jt_task` peut ne pas contenir de colonne `mach_code` dans la structure issue de la spec IFS initiale.
- Le loader `clean_data.alimenter_jt_task()` part de `raw_data.afvc` et enrichit via `afko`, `afvv`, `afru`, `crhd`, `jest` ; ce chemin ne donne pas à lui seul l'équipement.
- La table SAP standard à charger pour le lien ordre de maintenance -> objet technique est `AFIH` (`En-tête ordre de travail`).
- Dans ce projet, `AFIH` peut exister dans `raw_data.dd02l/dd02t` mais être absente de `raw_data` : vérifier explicitement avant de patcher le loader.

## Chemin recommandé

1. `AFVC` opération -> `AFKO` par `(mandt, aufpl)` pour récupérer `aufnr`.
2. `AFKO.AUFNR` -> `AFIH.AUFNR` par `(mandt, aufnr)`.
3. Source équipement prioritaire : `AFIH.EQUNR`.
4. Conversion vers code IFS éditable via `clean_data.maintenance_object` :
   - `object_type = 'EQUIPMENT'`
   - `sap_key = AFIH.EQUNR`
   - `code` = `mach_code` cible
   - `is_active = true` si la colonne existe/est pertinente.

Fallback possible si le métier accepte un objet fonctionnel plutôt qu'un équipement strict : `AFIH.TPLNR` -> `maintenance_object.object_type = 'FUNC_LOC'` -> `code`. Ne pas mélanger silencieusement ce fallback avec le numéro d'équipement demandé ; le documenter ou l'exposer séparément.

## Champs minimum à extraire dans AFIH

`MANDT`, `AUFNR`, `EQUNR`, `TPLNR`, `ILOAN`.

## Option d'implémentation directe

```sql
ALTER TABLE clean_data.jt_task
ADD COLUMN IF NOT EXISTS mach_code varchar(100);
```

Dans `clean_data.alimenter_jt_task()` :

- ajouter `mach_code` dans la liste `INSERT` ;
- ajouter `LEFT JOIN raw_data.afih h ON h.mandt = v.mandt AND h.aufnr = k.aufnr` ;
- ajouter `LEFT JOIN clean_data.maintenance_object mo_eq ON mo_eq.object_type = 'EQUIPMENT' AND mo_eq.sap_key = h.equnr AND mo_eq.is_active` ;
- mapper `mach_code = substring(coalesce(mo_eq.code, nullif(trim(h.equnr), '')), 1, 100)`.

## Contrôles avant/après

Avant patch :

```sql
SELECT EXISTS (
  SELECT 1 FROM information_schema.tables
  WHERE table_schema='raw_data' AND table_name='afih'
) AS raw_afih_exists,
EXISTS (
  SELECT 1 FROM raw_data.dd02l WHERE upper(tabname)='AFIH'
) AS sap_afih_in_dd02l;
```

Après chargement/patch :

```sql
SELECT count(*) AS total,
       count(mach_code) AS avec_mach_code,
       round(100.0 * count(mach_code) / nullif(count(*),0), 2) AS pct_avec_mach_code
FROM clean_data.jt_task;

SELECT mach_code, count(*)
FROM clean_data.jt_task
WHERE mach_code IS NOT NULL
GROUP BY mach_code
ORDER BY count(*) DESC
LIMIT 20;
```

## Piège

`raw_data.iloa` peut contenir `tplnr` mais pas d'`aufnr` exploitable ; ne pas utiliser `ILOA.AUFNR` comme chemin de secours sans mesurer sa couverture. `CAUFV` peut aussi être présente sans exposer `EQUNR` / `TPLNR` selon l'extraction actuelle.