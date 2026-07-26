# PM Actions ETL Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Créer les procédures stockées PL/pgSQL qui alimentent 4 tables IFS `clean_data.pm_action*` depuis `raw_data.pe_tools` (gammes d'entretien SAP), dans `sql/pm_actions/`, sur le pattern `sql/maintenanceRousource`.

**Architecture:** Une procédure `populate_*` idempotente (`TRUNCATE` + `INSERT ... SELECT`) par table cible, plus une procédure orchestratrice `populate_all_pm_actions` et un `compile.sh` de déploiement psql vers la base distante. Grain : 1 ligne `pe_tools` = 1 `pm_action` + 1 ligne dans chaque table fille. Les constantes de config IFS (org_code, connection_type, demand_type, unités d'intervalle) sont déclarées en `DECLARE` en tête de chaque procédure pour ajustement avant le run réel.

**Tech Stack:** PostgreSQL 12+ (schémas `raw_data` / `clean_data`), PL/pgSQL, psql, bash (`compile.sh`).

**Référence spec:** `docs/superpowers/specs/2026-07-06-pm-actions-etl-design.md`

---

## File Structure

Tous les fichiers dans `sql/pm_actions/` :

- `00_pm_helpers.sql` — fonction `clean_data.pe_num(text) -> numeric` (cast défensif, réutilisée partout)
- `01_populate_pm_action.sql` — procédure table maîtresse
- `02_populate_pm_action_work_step.sql` — procédure étape de travail
- `03_populate_pm_action_resource.sql` — procédure ressource planifiée
- `04_populate_pm_action_role.sql` — procédure rôle / main d'œuvre
- `05_populate_all_pm_actions.sql` — orchestrateur (`CALL` 01→04)
- `compile.sh` — déploiement psql des 6 fichiers dans l'ordre

**Convention `pm_no` (réutilisée dans les 4 procédures d'insertion) :**
```sql
COALESCE(clean_data.pe_num(t.plan_entretien), 900000 + t.raw_id)
```

**Déploiement/vérification :** `compile.sh` se connecte à la base distante `10.190.100.58` (psql). Les requêtes de vérification sont en lecture seule (MCP postgres ou `psql`). Ne pas exécuter les tests en local hors de ce canal.

---

## Task 1: Fonction helper `pe_num`

**Files:**
- Create: `sql/pm_actions/00_pm_helpers.sql`

- [ ] **Step 1: Écrire la fonction de cast défensif**

`sql/pm_actions/00_pm_helpers.sql` :
```sql
-- Cast défensif texte -> numeric pour les colonnes texte de raw_data.pe_tools
-- (charge, nb_intervenants, compteur_de_gamme, plan_entretien).
-- Retourne NULL si la valeur est vide ou non numérique (ex '2.0' -> 2.0, 'VL' -> NULL).
CREATE OR REPLACE FUNCTION clean_data.pe_num(p_text text)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE
        WHEN p_text IS NULL THEN NULL
        WHEN btrim(p_text) ~ '^-?[0-9]+(\.[0-9]+)?$' THEN btrim(p_text)::numeric
        ELSE NULL
    END;
$$;
```

- [ ] **Step 2: Déployer la fonction**

Run (depuis `sql/pm_actions/`, connexion base distante) :
```bash
PGPASSWORD=trimet2025 psql -h 10.190.100.58 -p 5432 -U postgres -d sap_migration_db -f 00_pm_helpers.sql
```
Expected: `CREATE FUNCTION`

- [ ] **Step 3: Vérifier le comportement du cast**

Run (lecture seule) :
```sql
SELECT clean_data.pe_num('2.0')   AS ok_num,     -- 2.0
       clean_data.pe_num('')       AS vide,       -- NULL
       clean_data.pe_num('VL')     AS texte,      -- NULL
       clean_data.pe_num(NULL)     AS nul;        -- NULL
```
Expected: `ok_num = 2.0`, les 3 autres = NULL

- [ ] **Step 4: Commit**

```bash
git add sql/pm_actions/00_pm_helpers.sql
git commit -m "feat(pm_actions): fonction helper pe_num (cast defensif texte->numeric)"
```

---

## Task 2: Procédure `populate_pm_action` (table maîtresse)

**Files:**
- Create: `sql/pm_actions/01_populate_pm_action.sql`

- [ ] **Step 1: Écrire la procédure**

`sql/pm_actions/01_populate_pm_action.sql` :
```sql
CREATE OR REPLACE PROCEDURE clean_data.populate_pm_action()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    -- Constantes de configuration IFS (ajuster avant le run réel)
    v_org_contract        VARCHAR := 'SJ';                  -- site (idem module maintenance)
    v_org_code            VARCHAR := 'FR_MAINT';            -- ⚠️ org obligatoire, à confirmer
    v_pm_revision         VARCHAR := '1';
    v_connection_type     VARCHAR := 'Functional Object';
    v_connection_type_db  VARCHAR := 'FUNCTIONAL';          -- ⚠️ valeur _db IFS à vérifier
    v_count INTEGER := 0;
BEGIN
    TRUNCATE TABLE clean_data.pm_action;

    INSERT INTO clean_data.pm_action (
        pm_no,
        pm_revision,
        mch_code_contract,
        mch_code,
        org_contract,
        org_code,
        connection_type,
        connection_type_db,
        "interval",
        pm_interval_unit,
        pm_interval_unit_db,
        description,
        note,
        latest_pm,
        last_changed
    )
    SELECT
        COALESCE(clean_data.pe_num(t.plan_entretien), 900000 + t.raw_id)          AS pm_no,
        v_pm_revision,
        v_org_contract,
        t.poste_technique,
        v_org_contract,
        v_org_code,
        v_connection_type,
        v_connection_type_db,
        -- interval : chiffres de tête de la fréquence, max 4 caractères
        NULLIF(left(regexp_replace(COALESCE(t.frequence, ''), '\D', '', 'g'), 4), '')  AS "interval",
        -- unité (display) selon le suffixe S/M/A
        CASE right(upper(btrim(t.frequence)), 1)
            WHEN 'S' THEN 'Semaines'
            WHEN 'M' THEN 'Mois'
            WHEN 'A' THEN 'Années'
            ELSE NULL
        END,
        -- unité (_db)
        CASE right(upper(btrim(t.frequence)), 1)
            WHEN 'S' THEN 'WEEKS'
            WHEN 'M' THEN 'MONTHS'
            WHEN 'A' THEN 'YEARS'
            ELSE NULL
        END,
        left(t.designation, 2000),
        left(t.designation, 2000),
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    FROM raw_data.pe_tools t;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'pm_action: % lignes insérées', v_count;
END;
$procedure$
;
```

- [ ] **Step 2: Déployer et exécuter la procédure**

Run :
```bash
PGPASSWORD=trimet2025 psql -h 10.190.100.58 -p 5432 -U postgres -d sap_migration_db \
  -f 01_populate_pm_action.sql \
  -c "CALL clean_data.populate_pm_action();"
```
Expected: `CREATE PROCEDURE` puis `NOTICE: pm_action: 121 lignes insérées`

- [ ] **Step 3: Vérifier volumétrie, unicité PK et NOT NULL**

Run (lecture seule) :
```sql
SELECT
  count(*)                                              AS total,          -- 121
  count(DISTINCT (pm_no, pm_revision))                  AS pk_distinct,    -- 121
  count(*) FILTER (WHERE pm_no IS NULL)                 AS pm_no_null,     -- 0
  count(*) FILTER (WHERE org_code IS NULL)              AS org_null,       -- 0
  count(*) FILTER (WHERE connection_type IS NULL)       AS conn_null       -- 0
FROM clean_data.pm_action;
```
Expected: `total=121, pk_distinct=121, pm_no_null=0, org_null=0, conn_null=0`

- [ ] **Step 4: Vérifier le décodage de la fréquence**

Run (lecture seule) :
```sql
SELECT DISTINCT t.frequence, a."interval", a.pm_interval_unit, a.pm_interval_unit_db
FROM clean_data.pm_action a
JOIN raw_data.pe_tools t
  ON a.pm_no = COALESCE(clean_data.pe_num(t.plan_entretien), 900000 + t.raw_id)
WHERE t.frequence IN ('26S','5A','3M')
ORDER BY t.frequence;
```
Expected :
- `26S -> interval=26, Semaines, WEEKS`
- `3M  -> interval=3,  Mois, MONTHS`
- `5A  -> interval=5,  Années, YEARS`

- [ ] **Step 5: Commit**

```bash
git add sql/pm_actions/01_populate_pm_action.sql
git commit -m "feat(pm_actions): procedure populate_pm_action depuis pe_tools"
```

---

## Task 3: Procédure `populate_pm_action_work_step`

**Files:**
- Create: `sql/pm_actions/02_populate_pm_action_work_step.sql`

- [ ] **Step 1: Écrire la procédure**

`sql/pm_actions/02_populate_pm_action_work_step.sql` :
```sql
CREATE OR REPLACE PROCEDURE clean_data.populate_pm_action_work_step()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_org_contract        VARCHAR := 'SJ';
    v_pm_revision         VARCHAR := '1';
    v_connection_type     VARCHAR := 'Functional Object';
    v_connection_type_db  VARCHAR := 'FUNCTIONAL';
    v_count INTEGER := 0;
BEGIN
    TRUNCATE TABLE clean_data.pm_action_work_step;

    INSERT INTO clean_data.pm_action_work_step (
        pm_no,
        pm_revision,
        pm_action_work_step_seq,
        description,
        order_no,
        mch_code_contract,
        mch_code,
        connection_type,
        connection_type_db
    )
    SELECT
        COALESCE(clean_data.pe_num(t.plan_entretien), 900000 + t.raw_id),
        v_pm_revision,
        row_number() OVER (ORDER BY t.raw_id)                              AS pm_action_work_step_seq,
        left(COALESCE(NULLIF(btrim(t.designation), ''), 'N/A'), 500)       AS description,
        clean_data.pe_num(t.compteur_de_gamme)                             AS order_no,
        v_org_contract,
        t.poste_technique,
        v_connection_type,
        v_connection_type_db
    FROM raw_data.pe_tools t;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'pm_action_work_step: % lignes insérées', v_count;
END;
$procedure$
;
```

- [ ] **Step 2: Déployer et exécuter**

Run :
```bash
PGPASSWORD=trimet2025 psql -h 10.190.100.58 -p 5432 -U postgres -d sap_migration_db \
  -f 02_populate_pm_action_work_step.sql \
  -c "CALL clean_data.populate_pm_action_work_step();"
```
Expected: `CREATE PROCEDURE` puis `NOTICE: pm_action_work_step: 121 lignes insérées`

- [ ] **Step 3: Vérifier volumétrie, PK et NOT NULL**

Run (lecture seule) :
```sql
SELECT
  count(*)                                          AS total,        -- 121
  count(DISTINCT pm_action_work_step_seq)           AS seq_distinct, -- 121
  count(*) FILTER (WHERE description IS NULL)        AS descr_null    -- 0
FROM clean_data.pm_action_work_step;
```
Expected: `total=121, seq_distinct=121, descr_null=0`

- [ ] **Step 4: Commit**

```bash
git add sql/pm_actions/02_populate_pm_action_work_step.sql
git commit -m "feat(pm_actions): procedure populate_pm_action_work_step"
```

---

## Task 4: Procédure `populate_pm_action_resource`

**Files:**
- Create: `sql/pm_actions/03_populate_pm_action_resource.sql`

- [ ] **Step 1: Écrire la procédure**

`sql/pm_actions/03_populate_pm_action_resource.sql` :
```sql
CREATE OR REPLACE PROCEDURE clean_data.populate_pm_action_resource()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_pm_revision     VARCHAR := '1';
    v_demand_type     VARCHAR := 'Work Order';   -- ⚠️ à confirmer
    v_demand_type_db  VARCHAR := 'WORK_ORDER';    -- ⚠️ valeur _db IFS à vérifier
    v_count INTEGER := 0;
BEGIN
    TRUNCATE TABLE clean_data.pm_action_resource;

    INSERT INTO clean_data.pm_action_resource (
        pm_no,
        pm_revision,
        pm_action_resource_seq,
        demand_type,
        demand_type_db,
        planned_hours,
        planned_quantity
    )
    SELECT
        COALESCE(clean_data.pe_num(t.plan_entretien), 900000 + t.raw_id),
        v_pm_revision,
        row_number() OVER (ORDER BY t.raw_id)          AS pm_action_resource_seq,
        v_demand_type,
        v_demand_type_db,
        clean_data.pe_num(t.charge)                    AS planned_hours,
        clean_data.pe_num(t.nb_intervenants)           AS planned_quantity
    FROM raw_data.pe_tools t;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'pm_action_resource: % lignes insérées', v_count;
END;
$procedure$
;
```

- [ ] **Step 2: Déployer et exécuter**

Run :
```bash
PGPASSWORD=trimet2025 psql -h 10.190.100.58 -p 5432 -U postgres -d sap_migration_db \
  -f 03_populate_pm_action_resource.sql \
  -c "CALL clean_data.populate_pm_action_resource();"
```
Expected: `CREATE PROCEDURE` puis `NOTICE: pm_action_resource: 121 lignes insérées`

- [ ] **Step 3: Vérifier volumétrie, PK, NOT NULL et report de charge**

Run (lecture seule) :
```sql
SELECT
  count(*)                                        AS total,        -- 121
  count(DISTINCT pm_action_resource_seq)          AS seq_distinct, -- 121
  count(*) FILTER (WHERE demand_type IS NULL)     AS demand_null,  -- 0
  count(*) FILTER (WHERE planned_hours IS NOT NULL) AS avec_charge  -- 119 (2 charges NULL)
FROM clean_data.pm_action_resource;
```
Expected: `total=121, seq_distinct=121, demand_null=0, avec_charge=119`

- [ ] **Step 4: Commit**

```bash
git add sql/pm_actions/03_populate_pm_action_resource.sql
git commit -m "feat(pm_actions): procedure populate_pm_action_resource (charge/intervenants)"
```

---

## Task 5: Procédure `populate_pm_action_role`

**Files:**
- Create: `sql/pm_actions/04_populate_pm_action_role.sql`

- [ ] **Step 1: Écrire la procédure**

`sql/pm_actions/04_populate_pm_action_role.sql` :
```sql
CREATE OR REPLACE PROCEDURE clean_data.populate_pm_action_role()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_org_contract  VARCHAR := 'SJ';
    v_org_code      VARCHAR := 'FR_MAINT';   -- ⚠️ à confirmer
    v_pm_revision   VARCHAR := '1';
    v_count INTEGER := 0;
BEGIN
    TRUNCATE TABLE clean_data.pm_action_role;

    INSERT INTO clean_data.pm_action_role (
        pm_no,
        pm_revision,
        row_no,
        description,
        duration,
        org_contract,
        org_code
    )
    SELECT
        COALESCE(clean_data.pe_num(t.plan_entretien), 900000 + t.raw_id),
        v_pm_revision,
        row_number() OVER (ORDER BY t.raw_id)    AS row_no,
        left(t.designation, 200)                 AS description,
        clean_data.pe_num(t.charge)              AS duration,
        v_org_contract,
        v_org_code
    FROM raw_data.pe_tools t;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'pm_action_role: % lignes insérées', v_count;
END;
$procedure$
;
```

- [ ] **Step 2: Déployer et exécuter**

Run :
```bash
PGPASSWORD=trimet2025 psql -h 10.190.100.58 -p 5432 -U postgres -d sap_migration_db \
  -f 04_populate_pm_action_role.sql \
  -c "CALL clean_data.populate_pm_action_role();"
```
Expected: `CREATE PROCEDURE` puis `NOTICE: pm_action_role: 121 lignes insérées`

- [ ] **Step 3: Vérifier volumétrie et PK**

Run (lecture seule) :
```sql
SELECT
  count(*)                       AS total,        -- 121
  count(DISTINCT row_no)         AS row_distinct  -- 121
FROM clean_data.pm_action_role;
```
Expected: `total=121, row_distinct=121`

- [ ] **Step 4: Commit**

```bash
git add sql/pm_actions/04_populate_pm_action_role.sql
git commit -m "feat(pm_actions): procedure populate_pm_action_role"
```

---

## Task 6: Orchestrateur `populate_all_pm_actions`

**Files:**
- Create: `sql/pm_actions/05_populate_all_pm_actions.sql`

- [ ] **Step 1: Écrire la procédure orchestratrice**

`sql/pm_actions/05_populate_all_pm_actions.sql` :
```sql
CREATE OR REPLACE PROCEDURE clean_data.populate_all_pm_actions()
 LANGUAGE plpgsql
AS $procedure$
BEGIN
    CALL clean_data.populate_pm_action();
    CALL clean_data.populate_pm_action_work_step();
    CALL clean_data.populate_pm_action_resource();
    CALL clean_data.populate_pm_action_role();
    RAISE NOTICE 'populate_all_pm_actions: terminé';
END;
$procedure$
;
```

- [ ] **Step 2: Déployer et exécuter l'orchestrateur**

Run :
```bash
PGPASSWORD=trimet2025 psql -h 10.190.100.58 -p 5432 -U postgres -d sap_migration_db \
  -f 05_populate_all_pm_actions.sql \
  -c "CALL clean_data.populate_all_pm_actions();"
```
Expected: 4 NOTICE `... 121 lignes insérées` + `NOTICE: populate_all_pm_actions: terminé`

- [ ] **Step 3: Vérifier la cohérence croisée des 4 tables**

Run (lecture seule) :
```sql
SELECT
  (SELECT count(*) FROM clean_data.pm_action)            AS pm_action,      -- 121
  (SELECT count(*) FROM clean_data.pm_action_work_step)  AS work_step,      -- 121
  (SELECT count(*) FROM clean_data.pm_action_resource)   AS resource,       -- 121
  (SELECT count(*) FROM clean_data.pm_action_role)       AS role,           -- 121
  (SELECT count(*) FROM clean_data.pm_action_work_step w
     WHERE NOT EXISTS (SELECT 1 FROM clean_data.pm_action a
       WHERE a.pm_no = w.pm_no AND a.pm_revision = w.pm_revision)) AS work_step_orphelins;  -- 0
```
Expected: `pm_action=121, work_step=121, resource=121, role=121, work_step_orphelins=0`

- [ ] **Step 4: Commit**

```bash
git add sql/pm_actions/05_populate_all_pm_actions.sql
git commit -m "feat(pm_actions): orchestrateur populate_all_pm_actions"
```

---

## Task 7: Script de déploiement `compile.sh`

**Files:**
- Create: `sql/pm_actions/compile.sh`
- Référence: `sql/maintenanceRousource/compile.sh` (copie adaptée)

- [ ] **Step 1: Écrire `compile.sh`**

`sql/pm_actions/compile.sh` — copie de `sql/maintenanceRousource/compile.sh` avec (a) le titre « PM ACTIONS » et (b) la liste `files` ci-dessous ; le reste (connexion, couleurs, `execute_sql`, boucle, résumé) est identique :
```bash
# ... en-tête, config connexion, fonctions log_* et execute_sql identiques à maintenanceRousource/compile.sh ...

echo "=========================================="
echo "  Compilation des procédures PM ACTIONS"
echo "=========================================="

# Liste des fichiers dans l'ordre d'exécution
# 00_pm_helpers doit être compilé en premier (dépendance pe_num)
files=(
    "00_pm_helpers.sql"
    "01_populate_pm_action.sql"
    "02_populate_pm_action_work_step.sql"
    "03_populate_pm_action_resource.sql"
    "04_populate_pm_action_role.sql"
    "05_populate_all_pm_actions.sql"
)

# ... boucle for + résumé identiques à maintenanceRousource/compile.sh ...
```

- [ ] **Step 2: Vérifier que `compile.sh` compile tout sans erreur**

Run (depuis `sql/pm_actions/`) :
```bash
bash compile.sh
```
Expected: `✅ ... compilé avec succès` pour les 6 fichiers, puis `✅ Toutes les procédures ont été compilées avec succès!`

- [ ] **Step 3: Ré-exécuter l'ETL complet (idempotence)**

Run :
```bash
PGPASSWORD=trimet2025 psql -h 10.190.100.58 -p 5432 -U postgres -d sap_migration_db \
  -c "CALL clean_data.populate_all_pm_actions();"
```
Expected: à nouveau 4× `121 lignes insérées` (le `TRUNCATE` garantit l'idempotence, aucune erreur de doublon)

- [ ] **Step 4: Commit**

```bash
git add sql/pm_actions/compile.sh
git commit -m "chore(pm_actions): script compile.sh (deploiement des procedures PM Actions)"
```

---

## Self-Review (rempli lors de la rédaction)

**Couverture spec :**
- §2 périmètre 4 tables → Tasks 2–5 ✅
- §3 grain + pm_no (fallback 900000+raw_id) → expression `COALESCE(pe_num(plan_entretien), 900000+raw_id)` dans chaque INSERT ✅
- §4 constantes IFS en `DECLARE` → présentes dans chaque procédure ✅
- §5 décodage fréquence S/M/A → Task 2 step 1 + vérif step 4 ✅
- §6 mapping colonne par colonne → INSERT de chaque task ✅
- §7 structure fichiers + convention proc → Tasks 1–7 ✅
- §8 casts défensifs (`pe_num`), idempotence (`TRUNCATE`), `row_number()` ordonné par `raw_id` → ✅

**Placeholder scan :** les `⚠️` sont des constantes de config volontairement paramétrables (documentées §4 spec), pas des TBD. Aucun step sans code.

**Cohérence types/noms :** `clean_data.pe_num(text)` défini Task 1, utilisé identiquement Tasks 2–5. Noms de procédures `populate_pm_action[_*]` cohérents entre les fichiers et l'orchestrateur Task 6. Colonne `"interval"` quotée (mot réservé). PK filles générées par `row_number() OVER (ORDER BY raw_id)` partout.

**Note vérifications :** les comptages attendus (119 charges non nulles, etc.) proviennent de l'analyse de `raw_data.pe_tools` (2 `charge` NULL, 3 `plan_entretien` NULL). Si `pe_tools` est rechargée avec d'autres données, réajuster les valeurs attendues.
