# Matrice conditionnelle Site × Famille — implémentation

Mise en œuvre de la proposition `docs/matrice valeur defaut.md`.
Écran : **Configuration → Matrice Site × Famille** (`/configuration/matrice-site-famille`).

Rien n'est déployé par ce commit : les scripts sont à jouer sur le serveur
(voir §6 « Déploiement »).

---

## 1. Ce que ça fait

Deux volets, une seule clé de résolution **(site, famille)** et une seule règle
de priorité : **la règle la plus précise gagne**.

| Volet | Table | Fonction SQL | Question à laquelle il répond |
|---|---|---|---|
| Valeurs | `public.etl_default_value_matrix` | `public.get_default_value_ctx()` | Quelle valeur mettre dans cette colonne pour ce site et cette famille ? |
| Routage | `public.etl_part_type_matrix` | `public.get_part_type_matrix()` | Faut-il créer la ligne `sales_part` / `purchase_part` / `manuf_part_attribute` pour cet article ? |

Ordre de résolution d'une valeur, du plus précis au plus général :

```
site + famille  >  site seul  >  famille seule  >  règle générale (joker)
      puis, si aucune règle de matrice ne correspond :
public.etl_default_values  (Configuration > Valeurs par défaut, migration 031)
      puis :
NULL
```

Une règle de matrice de type `NULL` est un choix **explicite** (vider la colonne
pour ce site / cette famille) : elle ne retombe pas sur la constante. C'est
pour cela que `get_default_value_ctx()` teste `FOUND` au lieu de faire un
`COALESCE` — un `COALESCE` rendrait le NULL explicite impossible à exprimer.

## 2. Source de la clé (points §6 de la proposition, tranchés)

- **Site** : le paramètre `p_contract` des procédures `alimenter_*_phl`
  (`SJ` | `CS`), déjà présent et validé en entrée de chaque procédure.
- **Famille** : `TRIM(phl."FAMILLE")` de `raw_data.v_phl_article_retenu`
  — la colonne `FAMILLE` du fichier PHL (valeurs en base le 2026-09-04 :
  `21`, `22`, `23`, `RF` ; la famille `19` (lingots) est déjà exclue par la vue,
  elle n'apparaît donc pas dans la grille).
  Une famille vide est ramenée à `NULL` (`NULLIF(TRIM(...), '')`) : elle ne
  matche alors que les règles joker.
- **Granularité** : (site, famille) uniquement. **Pas** d'exception par article
  — hors périmètre, et la structure resterait valable pour l'ajouter plus tard
  (une colonne `part_no` + un niveau de priorité supplémentaire).
- **Colonnes concernées** : aucune liste figée. Les trois procédures
  `alimenter_sales_part_phl`, `alimenter_purchase_part_phl` et
  `alimenter_manuf_part_attribute_phl` appellent désormais
  `get_default_value_ctx()` pour **toutes** leurs valeurs par défaut (140
  appels au total) : rendre une colonne conditionnelle = ajouter une ligne de
  matrice depuis l'écran, sans toucher au SQL. `density` et
  `use_theoritical_density_db` en font partie.
- **Indicateur source de type d'article** : le `STATUT` PHL (`F`/`I` =
  fabriqué) reste en place dans les procédures et **prime** — la matrice de
  routage s'applique **en plus**, elle ne peut que restreindre. Concrètement,
  passer une cellule à « Créé » ne fera pas apparaître un article que le filtre
  `STATUT` exclut déjà.
- **Combinaisons interdites** : aucune n'est contrôlée. Les trois tables sont
  indépendantes (un article peut être fabriqué *et* vendu). La dépendance
  existante `manuf_part_attribute → inventory_part` reste assurée par la garde
  `EXISTS` de la procédure, indépendante de la matrice.

## 3. Fichiers

### Base de données
- `migrations/052_matrice_valeurs_defaut_site_famille.sql`
  Les 2 tables, leurs index d'unicité, les 3 fonctions
  (`get_default_value_matrix`, `get_default_value_ctx`, `get_part_type_matrix`),
  le trigger de validation des valeurs, le seed neutre du routage, les
  requêtes de contrôle et le rollback.

  À noter : l'unicité de la clé naturelle passe par un **index d'expression**
  sur `COALESCE(contract,'*')` / `COALESCE(part_family,'*')`. Une contrainte
  `UNIQUE` ordinaire ne conviendrait pas — PostgreSQL considère deux `NULL`
  comme distincts, plusieurs lignes joker identiques passeraient.

### ETL (`sql/articlePhl/`)
- `alimenter_manuf_part_attribute_phl.sql` — 55 appels passés en
  `get_default_value_ctx()`, `density` complétée par la matrice quand aucune
  densité mesurée n'existe (`raw_data.phl_article_densite` ne couvre pas tous
  les articles ; une densité mesurée n'est jamais écrasée), garde de routage +
  purge.
  Les deux `UPDATE` finaux croisaient une sous-requête constante avec `phl` :
  ils sont passés en `LATERAL` pour que la résolution puisse lire la famille de
  la ligne courante.
- `alimenter_sales_part_phl.sql` — 34 appels + garde de routage + purge.
- `alimenter_purchase_part_phl.sql` — 51 appels + garde de routage + purge.

`alimenter_part_catalog_phl.sql` et `alimenter_inventory_part_phl.sql` ne sont
**pas** modifiés (hors périmètre de la proposition). Les y étendre est
mécanique : même substitution `get_default_value(` → `get_default_value_ctx(`
avec `p_contract, NULLIF(TRIM(phl."FAMILLE"), '')`, `phl` étant déjà dans la
portée de leur `SELECT`.

### Backend
- `backend/models/etl_default_value_matrix.py` — `EtlDefaultValueMatrix`, `EtlPartTypeMatrix`
- `backend/api/default_value_matrix.py` — blueprint `/api/v1/config/matrix/*`
- `backend/models/__init__.py`, `backend/api/__init__.py` — enregistrement

| Route | Rôle |
|---|---|
| `GET /config/matrix/meta` | sites, familles, colonnes éligibles, tables de routage |
| `GET/POST /config/matrix/values`, `PUT/DELETE .../{id}` | règles de valeur |
| `GET /config/matrix/resolve` | valeur effective pour un couple (site, famille) et son origine |
| `GET/POST /config/matrix/part-types`, `DELETE .../{id}` | règles de routage |

`POST /matrix/values` fait un **upsert** sur la cellule : l'écran est une
grille, l'utilisateur y voit une cellule et non une ligne technique.

### Frontend
- `frontend/src/services/matrixService.ts`
- `frontend/src/pages/MatriceSiteFamille.tsx` — deux onglets, grille
  familles × sites avec une ligne et une colonne « joker »
- `frontend/src/App.tsx` (route) et `frontend/src/pages/Configuration.tsx`
  (carte) — sans la carte, la page serait inaccessible malgré sa route.

La grille reproduit **côté client** la règle de priorité du SQL pour afficher
les valeurs héritées en gris : les deux implémentations doivent rester
alignées (`regleLaPlusSpecifique()` dans la page, `ORDER BY` dans les
fonctions SQL).

## 4. Effet sur les chargements

L'installation est **neutre** :

- `etl_default_value_matrix` vide → `get_default_value_ctx()` retombe sur
  `get_default_value()` : valeurs identiques à aujourd'hui.
- `etl_part_type_matrix` seedée à `should_create = TRUE` sur les trois jokers →
  aucun article n'est écarté.

Comme pour les constantes, **les modifications ne s'appliquent qu'au prochain
chargement ETL** : les données déjà chargées ne bougent pas tant que le module
articlePhl n'est pas relancé.

Passer une cellule de routage à « Non créé » **supprime** aussi, au prochain
chargement, les lignes déjà présentes pour ce site et cette famille. Sans cette
purge le flag serait sans effet : ces trois tables ne sont jamais vidées, les
procédures insèrent en APPEND avec une garde `NOT EXISTS`. La purge est limitée
aux articles présents dans `raw_data.v_phl_article_retenu` et au site chargé :
les lignes issues du module SAP ne sont pas touchées.

## 5. Garde-fou sur les valeurs

Le trigger `trg_etl_default_value_matrix_valider` reprend celui de la migration
049 : une valeur active qui ne peut pas être castée vers le type réel de la
colonne cible est refusée à l'enregistrement, avec le message qui dit quoi
faire. L'API remonte ce message tel quel (HTTP 400) plutôt qu'un 500 opaque.
C'est ce qui évite de rejouer l'incident du 2026-09-02 (`invalid input syntax
for type numeric: ""` au milieu d'un chargement).

## 6. Déploiement

```bash
# 1. Migration (crée tables + fonctions, seed neutre)
psql -h 10.190.100.58 -U postgres -d <base> -f migrations/052_matrice_valeurs_defaut_site_famille.sql

# 2. Recompiler le module articlePhl : les procédures appellent maintenant
#    get_default_value_ctx() et get_part_type_matrix().
#    compile.sh référence ses fichiers en relatif : se placer dans le dossier.
cd sql/articlePhl && ./compile.sh && cd -

# 3. Backend + frontend
./deploybackend.sh
./deployfrontend.sh
```

Ordre imposé : la migration **avant** la recompilation (les procédures
référencent les nouvelles fonctions).

### Contrôles après déploiement

Les requêtes de vérification sont en commentaire à la fin de la migration :
repli sur la constante, ordre de priorité des règles, routage neutre.

Test fonctionnel de bout en bout suggéré :

1. Poser `density` = une valeur pour (famille `23`, tous sites), une autre pour
   (site `CS`, famille `23`).
2. `GET /config/matrix/resolve?table_cible=clean_data.manuf_part_attribute&colonne=density&contract=SJ&part_family=23`
   → doit renvoyer la première ; avec `contract=CS`, la seconde ; avec
   `part_family=21`, la constante et `origine = CONSTANTE`.
3. Relancer le chargement articlePhl et vérifier les compteurs affichés par la
   procédure (`Densites completees par la matrice site x famille`,
   `Lignes supprimees par le routage site x famille`).
4. Vérifier qu'un article cumulant plusieurs créations (fabriqué + vendu) est
   bien présent dans les deux tables.
