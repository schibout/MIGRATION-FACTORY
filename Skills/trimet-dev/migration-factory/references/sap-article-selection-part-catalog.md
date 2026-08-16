# Sélection des articles SAP à migrer vers IFS PART_CATALOG

Contexte : MARA contient le référentiel complet article, mais PART_CATALOG ne doit porter que les articles réellement utilisés dans le périmètre migré. Ne pas charger MARA en totalité sans filtre d'usage.

## Table de sélection créée

Table clean_data : `selection_articles_utilises`

Colonnes :
- `matnr` : numéro article SAP retenu.
- `utilise_en_site` : présence active dans `raw_data.marc`.
- `utilise_en_stock` : stock non nul dans `raw_data.mard` sur au moins une quantité (`labst`, `umlme`, `insme`, `einme`, `speme`, `retme`).
- `utilise_en_achat` : présence dans `raw_data.ekpo` sur les 5 dernières années via `AEDAT`.
- `utilise_en_reservation` : présence dans `raw_data.resb` sur les 5 dernières années via `BDTER`.
- `utilise_en_bom_tete` : tête de nomenclature dans `raw_data.mast` sur les 5 dernières années via la date de création/modification disponible (`ANDAT`/`AEDAT`).
- `utilise_en_bom_composant` : composant de nomenclature dans `raw_data.stpo.idnrk` sur les 5 dernières années via la date de validité/création/modification disponible (`DATUV`/`ANDAT`/`AEDAT`).

Les sources d’état courant sans date d’usage fiable restent hors filtre 5 ans :
- `utilise_en_site` : présence active dans `raw_data.marc`.
- `utilise_en_stock` : stock non nul dans `raw_data.mard` sur au moins une quantité (`labst`, `umlme`, `insme`, `einme`, `speme`, `retme`). Ne pas exclure un stock courant seulement parce que la date de création MARD est ancienne.
- `nb_sources` : nombre de familles d'usage.
- `raisons_selection` : explication lisible des raisons de conservation.

Procédure : `clean_data.alimenter_selection_articles_utilises()`

## Règle métier

Un article MARA est retenu pour IFS PART_CATALOG s'il est actif dans MARA (`mara.lvorm <> 'X'`) et s'il apparaît dans au moins une source d'usage : MARC actif, MARD avec stock non nul, ou usage daté des 5 dernières années dans EKPO/RESB/MAST/STPO.

`raw_data.mseg` peut être ajouté si disponible, mais ne pas supposer son existence : introspecter d'abord.

## Pattern SQL recommandé

Préférer un CTE `usages` en `UNION` puis un pivot par `matnr`, au lieu de `EXISTS` corrélés contre chaque ligne MARA. Sur les volumes article, le pattern `UNION + GROUP BY` est beaucoup plus rapide.

Structure :
1. `mara_active` : `SELECT DISTINCT TRIM(matnr)` depuis `raw_data.mara` avec `lvorm <> 'X'`.
2. `usages` : `UNION` des articles utilisés, avec une colonne `source_usage` (`site`, `stock`, `achat`, `reservation`, `bom_tete`, `bom_composant`).
3. `pivot_usages` : `BOOL_OR(source_usage = ...)` groupé par `matnr`.
4. insertion dans `clean_data.selection_articles_utilises`.

Pour les quantités MARD en texte, parser prudemment :
`COALESCE(NULLIF(regexp_replace(REPLACE(TRIM(col), ',', '.'), '[^0-9.-]', '', 'g'), '')::numeric, 0) <> 0`

## Utilisation dans PART_CATALOG

Le loader `clean_data.alimenter_part_catalog*` peut filtrer MARA avec :

`JOIN clean_data.selection_articles_utilises sau ON sau.matnr = TRIM(mara.matnr)`

Attention : PART_CATALOG est global article, pas par site. Ne pas joindre MARC/MARD directement dans le loader PART_CATALOG d'une manière qui multiplie les lignes par `WERKS` ou `LGORT`.

## Vérifications attendues

Après exécution :
- Compter `raw_data.mara` vs `clean_data.selection_articles_utilises`.
- Compter les indicateurs d'usage avec `COUNT(*) FILTER (WHERE utilise_en_...)`.
- Vérifier que les articles supprimés MARA ne sont pas retenus : join MARA sur `matnr` avec `lvorm = 'X'`, attendu 0.
- Afficher quelques exemples triés par `nb_sources DESC` pour valider les raisons de sélection.

## Note d'environnement projet

Pour les chargements, essayer l'utilisateur projet `schibout` d'abord. Si le rôle n'existe pas sur la base active, utiliser le DSN disponible, mais ne jamais basculer sur `demo`. Cette note ne remplace pas la règle mémoire utilisateur : elle rappelle le pattern d'exécution des loaders du projet.