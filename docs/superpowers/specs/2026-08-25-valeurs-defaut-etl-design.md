# Valeurs par défaut ETL paramétrables — Conception

Date : 2026-08-25
Statut : validé (option A + écran validés par Samir)

## Problème

Les valeurs par défaut insérées dans les tables d'export `clean_data` (ex. `'TRIMET'`, `'01'`, `'FR'`, `'SUPPLIER'`) sont codées en dur dans les fonctions plpgsql des modules ETL. Elles changent régulièrement ; chaque changement exige de modifier le script SQL, recompiler la fonction et redéployer. L'objectif est de les gérer depuis un écran de l'application.

Un inventaire exhaustif existe pour le module fournisseurs : `sql/supplier/inventaire_colonnes_valeurs_defaut.csv` (classement par `type_valeur_defaut` : `CONSTANTE_FORCEE`, `NULL_EXPLICITE`, `REGLE_CONDITIONNELLE`, `DYNAMIQUE`, `FALLBACK`, avec script source et ligne).

## Approche retenue (option A)

Calque du pattern transcodification existant (`public.get_transcodification()` + table + API + écran) :
une table de paramètres + une fonction SQL `get_default_value()` appelée par les fonctions ETL à la place des littéraux, avec l'ancienne valeur en dur comme fallback.

Alternatives écartées : passe de post-traitement générique par UPDATE (deux sources de vérité, ne couvre pas les constantes dans les expressions type `'TRIMET'||'-'||id`) ; génération dynamique de tout le SQL d'insertion (refonte disproportionnée pour une plateforme à durée de vie 5 mois).

## Périmètre

- **Inclus** : colonnes de type `CONSTANTE_FORCEE` et `NULL_EXPLICITE` uniquement.
- **Exclus** : `REGLE_CONDITIONNELLE` / `DYNAMIQUE` / `FALLBACK` (SQL libre éditable depuis un écran = risque d'injection et de casse). Pas de création libre de lignes depuis l'écran (v1). Pas d'historique complet des valeurs (seulement dernier `updated_by` / `updated_at`).
- **Ordre** : module fournisseurs d'abord (inventaire déjà fait), puis extension module par module (customer, article, projet, maintenance…) en générant le même inventaire CSV au préalable.

## Composants

### 1. Migration 031 — table `public.etl_default_values`

```sql
CREATE TABLE public.etl_default_values (
    id            SERIAL PRIMARY KEY,
    module        VARCHAR(50)  NOT NULL,           -- ex. 'supplier'
    table_cible   VARCHAR(100) NOT NULL,           -- ex. 'clean_data.supplier_info_general'
    colonne       VARCHAR(100) NOT NULL,           -- ex. 'default_language' ou clé logique ex. 'our_id_prefix'
    variante      VARCHAR(30)  NOT NULL DEFAULT 'STANDARD',
    type_valeur   VARCHAR(20)  NOT NULL CHECK (type_valeur IN ('CONSTANTE','NULL')),
    valeur        TEXT,                            -- NULL autorisé si type_valeur='NULL'
    description   TEXT,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by    VARCHAR(50),
    updated_by    VARCHAR(50),
    CONSTRAINT uq_etl_default_values UNIQUE (table_cible, colonne, variante)
);
```

Seed inclus dans la migration : lignes `CONSTANTE_FORCEE` et `NULL_EXPLICITE` de l'inventaire supplier. Les constantes utilisées dans des expressions reçoivent une clé logique (ex. `our_id_prefix` pour le préfixe de `'TRIMET'||'-'||id`), documentée dans `description`.

### 2. Fonction `public.get_default_value()`

```
get_default_value(p_table text, p_colonne text, p_fallback text DEFAULT NULL,
                  p_variante text DEFAULT 'STANDARD') RETURNS text
```

- Ligne active trouvée + `type_valeur='CONSTANTE'` → retourne `valeur`.
- Ligne active trouvée + `type_valeur='NULL'` → retourne NULL.
- Pas de ligne, ligne inactive, ou erreur → retourne `p_fallback` (jamais d'exception, `RAISE WARNING` seulement — même contrat que `get_transcodification`). STABLE.

### 3. Modification des fonctions ETL supplier

Chaque littéral inventorié est remplacé par un appel avec l'ancienne valeur en fallback :

```sql
-- avant
'TRIMET' as company,
-- après
public.get_default_value('clean_data.ifs_fournisseurs', 'company', 'TRIMET') as company,
```

Le fallback = ancienne valeur codée en dur → zéro régression si la table de config est vide ou la ligne désactivée. L'inventaire CSV donne la liste exacte des remplacements (fichier + ligne). Les colonnes typées (boolean, numeric) reçoivent un cast explicite autour de l'appel (ex. `::boolean`).

### 4. Backend — modèle + API

- Modèle SQLAlchemy `backend/models/etl_default_value.py` (`EtlDefaultValue`), calqué sur `models/transcodification.py` (`to_dict`/`from_dict`, schéma `public`).
- Blueprint `backend/api/default_values.py`, routes `/api/v1/default-values` :
  - `GET /default-values` — pagination + filtres (`module`, `table_cible`, `colonne` (recherche partielle), `is_active`).
  - `GET /default-values/meta` — listes distinctes de modules et tables (pour alimenter les selects de filtre).
  - `PUT /default-values/<id>` — champs modifiables : `valeur`, `type_valeur`, `description`, `is_active` ; `updated_by` = identité JWT ; `updated_at` automatique.
  - Pas de POST ni DELETE en v1 (lignes créées par migration uniquement).
- JWT requis sur toutes les routes (comme transcodification).

### 5. Frontend — écran « Valeurs par défaut »

- Route `/configuration/valeurs-defaut` dans `App.tsx` ; entrée Sidebar « Valeurs par défaut » sous « Transcodification ».
- Page `frontend/src/pages/DefaultValuesManagement.tsx` + composants `frontend/src/components/defaultvalues/` (Filter, Table, Form) + service `defaultValueService.ts` — structure calquée sur l'ensemble transcodification.
- **Filtres** : Module, Table cible (dépendant du module, via `/meta`), Colonne (texte libre), Statut (actif/inactif/tous).
- **Tableau** (pagination serveur) : Table | Colonne | Variante | Type | Valeur | Description | Actif (switch inline) | Modifié par / le | Actions.
- **Dialog d'édition** : éditables = valeur, description, actif, case « NULL explicite » (bascule `type_valeur`) ; lecture seule = module, table, colonne, variante. Validation légère : colonnes suffixées `_db` de type booléen → select `TRUE`/`FALSE` (majuscules, contrainte IFS) ; sinon champ texte.
- **Bandeau d'information** permanent : « Les modifications s'appliquent au prochain chargement ETL » (changer une valeur ne modifie pas les données déjà chargées ; il faut relancer le chargement du module).

## Gestion d'erreurs

- `get_default_value` n'échoue jamais : tout problème → fallback + WARNING dans les logs PG.
- API : mêmes conventions que `transcodification.py` (try/except, log loguru, 404/500 JSON).
- Contrainte CHECK : `type_valeur='NULL'` avec `valeur` non vide est accepté (la valeur est ignorée) mais l'écran vide le champ quand la case NULL est cochée.

## Tests / vérification

- Exécution distante uniquement (pas de pip/pytest local) : migration + fonctions jouées sur le serveur 10.190.100.58, tests via `docker-compose exec backend`.
- Test SQL : `SELECT public.get_default_value(...)` sur les 3 cas (constante, NULL, absent→fallback) ; run `alimenter_*` supplier avant/après pour vérifier l'iso-résultat avec config par défaut, puis avec une valeur modifiée.
- Frontend : vérification syntaxe via esbuild (scratchpad) ; tsc ne couvre pas les fichiers.

## Extension aux autres modules (post-v1)

Pour chaque module : générer l'inventaire CSV (même format que supplier), ajouter le seed (migration suivante), remplacer les littéraux dans les fonctions ETL du module. L'écran et l'API n'exigent aucune modification.
