# Périmètre St-Jean des articles de maintenance (IBAU via structure IH02) — Design

Date : 2026-07-03
Statut : implémenté

## Évolution du périmètre (2026-07-03)

Décision initiale : filtrer la seule page IBAU sur la structure IH02. Étendue ensuite à
**toutes les pages articles de maintenance**, avec un périmètre « site St-Jean » unifié :

- **IBAU** : cadré par la structure IH02 (aucune donnée de division n'existe sur les IBAU —
  vérifié : 0 IBAU a une ligne `marc` ou `mbew`). Inchangé.
- **ERSA / NLAG** : cadré par la division (`marc.werks IN ('9200','2200')` — les deux plants
  St-Jean : 9200 « Trimet France, Usine de St Jean » et 2200 « ST JEAN »).
- **Note société** : les articles n'ont AUCUN champ société (`bukrs`) ; « STJN » ne peut se
  matcher que via les divisions. Le périmètre est donc exprimé en `werks`.

Prédicat unifié appliqué à toutes les pages (et aux compteurs) :

```
(mtart = 'IBAU'  AND présent dans la structure IH02)
OR (mtart <> 'IBAU' AND division ∈ {9200, 2200})
```

Comptes réels validés le 2026-07-03 : ERSA 19 765 · IBAU 8 446 · NLAG 902 · liste générale 29 113.

Implémentation : paramètre unique `st_jean` sur `GET /articles` et `GET /articles/stats`
(voir `_st_jean_scope_clause` dans [maintenance_articles.py](../../../backend/api/maintenance_articles.py)).
Le frontend l'envoie **toujours** (toutes les pages articles + compteurs du menu Maintenance).

---

## (Contexte initial — page IBAU seule)

## Contexte

- Page `/maintenance/articles/ibau` = `MaintenanceArticlesPage` avec `fixedMtart="IBAU"`
  ([frontend/src/App.tsx](../../../frontend/src/App.tsx#L199)). Elle liste **tous** les
  articles `raw_data.mara` de type IBAU (via [backend/api/maintenance_articles.py](../../../backend/api/maintenance_articles.py)).
- La structure IH02 (`/maintenance/ih02`) vit intégralement dans
  `clean_data.maintenance_object` (MO) : `FUNC_LOC`, `EQUIPMENT`, `ARTICLE` (matérialisés
  quand rattachés à une nomenclature), `BOM_ITEM`
  ([backend/api/ih02_hierarchy_mo.py](../../../backend/api/ih02_hierarchy_mo.py)).

## Objectif

Sur la route IBAU uniquement, n'afficher que les articles IBAU **présents dans la
structure IH02**. Filtre **fixe** (pas de toggle). ERSA / NLAG / liste générale inchangées.

Définition de « présent dans la structure IH02 » (critère retenu : *article OU équipement*) :
un `mara.matnr` (type IBAU, actif) tel que, dans `maintenance_object` (is_active) :
- il existe un nœud `object_type='ARTICLE'` avec `sap_key = matnr`, **OU**
- il existe un nœud `object_type='EQUIPMENT'` avec `attributes->>'matnr' = matnr`.

## Données réelles (validées le 2026-07-03)

| Mesure | Valeur |
|---|---|
| Articles IBAU actifs (`mara`) | 42 955 |
| IBAU présents comme nœud `ARTICLE` | 8 446 |
| IBAU présents comme matériau d'`EQUIPMENT` | 0 (matériaux d'équipement = NLAG/ERSA) |
| **Total IBAU dans la structure** | **8 446** |

Le critère « équipement » n'ajoute rien pour IBAU aujourd'hui mais est conservé dans la
logique SQL : il est correct, coûte peu, et couvre le cas futur d'un équipement référençant
un matériau IBAU. Les `matnr` d'équipement sont déjà normalisés sur 18 zéros → égalité directe
avec `mara.matnr`, pas de padding supplémentaire nécessaire.

## Architecture retenue (Approche A)

Paramètre backend `in_structure` sur les endpoints existants + prop frontend `structureOnly`
câblée en dur sur la route IBAU. Une seule source de vérité SQL, réutilisable.

### Backend — [backend/api/maintenance_articles.py](../../../backend/api/maintenance_articles.py)

1. `GET /articles` : nouveau paramètre `in_structure` (`'1'`/`'true'`). Quand actif, ajout à
   `where_clauses` de :
   ```sql
   AND (
     EXISTS (SELECT 1 FROM clean_data.maintenance_object mo
             WHERE mo.object_type = 'ARTICLE' AND mo.is_active AND mo.sap_key = m.matnr)
     OR EXISTS (SELECT 1 FROM clean_data.maintenance_object mo
                WHERE mo.object_type = 'EQUIPMENT' AND mo.is_active
                  AND mo.attributes->>'matnr' = m.matnr)
   )
   ```
   Le flag est intégré à la **clé de cache** (`CACHE_PREFIX`).
2. `GET /articles/stats` : accepte `in_structure` (+ `mtart`) et applique le même `EXISTS`
   (et le filtre `mtart`) sur `by_type` et `nb_groupes_articles`, pour que la carte compteur
   de la page IBAU affiche 8 446 et non 42 955. Clé de cache mise à jour.

### Frontend — [frontend/src/pages/MaintenanceArticlesPage.tsx](../../../frontend/src/pages/MaintenanceArticlesPage.tsx)

- Nouvelle prop `structureOnly?: boolean`.
- `loadArticles` et `loadStats` ajoutent `in_structure=1` (et `mtart` fixe pour stats) quand
  `structureOnly` est vrai.
- Libellé dans l'en-tête (« présents dans la structure IH02 ») pour expliquer la liste réduite.

### Routing — [frontend/src/App.tsx](../../../frontend/src/App.tsx)

```tsx
<Route path="maintenance/articles/ibau" element={<MaintenanceArticlesPage fixedMtart="IBAU" structureOnly />} />
```

## Décisions mineures

- Dropdown « Groupe articles » : reste global (tous les groupes IBAU). Quelques entrées
  peuvent donner 0 résultat une fois le filtre appliqué. Simplicité > exhaustivité ; filtrable
  ultérieurement si gênant.
- Performance : deux `EXISTS` indexés sur `maintenance_object(object_type, sap_key)` ;
  négligeable car `mara` est déjà scannée pour la liste.

## Tests / validation

- Requêtes SQL de volumétrie déjà exécutées (voir tableau ci-dessus).
- Vérification UI finale sur le serveur distant `10.190.100.58` (pas d'exécution locale de
  pip/python/pytest, conformément aux consignes projet).

## Hors périmètre

- ERSA, NLAG, liste générale `/maintenance/articles`.
- Toggle activable / désactivable.
- Ajout d'équipements dans la liste (la page reste une liste d'articles).
