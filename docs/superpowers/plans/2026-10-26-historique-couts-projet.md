# Finance > Historique des coûts par projet — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter dans le menu Finance une carte « Historique des coûts par projet » ouvrant un écran tableau (liste filtrée, totaux, export Excel, Recalculer / Synchroniser SAP) calqué sur Commandes d'achat, alimenté par la requête 3 de `docs/zcoa_credits_investissement_raw_data.sql`.

**Architecture :** une table snapshot `clean_data.historique_cout_projet` (une ligne par projet / élément d'OTP / année / période, TRUNCATE + INSERT par `clean_data.alimenter_historique_cout_projet()`), 4 routes dans `backend/api/finance.py` réutilisant `_start_sync`, `_feuille_tableau`, `_envoyer`, `_read_status`, une page React `FinanceHistoriqueCouts.tsx` copiée de `FinanceCommandesAchat.tsx`. Les deux grains (par projet, par OTP) sont servis par la même table : l'API agrège avec `GROUP BY` et calcule le cumul du réel par fenêtre.

**Tech Stack :** PostgreSQL (plpgsql), Flask + SQLAlchemy `text()`, openpyxl, React 18 + MUI + axios.

---

## Analyse de la doc (état vérifié en base le 26/10/2026)

| Source | État | Usage |
|---|---|---|
| `raw_data.rpsco` | 78 187 lignes, ledger `0003` seul alimenté | valeurs par type (WRTTP) et période (WLP00..16) |
| `raw_data.prps` | 2 772 (1 650 STJN) | élément d'OTP -> projet (`psphi`), `objnr` |
| `raw_data.proj` | 1 920 | définition de projet (`pspid`, `post1`, `verna`) |
| COEP, COBK, COOI, BPGE, COSP, BSEG | absentes ou vides | ordres d'investissement **non couverts** (pas de budget/réel pour IM01) |

Résultat de la requête 3 sur la base : 951 projets, années 2013 → 2029, 10 095 lignes au grain projet, **11 169 au grain OTP**, exécution 0,3 s. Aucune période spéciale (13-16) renseignée. Total réel 270,8 M€, budget annuel 246,3 M€.

Sémantique conservée telle quelle (voir en-tête de la doc) :
- `reel` = WRTTP 04 hors `VORGA = 'KOAO'` ; `plan` = 01 ; `budget_annuel` = 41 (période 0 de chaque année, le budget global année 0000 est exclu) ; `engag_cde` = 22 ; `engag_da` = 21 (rangés par période de livraison prévue, pas de coupure à la période d'édition).
- Société STJN seule, toutes classes d'objets (`scope`), tous projets. Les filtres (projet, années) sont **dans l'écran**, pas dans le chargement.
- Montants en EUR (devise société), signe SAP conservé.

Écarts / limites à afficher dans le mode d'emploi de l'écran : pas d'ordres d'investissement, engagements = encours actuel, ledger 0003.

## Décisions ponytail

- **Un seul grain stocké (OTP)**, le grain projet est un `GROUP BY` dans l'API : pas deux tables, pas deux loaders.
- **Pas de module ETL Python ni de ligne `etl_target_tables`** (non demandé) : les boutons Recalculer / Synchroniser SAP de l'écran suffisent. À ajouter plus tard sur le modèle de `sql/commandeAchat/add_etl_commande_achat_module.sql` + `etl_commande_achat.py` si on veut l'enchaîner dans l'écran ETL.
- **Pas d'onglet Mode d'emploi en composant séparé** : un `Alert` de 4 lignes dans la page porte les limites (voir Task 5).
- Cumul du réel calculé **sur tout l'historique** du projet puis filtré par année (sinon le cumul repartirait de zéro à l'année de début du filtre).

## Fichiers

- Create : `sql/historiqueCoutProjet/01_create_clean_data_historique_cout_projet.sql`
- Create : `sql/historiqueCoutProjet/02_alimenter_historique_cout_projet.sql`
- Create : `sql/historiqueCoutProjet/compile.sh`
- Create : `backend/tests/test_historique_cout_projet.py`
- Modify : `backend/api/finance.py` (nouveau bloc avant « Communs », docstring d'en-tête)
- Create : `frontend/src/pages/FinanceHistoriqueCouts.tsx`
- Modify : `frontend/src/pages/Finance.tsx` (carte), `frontend/src/App.tsx` (route + import)
- Modify : `CLAUDE.md` (puce « Points d'attention »)

---

### Task 1 : Table et fonction de chargement SQL

**Files:**
- Create: `sql/historiqueCoutProjet/01_create_clean_data_historique_cout_projet.sql`
- Create: `sql/historiqueCoutProjet/02_alimenter_historique_cout_projet.sql`
- Create: `sql/historiqueCoutProjet/compile.sh`

- [ ] **Step 1 : DDL de la table snapshot**

```sql
-- ============================================================================
-- clean_data.historique_cout_projet : historique des couts par projet SAP
-- (reconstitution de l'etat ZCOA / CJI3 sur raw_data.rpsco, cf.
-- docs/zcoa_credits_investissement_raw_data.sql, requete 3).
-- Une ligne par projet / element d'OTP / annee / periode. Table de SNAPSHOT :
-- TRUNCATE + INSERT par clean_data.alimenter_historique_cout_projet().
-- Societe STJN, ledger RPSCO 0003, version 000, montants en EUR (devise societe).
-- ============================================================================
CREATE TABLE IF NOT EXISTS clean_data.historique_cout_projet (
    projet          varchar(24) NOT NULL,  -- proj.pspid
    projet_libelle  text,                  -- proj.post1
    responsable     text,                  -- proj.verna
    element_otp     varchar(24) NOT NULL,  -- prps.posid
    otp_libelle     text,                  -- prps.post1
    annee           integer     NOT NULL,  -- rpsco.gjahr
    periode         integer     NOT NULL,  -- 0..16 (0 = budget annuel, 13-16 periodes speciales)
    reel            numeric(17,2) NOT NULL DEFAULT 0,  -- WRTTP 04 hors VORGA KOAO
    plan            numeric(17,2) NOT NULL DEFAULT 0,  -- WRTTP 01
    budget_annuel   numeric(17,2) NOT NULL DEFAULT 0,  -- WRTTP 41 (annee <> 0000)
    engag_cde       numeric(17,2) NOT NULL DEFAULT 0,  -- WRTTP 22 commandes non receptionnees
    engag_da        numeric(17,2) NOT NULL DEFAULT 0,  -- WRTTP 21 demandes d'achat
    charge_at       timestamp   NOT NULL DEFAULT current_timestamp,
    PRIMARY KEY (projet, element_otp, annee, periode)
);
```

- [ ] **Step 2 : fonction de chargement (requête 3 au grain OTP)**

```sql
-- ============================================================================
-- clean_data.alimenter_historique_cout_projet(p_bukrs)
-- Recharge clean_data.historique_cout_projet depuis raw_data.rpsco / prps / proj.
-- Retourne le nombre de lignes chargees. Si rpsco est vide (extraction SAP en
-- cours), la table est laissee telle quelle et un WARNING est emis.
-- ============================================================================
CREATE OR REPLACE FUNCTION clean_data.alimenter_historique_cout_projet(p_bukrs text DEFAULT 'STJN')
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_n integer;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM raw_data.rpsco LIMIT 1) THEN
        RAISE WARNING 'raw_data.rpsco est vide : historique des couts non recharge';
        RETURN 0;
    END IF;

    TRUNCATE clean_data.historique_cout_projet;

    INSERT INTO clean_data.historique_cout_projet
        (projet, projet_libelle, responsable, element_otp, otp_libelle, annee, periode,
         reel, plan, budget_annuel, engag_cde, engag_da)
    WITH otp AS (
        SELECT p.objnr, p.posid, p.post1 AS otp_libelle,
               j.pspid, j.post1 AS projet_libelle, j.verna
        FROM raw_data.prps p
        JOIN raw_data.proj j ON j.mandt = p.mandt AND j.pspnr = p.psphi
        WHERE p.pbukr = p_bukrs
    ),
    val AS (
        SELECT o.pspid, o.projet_libelle, o.verna, o.posid, o.otp_libelle,
               r.gjahr::int AS annee,
               v.per        AS periode,
               r.wrttp,
               r.vorga,
               COALESCE(NULLIF(REPLACE(TRIM(v.val), ',', '.'), '')::numeric, 0) AS mt
        FROM raw_data.rpsco r
        JOIN otp o ON o.objnr = r.objnr
        CROSS JOIN LATERAL (VALUES
            (0,  r.wlp00), (1,  r.wlp01), (2,  r.wlp02), (3,  r.wlp03), (4,  r.wlp04),
            (5,  r.wlp05), (6,  r.wlp06), (7,  r.wlp07), (8,  r.wlp08), (9,  r.wlp09),
            (10, r.wlp10), (11, r.wlp11), (12, r.wlp12), (13, r.wlp13), (14, r.wlp14),
            (15, r.wlp15), (16, r.wlp16)
        ) AS v(per, val)
        WHERE r.lednr = '0003'
          AND r.versn = '000'
          AND r.wrttp IN ('01', '04', '21', '22', '41')
          AND r.gjahr <> '0000'          -- budget global sans periode : exclu
    )
    SELECT v.pspid, v.projet_libelle, v.verna, v.posid, v.otp_libelle, v.annee, v.periode,
           COALESCE(SUM(v.mt) FILTER (WHERE v.wrttp = '04' AND v.vorga <> 'KOAO'), 0),
           COALESCE(SUM(v.mt) FILTER (WHERE v.wrttp = '01'), 0),
           COALESCE(SUM(v.mt) FILTER (WHERE v.wrttp = '41'), 0),
           COALESCE(SUM(v.mt) FILTER (WHERE v.wrttp = '22'), 0),
           COALESCE(SUM(v.mt) FILTER (WHERE v.wrttp = '21'), 0)
    FROM val v
    GROUP BY v.pspid, v.projet_libelle, v.verna, v.posid, v.otp_libelle, v.annee, v.periode
    HAVING bool_or(v.mt <> 0);

    GET DIAGNOSTICS v_n = ROW_COUNT;
    RAISE NOTICE 'historique_cout_projet : % lignes chargees (societe %)', v_n, p_bukrs;
    RETURN v_n;
END;
$$;
```

- [ ] **Step 3 : compile.sh** — copier `sql/commandeAchat/compile.sh` et remplacer uniquement le titre et la liste `files=(...)` :

```bash
cp sql/commandeAchat/compile.sh sql/historiqueCoutProjet/compile.sh
```
Dans la copie :
```bash
echo "  Compilation des procédures HISTORIQUE DES COUTS PAR PROJET"
...
files=(
    "01_create_clean_data_historique_cout_projet.sql"
    "02_alimenter_historique_cout_projet.sql"
)
```
(supprimer le commentaire sur `get_vendor_no_ifs` et les lignes 03/04). `chmod +x`.

- [ ] **Step 4 : vérifier à blanc sur la base** (via l'outil postgres ou `psql`, sans valider) :

```sql
BEGIN;
\i sql/historiqueCoutProjet/01_create_clean_data_historique_cout_projet.sql
\i sql/historiqueCoutProjet/02_alimenter_historique_cout_projet.sql
SELECT clean_data.alimenter_historique_cout_projet();   -- attendu : 11169
SELECT count(DISTINCT projet), min(annee), max(annee), round(sum(reel)) FROM clean_data.historique_cout_projet;
-- attendu : 951 | 2013 | 2029 | 270760258
ROLLBACK;
```

- [ ] **Step 5 : Commit**

```bash
git add sql/historiqueCoutProjet
git commit -m "Historique des couts par projet : table clean_data.historique_cout_projet + fonction de chargement (RPSCO ledger 0003)"
```

---

### Task 2 : Test sur la vraie base (transaction annulée)

**Files:**
- Create: `backend/tests/test_historique_cout_projet.py`

- [ ] **Step 1 : écrire le test**

```python
"""
clean_data.alimenter_historique_cout_projet : reconstitution de l'historique des
couts par projet (ZCOA requete 3) depuis raw_data.rpsco. Vraie base, transaction
jamais validee ; la fonction du depot est recompilee dans la transaction.
"""
import os
import sys

import psycopg2
import psycopg2.extras
import pytest

BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SQL_DIR = os.path.join(os.path.dirname(BACKEND), 'sql', 'historiqueCoutProjet')
if BACKEND not in sys.path:
    sys.path.insert(0, BACKEND)

HCP = 'clean_data.historique_cout_projet'


@pytest.fixture
def cur():
    try:
        from config.database import get_db_params
        conn = psycopg2.connect(**get_db_params())
    except Exception as exc:  # pragma: no cover
        pytest.skip(f'base injoignable : {exc}')
    try:
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        for name in ('01_create_clean_data_historique_cout_projet.sql',
                     '02_alimenter_historique_cout_projet.sql'):
            with open(os.path.join(SQL_DIR, name), encoding='utf-8') as f:
                cur.execute(f.read())
        cur.execute('SELECT clean_data.alimenter_historique_cout_projet() AS n')
        assert cur.fetchone()['n'] > 0
        yield cur
    finally:
        conn.rollback()
        conn.close()


def test_aucune_ligne_vide(cur):
    cur.execute(f'SELECT count(*) AS n FROM {HCP} '
                'WHERE reel = 0 AND plan = 0 AND budget_annuel = 0 AND engag_cde = 0 AND engag_da = 0')
    assert cur.fetchone()['n'] == 0


def test_reel_projet_egal_rpsco(cur):
    """Le reel d'un projet = somme RPSCO WRTTP 04 hors KOAO de ses OTP, toutes periodes."""
    cur.execute(f'SELECT projet FROM {HCP} GROUP BY projet ORDER BY sum(reel) DESC LIMIT 1')
    projet = cur.fetchone()['projet']
    cur.execute(f'SELECT round(sum(reel), 2) AS t FROM {HCP} WHERE projet = %s', (projet,))
    attendu = cur.fetchone()['t']
    cur.execute("""
        SELECT round(sum(COALESCE(NULLIF(REPLACE(TRIM(v.val), ',', '.'), '')::numeric, 0)), 2) AS t
        FROM raw_data.rpsco r
        JOIN raw_data.prps p ON p.objnr = r.objnr
        JOIN raw_data.proj j ON j.mandt = p.mandt AND j.pspnr = p.psphi
        CROSS JOIN LATERAL (VALUES (r.wlp00),(r.wlp01),(r.wlp02),(r.wlp03),(r.wlp04),(r.wlp05),
            (r.wlp06),(r.wlp07),(r.wlp08),(r.wlp09),(r.wlp10),(r.wlp11),(r.wlp12),(r.wlp13),
            (r.wlp14),(r.wlp15),(r.wlp16)) AS v(val)
        WHERE j.pspid = %s AND p.pbukr = 'STJN'
          AND r.lednr = '0003' AND r.versn = '000' AND r.wrttp = '04'
          AND r.vorga <> 'KOAO' AND r.gjahr <> '0000'
    """, (projet,))
    assert cur.fetchone()['t'] == attendu


def test_rpsco_vide_ne_purge_pas(cur):
    """Extraction SAP en cours (rpsco vide) : la table garde son contenu."""
    cur.execute(f'SELECT count(*) AS n FROM {HCP}')
    avant = cur.fetchone()['n']
    cur.execute('CREATE TEMP TABLE rpsco_sauve AS SELECT * FROM raw_data.rpsco')
    cur.execute('DELETE FROM raw_data.rpsco')
    cur.execute('SELECT clean_data.alimenter_historique_cout_projet() AS n')
    assert cur.fetchone()['n'] == 0
    cur.execute(f'SELECT count(*) AS n FROM {HCP}')
    assert cur.fetchone()['n'] == avant
```

- [ ] **Step 2 : lancer sur le serveur** (jamais en local, cf. mémoire `workflow_execution_distante`) :

```bash
ssh migration "cd /root/migration-Factory && git pull && docker cp backend/tests/test_historique_cout_projet.py migration-app-backend:/app/tests/ && docker cp sql/historiqueCoutProjet migration-app-backend:/sql/historiqueCoutProjet && docker exec -e PYTHONPATH=/app migration-app-backend python -m pytest /app/tests/test_historique_cout_projet.py -v"
```
Attendu : `3 passed`. Si le dépôt n'est pas monté dans le conteneur, adapter `SQL_DIR` par une variable d'environnement `HCP_SQL_DIR` (même piège que `tests/ibau_schema_helper.py`).

- [ ] **Step 3 : Commit**

```bash
git add backend/tests/test_historique_cout_projet.py
git commit -m "Historique des couts par projet : test de la fonction de chargement sur la vraie base"
```

---

### Task 3 : Routes API dans `backend/api/finance.py`

**Files:**
- Modify: `backend/api/finance.py` — insérer le bloc juste avant le commentaire `# Communs : export Excel, synchronisation SAP` (ligne ~772) ; compléter la docstring d'en-tête.

- [ ] **Step 1 : docstring d'en-tête** — ajouter après le bloc « Commandes d'achat : » :

```
Historique des couts par projet (clean_data.historique_cout_projet, RPSCO) :
  GET  /api/v1/finance/historique-couts  ?vue=projet (defaut, une ligne par projet /
                                         annee / periode) | otp (par element d'OTP) ;
                                         filtres search, annee_debut, annee_fin ;
                                         reel_cumule = cumul depuis le debut de l'historique
  GET  /api/v1/finance/historique-couts/export.xlsx
  GET|POST /api/v1/finance/historique-couts/sync   (RPSCO, PRPS, PROJ)
```

- [ ] **Step 2 : bloc de routes**

```python
# ---------------------------------------------------------------------------
# Historique des couts par projet (clean_data.historique_cout_projet,
# module sql/historiqueCoutProjet/, reconstitution ZCOA requete 3 sur RPSCO)
# ---------------------------------------------------------------------------

# Tables lues par clean_data.alimenter_historique_cout_projet.
HCP_SAP_TABLES = ['RPSCO', 'PRPS', 'PROJ']

# Colonnes de regroupement par vue ; les mesures sont sommees (SUM).
HCP_CLES = {
    'projet': ['projet', 'projet_libelle', 'responsable'],
    'otp': ['projet', 'projet_libelle', 'responsable', 'element_otp', 'otp_libelle'],
}
HCP_MESURES = ['reel', 'reel_cumule', 'plan', 'budget_annuel', 'engag_cde', 'engag_da']
HCP_LIBELLE = {
    'projet': 'Projet (PROJ-PSPID)',
    'projet_libelle': 'Désignation projet',
    'responsable': 'Responsable',
    'element_otp': "Élément d'OTP (PRPS-POSID)",
    'otp_libelle': "Désignation OTP",
    'annee': 'Année',
    'periode': 'Période',
    'reel': 'Réel',
    'reel_cumule': 'Réel cumulé',
    'plan': 'Plan',
    'budget_annuel': 'Budget annuel',
    'engag_cde': 'Commandes non réceptionnées',
    'engag_da': "Demandes d'achat",
}


def _hcp_vue():
    return 'otp' if request.args.get('vue') == 'otp' else 'projet'


def _hcp_colonnes(vue):
    return HCP_CLES[vue] + ['annee', 'periode'] + HCP_MESURES


def _hcp_requete(vue):
    """(SQL sans LIMIT, params) : lignes agregees au grain de la vue, cumul du reel
    calcule sur TOUT l'historique du projet / de l'OTP puis filtre par annee."""
    search = (request.args.get('search') or '').strip()
    cles = HCP_CLES[vue]
    where, params = [], {}
    if search:
        where.append('(projet ILIKE :s OR projet_libelle ILIKE :s OR responsable ILIKE :s '
                     'OR element_otp ILIKE :s)')
        params['s'] = f'%{search}%'
    interne = ('WHERE ' + ' AND '.join(where)) if where else ''

    externe = []
    for borne, op in (('annee_debut', '>='), ('annee_fin', '<=')):
        v = request.args.get(borne)
        if v and v.isdigit():
            externe.append(f'annee {op} :{borne}')
            params[borne] = int(v)
    clause_annee = ('WHERE ' + ' AND '.join(externe)) if externe else ''

    sql = (
        f'WITH agg AS ('
        f'  SELECT {", ".join(cles)}, annee, periode, '
        f'    SUM(reel) AS reel, '
        f'    SUM(SUM(reel)) OVER (PARTITION BY {", ".join(cles)} ORDER BY annee, periode) AS reel_cumule, '
        f'    SUM(plan) AS plan, SUM(budget_annuel) AS budget_annuel, '
        f'    SUM(engag_cde) AS engag_cde, SUM(engag_da) AS engag_da '
        f'  FROM clean_data.historique_cout_projet {interne} '
        f'  GROUP BY {", ".join(cles)}, annee, periode) '
        f'SELECT {", ".join(_hcp_colonnes(vue))} FROM agg {clause_annee} '
        f'ORDER BY {", ".join(cles)}, annee, periode'
    )
    return sql, params


@finance_blueprint.route('/historique-couts', methods=['GET'])
@jwt_required()
def list_historique_couts():
    page = max(int(request.args.get('page', 1)), 1)
    page_size = min(max(int(request.args.get('page_size', 50)), 1), 500)
    vue = _hcp_vue()
    sql, params = _hcp_requete(vue)

    rows = db.session.execute(
        text(f'{sql} LIMIT :limit OFFSET :offset'),
        {**params, 'limit': page_size, 'offset': (page - 1) * page_size}).mappings().all()
    stats = db.session.execute(text(
        f'SELECT count(*) AS lignes, count(DISTINCT projet) AS projets, '
        f'sum(reel) AS reel, sum(plan) AS plan, sum(budget_annuel) AS budget_annuel, '
        f'sum(engag_cde) AS engag_cde, sum(engag_da) AS engag_da FROM ({sql}) q'),
        params).mappings().one()
    annees = [r[0] for r in db.session.execute(text(
        'SELECT DISTINCT annee FROM clean_data.historique_cout_projet ORDER BY 1'))]

    return jsonify({
        'rows': [{k: _json(v) for k, v in r.items()} for r in rows],
        'total': stats['lignes'],
        'page': page,
        'page_size': page_size,
        'stats': {k: _json(v) for k, v in stats.items()},
        'annees': annees,
        'colonnes': [{'key': c, 'label': HCP_LIBELLE[c],
                      'kind': 'montant' if c in HCP_MESURES else 'text'}
                     for c in _hcp_colonnes(vue)],
        'sync': _read_status('historique_cout_projet'),
    })


@finance_blueprint.route('/historique-couts/export.xlsx', methods=['GET'])
@jwt_required()
def export_historique_couts_excel():
    from openpyxl import Workbook

    vue = _hcp_vue()
    sql, params = _hcp_requete(vue)
    rows = db.session.execute(text(sql), params).all()
    db.session.commit()  # liberer la transaction de lecture avant la generation
    wb = Workbook()
    _feuille_tableau(wb.active, 'Historique des coûts',
                     [(c, HCP_LIBELLE[c]) for c in _hcp_colonnes(vue)], rows, set(HCP_MESURES))
    return _envoyer(wb, f'historique_couts_{vue}')


@finance_blueprint.route('/historique-couts/sync', methods=['GET'])
@jwt_required()
def get_hcp_sync_status():
    return jsonify(_read_status('historique_cout_projet') or {'status': 'never'})


@finance_blueprint.route('/historique-couts/sync', methods=['POST'])
@jwt_required()
def start_hcp_sync():
    def load(conn):
        return conn.execute(text('SELECT clean_data.alimenter_historique_cout_projet()')).scalar()

    return _start_sync('historique_cout_projet', HCP_SAP_TABLES,
                       'clean_data.historique_cout_projet', load,
                       extraire=_sync_source() == 'sap')
```

Points d'attention :
- `_feuille_tableau` met `freeze_panes = 'C2'` et une largeur 34 aux colonnes commençant par `libelle`/`designation` : `projet_libelle` et `otp_libelle` ne matchent pas (préfixe), elles sortiront en 16. Acceptable ; sinon élargir la condition `startswith` à `'_libelle' in col`.
- `_sync_source()` lit `request.json.source` ('sap' | 'mf'), déjà utilisé par les deux autres écrans.

- [ ] **Step 3 : vérification syntaxe** : `python -m py_compile backend/api/finance.py` sur le serveur (ou `docker exec migration-app-backend python -m py_compile /app/api/finance.py` après copie).

- [ ] **Step 4 : Commit**

```bash
git add backend/api/finance.py
git commit -m "Finance : API historique des couts par projet (liste par projet / OTP, export Excel, synchronisation RPSCO)"
```

---

### Task 4 : Page React `FinanceHistoriqueCouts.tsx`

**Files:**
- Create: `frontend/src/pages/FinanceHistoriqueCouts.tsx`

- [ ] **Step 1 : écrire la page** (même squelette que `FinanceCommandesAchat.tsx`, sans onglets IFS ni ZIP)

```tsx
import {
    Cached as RecalculIcon,
    FileDownload as ExcelIcon,
    Search as SearchIcon,
    Sync as SyncIcon,
    Timeline as HistoriqueIcon,
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Button,
    Chip,
    FormControl,
    InputAdornment,
    InputLabel,
    LinearProgress,
    MenuItem,
    Paper,
    Select,
    Tab,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TablePagination,
    TableRow,
    Tabs,
    TextField,
    Tooltip,
    Typography,
} from '@mui/material';
import React, { useCallback, useEffect, useState } from 'react';
import api from '../services/api';

// Même logique que FinanceCommandesAchat : liste paginée, export Excel, Recalculer / Synchroniser SAP.
// Source : clean_data.historique_cout_projet (RPSCO ledger 0003, cf. docs/zcoa_credits_investissement_raw_data.sql).

type Row = Record<string, string | number | null>;
type Vue = 'projet' | 'otp';

interface SyncStatus {
  status: 'never' | 'running' | 'completed' | 'failed';
  step?: string;
  progress?: number;
  error?: string | null;
  rows?: number | null;
  started_at?: string;
  finished_at?: string | null;
}

interface Colonne { key: string; label: string; kind: 'montant' | 'text' }

interface Stats {
  lignes: number;
  projets: number;
  reel: number | null;
  plan: number | null;
  budget_annuel: number | null;
  engag_cde: number | null;
  engag_da: number | null;
}

interface ListResponse {
  rows: Row[];
  total: number;
  stats: Stats;
  annees: number[];
  colonnes: Colonne[];
  sync: SyncStatus | null;
}

const ONGLETS: { value: Vue; label: string; description: string }[] = [
  { value: 'projet', label: 'Par projet',
    description: 'Une ligne par projet SAP, année et période (tous les éléments d\'OTP du projet cumulés). Réel cumulé = depuis le début de l\'historique.' },
  { value: 'otp', label: "Par élément d'OTP",
    description: "Une ligne par élément d'OTP, année et période." },
];

const euros = (v: number | null | undefined) =>
  v == null ? '—' : v.toLocaleString('fr-FR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

const formatCell = (v: string | number | null, kind: Colonne['kind']) => {
  if (v == null || v === '') return '';
  return kind === 'montant' ? euros(Number(v)) : String(v);
};

const formatDateTime = (iso?: string | null) => (iso ? new Date(iso).toLocaleString('fr-FR') : '');

const FinanceHistoriqueCouts: React.FC = () => {
  const [vue, setVue] = useState<Vue>('projet');
  const [data, setData] = useState<ListResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(50);
  const [search, setSearch] = useState('');
  const [searchInput, setSearchInput] = useState('');
  const [anneeDebut, setAnneeDebut] = useState('');
  const [anneeFin, setAnneeFin] = useState('');
  const [sync, setSync] = useState<SyncStatus | null>(null);
  const [exporting, setExporting] = useState(false);

  const filtres = { vue, search, annee_debut: anneeDebut, annee_fin: anneeFin };

  const load = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await api.get<ListResponse>('/finance/historique-couts', {
        params: { ...filtres, page: page + 1, page_size: pageSize },
      });
      setData(res.data);
      setSync(res.data.sync);
    } catch (err) {
      console.error('Erreur chargement historique des coûts:', err);
      setError("Erreur lors du chargement de l'historique des coûts");
    } finally {
      setLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [vue, page, pageSize, search, anneeDebut, anneeFin]);

  useEffect(() => { load(); }, [load]);

  // Suivi de la synchronisation en cours (rechargement de la liste à la fin)
  useEffect(() => {
    if (sync?.status !== 'running') return undefined;
    const timer = setInterval(async () => {
      try {
        const res = await api.get<SyncStatus>('/finance/historique-couts/sync');
        setSync(res.data);
        if (res.data.status !== 'running') load();
      } catch (err) {
        console.error('Erreur statut synchronisation:', err);
      }
    }, 5000);
    return () => clearInterval(timer);
  }, [sync?.status, load]);

  // 'sap' : extraction RPSCO/PRPS/PROJ puis rechargement ; 'mf' : rechargement seul depuis raw_data
  const handleSync = async (source: 'sap' | 'mf') => {
    try {
      setError(null);
      const res = await api.post<SyncStatus>('/finance/historique-couts/sync', { source });
      setSync(res.data);
    } catch (err: any) {
      if (err?.response?.status === 409) setSync(err.response.data);
      else setError('Impossible de lancer la synchronisation');
    }
  };

  const handleExport = async () => {
    try {
      setExporting(true);
      setError(null);
      const res = await api.get('/finance/historique-couts/export.xlsx', { params: filtres, responseType: 'blob' });
      const match = /filename="?([^";]+)"?/.exec(res.headers['content-disposition'] ?? '');
      const url = window.URL.createObjectURL(res.data);
      const link = document.createElement('a');
      link.href = url;
      link.download = match?.[1] ?? 'historique_couts.xlsx';
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(url);
    } catch (err) {
      console.error('Erreur export Excel historique des coûts:', err);
      setError("Erreur lors de l'export Excel");
    } finally {
      setExporting(false);
    }
  };

  const running = sync?.status === 'running';
  const stats = data?.stats;
  const colonnes = data?.colonnes ?? [];
  const annees = data?.annees ?? [];

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 2, gap: 2, flexWrap: 'wrap' }}>
        <HistoriqueIcon sx={{ fontSize: 32, color: '#3949ab' }} />
        <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
          Historique des coûts par projet
        </Typography>
        <Box sx={{ ml: 'auto', display: 'flex', gap: 1 }}>
          <Tooltip title="Classeur Excel des lignes filtrées (toutes les pages) de l'onglet affiché">
            <span>
              <Button variant="outlined" color="success" startIcon={<ExcelIcon />} onClick={handleExport} disabled={exporting || !data?.total}>
                {exporting ? 'Export…' : 'Exporter Excel'}
              </Button>
            </span>
          </Tooltip>
          <Tooltip title="Recharge l'historique depuis les tables SAP déjà extraites (RPSCO, PRPS, PROJ), sans appeler SAP">
            <span>
              <Button variant="outlined" startIcon={<RecalculIcon />} onClick={() => handleSync('mf')} disabled={running}>
                Recalculer
              </Button>
            </span>
          </Tooltip>
          <Tooltip title="Ré-extrait de SAP RPSCO, PRPS, PROJ puis recharge la table">
            <span>
              <Button variant="contained" startIcon={<SyncIcon />} onClick={() => handleSync('sap')} disabled={running}>
                {running ? 'Synchronisation…' : 'Synchroniser SAP'}
              </Button>
            </span>
          </Tooltip>
        </Box>
      </Box>

      <Tabs value={vue} onChange={(_, v: Vue) => { setVue(v); setPage(0); }} sx={{ mb: 2 }}>
        {ONGLETS.map((o) => <Tab key={o.value} value={o.value} label={o.label} />)}
      </Tabs>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        {ONGLETS.find((o) => o.value === vue)?.description}
      </Typography>

      <Alert severity="info" sx={{ mb: 2 }}>
        Société STJN, ledger RPSCO 0003, montants en EUR. Réel = WRTTP 04 hors répartition (KOAO), Plan = 01,
        Budget annuel = 41 (période 0 ; le budget global sans année est exclu), Commandes non réceptionnées = 22,
        Demandes d'achat = 21 (engagements rangés par période de livraison prévue : encours actuel).
        Les ordres d'investissement (IM01) ne sont pas couverts : COEP / COOI / BPGE ne sont pas extraites.
      </Alert>

      {stats && (
        <Box sx={{ display: 'flex', gap: 1, mb: 2, flexWrap: 'wrap' }}>
          <Chip label={`${stats.projets.toLocaleString('fr-FR')} projets`} color="primary" />
          <Chip label={`${stats.lignes.toLocaleString('fr-FR')} lignes`} />
          <Chip label={`Réel : ${euros(stats.reel)} €`} color="success" />
          <Chip label={`Budget annuel : ${euros(stats.budget_annuel)} €`} />
          <Chip label={`Plan : ${euros(stats.plan)} €`} />
          <Chip label={`Cdes non réceptionnées : ${euros(stats.engag_cde)} €`} />
          <Chip label={`DA : ${euros(stats.engag_da)} €`} />
        </Box>
      )}

      {running && (
        <Alert severity="info" sx={{ mb: 2 }}>
          {sync?.step} — démarrée le {formatDateTime(sync?.started_at)}
          <LinearProgress variant="determinate" value={sync?.progress ?? 0} sx={{ mt: 1 }} />
        </Alert>
      )}
      {sync?.status === 'completed' && (
        <Alert severity="success" sx={{ mb: 2 }}>
          Dernière synchronisation le {formatDateTime(sync.finished_at)} : {sync.rows?.toLocaleString('fr-FR')} lignes chargées.
        </Alert>
      )}
      {sync?.status === 'failed' && (
        <Alert severity="error" sx={{ mb: 2 }}>
          Synchronisation en échec le {formatDateTime(sync.finished_at)} : {sync.error}
        </Alert>
      )}
      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

      <Box sx={{ display: 'flex', gap: 2, mb: 2, flexWrap: 'wrap', alignItems: 'center' }}>
        <TextField
          size="small"
          placeholder="Projet, désignation, responsable, élément d'OTP…"
          value={searchInput}
          onChange={(e) => setSearchInput(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') { setPage(0); setSearch(searchInput); } }}
          sx={{ minWidth: 380 }}
          InputProps={{ startAdornment: <InputAdornment position="start"><SearchIcon /></InputAdornment> }}
        />
        <FormControl size="small" sx={{ minWidth: 130 }}>
          <InputLabel>Année de</InputLabel>
          <Select label="Année de" value={anneeDebut} onChange={(e) => { setPage(0); setAnneeDebut(e.target.value); }}>
            <MenuItem value="">Toutes</MenuItem>
            {annees.map((a) => <MenuItem key={a} value={String(a)}>{a}</MenuItem>)}
          </Select>
        </FormControl>
        <FormControl size="small" sx={{ minWidth: 130 }}>
          <InputLabel>Année à</InputLabel>
          <Select label="Année à" value={anneeFin} onChange={(e) => { setPage(0); setAnneeFin(e.target.value); }}>
            <MenuItem value="">Toutes</MenuItem>
            {annees.map((a) => <MenuItem key={a} value={String(a)}>{a}</MenuItem>)}
          </Select>
        </FormControl>
      </Box>

      <Paper>
        {loading && <LinearProgress />}
        <TableContainer sx={{ maxHeight: 'calc(100vh - 460px)' }}>
          <Table size="small" stickyHeader>
            <TableHead>
              <TableRow>
                {colonnes.map((c) => (
                  <TableCell key={c.key} align={c.kind === 'montant' ? 'right' : 'left'} sx={{ fontWeight: 600, whiteSpace: 'nowrap' }}>
                    {c.label}
                  </TableCell>
                ))}
              </TableRow>
            </TableHead>
            <TableBody>
              {data?.rows.map((r) => (
                <TableRow key={`${r.projet}-${r.element_otp ?? ''}-${r.annee}-${r.periode}`} hover>
                  {colonnes.map((c) => (
                    <TableCell key={c.key} align={c.kind === 'montant' ? 'right' : 'left'} sx={{ whiteSpace: 'nowrap' }}>
                      {formatCell(r[c.key], c.kind)}
                    </TableCell>
                  ))}
                </TableRow>
              ))}
              {data?.rows.length === 0 && (
                <TableRow>
                  <TableCell colSpan={colonnes.length || 1} align="center">
                    Aucune ligne : lancer « Recalculer » (ou « Synchroniser SAP » si RPSCO n'a jamais été extraite)
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </TableContainer>
        <TablePagination
          component="div"
          count={data?.total ?? 0}
          page={page}
          rowsPerPage={pageSize}
          rowsPerPageOptions={[25, 50, 100, 250]}
          onPageChange={(_, p) => setPage(p)}
          onRowsPerPageChange={(e) => { setPageSize(parseInt(e.target.value, 10)); setPage(0); }}
          labelRowsPerPage="Lignes par page"
        />
      </Paper>
    </Box>
  );
};

export default FinanceHistoriqueCouts;
```

- [ ] **Step 2 : vérifier la syntaxe avec esbuild** (tsc ne vérifie rien, cf. mémoire `verification_frontend_esbuild`) :

```bash
npx --prefix "$SCRATCH" esbuild frontend/src/pages/FinanceHistoriqueCouts.tsx --bundle --outfile=/dev/null --loader:.tsx=tsx --external:react --external:@mui/* --external:../services/api ; echo "exit=$?"
```
Attendu : `exit=0` (le succès s'écrit sur stderr : tester le code de sortie, pas la sortie).

- [ ] **Step 3 : Commit**

```bash
git add frontend/src/pages/FinanceHistoriqueCouts.tsx
git commit -m "Finance : ecran Historique des couts par projet (par projet / par OTP, export Excel, synchronisation)"
```

---

### Task 5 : Carte Finance + route

**Files:**
- Modify: `frontend/src/pages/Finance.tsx` (tableau `financeItems`, import d'icône)
- Modify: `frontend/src/App.tsx:29-30` (import) et `:245-246` (route)

- [ ] **Step 1 : carte** — dans `Finance.tsx`, ajouter `Timeline as HistoriqueIcon` à l'import `@mui/icons-material` et, après la carte « Commandes d'achat » :

```tsx
  {
    title: 'Historique des coûts par projet',
    path: '/finance/historique-couts',
    icon: <HistoriqueIcon sx={{ fontSize: 48, color: '#3949ab' }} />,
    description: 'Réel, plan, budget annuel et engagements par projet SAP, année et période (RPSCO), synchronisables depuis SAP',
  },
```

- [ ] **Step 2 : route** — dans `App.tsx` :

```tsx
import FinanceHistoriqueCouts from './pages/FinanceHistoriqueCouts';
...
          <Route path="finance/historique-couts" element={<FinanceHistoriqueCouts />} />
```
(après la ligne `finance/comptes`).

- [ ] **Step 3 : esbuild sur `App.tsx`** (même commande que Task 4 Step 2, cible `frontend/src/App.tsx` avec `--external:./pages/*` retiré pour inclure la nouvelle page) ; attendu `exit=0`.

- [ ] **Step 4 : Commit**

```bash
git add frontend/src/pages/Finance.tsx frontend/src/App.tsx
git commit -m "Finance : carte et route Historique des couts par projet"
```

---

### Task 6 : Déploiement serveur et test de bout en bout

- [ ] **Step 1 : SQL + backend + frontend** (cf. mémoire `installer_sur_serveur`) :

```bash
ssh migration "cd /root/migration-Factory && git pull && cd sql/historiqueCoutProjet && chmod +x compile.sh && ./compile.sh && cd /root/migration-Factory && ./deploybackend.sh && ./deployfrontend.sh"
```
Attendu : `✅ Toutes les procédures ont été compilées avec succès!`, puis santé backend/frontend OK sur `127.0.0.1:5000` / `127.0.0.1:3100`.

- [ ] **Step 2 : premier chargement** (sans extraction, RPSCO est déjà en base) :

```bash
ssh migration "docker exec migration-app-backend python -c \"
from app import app
from models import db
from sqlalchemy import text
with app.app_context():
    with db.engine.begin() as c:
        print(c.execute(text('SELECT clean_data.alimenter_historique_cout_projet()')).scalar())\""
```
Attendu : `11169` (à quelques lignes près si RPSCO a été ré-extraite).

- [ ] **Step 3 : Playwright sur http://10.190.100.58:8081/finance** : la carte « Historique des coûts par projet » est présente ; clic -> tableau non vide, chips « 951 projets » ; passer sur « Par élément d'OTP » -> colonnes Élément d'OTP / Désignation OTP ; filtre « Année de = 2026 » -> `Réel cumulé` de la première ligne > `Réel` (cumul sur tout l'historique) ; « Exporter Excel » télécharge `historique_couts_projet_*.xlsx` ; « Recalculer » -> bandeau « Dernière synchronisation … 11 169 lignes chargées ».

- [ ] **Step 4 : CLAUDE.md** — ajouter dans « Points d'attention », après la puce Commandes d'achat :

```
- **Historique des coûts par projet (`/finance/historique-couts`, `sql/historiqueCoutProjet/`, 2026-10-26)** : `clean_data.historique_cout_projet` = reconstitution de ZCOA (requête 3 de `docs/zcoa_credits_investissement_raw_data.sql`) sur `raw_data.rpsco` (ledger `0003`, version `000`, société STJN) au grain projet / élément d'OTP / année / période (11 169 lignes, 951 projets, 2013-2029) ; `reel` = WRTTP 04 hors `vorga='KOAO'`, `plan` = 01, `budget_annuel` = 41 (année 0000 = budget global exclu), `engag_cde` = 22, `engag_da` = 21 (encours actuel, rangés par période de livraison prévue). La vue « par projet » est un `GROUP BY` dans `api/finance.py` ; `reel_cumule` est calculé sur tout l'historique AVANT le filtre d'années. **Pas d'ordres d'investissement** (COEP/COOI/BPGE absentes). Pas de module ETL (`etl_target_tables`) : rechargement par les boutons Recalculer / Synchroniser SAP (RPSCO, PRPS, PROJ) uniquement ; `rpsco` vide -> WARNING sans purge. Test : `backend/tests/test_historique_cout_projet.py`.
```

- [ ] **Step 5 : Commit final**

```bash
git add CLAUDE.md
git commit -m "CLAUDE.md : historique des couts par projet"
```

---

## Hors périmètre (à décider plus tard)

- **Ordres d'investissement IM01** : impossible tant que COEP / COOI / BPGE ne sont pas extraites (vides). Ajouter ces tables à l'extracteur (`table_config.py`, hors dépôt) puis un second UNION dans le loader.
- **Synthèse par crédit (requête 1 : enveloppe / pris en charge / disponible)** et **détail par commande (requête 2)** : deux autres onglets possibles sur le même écran ; chacun = un CTE de plus et une entrée dans `HCP_CLES`-like. Non demandé.
- **Module ETL + export catégorie** (`etl_target_tables`, `export_service.export_category_data`) : utile seulement si le chargement doit s'enchaîner avec les autres modules dans l'écran ETL.
