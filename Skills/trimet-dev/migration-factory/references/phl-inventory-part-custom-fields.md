# PHL — champs custom INVENTORY_PART

Contexte issu d'une correction sur les articles PHL dans `clean_data.alimenter_inventory_part_phl()`.

## Règle métier durable

Pour les articles PHL retenus (`raw_data.v_phl_article_retenu`, statut commençant par `F` ou `I`) alimentés dans `clean_data.inventory_part` :

- `c_spire_code` doit être forcé à `S`.
- `unit_meas` doit suivre la transcodification UOM sans upper-case forcé sur la valeur source PHL : `public.get_transcodification('UOM', NULLIF(TRIM(phl."U/M"), ''))`, fallback `phl."U/M"`, puis `PCE`.
- Pour PHL, la transcodification active `UOM / SAP / IFS / source_value = 't'` doit retourner `target_value = 't'` et non `kg`.
- Ces valeurs doivent être présentes à l'INSERT et dans l'UPDATE des lignes déjà existantes.
- `c_density` n'est alimentée que pour les **plaques, tés et lingots** (`FAMILLE` = 20, 24, 19) : `public.get_default_value('clean_data.inventory_part', 'c_density', '2.7')` (variante `STANDARD`, valeur théorique 2.7). Pour les **fils** (`FAMILLE` = 21, 22, 23, RF) la densité n'est pas requise : `public.get_default_value('clean_data.inventory_part', 'c_density', NULL, 'FIL')` -> `NULL`. Les deux branches passent par `get_default_value` et restent modifiables depuis `/configuration/valeurs-defaut`.
- **Pas de reprise du code famille 19** (lingots) : les lignes `FAMILLE = '19'` sont exclues dès la vue `raw_data.v_phl_article_retenu`, donc de toutes les procédures `alimenter_*_phl`.

## Champs custom PHL déjà mappés

Depuis `raw_data.v_phl_article_retenu` vers `clean_data.inventory_part` :

- `DIAMETRE` -> `c_diameter`
- `ALLIAGE` -> `c_alloy_code`
- `SERIE ALL` -> `c_alloy_serie_code`
- `FAMILLE` -> `c_family_code`
- `EPAISSEUR` -> `c_epaisseur_brut`
- `LONGUEUR` -> `c_longueur_brut`
- `LARGEUR` -> `c_largeur_brut`
- `POIDS COMMERCIAL` -> `c_commercial_weight`
- `FORME` -> `c_forme_code` via `public.get_transcodification('FORME', NULLIF(TRIM(phl."FORME"), ''), 'PHL', 'IFS')`, fallback valeur PHL brute
- `SCIAGE` -> `c_sawing_code`
- `NORME CHARGE` -> `c_load_standard_code`
- constante `S` -> `c_spire_code`
- `POIDS NET` -> `storage_weight_requirement`
- `VOLUME NET` -> `storage_volume_requirement`
- `FACTEUR CHARGEMENT` -> `intrastat_conv_factor`

## Pitfall

La procédure PHL était idempotente avec `NOT EXISTS`; ajouter seulement des colonnes dans l'INSERT ne corrige pas les articles déjà existants. Pour tout nouveau champ PHL, ajouter aussi une section `UPDATE ... FROM src` et inclure le champ dans le test `IS DISTINCT FROM`.

## Vérification recommandée

Après compilation et exécution de `clean_data.alimenter_inventory_part_phl()` :

```sql
SELECT count(*) AS total_phl,
       count(*) FILTER (WHERE ip.c_spire_code = 'S') AS spire_s,
       count(*) FILTER (WHERE ip.c_spire_code IS NULL) AS spire_null,
       count(*) FILTER (WHERE ip.c_spire_code IS NOT NULL AND ip.c_spire_code <> 'S') AS spire_other
FROM clean_data.inventory_part ip
JOIN raw_data.v_phl_article_retenu phl
  ON ip.part_no = SUBSTRING(TRIM(phl."N. ARTICLE"), 1, 25)
WHERE ip.contract = 'SJ'
  AND phl."N. ARTICLE" IS NOT NULL
  AND TRIM(phl."N. ARTICLE") <> ''
  AND UPPER(LEFT(TRIM(phl."STATUT"), 1)) IN ('F','I');
```

Pour contrôler un article précis :

```sql
SELECT contract, part_no, c_spire_code
FROM clean_data.inventory_part
WHERE part_no = '<PART_NO>';
```

## Compilation via Hermes sans psql

Si `psql` n'est pas disponible dans l'environnement Hermes, utiliser Python avec `uv run --with 'psycopg[binary]'` et le DSN PostgreSQL du `config.yaml` pour exécuter le fichier SQL, puis lancer la procédure et vérifier les compteurs. Ne pas enregistrer comme règle durable que `psql` manque : c'est seulement un état d'environnement possible.
