# Plan d'exploitation des classeurs de spec IFS (Lot*.xlsx)

## Solution proposée : la "Spec Factory" — traiter le fichier Excel comme du code source

L'idée originale : **ne plus lire ces classeurs, les compiler.** Chaque classeur Lot*.xlsx est
un dictionnaire de données structuré (vérifié sur Lot09 : 16 feuilles entités partageant
exactement les mêmes 31 colonnes de métadonnées). On le charge dans un référentiel central
`public.ifs_field_catalog`, et **tout le reste est généré depuis ce référentiel** : DDL,
squelettes de loaders, règles de gestion, valeurs par défaut, seeds de transcodification,
et configurations d'écrans React pilotées par les métadonnées.

Quand une V4 du fichier arrive, on recharge le catalogue et on **diffe** : les changements
de spec deviennent visibles en SQL, et les objets impactés sont régénérés. Fini le
re-pointage manuel des 222 champs.

```
Lot09_V3.xlsx ──► spec2catalog.py ──► public.ifs_field_catalog (222 lignes pour LOT09)
                                              │
              ┌───────────────┬───────────────┼────────────────┬──────────────────┐
              ▼               ▼               ▼                ▼                  ▼
        DDL clean_data   Squelettes     Règles de       Seeds transco      Configs écrans
        (13 tables)      alimenter_*    gestion JSON    (enums DB<==>      React (JSON par
                                        + contrôles     Client)            entité)
                                        qualité SQL
```

---

## Phase 1 — Le référentiel de métadonnées (fait, prototype validé)

**Livrable : `create_public_ifs_field_catalog.sql` + `spec2catalog.py`**

- Table `public.ifs_field_catalog` : une ligne par champ, clé `(lot_id, entity, field_name)`,
  upsert idempotent `ON CONFLICT ON CONSTRAINT uq_ifs_field_catalog DO UPDATE`.
- Le parseur lit la feuille de garde `Migration Object Definitions` pour ne traiter que les
  entités `IN_SCOPE=YES` (13 sur 20 pour Lot09 ; les 7 autres sont marquées "Pas de migration").
- Métadonnées capturées : type + longueur, MANDATORY, PRIMARY_KEY, LOV, DEFAULT_VALUE,
  REFERENCE (LOV IFS : PersonInfo, CompanyFinance, WorkTimeCalendar...), ENUMERATION_VALUES
  (paires DB-value ⟺ Client-value parsées en JSONB), RND_FLAGS, TRANSFORMATION_RULES, COMMENTS.
- Les commentaires métier ("id de ASAP", "colonne budget initial de sharepoint"...) sont
  conservés : ils encodent le **mapping source→cible** décidé en atelier.

Validation faite sur Lot09 : 13 entités, 222 champs, 39 defaults, 37 références LOV,
32 énumérations, 30 règles de transformation.

## Phase 2 — Génération du DDL clean_data

**Livrable : 13 fichiers `clean_data_<entity>.sql` générés (exemple joint : PROJECT)**

Le générateur applique les conventions du projet automatiquement :
- `VARCHAR2(n)→VARCHAR(n)`, `NUMBER(n)→NUMERIC(n,0)`, `DATE→DATE`, snake_case, tout nullable,
  pas de PK ni DEFAULT en base (les defaults sont des règles de chargement, pas du DDL).
- Le pattern IFS `colonne`/`colonne_db` est reproduit tel quel (vérifié : `earned_value_method`
  VARCHAR(4000) + `earned_value_method_db` VARCHAR(20), identique à ta table
  `manuf_part_attribute`).
- Colonnes `IN_SCOPE=NO` incluses mais commentées (traçabilité de la spec complète).

Garde-fou : avant tout `CREATE`, comparer avec l'existant (ex : `clean_data.project_base`,
`project_role`, `project_role_assignment` existent déjà) — le générateur doit produire un
**rapport d'écart** plutôt qu'écraser. C'est une requête simple :
`information_schema.columns` vs `ifs_field_catalog` sur `(entity, field_name)`.

## Phase 3 — Règles de gestion et valeurs par défaut exécutables

**Livrable : `rules_LOT09.json` (généré) + vues de contrôle qualité**

Chaque métadonnée devient une règle machine-exploitable, extraite en JSON :

| Métadonnée spec        | Règle générée        | Exemple Lot09                                  |
|------------------------|----------------------|-----------------------------------------------|
| MANDATORY=TRUE         | `NOT_NULL_ON_LOAD`   | NAME, MANAGER, COMPANY, CALENDAR_ID            |
| DEFAULT_VALUE          | `DEFAULT`            | MANAGER→`KAPEIFS`, COMPANY→`TRIM`, CALENDAR→`*`|
| ENUMERATION_VALUES     | `ENUM_DB_VALUES`     | earned_value_method ∈ {BASELINE, PLANNED}      |
| REFERENCE              | `FK_LOGICAL`         | MANAGER→PersonInfo, CUSTOMER_ID→CustomerInfo   |
| CHECK_FOR_DUPLICATES   | `DEDUP_KEY`          | alimente le `DISTINCT ON` du loader            |

Deux usages concrets :
1. **Dans les loaders `alimenter_*`** : le squelette généré injecte
   `COALESCE(source, 'KAPEIFS')` pour les defaults, un `WHERE ... IS NOT NULL` +
   comptage des rejets pour les mandatory, et la validation enum via jointure sur le catalogue.
2. **Vues de contrôle qualité génériques** : une seule vue
   `v_dq_violations(entity, field, rule, nb_lignes)` qui croise dynamiquement
   `ifs_field_catalog` et les tables clean_data — les contrôles suivent la spec sans
   réécriture.

## Phase 4 — Seeds de transcodification

Les 32 `ENUMERATION_VALUES` (paires `DB-value ⟺ Client-value`) sont exactement le format de
`public."TranscodificationTable"`. Le générateur produit les upserts :

```sql
INSERT INTO public."TranscodificationTable" (category, source_value, target_value, source_system, target_system)
SELECT entity || '.' || field_name, e->>'client', e->>'db', 'IFS_CLIENT', 'IFS_DB'
FROM public.ifs_field_catalog, jsonb_array_elements(enumeration_values) e
WHERE lot_id = 'LOT09' AND enumeration_values IS NOT NULL
ON CONFLICT ON CONSTRAINT unique_transcodification DO UPDATE SET target_value = EXCLUDED.target_value;
```

Les valeurs `_db` des loaders passent alors par `get_transcodification()` au lieu de
CASE codés en dur.

## Phase 5 — Écrans pilotés par les métadonnées (côté React de migration-Factory)

C'est là que l'approche paie le plus : **un seul composant générique `<EntityForm entity="PROJECT">`**
au lieu de 13 écrans codés à la main. Un endpoint Flask
`GET /api/catalog/<entity>` renvoie le JSON du catalogue, et le front en déduit :

- **le formulaire** : ordre des champs (`sort_order`), libellés français (`field_label_fr`),
  infobulle (`field_description`), champ requis (`mandatory`), lecture seule
  (`insertable/updatable` — ex : ACTUAL_START non insérable), longueur max (`data_length`) ;
- **les widgets** : `enumeration_values` → `<select>` avec libellés Client-values ;
  `reference` → autocomplete branché sur la table référencée (PersonInfo → sharepoint_users /
  référentiel personnes) ; `DATE` → datepicker ;
- **le pré-remplissage** : `default_value` (KAPEIFS, TRIM, *) appliqué à la création ;
- **la grille de recette** : mêmes métadonnées pour un tableau de validation des données
  migrées, avec surlignage des violations issues de `v_dq_violations`.

Nouveau lot = nouvelles entités visibles dans l'appli **sans une ligne de code front**.

## Phase 6 — Cycle de vie des versions de spec

- `lot_id` + `source_file` dans le catalogue ⇒ recharger une V4 met à jour par upsert.
- Vue `v_catalog_diff` (comparaison avant/après sur snapshot) : champs ajoutés/supprimés,
  types modifiés, defaults changés, bascules IN_SCOPE. C'est le **journal des changements
  de spec**, requêtable — utile aussi pour l'agent Hermes (contexte compact, questions du
  type "quels champs obligatoires de PROJECT n'ont pas de mapping source ?").

---

## Ordre de mise en œuvre conseillé

1. Exécuter `create_public_ifs_field_catalog.sql` puis `load_catalog_LOT09.sql` (fournis).
2. Rapport d'écart catalogue vs tables clean_data existantes (project_base, project_role...)
   avant de jouer les DDL générés.
3. Brancher les seeds transco (phase 4) — quasi gratuit, une requête.
4. Générer le squelette `alimenter_project` avec règles injectées, comparer avec tes loaders
   manuels pour calibrer le template.
5. Endpoint Flask `/api/catalog/<entity>` + composant `<EntityForm>` générique.
6. Rejouer le pipeline sur les autres lots (Lot01..LotNN) : le format est identique.
