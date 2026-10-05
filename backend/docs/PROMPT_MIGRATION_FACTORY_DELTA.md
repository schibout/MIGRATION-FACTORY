# Prompt — Migration Factory : choix « delta » / « rechargement complet » des extractions SAP

> **Objectif** : dans Migration Factory, ajouter sur l'écran de lancement d'une extraction SAP une
> case à cocher « Recharger depuis le début » et la transmettre à l'API d'extraction (pyrfc_app,
> FastAPI, port 8000). Afficher ensuite, pour chaque table du job, la stratégie réellement
> appliquée (différentiel ou complète).

---

## Ce qui a changé côté API d'extraction (déjà livré, rien à faire là-bas)

Jusqu'ici, chaque appel à `POST /extract` vidait chaque table (TRUNCATE) et la rechargeait
entièrement. Désormais :

- **Par défaut : différentiel.** Pour chaque table, l'API ne lit dans SAP que les lignes créées ou
  modifiées depuis le début du dernier run réussi de cette table, moins un jour de marge. La date
  est lue dans `public.extraction_details`. Les lignes sont mises à jour ou insérées par clé
  primaire, sans TRUNCATE. Filtre RFC appliqué (exemple AUFK) :
  `AEDAT >= '20261004' OR ERDAT >= '20261004'`.
- **Bascule automatique en complet**, table par table, quand le différentiel est impossible :
  - première extraction réussie de la table ;
  - table PostgreSQL vide ou recréée ;
  - table sans champ de date de modification (AEDAT / UPDAT / LAEDA). C'est le cas de la majorité
    des tables : AFKO, AFVC, AFIH, JEST, MAKT, MARC, BSEG, tables T*… Les tables qui n'ont que
    ERDAT (EINA, EINE, EBAN…) restent aussi en complet.
- **Rechargement complet forcé** avec le nouveau champ `rechargement_complet: true` : TRUNCATE et
  rechargement de toutes les tables du job.
- **Limite connue** : le différentiel ne voit pas les suppressions faites dans SAP. Seul un
  rechargement complet les fait disparaître.

### Contrat API

`POST /extract` : nouveau champ booléen, accepté au premier niveau du body **ou** dans `options`
(`options` prime) :

```json
{
  "tables": ["AUFK", "AFKO", "EQUI"],
  "rechargement_complet": false,
  "options": { "batch_size": 500, "mode": "standard" },
  "user_id": "<uuid>"
}
```

Réponse :

```json
{
  "extraction_id": "…",
  "status": "pending",
  "tables": ["AUFK", "AFKO", "EQUI"],
  "rechargement_complet": false,
  "persisted_db": true
}
```

Synonymes acceptés pour un rechargement complet, pour compatibilité :
`truncate_before: true`, `options.clean: true`, `mode` ou `options.mode` valant `"complet"` ou
`"complete"`. **Point d'attention** : si Migration Factory envoie déjà l'un de ces synonymes à
chaque lancement (par exemple `options.clean: true` ou `mode: "complete"` codé en dur), toutes
les extractions resteront en complet. Il faut le retirer et ne plus piloter le comportement que
par `rechargement_complet`.

`GET /status/{job_id}` (et `/jobs/{job_id}`) : chaque entrée de `tablesDetails` porte un nouveau
champ `strategy` (texte, `null` tant que la table n'a pas démarré) :

```json
{ "name": "AUFK", "status": "completed", "rows": 7276,
  "startTime": "…", "endTime": "…",
  "strategy": "differentielle (AEDAT >= '20260710' OR ERDAT >= '20260710')" }
{ "name": "AFKO", "status": "completed", "rows": 268944,
  "strategy": "complete (aucun champ de modification)" }
```

Valeurs possibles de `strategy` :

| Valeur (préfixe) | Sens |
|---|---|
| `differentielle (<condition>)` | delta appliqué, condition RFC entre parenthèses |
| `complete (forcee)` | `rechargement_complet: true` demandé |
| `complete (premiere extraction)` | aucun run réussi antérieur pour la table |
| `complete (table cible vide ou recreee)` | table PostgreSQL vide ou recréée |
| `complete (aucun champ de modification)` | table sans AEDAT/UPDAT/LAEDA |

La même valeur est stockée en base dans `public.extraction_details.strategie` (colonne TEXT
ajoutée automatiquement par l'API, `NULL` pour les jobs antérieurs).

---

## Travail à faire dans Migration Factory

1. **Repérer le code existant** : le formulaire de lancement d'extraction SAP (front), la route
   backend qui relaie vers `POST {API_EXTRACTION}/extract`, et l'écran de suivi ou d'historique
   des jobs qui lit `GET /status/{job_id}` ou `public.extraction_details`.
2. **Formulaire** : ajouter une case à cocher « Recharger depuis le début (complet) »,
   **décochée par défaut**. Texte d'aide : « Décoché : seules les données SAP créées ou modifiées
   depuis la dernière extraction réussie sont relues (les tables sans date de modification sont
   toujours rechargées en entier). Coché : chaque table est vidée puis rechargée entièrement ;
   nécessaire pour prendre en compte les suppressions faites dans SAP. »
3. **Backend / relais** : transmettre la valeur sous la forme `rechargement_complet: <bool>` dans
   le body de `POST /extract`. Retirer tout `clean`, `truncate_before` ou `mode: "complet"` /
   `"complete"` envoyé par défaut (voir le point d'attention ci-dessus). Valider le type (booléen)
   et prendre `false` si le champ est absent.
4. **Historique** : si Migration Factory enregistre ses propres jobs, mémoriser le choix
   (complet ou différentiel) avec le job, pour l'afficher dans la liste.
5. **Suivi d'un job** : afficher `strategy` par table, avec un badge « Delta » si la valeur
   commence par `differentielle`, sinon « Complet », et le texte complet en infobulle. Gérer
   `null` (table pas encore démarrée, ou job antérieur à cette évolution).
6. **Confirmation** : quand la case est cochée, demander une confirmation avant l'envoi
   (« Les tables sélectionnées vont être vidées puis rechargées entièrement. Continuer ? »).
7. **Tests** :
   - backend : le body relayé contient `rechargement_complet` à `true` ou `false` selon la case,
     et plus aucun synonyme de rechargement complet par défaut ;
   - front : la case est décochée par défaut, et la confirmation s'affiche quand elle est cochée ;
   - affichage du badge pour `differentielle (…)`, `complete (…)` et `null`.

## Recette de bout en bout

1. Lancer AUFK case décochée. `tablesDetails[0].strategy` doit commencer par
   `differentielle (AEDAT >= '…' OR ERDAT >= '…')`, avec quelques milliers de lignes et non
   environ 270 000.
2. Relancer AUFK case décochée juste après. La borne de date avance (début du run précédent moins
   un jour) et le nombre de lignes chute.
3. Lancer AFKO case décochée. La stratégie attendue est `complete (aucun champ de modification)`.
4. Lancer AUFK case cochée. La stratégie attendue est `complete (forcee)`, et la table est
   rechargée en entier.
5. Vérifier en base :
   ```sql
   SELECT job_id, table_name, status, rows_extracted, strategie, start_time
   FROM public.extraction_details
   WHERE table_name IN ('AUFK', 'AFKO')
   ORDER BY start_time DESC LIMIT 10;
   ```

## Hors périmètre

- Le différentiel des tables sans date de modification (par exemple AFKO / AFVC filtrées sur les
  ordres modifiés dans AUFK) : chantier séparé côté API.
- Les textes longs SAP (`raw_data.sap_long_text`) : extraits par un script dédié
  (`texteSurCommande/extract_textes_longs_rfc.py`), non concernés par cette évolution.
