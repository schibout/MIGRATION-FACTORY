# Migration IH02 — Table unique `maintenance_object`

Migration de l'ecran **`/maintenance/ih02`** (hierarchie des postes techniques SAP) vers un modele a **table unique** stockant les postes techniques, les equipements, les articles et les liens de nomenclature, en conservant a l'identique toutes les fonctionnalites actuelles.

---

## 1. Contexte et probleme actuel

L'ecran IH02 (`frontend/src/pages/IH02HierarchyPage.tsx` + `backend/api/ih02_hierarchy.py`, blueprint `/api/v1/ih02-hierarchy/*`) interroge et **modifie** directement les tables SAP brutes :

| Objet | Tables sources actuelles |
|---|---|
| Postes techniques (hierarchie) | `raw_data.iflot` (tplnr/tplma), `iflos` (strno/tplkz), `iflotx` (designations F/E), `iflo` (ppsid = poste de travail PM) |
| Equipements | `raw_data.itob` (vue equi+eqkt+equz+iloa), `equz`, `crhd`, `crtx` |
| Articles | `raw_data.mara`, `makt` |
| Nomenclatures FL (BOM `stlty='T'`) | `raw_data.tpst`, `stko`, `stpo` + vue materialisee `clean_data.v_fl_nomenclature` |
| Nomenclatures matiere (BOM `stlty='M'`) | `raw_data.mast`, `stpo` |
| Postes de travail | `raw_data.crhd`, `crtx` |

Problemes :

1. **Ecritures dans `raw_data`** (update-location, add-node, delete-node, bom-component, update-equipment...) alors que la convention projet impose `raw_data` en lecture seule.
2. **Complexite** : chaque endpoint reconstruit les memes jointures (5 a 8 tables), CTE recursifs, LATERAL pour les langues, gestion `mandt`, fallback si `iflo` absent, etc.
3. **Fragilite** : la designation vit dans 3 tables selon la langue, le poste de travail dans `iflo`+`crhd`, la quantite BOM dans `stpo` avec cle composite (`stlty`,`stlnr`,`stlal`,`posnr`)... une modification touche N tables sans transaction metier claire.
4. **Performance** : `REFRESH MATERIALIZED VIEW` complet apres chaque edition de BOM ; comptages d'enfants recalcules a chaque appel.
5. **Pas d'audit** : aucune trace de qui a modifie quoi.

## 2. Cible : une table unique `clean_data.maintenance_object`

### 2.1 Principe

Un **modele en liste d'adjacence typee** : chaque ligne est un objet ou un lien de nomenclature, la hierarchie complete tient dans la colonne `parent_id`.

```
maintenance_object
├── object_type = 'FUNC_LOC'   → poste technique   (parent_id = FL parent, NULL si racine)
├── object_type = 'EQUIPMENT'  → equipement        (parent_id = FL porteur ou equipement superieur)
├── object_type = 'ARTICLE'    → article "maitre"  (parent_id = NULL ; 1 seule ligne par matnr)
└── object_type = 'BOM_ITEM'   → ligne de nomenclature
                                  parent_id     = FL / EQUIPMENT / ARTICLE possesseur de la BOM
                                  ref_object_id = ligne ARTICLE composant
                                  quantity/unit = quantite du lien
```

- Les articles ne sont **pas dupliques** : un article utilise dans 40 nomenclatures = 1 ligne `ARTICLE` + 40 lignes `BOM_ITEM` qui la referencent.
- Les attributs communs (code, designation, type, poste de travail, centre de couts...) sont des **colonnes typees** ; les attributs specifiques SAP (fabricant, n° serie, garantie, poids, mtart...) vont dans **`attributes JSONB`** pour ne rien perdre ("toutes les informations importantes de chaque objet") sans creer 60 colonnes.
- La table vit dans `clean_data` (donnees transformees, editables), alimentee depuis `raw_data` par une procedure — conforme au pipeline existant (`sql/maintenance/proc_load_*.sql`). `raw_data` redevient strictement lecture seule.

### 2.2 DDL

```sql
-- sql/maintenance/create_maintenance_object.sql
CREATE TABLE clean_data.maintenance_object (
    id              BIGSERIAL PRIMARY KEY,
    object_type     TEXT NOT NULL CHECK (object_type IN ('FUNC_LOC','EQUIPMENT','ARTICLE','BOM_ITEM')),

    -- Identite SAP d'origine (tracabilite / re-chargement idempotent)
    sap_key         TEXT NOT NULL,          -- tplnr | equnr | matnr | stlty:stlnr:stlal:posnr
    code            TEXT,                   -- affichage : strno | equnr sans zeros | matnr sans zeros
    designation     TEXT,                   -- pltxt F>E>any | eqktx | maktx F>E>any

    -- Hierarchie (adjacence) + reference article pour les BOM_ITEM
    parent_id       BIGINT REFERENCES clean_data.maintenance_object(id) ON DELETE CASCADE,
    ref_object_id   BIGINT REFERENCES clean_data.maintenance_object(id),
    sort_order      INTEGER,                -- posnr numerique pour les BOM_ITEM

    -- Attributs communs (colonnes car filtres / affiches dans l'arbre)
    type_code       TEXT,                   -- fltyp | eqart | mtart
    category        TEXT,                   -- tplkz | eqtyp | postp (item_category)
    work_center     TEXT,                   -- arbpl resolu (iflo.ppsid -> crhd | equz.gewrk -> crhd)
    work_center_txt TEXT,                   -- crtx.ktext
    cost_center     TEXT,                   -- kostl
    plant           TEXT,                   -- iwerk
    planner_group   TEXT,                   -- ingrp
    quantity        NUMERIC(15,3),          -- BOM_ITEM : stpo.menge
    unit            TEXT,                   -- BOM_ITEM : stpo.meins

    -- Tout le reste des champs SAP importants, par type d'objet
    attributes      JSONB NOT NULL DEFAULT '{}'::jsonb,

    -- Cycle de vie / audit
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,   -- soft delete (lvorm/loevm ou suppression UI)
    source          TEXT NOT NULL DEFAULT 'SAP',      -- 'SAP' (charge) | 'MANUAL' (cree via UI)
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      TEXT,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by      TEXT,

    CONSTRAINT uq_mo_type_key UNIQUE (object_type, sap_key),
    -- Un BOM_ITEM doit avoir un parent et un article reference ; un ARTICLE n'a pas de parent
    CONSTRAINT ck_mo_bom  CHECK (object_type <> 'BOM_ITEM' OR (parent_id IS NOT NULL AND ref_object_id IS NOT NULL)),
    CONSTRAINT ck_mo_art  CHECK (object_type <> 'ARTICLE'  OR parent_id IS NULL),
    CONSTRAINT ck_mo_ref  CHECK (object_type =  'BOM_ITEM' OR ref_object_id IS NULL)
);

CREATE INDEX idx_mo_parent      ON clean_data.maintenance_object (parent_id);
CREATE INDEX idx_mo_type        ON clean_data.maintenance_object (object_type);
CREATE INDEX idx_mo_ref         ON clean_data.maintenance_object (ref_object_id) WHERE ref_object_id IS NOT NULL;
CREATE INDEX idx_mo_code        ON clean_data.maintenance_object (code);
-- Recherche plein texte (equivalent des ILIKE actuels) :
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_mo_designation_trgm ON clean_data.maintenance_object USING gin (designation gin_trgm_ops);
CREATE INDEX idx_mo_code_trgm        ON clean_data.maintenance_object USING gin (code gin_trgm_ops);

-- Trigger updated_at
CREATE OR REPLACE FUNCTION clean_data.mo_touch() RETURNS trigger AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_mo_touch BEFORE UPDATE ON clean_data.maintenance_object
FOR EACH ROW EXECUTE FUNCTION clean_data.mo_touch();
```

### 2.3 Contenu de `attributes` par type

| object_type | Cles JSONB (issues des champs affiches aujourd'hui dans l'UI) |
|---|---|
| `FUNC_LOC` | `tplma_sap`, `strno`, `tplkz`, `fltyp`, `mandt` |
| `EQUIPMENT` | `equnr_long`, `herst`, `herld`, `typbz`, `sernr`, `invnr`, `groes`, `brgew`, `gewei`, `answt`, `waers`, `ansdt`, `baujj`, `baumm`, `inbdt`, `erdat`, `ernam`, `aedat`, `aenam`, `gwlen`, `gwldt`, `elief`, `matnr`, `begru`, `bukrs`, `gsber`, `swerk`, `stort`, `beber`, `warpl`, `hequi`, `tplnr_sap` |
| `ARTICLE` | `matnr_long`, `mtart`, `meins_base`, `mbrsh`, `matkl`, textes alternatifs (`maktx_e`) |
| `BOM_ITEM` | `stlty` ('T' ou 'M'), `stlnr`, `stlal`, `stlan`, `posnr`, `stlkn`, `postp`, `base_quantity` (stko.bmeng), `base_unit` (stko.bmein) |

Regle : tout champ qu'un endpoint lit aujourd'hui doit exister soit en colonne, soit dans `attributes`. La procedure de chargement (section 3) fait foi.

### 2.4 Ce que ce modele conserve

| Fonctionnalite actuelle | Equivalent table unique |
|---|---|
| Arbre lazy-loading (racines / enfants) | `WHERE parent_id IS NULL AND object_type='FUNC_LOC'` / `WHERE parent_id = :id` — plus de CTE pour le niveau (calculable) ni de `children_counts` multi-tables |
| FL + equipements meles dans l'arbre | un seul `SELECT ... WHERE parent_id = :id ORDER BY object_type, code` |
| Hierarchie equipement (hequi) | `parent_id` pointe l'equipement superieur |
| BOM d'un FL / BOM matiere recursive d'un article | `SELECT b.*, a.* FROM maintenance_object b JOIN maintenance_object a ON a.id=b.ref_object_id WHERE b.parent_id=:id AND b.object_type='BOM_ITEM'` — le meme SQL sert les deux (plus de distinction stlty T/M cote requete) |
| bom-counts / article-bom-counts | `GROUP BY parent_id` sur les BOM_ITEM (une requete, plus de vue materialisee a rafraichir) |
| Recherche (min 2 caracteres, FL + equipements) | `ILIKE` sur `code`/`designation` avec index trigram |
| Deplacement drag & drop + garde anti-cycle | `UPDATE ... SET parent_id` + CTE recursif sur `parent_id` |
| Bulk-update sur descendants | CTE recursif + `UPDATE` sur la meme table — et desormais **tous** les champs deviennent bulk-editables (aujourd'hui seule la designation l'est) |
| Ajout / suppression FL et equipement | `INSERT` / soft delete `is_active=false` (le `ON DELETE CASCADE` reste pour purge physique) |
| Poste de travail herite (remontee tplma) | remontee `parent_id` sur la meme table (1 requete recursive au lieu d'une boucle Python) |
| Exports CSV structures / equipements | memes colonnes, `SELECT` simple |
| Stats par niveau | CTE recursif unique sur `parent_id` |

## 3. SQL — scripts a creer (`sql/maintenance/`)

### 3.1 `create_maintenance_object.sql`
DDL de la section 2.2 (+ `GRANT SELECT` au role `readonly_ai` si on veut exposer la table a l'Assistant IA plus tard — hors perimetre).

### 3.2 `proc_load_maintenance_object.sql` — chargement initial idempotent

Procedure `clean_data.proc_load_maintenance_object()` en 5 passes ordonnees (les FK parent imposent l'ordre). Idempotente via `ON CONFLICT (object_type, sap_key)` : re-executable apres une nouvelle extraction SAP **sans ecraser** les lignes `source='MANUAL'` ni les champs modifies via l'UI (strategie : `DO UPDATE` seulement si `updated_by IS NULL`).

```
Passe 1 — FUNC_LOC (sans parent) :
  iflot i
  LEFT JOIN iflos s   (code = COALESCE(NULLIF(TRIM(strno),''), tplnr), category = tplkz)
  LEFT JOIN iflotx F/E/any (designation, meme cascade F > E > any # 'vide' qu'aujourd'hui)
  LEFT JOIN iflo fl + crhd + crtx (work_center, work_center_txt) -- si iflo present
  → sap_key = tplnr, type_code = fltyp, plant = iwerk, planner_group = ingrp

Passe 2 — resolution parent des FUNC_LOC :
  UPDATE ... SET parent_id = p.id FROM maintenance_object p
  WHERE p.object_type='FUNC_LOC' AND p.sap_key = attributes->>'tplma_sap'

Passe 3 — EQUIPMENT :
  itob t LEFT JOIN equz (datbi='99991231') + crhd + crtx
  → sap_key = equnr, code = LTRIM(equnr,'0'), designation = eqktx,
    parent_id = FL (tplnr) si hequi vide, sinon equipement hequi (2e UPDATE de resolution),
    type_code = eqart, category = eqtyp, cost_center = kostl, plant = iwerk,
    planner_group = ingrp, attributes = to_jsonb(...) des ~30 champs itob

Passe 4 — ARTICLE (uniquement les articles references par une BOM T ou M, + matnr des equipements) :
  SELECT DISTINCT idnrk FROM stpo WHERE stlty IN ('T','M')
  JOIN mara / makt (cascade F > E > any)
  → sap_key = matnr, code = LTRIM(matnr,'0'), type_code = mtart

Passe 5 — BOM_ITEM :
  a) BOM de FL   : tpst → stko → stpo (stlty='T')  parent = FL,      ref = ARTICLE(idnrk)
  b) BOM matiere : mast → stpo (stlty='M', BOM preferee werks='9200' comme aujourd'hui)
                   parent = ARTICLE(matnr), ref = ARTICLE(idnrk)
  → sap_key = stlty||':'||stlnr||':'||stlal||':'||posnr(:stlkn pour M),
    quantity = menge::numeric, unit = meins, sort_order = posnr::int
```

En fin de procedure : `RAISE NOTICE` des volumes par type + controles d'integrite (BOM_ITEM orphelins, parents non resolus → log dans une table temporaire de rejets, comme les autres procs du dossier).

### 3.3 `recreate_v_fl_nomenclature.sql` — compatibilite descendante

`clean_data.v_fl_nomenclature` (utilisee par `/bom/<tplnr>` et potentiellement par les exports `etl_export_queries`) est recreee en **vue simple** (plus materialisee → plus de REFRESH) sur la table unique, memes colonnes de sortie :

```sql
CREATE OR REPLACE VIEW clean_data.v_fl_nomenclature AS
SELECT fl.sap_key AS tplnr, fl.code AS tplnr_display, fl.designation AS fl_designation,
       b.attributes->>'stlnr' AS stlnr, b.attributes->>'stlal' AS stlal, b.attributes->>'stlan' AS stlan,
       b.attributes->>'base_quantity' AS base_quantity, b.attributes->>'base_unit' AS base_unit,
       b.attributes->>'posnr' AS posnr, a.sap_key AS idnrk, a.code AS matnr_short,
       b.category AS item_category, b.quantity::text AS quantity, b.unit,
       a.type_code AS material_type, a.designation, b.sort_order
FROM clean_data.maintenance_object b
JOIN clean_data.maintenance_object fl ON fl.id = b.parent_id AND fl.object_type = 'FUNC_LOC'
JOIN clean_data.maintenance_object a  ON a.id  = b.ref_object_id
WHERE b.object_type = 'BOM_ITEM' AND b.is_active;
```

Verifier au passage les autres consommateurs de la vue : `grep -r v_fl_nomenclature backend/ sql/` et les requetes dynamiques dans `public.etl_export_queries`.

### 3.4 `checks_maintenance_object.sql` — parite avant bascule

Requetes de recette comparant ancien / nouveau monde :

```sql
-- Volumes
SELECT 'FL' src, COUNT(*) FROM raw_data.iflot
UNION ALL SELECT 'FL_new', COUNT(*) FROM clean_data.maintenance_object WHERE object_type='FUNC_LOC';
-- idem EQUIPMENT vs itob, BOM_ITEM T vs v_fl_nomenclature (ancienne), racines, etc.

-- Zero orphelin
SELECT COUNT(*) FROM clean_data.maintenance_object
WHERE object_type='FUNC_LOC' AND parent_id IS NULL
  AND NULLIF(TRIM(attributes->>'tplma_sap'),'') IS NOT NULL;

-- Echantillon : meme arbre pour 10 tplnr connus (T340-E100-1005...)
```

### 3.5 Mise a jour `compile.sh`
Ajouter les nouveaux scripts dans l'ordre : create → proc_load → recreate vue → checks.

## 4. Backend — plan detaille

**Strategie : conserver a l'identique les routes et les contrats JSON** (`/api/v1/ih02-hierarchy/*`, champs `row_id`, `node_id`, `designation`, `children_count`, `equnr`, `equnr_short`, `data.locations` / `data.equipment`...). Le frontend fonctionne alors sans modification fonctionnelle. Les identifiants exposes restent les cles SAP (`tplnr`, `equnr`, `idnrk`) — l'`id` bigint reste interne, ce qui evite toute migration d'etat cote React.

Reecrire `backend/api/ih02_hierarchy.py` route par route (26 routes) :

| Route(s) | Avant | Apres |
|---|---|---|
| `GET /root-nodes`, `GET /children` | iflot+iflos+iflotx+iflo+crhd + CTE counts, puis itob+equz+crhd+crtx | 1 requete : `SELECT ..., (SELECT COUNT(*) FROM mo c WHERE c.parent_id=o.id AND c.object_type IN ('FUNC_LOC','EQUIPMENT') AND c.is_active) AS children_count FROM mo o WHERE o.parent_id = (SELECT id FROM mo WHERE object_type='FUNC_LOC' AND sap_key=:parent)` ; separer locations/equipment en Python |
| `GET /node-details`, `GET /equipment-details` | 8 jointures + boucle Python heritage poste de travail | `SELECT` sur la ligne + depliage `attributes` ; heritage = CTE recursif ascendant sur `parent_id` |
| `GET /search` | ILIKE multi-tables | ILIKE sur `code`/`designation` (index trgm), `object_type IN ('FUNC_LOC','EQUIPMENT')`, LIMIT 100/50 conserves |
| `PUT /update-location`, `PUT /update-equipment` | UPDATE raw_data.iflotx/iflot/iflo/eqkt... | `UPDATE mo SET designation=..., work_center=..., attributes = attributes || :patch, updated_by = :user WHERE object_type=... AND sap_key=...` — validation `work_center` contre les lignes crhd chargees (ou table de ref, voir note 4.1) |
| `PUT /move-node` | UPDATE iflot.tplma + CTE anti-cycle | `UPDATE mo SET parent_id` + meme garde anti-cycle via CTE recursif sur `parent_id` |
| `PUT /bulk-update` | seulement designation via iflotx | CTE descendants + `UPDATE` : tous les champs de `BULK_FIELDS` du frontend deviennent reellement modifiables (designation, type_poste, centre_couts, poste resp., quantite, unite) |
| `POST /add-node`, `POST /add-equipment` | INSERT iflot+iflotx / equi+eqkt... | `INSERT INTO mo (..., source='MANUAL', created_by=:user)` |
| `DELETE /delete-node`, `DELETE /delete-equipment` | DELETE physique iflot/iflotx/iflo | soft delete `is_active=false` sur le sous-arbre (CTE) — recuperable ; message identique |
| `GET /bom/<tplnr>`, `GET /article-bom/<matnr>`, `GET /bom-counts`, `GET /article-bom-counts` | vue materialisee + mast/stpo/mara/makt/LATERAL | requetes BOM_ITEM de la section 2.4 ; counts = `GROUP BY parent_id` ; `children_count` d'un composant = count des BOM_ITEM dont `parent_id = article.id` |
| `PUT /bom-component`, `PUT /article-bom-component` | UPDATE stpo + makt + REFRESH matview | `UPDATE mo SET quantity, unit, ref_object_id=(id de l'article choisi) WHERE object_type='BOM_ITEM' AND sap_key=...` ; edition `maktx` = update `designation` de la ligne ARTICLE ; **plus aucun REFRESH** |
| `GET /work-centers` | crhd+crtx | inchange (referentiel, lecture seule — reste sur raw_data, cf. note 4.1) |
| `GET /export-structures`, `GET /export-equipment` | multi-jointures + CTE | SELECT plat sur la table, memes colonnes CSV |
| `GET /search-equipment`, `GET /search-article` | itob / mara+makt | `WHERE object_type='EQUIPMENT'|'ARTICLE'` + trgm |
| `GET /stats`, `GET /descendants-count` | CTE sur iflot | CTE sur `parent_id` |

Notes :

1. **Referentiel postes de travail (`crhd`/`crtx`)** : lecture seule, jamais edite par l'ecran → il reste en `raw_data` (le mettre dans la table unique n'apporte rien : ce ne sont ni des postes techniques, ni des structures, ni des articles). La validation `arbpl` continue de se faire contre `crhd werks='9200'`.
2. **Helper commun** : une fonction `_resolve(object_type, sap_key) -> id` et un module `services/maintenance_object_service.py` pour factoriser resolution d'id, CTE descendants/ascendants et mapping ligne → payload JSON (aujourd'hui duplique dans chaque route).
3. **`_normalize_sap_matnr`** conserve tel quel (les `sap_key` ARTICLE restent en matnr 18 caracteres).
4. **Transactions** : chaque mutation = 1 UPDATE/INSERT sur 1 table → plus de rollbacks partiels multi-tables.
5. **Audit** : renseigner `created_by`/`updated_by` depuis le JWT (`get_jwt_identity()`).

## 5. Frontend — plan detaille

Grace au contrat API conserve, l'essentiel de `IH02HierarchyPage.tsx` est **inchange** : arbre, drag & drop, dialogs, BOM recursive, exports.

**Etat : implemente.** Modifications reellement apportees :

1. **Champs desormais persistants** : `centre_couts`, `art_type_construction`, `quantite`, `unite` sur les postes techniques etaient renvoyes `NULL::text` (non stockables dans iflot). Ils sont maintenant persistes. **Aucun garde-fou frontend a retirer** : les champs etaient deja editables cote UI (`startEditLocation` + `saveLocation` les envoyaient deja) ; le blocage etait uniquement backend, desormais leve.
2. **Bulk-update** : cote front `BULK_FIELDS` (7 champs) etait deja pret et envoyait tout ; c'est le backend qui ignorait tout sauf `designation`. Le nouveau backend applique reellement chaque champ sur le noeud + descendants. Aucun changement frontend necessaire.
3. **Tracabilite (nouveau)** : `LocationNode` et `EquipmentDetails` recoivent 3 champs optionnels (`source`, `updated_by`, `updated_at`). Une section **"Tracabilite"** s'affiche en lecture dans le panneau poste technique (origine SAP/application, modifie par, derniere modification) et dans l'onglet General de l'equipement. Rendu conditionnel → **compatible avec l'ancien backend** (champs absents = section masquee). Cote backend, `node-details` et `equipment-details` renvoient desormais ces 3 champs.
4. **Suppression** : soft delete cote backend ; le wording frontend est inchange (le snackbar utilise deja son propre message).
5. Aucun changement dans `services/api.ts`, le routing, ni le store Redux.

## 6. Plan de bascule (phases)

| Phase | Contenu | Validation |
|---|---|---|
| **P1 — SQL** | `create_maintenance_object.sql`, `proc_load_maintenance_object.sql`, execution du chargement sur 10.190.100.58, `checks_maintenance_object.sql` | volumes identiques (iflot vs FUNC_LOC, itob vs EQUIPMENT, lignes BOM), 0 orphelin, echantillons d'arbres identiques |
| **P2 — Backend** | reecriture `ih02_hierarchy.py` + `services/maintenance_object_service.py` derriere un flag `IH02_USE_MAINTENANCE_OBJECT` (settings/env) permettant de rebasculer sur l'ancien code | comparaison JSON ancien/nouveau sur `/root-nodes`, `/children`, `/node-details`, `/bom/*`, `/search` pour un jeu de noeuds de reference |
| **P3 — Vue compat** | `recreate_v_fl_nomenclature.sql` + verification des exports `etl_export_queries` qui la referencent | exports IFS identiques a l'octet pres (diff CSV) |
| **P4 — Frontend** | ajustements section 5, `npm run build` | recette manuelle : expand/collapse, recherche, drag & drop, edition FL + equipement + BOM, bulk, ajout, suppression, 2 exports |
| **P5 — Cutover** | deploiement (`./deploybackend.sh` + `./deployfrontend.sh` — attention au piege du conteneur jamais recree), flag active, ancien code conserve un sprint puis supprime | monitoring logs backend 48h |
| **Rollback** | flag a `false` → ancien code re-lit `raw_data` (intact puisqu'on n'y ecrit plus qu'en P5-) ; la table unique peut etre rechargee a tout moment via la proc | — |

Point d'attention rollback : **des que des editions UI partent dans la table unique, `raw_data` ne les voit plus**. Geler les editions IH02 pendant P2-P4 (ou accepter de les rejouer), et considerer la table unique comme seule source de verite apres P5.

## 7. Recapitulatif des fichiers

| Action | Fichier |
|---|---|
| Creer | `sql/maintenance/create_maintenance_object.sql` |
| Creer | `sql/maintenance/proc_load_maintenance_object.sql` |
| Creer | `sql/maintenance/recreate_v_fl_nomenclature.sql` |
| Creer | `sql/maintenance/checks_maintenance_object.sql` |
| Creer | `sql/maintenance/backfill_bom_potx.sql` (textes composant potx1/potx2 sans reload) |
| Creer | `backend/api/ih02_hierarchy_mo.py` (26 routes sur la table unique, contrats JSON inchanges ; helpers + service factorises dans le meme fichier) |
| Modifier | `backend/api/__init__.py` (enregistrement conditionnel du blueprint selon le flag) |
| Modifier | `backend/config/settings.py` (flag `IH02_USE_MAINTENANCE_OBJECT`) |
| Conserver | `backend/api/ih02_hierarchy.py` (ancien backend intact = rollback) |
| Modifier | `frontend/src/pages/IH02HierarchyPage.tsx` (points section 5) |
| Modifier | `sql/maintenance/compile.sh` |
| Modifier | `docs/guide_maintenance.md` (nouvelle architecture) |

## 8. Constats donnees (verifies sur 10.190.100.58, lecture seule)

Verifications faites contre la base reelle avant d'ecrire le SQL. Deux points **structurants** :

1. **`raw_data.equz` est VIDE (0 ligne).** La vue `raw_data.itob` derive `tplnr`, `iwerk`, `ingrp`, `gewrk`, `iloan` (donc localisation, division, poste de travail, **rattachement au poste technique**) du "record courant" `equz.datbi='99991231'`. Sans equz :
   - les 7647 equipements ont `tplnr = NULL` → dans l'ecran **actuel**, `/children` (`WHERE t.tplnr=%s`) ne renvoie **aucun equipement sous les postes techniques** ; l'arbre equipement est donc deja non alimente aujourd'hui ;
   - `hequi` et `warpl` sont de toute facon codes en dur a `NULL` dans la vue itob → **hierarchie d'equipements indisponible** quelle que soit la solution.
   - **Consequence migration** : la procedure charge quand meme les 7647 equipements (comme lignes `EQUIPMENT`), mais ils restent sans parent tant qu'`equz` n'est pas extrait. Des qu'`equz` sera charge dans `raw_data`, un simple `CALL clean_data.load_maintenance_object()` rattachera automatiquement les equipements (passe 3b) et remplira localisation/poste de travail. **Aucune modification de code ne sera necessaire.**
   - **Action recommandee cote extraction** : extraire la table SAP `EQUZ` dans `raw_data` (et idealement `EQST/`hierarchie pour hequi si l'on veut l'arbre d'equipements).

2. **Postes techniques : arbre propre.** 11039 FL, 1 seule racine, 11038 avec parent, **tous resolus** (0 orphelin). La hierarchie migre sans perte.

3. **BOM postes techniques (`stlty='T'`)** : 45094 lignes de composants, dont **24736 rattachees a un FL existant** dans `iflot`. Les ~20358 restantes referencent un `tplnr` **absent d'`iflot`** (donnee orpheline) : elles ne sont de toute facon **pas atteignables dans l'arbre** (pas de noeud FL correspondant) et sont deja filtrees en aval par `equipment_functional` (proc `load_equipment_object_spare`). Le modele cible ne conserve donc que les 24736 lignes reellement rattachables — c'est **plus correct** que l'ancienne vue materialisee qui les gardait toutes via un LEFT JOIN. A verifier neanmoins sur les exports `etl_export_queries` consommant `v_fl_nomenclature` (phase P3).

4. Volumes de reference (source) : `iflot`=11039, `itob`=7647, articles distincts en BOM=27140, `stpo` T=45836 / M=103671, `crhd`=49, `iflo`=39929, `mast` present. Toutes les colonnes SAP referencees par le SQL ont ete verifiees existantes ; le cast des quantites (`NUMERIC(15,3)`) couvre le max reel (900000).

## 8bis. Edition des composants de nomenclature (articles)

Ajout : un composant de nomenclature (article sous un poste technique ou sous un
autre article) est desormais **selectionnable** dans l'arbre et affiche un
**panneau de details a droite** (comme les postes/equipements), avec mode edition.

Perimetre (**option B — ligne uniquement**) : on edite les donnees propres a
**cette occurrence**, pas la fiche article partagee.
- **Fiche article** (code, designation, type matiere) : lecture seule (partagee).
- **Ligne de nomenclature** (editable) : article pointe (idnrk, avec recherche),
  quantite, unite, categorie (postp), position (posnr), textes composant (potx1/potx2).

Points techniques :
- La ligne est localisee par **`stlkn`** (identifiant de position stable SAP) et
  non plus par `posnr` -> `posnr` devient editable sans casser l'update.
- `potx1`/`potx2` ajoutes aux attributs BOM_ITEM : procedure de chargement mise a
  jour (futurs loads) **+ backfill** (`backfill_bom_potx.sql`) sur l'existant, sans
  reload -> aucune modif manuelle ecrasee.
- L'ancien petit popup d'edition BOM est **supprime** au profit du panneau.
- Endpoints `/bom-component` et `/article-bom-component` etendus (champs optionnels
  category/posnr/potx1/potx2), retro-compatibles.

## 8bis-2. Renommage des identifiants (code structure / code article)

L'identifiant affiche d'un poste technique (« Identifiant structuré », ex. `T120-F010`)
et le code d'un article (ex. `609015`) sont **editables** dans les panneaux de droite.

Principe : la colonne **`code` est editable**, la colonne **`sap_key` est immuable**
(cle SAP d'origine = reference API + tracabilite). La hierarchie (`parent_id`) et les
nomenclatures (`ref_object_id`) referencent les objets par **id interne** — un
renommage ne casse donc rien. Pas de migration SQL (id/parent_id existent deja).

- Poste technique : champ « Identifiant structuré » du panneau -> `PUT /update-location`
  (champ `code`, controle d'unicite applicatif -> 409 si deja utilise).
- Article : champ « Code article » du panneau composant (fiche partagee, s'applique
  partout) -> `PUT /article-master` (localise par sap_key/idnrk ; resynchronise le
  code denormalise des BOM_ITEM referencant l'article).
- Propagation exports IFS : relancer `alimenter_equipment_functional()` puis
  `load_equipment_object_spare('FULL')` apres des renommages de postes techniques
  (mch_code = code).

## 8ter. Procedures ETL maintenance : rebasage sur maintenance_object

Objectif : les procs qui alimentent les cibles IFS lisent la table unique (et
non plus raw_data) afin que les modifications faites dans l'ecran IH02 se
propagent aux exports.

| Procedure | Cible | Source apres rebasage | Statut |
|---|---|---|---|
| `alimenter_equipment_functional` | `equipment_functional` | `maintenance_object` (FUNC_LOC) ; `jest` en referentiel statut (defensif) | ✅ **Rebase** (parite validee : 11039=11039, seules les editions ecran different) |
| `load_equipment_object_spare` | `equipment_object_spare` | `v_fl_nomenclature` (=maintenance_object BOM_ITEM T) + `equipment_functional` | ✅ Deja base MO (via la vue) |
| `load_equipment_spare_structure` | `equipment_spare_structure` | `raw_data.mast/stko/stpo` (BOM matiere M, tous werks) | ⚠️ **Non rebase** — voir ci-dessous |

**Pourquoi `load_equipment_spare_structure` reste sur raw_data** : cette proc a
besoin de **toutes** les BOM matiere (sites SJ **et** CS) et du champ `werks`
(9200→SJ, 2200→CS) pour le contrat. Or `maintenance_object` ne stocke, par
conception, qu'**une** BOM matiere preferee par article (werks 9200) et pas le
`werks`. Rebaser en l'etat perdrait ~la moitie des aretes (site CS). Pour le
rebaser proprement il faudrait enrichir le modele MO (stocker toutes les BOM M
multi-werks + le werks), ce qui impacte aussi l'affichage de l'ecran.

**Decision : cette proc reste sur `raw_data`** (BOM matiere multi-sites = donnee
de reference SAP ; edition ecran rare ; l'ecran ne montre que la BOM preferee).
Aucun rebasage prevu tant que ce besoin ne se materialise pas.

## 8quater. Etats sauvegardes, restauration et rechargement SAP (livre le 2026-07-27)

La strategie de fusion decrite en §3.2 (`DO UPDATE` seulement si `updated_by IS NULL`)
etait documentee mais **non implementee** : la seule procedure existante
(`load_maintenance_object()`) supprime toutes les lignes `source='SAP'` et
detruisait donc le travail saisi dans l'UI. Trois besoins utilisateurs sont
desormais couverts : **sauvegarder un etat**, **le restaurer**, **recharger depuis SAP**.

### Base de donnees

| Objet | Role |
|---|---|
| schema `snapshots` | copies de tables (`snapshots.s<id>_<schema>_<table>`, creees a la volee) |
| `public.maintenance_snapshots` | metadonnees d'un etat (nom, type, volumes, auteur) |
| `public.maintenance_jobs` | suivi des operations longues ; index unique partiel `uq_maintenance_jobs_one_active` = **un seul job a la fois** |
| FK de `maintenance_object` | passees en `DEFERRABLE INITIALLY IMMEDIATE` : indispensable pour reinserer une copie en conservant les `id` |

Migration : `migrations/027_create_maintenance_snapshots.sql` (idempotente).

### Perimetre d'un snapshot

`clean_data.maintenance_object` **+** les tables `raw_data` encore ecrites en direct
par les ecrans Hierarchie / Equipements / Articles : `iflot, iflotx, iflos, iloa,
equi, eqkt, equz, mara, makt` (cf. `SNAPSHOT_TABLES`). Les `id` sont conserves et
les colonnes appariees **par nom** — une migration ajoutant une colonne n'invalide
pas les snapshots anterieurs.

### Modes de rechargement

- **Fusion** (`load_maintenance_object_merge()`, nouvelle procedure) : une ligne est
  **protegee** des que `source='MANUAL'` OU `updated_by IS NOT NULL`. Elle n'est ni
  mise a jour, ni deplacee, ni supprimee. Les autres lignes SAP sont rafraichies et
  les nouveautes ajoutees. Les `id` etant conserves, les rattachements manuels
  restent valides et les lignes MANUAL ne sont plus emportees par le
  `ON DELETE CASCADE` (ce que le mode FULL ne garantit pas).
  Les objets disparus de SAP ne sont supprimes que s'ils n'ont **aucun enfant** ;
  sinon ils sont marques `attributes->>'sap_missing' = 'true'` et comptes en rejets.
- **Reinitialisation** : `load_maintenance_object()` inchangee (comportement destructif d'origine).

Dans les deux cas un snapshot `AUTO_PRE_RELOAD` est pris **avant** toute modification.

### Chaine complete

`snapshot auto` → `extraction SAP` (optionnelle, tables de `MAINTENANCE_SAP_TABLES`)
→ `reconstruction` (merge ou reset) → `alimenter_equipment_functional()` +
`load_equipment_object_spare('FULL')`.

⚠️ **Limite a connaitre** : le mode Fusion ne protege que `maintenance_object`.
Une **re-extraction** ecrase les tables `raw_data`, donc les editions faites depuis
les ecrans Equipements et Articles. Le snapshot automatique est le filet de securite ;
l'avertissement est affiche dans le dialogue de rechargement.

### API (`/api/v1/maintenance`, toutes les routes sous `@jwt_required()`)

```
POST   /snapshots                 { name, description }
GET    /snapshots
DELETE /snapshots/<id>
POST   /snapshots/<id>/restore    -> 202 { job }
POST   /reload                    { mode: merge|reset, with_extraction: bool } -> 202 { job }
GET    /jobs | /jobs/<id> | /jobs/active
```

Pendant un job `RESTORE`/`RELOAD`, les blueprints `ih02_hierarchy_mo`,
`maintenance_hierarchy` et `maintenance_articles` renvoient **409** sur toute
methode mutante (hook `before_request` → `api.maintenance_snapshots.active_job_conflict`).

### Fichiers

```
migrations/027_create_maintenance_snapshots.sql
sql/maintenance/proc_load_maintenance_object_merge.sql
backend/services/maintenance_snapshot_service.py
backend/services/maintenance_reload_service.py
backend/api/maintenance_snapshots.py
backend/tests/test_maintenance_snapshot_service.py
backend/tests/test_maintenance_reload_api.py
frontend/src/services/maintenanceSnapshotService.ts
frontend/src/components/maintenance/{SnapshotManagerDialog,ReloadSapDialog,MaintenanceJobBanner}.tsx
```

### Points d'attention exploitation

- L'etat des jobs est **persiste en base** (pas un dict memoire) : indispensable avec
  `gunicorn -w 4`, sinon le polling tombe 3 fois sur 4 sur le mauvais worker.
- Un verrou consultatif PostgreSQL (cle `778812`) protege l'execution ; un job reste
  `RUNNING` sans verrou plus de 2 minutes est considere orphelin (redemarrage du
  conteneur) et bascule en `ERROR`, sans quoi l'index unique bloquerait toute operation.
- `sql/maintenance/compile.sh` lance `create_maintenance_object.sql` qui fait un
  `DROP TABLE ... CASCADE` : **ne pas** lancer le script entier sur une base en service,
  compiler uniquement `proc_load_maintenance_object_merge.sql`.
- **Volumetrie** : un snapshot copie ~1,7 M lignes pour **~370 Mo** (mesure du 2026-07-27) —
  `raw_data.iloa` pese a lui seul 196 Mo / 1,1 M lignes, `clean_data.maintenance_object`
  74 Mo, `raw_data.makt` 52 Mo. La purge est automatique en fin de job reussi : seuls les
  **3 derniers snapshots automatiques** sont conserves (`MAINTENANCE_AUTO_SNAPSHOT_KEEP`) ;
  les snapshots nommes par l'utilisateur ne sont jamais purges. Surveiller l'espace disque,
  le serveur heberge aussi Ollama.

## 9. Benefices attendus

- `raw_data` strictement lecture seule (conformite convention projet).
- 14 tables sources → 1 table applicative + 2 referentiels lecture seule (crhd/crtx).
- Suppression de la vue materialisee et de ses REFRESH bloquants apres chaque edition BOM.
- Requetes d'arbre triviales (index `parent_id`) et recherche indexee trgm.
- Bulk-update reellement fonctionnel sur tous les champs annonces par l'UI.
- Audit (`created_by`/`updated_by`/`updated_at`) et soft delete recuperable.
- Champs jusqu'ici non persistables (centre de couts FL, quantite, unite...) deviennent stockables.
