# PHL — densité et champs IFS forcés sur articles

Contexte réutilisable pour les procédures d’articles PHL/Saint-Jean dans `clean_data`.

## Règles métier validées

- `clean_data.part_catalog.condition_code_usage_db` doit être forcé à `NOT_ALLOW_COND_CODE`.
- `clean_data.inventory_part.intrastat_conv_factor` doit rester vide (`NULL`) ; ne pas le réalimenter depuis `facteur_chargement` / `FACTEUR CHARGEMENT`.
- Pour `clean_data.inventory_part.c_density`, la règle PHL validée est de forcer la valeur constante `2.7` pour tous les articles PHL retenus (`contract = 'SJ'`, jointure sur `raw_data.v_phl_article_retenu."N. ARTICLE"`). Ne plus alimenter ce champ depuis la table de densité source.
- Pour `clean_data.manuf_part_attribute.density`, la densité source reste `raw_data.phl_article_densite.densite`, avec clé `raw_data.phl_article_densite.identifiant`.
- Les colonnes densité doivent conserver les décimales : utiliser `NUMERIC(20,6)` si besoin, pas `NUMERIC(20,0)`.

## Procédures à vérifier/patcher quand ces règles changent

- `clean_data.alimenter_part_catalog_phl()` : forcer `condition_code_usage_db = 'NOT_ALLOW_COND_CODE'`.
- `clean_data.alimenter_part_catalog_saint_jean()` : ne pas reprendre `autorise_cd_cond_2`, forcer `NOT_ALLOW_COND_CODE`.
- `clean_data.ajouter_article_silicium()` : forcer aussi `NOT_ALLOW_COND_CODE` pour éviter une exception article générique.
- `clean_data.alimenter_inventory_part_phl()` :
  - insérer/mettre à jour `c_density` avec la constante `2.7::numeric` pour tous les articles PHL retenus ;
  - forcer `intrastat_conv_factor` à `NULL` dans l’INSERT et dans l’UPDATE idempotent ;
  - inclure `c_density` dans la comparaison `IS DISTINCT FROM` pour que les lignes existantes soient corrigées.
- `clean_data.alimenter_inventory_part_saint_jean()` : forcer `intrastat_conv_factor` à `NULL`.
- `clean_data.alimenter_manuf_part_attribute_phl()` :
  - insérer `density` depuis `raw_data.phl_article_densite` ;
  - ajouter un UPDATE idempotent après l’INSERT pour corriger les lignes déjà présentes.

## Requêtes de contrôle utiles

```sql
-- Plus aucune procédure ne doit réintroduire ALLOW_COND_CODE.
SELECT p.proname
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'clean_data'
  AND p.prosrc LIKE '%''ALLOW_COND_CODE''%'
ORDER BY p.proname;

-- Plus aucune procédure inventory ne doit alimenter intrastat depuis facteur_chargement.
SELECT p.proname
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'clean_data'
  AND p.prosrc ILIKE '%facteur_chargement%'
  AND p.prosrc ILIKE '%intrastat_conv_factor%'
ORDER BY p.proname;

-- Etat des données après update/chargement.
SELECT
  (SELECT count(*) FROM clean_data.part_catalog
   WHERE condition_code_usage_db IS DISTINCT FROM 'NOT_ALLOW_COND_CODE') AS part_catalog_non_conformes,
  (SELECT count(*) FROM clean_data.inventory_part
   WHERE intrastat_conv_factor IS NOT NULL) AS inventory_part_intrastat_non_vides,
  (SELECT count(*) FROM clean_data.inventory_part
   WHERE c_density IS NOT NULL) AS inventory_part_densites,
  (SELECT count(*) FROM clean_data.manuf_part_attribute
   WHERE density IS NOT NULL) AS manuf_part_attribute_densites;
```

## Pitfalls

- Ne pas se limiter aux données déjà chargées : si l’utilisateur demande ensuite de « mettre à jour les procédures », recompiler les fonctions loader concernées pour éviter que la prochaine relance annule les corrections manuelles.
- `psql` peut être absent dans l’environnement agent ; compiler via Python + `uv run --with 'psycopg[binary]' python ...` est un bon fallback. Ne pas enregistrer l’absence de `psql` comme règle durable.
- Pour l’écriture PostgreSQL du projet, utiliser `schibout` quand disponible ; si l’authentification échoue et qu’un compte de référence projet est déjà documenté, utiliser ce compte pour débloquer l’action et signaler clairement le compte utilisé.
