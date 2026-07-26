# Design — ETL `pe_tools` → `pm_action*` (module PM Actions)

Date : 2026-07-06
Statut : validé (brainstorming), en attente revue utilisateur

## 1. Objectif

Créer les procédures stockées PL/pgSQL qui alimentent les tables IFS
`clean_data.pm_action*` à partir de la table plate `raw_data.pe_tools`
(gammes d'entretien SAP, 121 lignes), en suivant le pattern des autres
dossiers ETL du dépôt (`sql/maintenanceRousource`, `sql/maintenance`).

Livrables dans `sql/pm_actions/`.

## 2. Périmètre

Sur les 9 tables `pm_action*`, on alimente dans un premier temps **4 tables** :

| Table cible | Rôle | Alimentée ? |
|---|---|---|
| `pm_action` | Table maîtresse (l'action de maintenance) | ✅ |
| `pm_action_work_step` | Étape/opération de la gamme | ✅ |
| `pm_action_resource` | Ressource planifiée (charge, intervenants) | ✅ |
| `pm_action_role` | Rôle / main d'œuvre | ✅ |
| `pm_action_criteria` | — | ❌ (hors périmètre) |
| `pm_action_calendar_plan` | — | ❌ |
| `pm_action_job` | — | ❌ |
| `pm_action_planning` | — | ❌ |
| `pm_action_spare_part` | — | ❌ |

## 3. Grain et identité

- **Grain** : 1 ligne `pe_tools` = 1 `pm_action`.
  Justification : au sein d'un même `groupe_de_gamme`, chaque
  `compteur_de_gamme` porte une **fréquence différente** (ex groupe 523240 :
  4S, 52S, 26S). Or dans IFS la fréquence (`interval`) est portée par
  `pm_action`. Deux fréquences ne peuvent donc pas cohabiter dans une seule
  action → on ne fusionne pas le groupe.

- **Chaque table fille** reçoit 1 ligne par `pm_action` (1 work_step,
  1 resource, 1 role).

- **`pm_no`** (numérique, partie de la PK `(pm_no, pm_revision)`) :
  - `plan_entretien::numeric` quand présent (118 lignes ; toutes uniques et
    numériques, plage 33602–35856).
  - Repli `900000 + raw_id` pour les 3 lignes sans `plan_entretien`
    (raw_id 37, 85, 86). Le socle 900000 est hors de la plage des numéros
    SAP (33k–70k) → aucune collision possible.

- **`pm_revision`** = `'1'` (constante, première migration).

- **PK des tables filles** (`pm_action_work_step_seq`,
  `pm_action_resource_seq`, `pm_action_role.row_no`) : ce sont des séquences
  **globales** (PK mono-colonne côté cible), générées par `row_number()`
  sur l'ensemble des lignes.

## 4. Constantes IFS (déclarées en tête de procédure)

Valeurs de configuration IFS non dérivables de `pe_tools`. Déclarées en
variables `DECLARE` pour ajustement avant le run réel.

| Constante | Valeur | Cible | Note |
|---|---|---|---|
| `v_org_contract` | `'SJ'` | `pm_action.org_contract`, `role.org_contract` | Site, identique module maintenance |
| `v_org_code` | `'FR_MAINT'` *(placeholder)* | `pm_action.org_code` (**NOT NULL**), `role.org_code` | ⚠️ à confirmer avant run — pas de mapping depuis pe_tools |
| `v_pm_revision` | `'1'` | `pm_revision` (toutes tables) | |
| `v_connection_type` | `'Functional Object'` | `pm_action.connection_type` (**NOT NULL**) | poste_technique = objet fonctionnel |
| `v_connection_type_db` | `'FUNCTIONAL'` | `pm_action.connection_type_db` | ⚠️ valeur `_db` IFS à vérifier |
| `v_demand_type` | `'Work Order'` *(placeholder)* | `resource.demand_type` (**NOT NULL**) | ⚠️ à confirmer avant run |
| `v_demand_type_db` | `'WORK_ORDER'` *(placeholder)* | `resource.demand_type_db` | ⚠️ valeur `_db` IFS à vérifier |

## 5. Décodage de la fréquence

Champ `frequence` = `<nombre><unité>` où unité ∈ {S, M, A}.

| Suffixe | Unité IFS (display) | `_db` (placeholder) |
|---|---|---|
| `S` | Semaines | `WEEKS` |
| `M` | Mois | `MONTHS` |
| `A` | Années | `YEARS` |

- `interval` = chiffres de tête (`regexp_replace(frequence, '\D', '', 'g')`),
  tronqué à 4 caractères (valeurs observées : 1 à 104).
- `pm_interval_unit` (display) et `pm_interval_unit_db` selon le suffixe.
- Valeurs distinctes présentes : 1S, 4S, 12S, 26S, 52S, 104S, 2M, 3M, 3A, 5A.
- `frequence` NULL (2 lignes) → `interval` / unités laissés NULL.

⚠️ Les libellés `pm_interval_unit`/`_db` IFS exacts sont à vérifier ;
déclarés paramétrables comme les autres constantes.

## 6. Mapping détaillé des champs

### 6.1 `pm_action` (une ligne par pe_tools)
| Colonne cible | Source / valeur |
|---|---|
| `pm_no` | `plan_entretien::numeric` sinon `900000 + raw_id` |
| `pm_revision` | `v_pm_revision` |
| `mch_code` | `poste_technique` |
| `mch_code_contract` | `v_org_contract` (`'SJ'`) |
| `description` | `designation` |
| `note` | `designation` |
| `interval` | fréquence décodée (§5) |
| `pm_interval_unit` / `_db` | fréquence décodée (§5) |
| `org_contract` | `v_org_contract` |
| `org_code` | `v_org_code` |
| `connection_type` / `_db` | `v_connection_type` / `v_connection_type_db` |
| `latest_pm` / `last_changed` | `CURRENT_TIMESTAMP` |
| autres colonnes | NULL |

### 6.2 `pm_action_work_step`
| Colonne cible | Source / valeur |
|---|---|
| `pm_no`, `pm_revision` | idem pm_action (jointure sur la même ligne) |
| `pm_action_work_step_seq` | `row_number()` global |
| `description` | `designation` (**NOT NULL** ; fallback `'N/A'` si designation NULL) |
| `order_no` | `compteur_de_gamme::numeric` (NULL si absent) |
| `mch_code` | `poste_technique` |
| `mch_code_contract` | `v_org_contract` |
| `connection_type` / `_db` | `v_connection_type` / `v_connection_type_db` |

### 6.3 `pm_action_resource`
| Colonne cible | Source / valeur |
|---|---|
| `pm_no`, `pm_revision` | idem pm_action |
| `pm_action_resource_seq` | `row_number()` global (**NOT NULL**) |
| `demand_type` / `_db` | `v_demand_type` / `v_demand_type_db` (**NOT NULL**) |
| `planned_hours` | `charge::numeric` (NULL si absent/non numérique) |
| `planned_quantity` | `nb_intervenants::numeric` |

### 6.4 `pm_action_role`
| Colonne cible | Source / valeur |
|---|---|
| `pm_no`, `pm_revision` | idem pm_action |
| `row_no` | `row_number()` global (**NOT NULL**) |
| `description` | `designation` (tronqué à 200 car.) |
| `duration` | `charge::numeric` |
| `org_contract` | `v_org_contract` |
| `org_code` | `v_org_code` |

## 7. Structure des fichiers (`sql/pm_actions/`)

Pattern `maintenanceRousource` : procédures numérotées idempotentes +
`compile.sh` de déploiement psql.

```
01_populate_pm_action.sql            CREATE OR REPLACE PROCEDURE clean_data.populate_pm_action()
02_populate_pm_action_work_step.sql  ... populate_pm_action_work_step()
03_populate_pm_action_resource.sql   ... populate_pm_action_resource()
04_populate_pm_action_role.sql       ... populate_pm_action_role()
05_populate_all_pm_actions.sql       ... populate_all_pm_actions() -> CALL 01..04 dans l'ordre
compile.sh                           déploie les 5 fichiers (copie du compile.sh maintenanceRousource)
```

Convention de chaque procédure (calquée sur `populate_ifs_person`) :
1. `DECLARE` des constantes IFS (§4) + `v_count INTEGER`.
2. `TRUNCATE TABLE clean_data.<cible>;` (ré-exécutable).
3. `INSERT INTO ... SELECT ... FROM raw_data.pe_tools`.
4. `GET DIAGNOSTICS v_count = ROW_COUNT; RAISE NOTICE '...: % lignes', v_count;`.

Ordre d'exécution : `pm_action` d'abord (parent logique), puis les 3 filles.
`05_populate_all_pm_actions` orchestre l'ensemble via `CALL`.

## 8. Robustesse / cas limites

- Casts sécurisés : `charge`, `nb_intervenants`, `compteur_de_gamme` sont du
  `text` → utiliser un cast défensif (`NULLIF(trim(x),'')::numeric` ou une
  fonction de garde) pour éviter les erreurs sur valeurs vides/non numériques.
- Encodage : `designation` contient des caractères mal encodés
  (ex `CONTRâLE`) — on migre tel quel (transformation d'encodage hors
  périmètre de ce lot).
- Idempotence : `TRUNCATE` + `INSERT` → chaque proc peut être rejouée.
- `row_number()` déterministe : ordonné par `raw_id` pour des seq stables.

## 9. Hors périmètre (YAGNI)

- Les 5 autres tables `pm_action*` (criteria, calendar_plan, job, planning,
  spare_part).
- La configuration des requêtes d'export (`etl_export_queries`) — l'export
  PM Action côté frontend existe déjà (`exportPmActionData`), à traiter dans
  un lot séparé si besoin.
- La correction d'encodage des libellés.
- Le mapping fin `localisation`/`type` → `org_code` (décision : constante).
