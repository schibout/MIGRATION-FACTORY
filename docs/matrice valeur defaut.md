# Proposition — Matrice conditionnelle Site × Famille (valeurs par défaut + routage de création)

Objectif : traiter deux cas où le module actuel *Configuration → Valeurs par
défaut* (table `public.etl_default_values`, une CONSTANTE ou NULL par
`(table_cible, colonne, variante)`) ne suffit pas, parce que la bonne réponse
dépend du site (`contract`) et de la famille de l'article :

1. la **valeur par défaut d'une colonne** (ex. `density`,
   `use_theoritical_density` dans `clean_data.manuf_part_attribute`) — §2 à §4 ;
2. le **choix des tables à créer pour un article** (`sales_part`,
   `purchase_part`, `manuf_part_attribute`) — un article peut être vendu,
   acheté et/ou fabriqué selon son site et sa famille — §5.

Les deux volets partagent la même clé de résolution (site, famille) et le
même principe de priorité (le plus spécifique gagne).

## 1. Pourquoi une matrice plutôt qu'une constante

Pour une colonne comme `density`, la valeur par défaut correcte varie selon le
site de production et la famille de l'article (alliage, type de pièce, etc.) :
une seule constante par colonne ne suffit pas, et écrire un cas particulier en
dur dans le script `alimenter_*` pour chaque colonne concernée ne passe pas à
l'échelle vu le nombre de colonnes visées (densité théorique, porosité, et
les autres attributs du même type).

Le mécanisme doit donc rester **générique** (une nouvelle colonne à traiter =
une ligne de configuration, pas une modification de schéma ni de code ETL),
sur le même principe que `etl_default_values` aujourd'hui.

## 2. Modèle de données

Nouvelle table `public.etl_default_value_matrix`, même conventions que
`etl_default_values` (`SERIAL`, `created_at`/`updated_at`, trigger
`update_updated_at_column()`, `UNIQUE` sur clé naturelle) :

```sql
CREATE TABLE public.etl_default_value_matrix (
    id              SERIAL PRIMARY KEY,
    table_cible     VARCHAR(100) NOT NULL,   -- ex. 'clean_data.manuf_part_attribute'
    target_column   VARCHAR(100) NOT NULL,   -- ex. 'density', 'use_theoritical_density'
    contract        VARCHAR(5),              -- site IFS ; NULL = joker (toutes valeurs)
    part_family     VARCHAR(50),             -- famille article ; NULL = joker
    variante        VARCHAR(50),             -- optionnel, même rôle que dans etl_default_values
    default_value   VARCHAR(4000) NOT NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT now(),
    updated_at      TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (table_cible, target_column, contract, part_family, variante)
);

CREATE TRIGGER trg_etl_default_value_matrix_updated_at
    BEFORE UPDATE ON public.etl_default_value_matrix
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

Une ligne « joker » (`contract` et/ou `part_family` à `NULL`) sert de repli
générique. Le grain reste (site, famille) — pas l'article — conformément à
ce que tu décris (comparer site + famille, pas l'article lui-même) ; voir
point ouvert §5 si un jour il faut une exception par article précis.

## 3. Algorithme de résolution

Fonction SQL, même esprit que `get_transcodification()` :

```sql
CREATE OR REPLACE FUNCTION public.get_default_value_matrix(
    p_table_cible   VARCHAR,
    p_target_column VARCHAR,
    p_contract      VARCHAR,
    p_part_family   VARCHAR,
    p_variante      VARCHAR DEFAULT NULL
) RETURNS VARCHAR AS $$
    SELECT default_value
    FROM public.etl_default_value_matrix
    WHERE table_cible = p_table_cible
      AND target_column = p_target_column
      AND (contract = p_contract OR contract IS NULL)
      AND (part_family = p_part_family OR part_family IS NULL)
      AND (variante = p_variante OR (variante IS NULL AND p_variante IS NULL))
    ORDER BY
        (contract IS NOT NULL)::int + (part_family IS NOT NULL)::int DESC  -- + précis d'abord
    LIMIT 1;
$$ LANGUAGE sql STABLE;
```

Ordre de priorité obtenu : (site + famille) exact > site seul > famille seule
> joker global. Si aucune ligne ne matche du tout, le loader retombe sur
`etl_default_values` (constante classique), puis sur `NULL` — la matrice
s'ajoute au mécanisme existant, elle ne le remplace pas.

## 4. Intégration dans les loaders

Dans les fonctions `alimenter_*` concernées (pattern habituel : dédoublonnage
`DISTINCT ON`, garde `NOT EXISTS`, `GET DIAGNOSTICS`), remplacer l'appel à la
valeur constante par un `COALESCE` :

```sql
COALESCE(
    src.density,                                                              -- valeur source si présente
    get_default_value_matrix('clean_data.manuf_part_attribute', 'density',
                              src.contract, fam.part_family),                 -- matrice site×famille
    get_default_value('clean_data.manuf_part_attribute', 'density')           -- constante existante (repli)
) AS density
```

Point à vérifier : la source de `fam.part_family` (voir §5).

## 5. Second volet — quelles tables créer pour un article

Un article peut relever de plusieurs cas à la fois (fabriqué **et** vendu,
par exemple), donc pas un simple champ « type d'article » à une seule
valeur : plutôt un flag de création par table cible, résolu par (site,
famille) — même structure et même logique de priorité que la matrice de
valeurs (§2-3), pour rester dans le même mécanisme générique.

```sql
CREATE TABLE public.etl_part_type_matrix (
    id              SERIAL PRIMARY KEY,
    target_table    VARCHAR(100) NOT NULL,   -- ex. 'clean_data.sales_part'
    contract        VARCHAR(5),              -- site ; NULL = joker
    part_family     VARCHAR(50),             -- famille ; NULL = joker
    should_create   BOOLEAN NOT NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT now(),
    updated_at      TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (target_table, contract, part_family)
);

CREATE TRIGGER trg_etl_part_type_matrix_updated_at
    BEFORE UPDATE ON public.etl_part_type_matrix
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

`get_part_type_matrix(target_table, contract, part_family)` — même requête
que `get_default_value_matrix()` (§3), mais retourne `should_create`.

Dans le chargement : avant d'insérer la ligne `sales_part` (ou
`purchase_part`, ou `manuf_part_attribute`) pour un article, vérifier le
flag résolu pour ce site/famille ; ne créer la ligne que si `should_create =
true`. Comme le grain est (site, famille) et non l'article, deux articles de
la même famille sur le même site suivent toujours la même règle de création
— cohérent avec ce que tu décris (déduit du contexte, pas d'un champ
explicite par article).

## 6. Points à trancher

- **Source de la « famille »** : quelle colonne définit la famille article
  côté PHL/raw_data (ex. un champ type groupe de marchandises, ou une colonne
  dédiée du fichier PHL) ? À préciser pour écrire la jointure dans les
  loaders.
- **Granularité** : confirmé — la clé est (site, famille), pas l'article
  individuel. Faut-il malgré tout prévoir une exception ponctuelle par
  article précis (override au-dessus de la matrice), ou est-ce hors périmètre
  pour l'instant ?
- **Liste des colonnes concernées** : tu mentionnes plusieurs cas (densité
  théorique et au moins 3 autres attributs) — utile de lister les noms de
  colonnes cible exacts (`information_schema.columns` sur
  `clean_data.manuf_part_attribute`) pour cadrer le périmètre du premier lot
  et vérifier qu'ils y figurent bien plutôt que dans une autre table cible
  (ex. `inventory_part`, `part_catalog`).
- **Écran de configuration** : l'écran actuel (*Configuration → Valeurs par
  défaut*) affiche une ligne = une valeur. Pour la matrice, l'ergonomie la
  plus proche de ce que tu décris est une vue croisée (grille) : lignes =
  familles, colonnes = sites, une grille par colonne cible sélectionnée —
  à confirmer que c'est bien ça plutôt qu'un tableau plat filtrable.
- **Routage de création (§5)** : la source PHL a-t-elle déjà un indicateur
  explicite (même partiel) du type d'article — fabriqué / acheté / vendu —
  qui doit primer sur la matrice quand il est renseigné ? Ou est-ce
  entièrement déduit du site/famille, sans aucune donnée source à ce sujet ?
- **`sales_part` vs `purchase_part` vs `manuf_part_attribute`** : ces trois
  cas sont-ils bien indépendants (un article peut cumuler plusieurs
  créations), ou existe-t-il des combinaisons interdites à valider (ex. un
  article ne peut pas être uniquement `purchase_part` sans `inventory_part`) ?

## 7. Étapes de mise en œuvre

1. Confirmer les points §6 (source de la famille, périmètre des colonnes,
   indicateur source pour le routage de création).
2. Migration `public.etl_default_value_matrix` + `public.etl_part_type_matrix`
   + triggers + fonctions `get_default_value_matrix()` / `get_part_type_matrix()`.
3. Adapter les loaders `alimenter_*` concernés : COALESCE à 3 niveaux pour
   les valeurs (§4), garde `should_create` avant insertion pour le routage (§5).
4. Écran Configuration : mode « Matrice » à côté du mode « Constante »
   existant (filtre table cible / colonne, grille famille × site éditable)
   + un onglet dédié au routage de création (`sales_part` / `purchase_part` /
   `manuf_part_attribute` par site × famille).
5. Jeu de test : quelques combinaisons site/famille réelles + cas joker,
   vérifier l'ordre de priorité sur un rechargement, et vérifier qu'un
   article cumulant plusieurs créations (ex. fabriqué + vendu) est bien géré.
---

## 8. Statut : implémenté le 2026-09-04

Cette proposition est réalisée. Détail, décisions prises sur les points §6 et
procédure de déploiement : **`docs/README_MATRICE_VALEURS_DEFAUT.md`**.

Écarts assumés par rapport au texte ci-dessus :

- **Nommage** : la colonne s'appelle `colonne` (et non `target_column`), pour
  rester identique à `public.etl_default_values`.
- **`type_valeur`** : la table de valeurs porte, comme `etl_default_values`, un
  couple `type_valeur`/`valeur`, afin qu'une cellule puisse forcer un NULL
  explicite — un simple `COALESCE` à trois niveaux (§4) rendrait ce cas
  inexprimable.
- **Unicité** : `UNIQUE (…, contract, part_family, …)` ne suffit pas —
  PostgreSQL considère deux `NULL` comme distincts, donc plusieurs lignes joker
  identiques passeraient. L'unicité est portée par un index d'expression sur
  `COALESCE(contract,'*')` / `COALESCE(part_family,'*')`.
- **Intégration dans les loaders** : plutôt que le `COALESCE` à trois niveaux
  écrit à la main colonne par colonne, une fonction
  `public.get_default_value_ctx()` encapsule les trois niveaux. Les procédures
  `alimenter_{sales_part,purchase_part,manuf_part_attribute}_phl` l'utilisent
  pour **toutes** leurs valeurs par défaut : rendre une colonne conditionnelle
  ne demande plus aucune modification SQL.
- **Routage** : le garde d'insertion est doublé d'une purge, sinon passer une
  cellule à « ne pas créer » resterait sans effet sur les lignes déjà chargées
  (ces tables ne sont jamais vidées).
