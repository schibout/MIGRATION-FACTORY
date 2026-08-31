# Articles PHL (`raw_data.phl_article`)

Contexte : réponses aux demandes du type « liste des articles PHL ».

## Table source

- Schéma/table : `raw_data.phl_article`
- Volume observé : 3657 lignes, dont une ligne d'en-tête importée dans les données (`"STATUT" = 'STATUT'`).
- Articles distincts observés : 2848 sur `"N. ARTICLE"` hors ligne d'en-tête.
- Statuts observés : `F` = 1774, `I` = 1882.

## Colonnes utiles pour une liste lisible

Colonnes à privilégier pour une première réponse ou un export synthétique :

```sql
SELECT
  "NUMERO" AS numero,
  "N. ARTICLE" AS article,
  "DESCRIPTION" AS description,
  "STATUT" AS statut,
  "ALLIAGE" AS alliage,
  "SERIE ALL" AS serie_alliage,
  "FORME" AS forme,
  "DIAMETRE" AS diametre,
  "NORME CHARGE" AS norme_charge,
  "POIDS COMMERCIAL" AS poids_commercial,
  "U/M" AS unite
FROM raw_data.phl_article
WHERE "N. ARTICLE" IS NOT NULL
  AND "N. ARTICLE" <> 'N. ARTICLE'
ORDER BY NULLIF(regexp_replace("NUMERO", '[^0-9]', '', 'g'), '')::int NULLS LAST,
         "N. ARTICLE";
```

## Répartitions utiles

Principales formes observées :

- `FIL ALLIAGE MECANIQ.` : 1662
- `PLAQUES` : 851
- `REBUT FIL` : 316
- `FIL ALUMINIUM` : 245
- `LINGOTS MOULAGE` : 173
- `LINGOTS TES` : 126
- `REBUT PLAQUE` : 111
- `REBUT LINGOT MOULAGE` : 89
- `FIL ALLIAGE CONDUCTE` : 65

## Pièges

- Pour `clean_data.alimenter_inventory_part_phl()`, les caractéristiques PHL doivent alimenter les colonnes custom `inventory_part` : `DIAMETRE -> c_diameter`, `ALLIAGE -> c_alloy_code`, `ALLIAGE -> c_alloy_serie_code` en prenant les 4 premiers caractères (ne plus utiliser `SERIE ALL`), `FAMILLE -> c_family_code`, `EPAISSEUR/LONGUEUR/LARGEUR -> c_*_brut`, `POIDS COMMERCIAL -> c_commercial_weight`, `FORME -> c_forme_code` via `public.get_transcodification('FORME', NULLIF(TRIM(phl."FORME"), ''), 'PHL', 'IFS')` avec fallback sur la valeur brute, `SCIAGE -> c_sawing_code`, `NORME CHARGE -> c_load_standard_code`, `STATUT -> c_final_state_code` (`I` ou `F`), `POIDS NET -> storage_weight_requirement`, `VOLUME NET -> storage_volume_requirement`, `FACTEUR CHARGEMENT -> intrastat_conv_factor`. Prévoir aussi un `UPDATE` des lignes existantes car la procédure est idempotente avec `NOT EXISTS`.
- `c_density` = `2.7` uniquement pour les plaques / tés / lingots (`FAMILLE` 20, 24, 19) via `get_default_value(..., 'c_density', '2.7')`, `NULL` pour les fils (21, 22, 23, RF) via `get_default_value(..., 'c_density', NULL, 'FIL')`.
- Les articles de `FAMILLE = '19'` (lingots) ne sont pas repris : filtre porté par la vue `raw_data.v_phl_article_retenu`.
- Quand l'utilisateur demande de forcer des paramètres IFS « pour les articles PHL dans `alimenter_inventory_part_phl` », ne pas supposer que les champs sont dans `inventory_part` : introspecter `ifs_field_catalog` / `information_schema`, puis mettre à jour la table propriétaire tout en gardant l'orchestration demandée dans la fonction PHL si c'est le point d'entrée métier. Exemple validé : `Plan Manufacturing Supply on Due Date` appartient à `clean_data.manuf_part_attribute` (`plan_manuf_sup_on_due_date_db = 'TRUE'` et `plan_manuf_sup_on_due_date = 'TRUE'`) ; `Allow Many Lots per Production Order` correspond à `clean_data.part_catalog` (`lot_quantity_rule_db = 'MULTI_LOTS'`, et si présent le libellé `lot_quantity_rule = 'Many Lots Per Production Order'`). Filtrer les PHL via `raw_data.v_phl_article_retenu`, `"N. ARTICLE"` non vide, `STATUT` commençant par `F` ou `I`, et `SUBSTRING(TRIM("N. ARTICLE"),1,25)`.
- Si l'utilisateur demande « partout dans toutes les procédures PHL ou SAP » pour `Plan Manufacturing Supply on Due Date`, contrôler toutes les fonctions `clean_data.alimenter%` via `pg_proc.prosrc ILIKE '%manuf_part_attribute%'` et `%plan_manuf_sup_on_due_date%`. Ne pas se limiter au loader cité : dans le cas PHL, `clean_data.alimenter_manuf_part_attribute_phl()` insère directement `manuf_part_attribute` et doit inclure les deux colonnes dans l'`INSERT` (`plan_manuf_sup_on_due_date_db`, `plan_manuf_sup_on_due_date`) avec deux valeurs `'TRUE'`; `clean_data.alimenter_inventory_part_phl()` peut rester un garde-fou `UPDATE` des lignes existantes. Après modification, exécuter aussi un `UPDATE clean_data.manuf_part_attribute SET plan_manuf_sup_on_due_date_db='TRUE', plan_manuf_sup_on_due_date='TRUE' WHERE (...) IS DISTINCT FROM ('TRUE','TRUE')` puis vérifier `COUNT(*) FILTER` OK/KO. S'il n'existe aucune fonction SAP touchant `manuf_part_attribute`, le dire explicitement.
- Pour les unités PHL, `raw_data.v_phl_article_retenu."U/M" = 't'` doit devenir `kg` côté IFS. Ajouter/maintenir la transcodification `public."TranscodificationTable"` avec `category='UOM'`, `source_system='PHL'`, `target_system='IFS'`, `source_value='t'`, `target_value='kg'`, puis utiliser `public.get_transcodification('UOM', ..., 'PHL', 'IFS')`. Ne pas se fier à la transcodification globale/SAP où `t` peut rester `t`. Appliquer la règle dans `inventory_part.unit_meas` et `part_catalog.unit_code`, avec un `UPDATE` des lignes existantes dans les loaders idempotents. Vérifier ensuite qu'aucun article PHL avec `U/M='t'` ne reste différent de `kg` dans les deux tables.
- Les articles rebut PHL se reconnaissent par `UPPER("FORME") LIKE '%REBUT%'`. Pour `part_catalog`, ils doivent avoir `lot_tracking_code_db = 'NOT LOT TRACKING'`; les autres restent `LOT TRACKING`. Pour la forme IFS, passer par les transcodifications `FORME` PHL→IFS : notamment `LINGOTS TES -> TE`, `PLAQUES -> PLAQUE`, `REBUT FIL -> FILS`, `REBUT PLAQUE -> PLAQUE`, `REBUT LINGOT TES -> TE`, `FIL ALLIAGE CONDUCTE -> FILS`, `FIL ALUMINIUM -> FILS`, `FIL ALLIAGE MECANIQ. -> FILS`.
- Les colonnes numériques custom `c_diameter`, `c_epaisseur_brut`, `c_longueur_brut`, `c_largeur_brut`, `c_commercial_weight` sont actuellement `NUMERIC(...,0)` en base clean_data : les valeurs décimales PHL (ex. 18.5 ou 9.5) sont arrondies au stockage sauf évolution du DDL.
- Quand l'utilisateur demande de « corriger et compiler » un loader PHL, ne pas se limiter au fichier SQL : appliquer réellement le `CREATE OR REPLACE FUNCTION`, exécuter la fonction, puis vérifier en base active via `pg_proc.prosrc ILIKE '%c_diameter%'`, `'%c_commercial_weight%'` et `'%UPDATE clean_data.inventory_part%'`. Vérifier aussi les compteurs de champs alimentés et un article témoin. Si le MCP PostgreSQL est read-only, utiliser un script Python `uv run --with psycopg[binary] ...` qui lit la chaîne de connexion PostgreSQL depuis la config Hermes et se connecte à `sap_migration_db` ; ne pas compiler par erreur dans la base `postgres`.
- La colonne `NUMERO` n'est pas unique ; ne pas la présenter comme identifiant article.
- Plusieurs lignes peuvent avoir le même `"N. ARTICLE"`. Pour une liste d'articles uniques, utiliser `DISTINCT ON ("N. ARTICLE")` ou grouper explicitement.
- Exclure la ligne d'en-tête importée avec `"N. ARTICLE" <> 'N. ARTICLE'` ou `"STATUT" <> 'STATUT'`.
- Les noms de colonnes contiennent espaces, points, slashs et accents : toujours les double-quoter.