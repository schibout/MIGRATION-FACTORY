# Règles de reprise des données « Opérations en cours »

Le chapitre 1 reprend les règles fixées pour la reprise, complétées par leur traduction SAP. Les chapitres 2 à 5 décrivent les règles appliquées par les loaders de `sql/operation/` : elles restent à valider par le métier lorsqu'elles ne viennent pas d'une demande explicite.

## Détail des règles

### 1. Ordres de maintenance – Transaction IW39

La reprise concerne les ordres de maintenance SAP répondant aux critères suivants :

| Critère | Traduction SAP | État du code |
|---|---|---|
| Date à partir du 01/01/2026 jusqu'à aujourd'hui | Date de création de l'ordre : `AUFK.ERDAT >= 20260101` | Conforme (aucune borne haute nécessaire : pas de date de création future) |
| Division poste de travail 9200 | Poste responsable `AFIH.GEWRK` → `CRHD` (`OBJTY = 'A'`), `CRHD.WERKS = '9200'` | Conforme |
| Les secteurs suivants (7.MATC, 7.MCAR, 7.MSCT, 7.MENG, 7.MFIE, 7.MELY, 7.MNRJ, 7.MSGX, 7.MTRO), identifiés à partir du poste responsable renseigné dans SAP | `CRHD.ARBPL` dans cette liste | Conforme |
| Uniquement les ordres ayant un statut en cours | Statut `REL` (`I0002`) actif dans `JEST`, et aucun statut actif `TECO` (`I0045`), `CLSD` (`I0046`) ou `DLFL` (`I0076`) | Conforme |

Ces critères sont portés par une seule vue, `clean_data.v_sap_ordre_repris` (`00_operation_helpers.sql`).

Précisions :

- Le critère de date porte sur la création de l'ordre, pas sur sa date de début planifiée (`AFKO.GSTRP`) : décision du 05/10/2026. Un ordre créé en 2026 peut donc avoir un début planifié antérieur à 2026 ou futur.
- Un ordre seulement créé (`CRTD`, sans `REL`) n'est pas repris.
- Les avis SAP (`QMEL`) ne sont pas repris : aucun bon de travail n'est créé à partir d'un avis.
- L'ordre doit être présent à la fois dans `AFKO`, `AUFK` et `AFIH` ; sinon il est écarté sans message d'erreur.

### 2. Opérations – `clean_data.jt_task`

**Opérations reprises**

Une opération `AFVC` est reprise si :

- son ordre appartient au périmètre du chapitre 1 ;
- elle n'est pas supprimée (`AFVC.LOEKZ` vide) ;
- elle n'est pas terminée : fin réelle vide, ou égale ou postérieure à la date du jour (demande du 01/10/2026) ;
- elle a une date de référence : début planifié, sinon fin planifiée, sinon date de la dernière confirmation.

**Valeurs reprises**

| Champ IFS | Règle |
|---|---|
| `task_seq` | `AUFPL × 100000000 + APLZL` |
| `order_no`, `wo_no` | Numéro d'ordre SAP (`AUFNR`) |
| `site`, `organization_site`, `company` | Écran Valeurs par défaut (`SJ` en repli pour les deux sites) |
| `organization_id` | Poste de l'opération transcodé, catégorie `Organization` (7.MCAR → SJ-MCAR) ; vide si non transcodé |
| `priority_id` | `AFIH.PRIOK` transcodé, catégorie `TASK_PRIORITY` ; vide si absent ou non transcodé |
| `work_type_id` | `AFIH.ILART` transcodé, catégorie `WORK_TYPE` (21 → MP21) ; vide si non transcodé |
| `description` | `AFVC.LTXA1`, sinon « Opération SAP » suivi du numéro d'opération |
| `long_description` | Texte long de l'opération, sinon de l'ordre, sinon `AFVC.LTXA2` |
| `prepared_by` | Personne IFS issue de `AFVC.AFNAM` |
| `reported_by` | Personne IFS du créateur de l'ordre, sinon de l'auteur de la dernière confirmation, sinon valeur par défaut |
| `reported_date` | Date de la dernière confirmation (`AFRU`) |
| `earliest_start` | Début planifié (`AFVV.FSAVD`, sinon `AFKO.GSTRP`), sinon fin planifiée, sinon `reported_date` |
| `duration` | `AFVV.DAUNO`, sinon `AFVV.ARBEI`, arrondi |
| `vendor_no` | Numéro IFS (600xxx) du fichier de sélection, jamais le `LIFNR` SAP ; vide si fournisseur inconnu |
| `mach_code` | Code IFS du poste technique de l'ordre (`ILOA.TPLNR`), sinon le `TPLNR` SAP |

Seule `earliest_start` est alimentée parmi les dates de planification : `planned_*`, `latest_*` et `actual_*` restent vides (demande du 07/10/2026).

### 3. Ressources – `clean_data.jt_task_resource`

- Une seule ressource par opération reprise ; une opération absente de `jt_task` n'a pas de ressource.
- `planned_quantity` : `AFVC.ANZMA` s'il est supérieur à 0, sinon 1.
- `resource_seq` : l'organisation de la tâche (`jt_task.organization_id`).
- `resource_group_seq` : poste de l'opération rapproché de `resource_detail_file`, par transcodification `RESOURCE_GROUP`, puis `ARBPL`, puis construction du code (7.MCAR → SJ-MCAR).
- `demand_type_db` : `EQUIPMENT` si la ressource est de type équipement, sinon `PERSON`.

### 4. Composants – `clean_data.maint_material_req_line`

Une réservation `RESB` est reprise si :

- elle est rattachée à une opération présente dans `jt_task` ;
- elle n'est pas supprimée (`RESB.XLOEK` vide) ;
- elle porte un article (`MATNR` renseigné) ;
- c'est un article stocké (`POSTP = 'L'`).

Les composants déjà sortis ne sont pas exclus : le filtre sur `KZEAR` a été retiré le 07/10/2026.

Valeurs reprises :

- `spare_contract`, `catalog_contract`, `supply_site` : division 9200 → `SJ`, 9000 → `CS`, sinon la division SAP.
- `part_no` : `MATNR` sans ses zéros de tête.
- `plan_qty` : `RESB.BDMNG`.
- `date_required` : `RESB.BDTER`.
- `vendor_no` : même règle que pour les opérations.

### 5. Chargement

- Ordre obligatoire : `jt_task`, puis `jt_task_resource`, puis `maint_material_req_line` (`CALL clean_data.alimenter_all_operation()`).
- Chaque chargement vide puis recharge les trois tables : une correction manuelle faite dans ces tables n'est pas conservée.
- Toutes les tables SAP sources doivent provenir de la même extraction complète, sinon le périmètre est faussé (voir ci-dessous).
- `clean_data.sp_keep_jt_task_recent` réduit les tables à un échantillon de test : à ne pas utiliser avant une livraison.

## État des contrôles au 05/11/2026

**Le code respecte les règles du chapitre 1, mais pas encore les données chargées.** Contrôles en lecture seule sur la base. Les fonctions déployées sont identiques à celles du dépôt.

| Contrôle | Résultat | Conforme |
|---|---|---|
| Vue : ordres hors date, hors division ou hors secteurs | 0 sur 1 480 ordres | Oui |
| Vue : ordres clos ou sans `REL` | 0 | Oui |
| Ressources et composants sans opération | 0 | Oui |
| Doublons de `task_seq` | 0 | Oui |
| Couverture « jusqu'à aujourd'hui » | S'arrête au 10/07/2026 | **Non** |
| `jt_task` limité au périmètre actuel | 1 488 opérations sur 2 826 (1 412 ordres) hors périmètre | **Non** |
| Ordres du périmètre présents dans `jt_task` | 184 ordres sur 1 480 absents | **Non** |

**Extractions SAP désynchronisées.** Dernière mise à jour par table :

| Tables | Dernière mise à jour |
|---|---|
| `AFKO`, `AFVC`, `AFVV`, `AFRU` | 11/07/2026 |
| `RESB` | 21/07/2026 |
| `AFIH` | 03/08/2026 |
| `AUFK` | 26/10/2026 |
| `CRHD` | 04/11/2026 |
| `JEST` | 05/11/2026 |

Conséquences :

- Aucun ordre créé après le 10/07/2026 n'est repris, car ces ordres sont absents d'`AFKO`. 2 008 ordres créés depuis sont `REL` et non clos, toutes divisions confondues ; leur appartenance aux secteurs ne peut pas être déterminée tant qu'`AFIH` n'est pas à jour.
- Le dernier chargement date du 07/10/2026. Les 1 412 ordres hors périmètre sont tous clôturés depuis d'après `JEST`.

**À faire :** relancer une extraction complète des tables ci-dessus, puis le chargement du module, puis ces contrôles.

Requêtes de contrôle :

```sql
-- Couverture : doit approcher la date de l'extraction
SELECT max(a.erdat)
FROM clean_data.v_sap_ordre_repris o
JOIN raw_data.aufk a USING (mandt, aufnr);

-- Opérations chargées hors périmètre : doit renvoyer 0
SELECT count(*)
FROM clean_data.jt_task t
WHERE NOT EXISTS (
    SELECT 1 FROM clean_data.v_sap_ordre_repris o
    WHERE o.aufnr = lpad(t.wo_no::text, 12, '0')
);
```

## Points à valider

1. **Secteur de l'opération :** le périmètre se lit sur le poste responsable de l'ordre, mais `organization_id` vient du poste de l'opération. Une opération peut donc porter un autre poste : 9 opérations du périmètre actuel sont sur 7.MAST, sans organisation IFS. Faut-il ajouter une transcodification pour ce poste ou les écarter ?
2. **Opérations terminées d'un ordre en cours :** elles sont écartées alors que l'ordre reste repris (environ 219 opérations sur 1 564 d'après `AFVV`). Cette règle est-elle confirmée ?
3. **Priorité :** seuls 220 ordres sur 1 480 ont une priorité SAP (`AFIH.PRIOK`). `priority_id` est-il obligatoire dans IFS ?
4. **Poste technique :** `mach_code` est calculé, mais absent de la liste de colonnes de l'export dans `etl_export_queries`. Doit-il être exporté ?
