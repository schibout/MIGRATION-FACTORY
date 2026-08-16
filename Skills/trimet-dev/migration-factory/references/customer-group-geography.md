# Groupes client IFS selon pays du siège

Contexte : alimentation client SAP/IFS dans `clean_data`, notamment `ifs_customer.customer_group` et `cust_ord_customer.cust_grp`.

## Règle métier

Le groupe client doit être déterminé d'après le pays de l'adresse du siège :

- `0` : client basé en France (`FR`)
- `1` : client basé dans l'Union Européenne hors France
- `2` : autre pays

Liste UE utilisée hors France : `AT, BE, BG, CY, CZ, DE, DK, EE, ES, FI, GR, HR, HU, IE, IT, LT, LU, LV, MT, NL, PL, PT, RO, SE, SI, SK`.

## Procédures concernées

Procédures SAP qui alimentent `clean_data.ifs_customer.customer_group` :

- `clean_data.sp_insert_ifs_customer_from_sap`
- `clean_data.sp_insert_ifs_customer_ref`

Dans ces procédures, remplacer l'ancien mapping SAP `knvv.kdgrp AS customer_group` par une règle basée sur `kna1.land1`, par exemple :

```sql
CASE
    WHEN UPPER(TRIM(kna1.land1)) = 'FR' THEN '0'
    WHEN UPPER(TRIM(kna1.land1)) IN ('AT','BE','BG','CY','CZ','DE','DK','EE','ES','FI','GR','HR','HU','IE','IT','LT','LU','LV','MT','NL','PL','PT','RO','SE','SI','SK') THEN '1'
    ELSE '2'
END AS customer_group
```

Procédure fichier qui alimente `clean_data.cust_ord_customer.cust_grp` :

- `clean_data.sp_insert_cust_ord_customer_from_file_customer`

Dans cette procédure, `cust_grp` ne doit pas rester `NULL`; utiliser `fc.country` :

```sql
CASE
    WHEN UPPER(TRIM(fc.country)) = 'FR' THEN '0'
    WHEN UPPER(TRIM(fc.country)) IN ('AT','BE','BG','CY','CZ','DE','DK','EE','ES','FI','GR','HR','HU','IE','IT','LT','LU','LV','MT','NL','PL','PT','RO','SE','SI','SK') THEN '1'
    ELSE '2'
END::VARCHAR(10)
```

Ne pas oublier d'ajouter `fc.country` au `GROUP BY` si le SELECT est agrégé.

## Vérifications utiles

Après compilation, vérifier dans `pg_proc.prosrc` que les marqueurs sont présents :

```sql
SELECT p.proname,
       p.prosrc ILIKE '%UPPER(TRIM(kna1.land1))%' AS has_kna1_rule,
       p.prosrc ILIKE '%UPPER(TRIM(fc.country))%' AS has_fc_rule
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'clean_data'
  AND p.proname IN (
      'sp_insert_ifs_customer_from_sap',
      'sp_insert_ifs_customer_ref',
      'sp_insert_cust_ord_customer_from_file_customer'
  )
ORDER BY p.proname;
```

Si besoin, simuler la répartition avant de rejouer les loaders :

```sql
WITH calc AS (
    SELECT CASE
             WHEN UPPER(TRIM(country)) = 'FR' THEN '0'
             WHEN UPPER(TRIM(country)) IN ('AT','BE','BG','CY','CZ','DE','DK','EE','ES','FI','GR','HR','HU','IE','IT','LT','LU','LV','MT','NL','PL','PT','RO','SE','SI','SK') THEN '1'
             ELSE '2'
           END AS future_customer_group
    FROM clean_data.ifs_customer
)
SELECT future_customer_group, COUNT(*)
FROM calc
GROUP BY future_customer_group
ORDER BY future_customer_group;
```

Comme pour les autres loaders, compiler seulement si l'utilisateur demande la modification; ne rejouer les procédures d'alimentation que sur demande explicite.