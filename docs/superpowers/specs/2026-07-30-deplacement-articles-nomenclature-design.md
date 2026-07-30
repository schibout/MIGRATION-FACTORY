# Déplacement des articles dans l'arbre IH02

**Date** : 2026-07-30
**Écran** : `/maintenance/ih02`

## Besoin

Un article doit pouvoir être déplacé par glisser-déposer, **sous un autre article
ou sous un poste technique**, comme on déplace déjà un poste technique.

Aujourd'hui, seuls les postes techniques sont `draggable`
([IH02HierarchyPage.tsx:1487](../../../frontend/src/pages/IH02HierarchyPage.tsx#L1487)) ;
ni les équipements ni les articles ne le sont. Corriger le rattachement d'une
pièce impose de la supprimer puis de la recréer ailleurs.

## Ce qu'on déplace réellement

Un article (`ARTICLE`) est une **fiche partagée** entre tous ses emplacements :
la déplacer n'aurait pas de sens. Ce qui est déplacé est la **ligne de
nomenclature** (`BOM_ITEM`) qui rattache cet article à un porteur :

| Porteur | `attributes.stlty` | Origine SAP |
|---|---|---|
| Poste technique | `'T'` | `tpst` → `stko` → `stpo` |
| Article parent | `'M'` | `mast` → `stpo` |

Déplacer = changer `parent_id` de la ligne. La fiche article n'est pas touchée.

## Décisions

| Sujet | Décision |
|---|---|
| Portée | Poste ↔ poste, article ↔ article, **et entre les deux mondes** |
| Comportement | Identique au déplacement d'un poste technique : on change `parent_id`, on pose `updated_by`, les clés SAP restent intactes |
| Exception | `attributes.stlty` est réaligné sur la nature du nouveau parent (voir ci-dessous) |

### Pourquoi `stlty` doit être réaligné

`stlty` est le discriminateur des deux mondes **partout** :

- vue d'export `clean_data.v_fl_nomenclature` : `WHERE ... stlty = 'T'`
- `GET /bom/<tplnr>` et `/bom-counts` : `stlty = 'T'`
- `GET /article-bom/<matnr>` et `/article-bom-counts` : `stlty = 'M'`
- `PUT /bom-component` : `stlty = 'T'`

Une ligne déplacée d'un monde à l'autre sans réalignement de `stlty` ne
correspondrait à aucun filtre : elle **disparaîtrait de l'écran et des exports
IFS**, sans erreur ni trace. C'est la seule entorse au principe « clés SAP
intactes », et elle est indispensable.

Le préfixe de `sap_key` (`'T:'` / `'M:'`) n'est **pas** réaligné : il n'est
construit qu'au chargement (`proc_load_maintenance_object*.sql`) et **aucun code
ne le relit** (vérifié). Il devient une trace de l'origine.

## Contrat d'API

### Modifications additives

`GET /bom/<tplnr>` et `GET /article-bom/<matnr>` renvoient en plus `bom_key`
(le `sap_key` de la ligne ; nommé ainsi côté API pour ne pas le confondre avec
`idnrk`, qui est le `sap_key` de l'article).

C'est le seul identifiant stable et unique d'une ligne (contrainte
`uq_mo_type_key`). Le couple `(stlnr, stlkn)` actuellement utilisé par
`PUT /bom-component` n'est pas garanti unique d'un monde à l'autre et ne peut
pas servir de poignée de déplacement.

### Nouvel endpoint

```
PUT /api/v1/ih02-hierarchy/move-bom-item
{
  "bom_key":         "T:00001234:01:0010",
  "new_parent_type": "FUNC_LOC" | "ARTICLE",
  "new_parent_key":  "T110-M220"        // tplnr, ou idnrk si ARTICLE
}
```

Traitement :

1. Résoudre la ligne par `(object_type='BOM_ITEM', sap_key = bom_key)` → 404 sinon.
2. Résoudre le parent cible par `(new_parent_type, new_parent_key)` → 404 sinon.
3. Si la cible est un `ARTICLE` : refuser un cycle (voir ci-dessous) → 400.
4. `UPDATE` : `parent_id`, `attributes.stlty` (`'T'` ou `'M'`), `updated_by`.
5. Retourner l'ancien et le nouveau porteur, pour le message de confirmation.

Réponses : 200, 400 (cycle), 404 (ligne ou cible introuvable), 409 (job
maintenance en cours — déjà couvert par le `before_request` du blueprint).

### Garde anti-cycle

Déplacer la ligne référençant l'article `A` sous l'article `P` crée l'arête
`P → A`. Le cycle apparaît si `P` est déjà atteignable depuis `A` en suivant
`BOM_ITEM.parent_id` → `BOM_ITEM.ref_object_id`. On refuse dans ce cas, sur le
modèle du garde existant de `PUT /move-node`.

## Frontend

- `renderBomComponent` : rendre la ligne `draggable`, avec `onDragStart`.
- Généraliser l'état de glisser-déposer : `draggedNode: TreeNode | null` ne sait
  représenter qu'un nœud d'arbre. Le remplacer par un état discriminé
  (`{ kind: 'node' | 'bom', ... }`) portant, pour une ligne, sa `sap_key`, son
  `mode` (`'fl'` / `'article'`) et son porteur actuel.
- Cibles de dépôt :
  - poste technique — le gestionnaire `onDrop` existe, il faut l'étendre ;
  - ligne d'article — nouvelle cible.
- Confirmation via la boîte de dialogue existante (`pendingDrop`), adaptée pour
  décrire un déplacement de ligne.
- Après confirmation : recharger la nomenclature **source** et la **cible**
  (`loadBom(tplnr, true)` / `loadArticleBom(idnrk, true)`), et rafraîchir les
  compteurs. Ne pas vider l'arbre : c'est ce qui provoquait le repli corrigé en
  `10f4e6b`.

## Conséquences assumées

- **Le porteur d'origine n'affiche plus l'article, alors que SAP l'y a
  toujours.** Un rechargement en mode fusion ne le rétablit pas : la ligne porte
  `updated_by`, elle est protégée et reste où l'utilisateur l'a mise. C'est le
  sens d'un déplacement, mais la conséquence doit être connue.
- Déposer un article sur un porteur qui le contient déjà est **autorisé** : les
  répétitions sont légitimes (jusqu'à 12 occurrences du même article dans une
  nomenclature matière, constaté en base).
- `posnr` / `sort_order` de la ligne déplacée peuvent se télescoper avec ceux de
  la cible : cela n'affecte que l'ordre d'affichage.

## Vérification

1. Déplacer une ligne d'un poste vers un autre poste : elle disparaît du premier,
   apparaît sous le second, `stlty` reste `'T'`.
2. Déplacer une ligne d'un poste vers un article : `stlty` passe à `'M'`, la
   ligne apparaît dans la nomenclature matière de l'article cible et **disparaît
   de `v_fl_nomenclature`**.
3. Déplacer dans l'autre sens : `stlty` repasse à `'T'`, la ligne **réapparaît
   dans `v_fl_nomenclature`** — c'est le test qui prouve que le réalignement de
   `stlty` fonctionne.
4. Tenter de déplacer un composant sous un article qui en descend : refus 400,
   aucune modification en base.
5. L'arbre ne se replie pas après un déplacement, et les compteurs de
   nomenclature des deux porteurs sont à jour.
6. `sap_key` et les identifiants SAP de la ligne sont inchangés ; `updated_by`
   est renseigné.
