# Import PE Tools par fichier + organisation de maintenance — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permettre de déposer les CSV `PeTool - 7.<CODE>.csv` depuis l'écran `/maintenance/pe-tools`, tracer le fichier d'origine de chaque ligne et en déduire l'organisation de maintenance IFS, reprise ensuite par l'ETL PM Actions (`pm_action.org_code`).

**Architecture:** Migration SQL (colonnes `nom_fichier` / `organisation_maintenance` / `imported_at` sur `raw_data.pe_tools`, table de paramétrage `public.pe_tools_organisation`, fonctions `pe_tools_code_fichier` / `pe_tools_org_code`). Service Python pur de parsing CSV (cp850, `;`, en-têtes métier → colonnes SQL) testé sans base. Route Flask `POST /pe-tools/import` en mode « remplacer par fichier », une transaction par fichier. Écran : bouton Importer + dialog de résultat, colonnes calculées en lecture seule. ETL : `org_code = COALESCE(org du fichier, valeur par défaut)`.

**Tech Stack:** PostgreSQL (plpgsql/SQL), Flask + psycopg2 (`get_db_connection`, `RealDictCursor`, `execute_values`), pytest (local, `cd backend && python -m pytest`), React 18 + MUI + axios (`api` de `services/api.ts`), esbuild (scratchpad) pour la vérification de syntaxe frontend.

Spec : `docs/superpowers/specs/2026-09-15-pe-tools-import-organisation-design.md`.

**Contraintes d'environnement (à lire avant de commencer) :**
- Backend : `pytest` tourne en local (`cd backend && python -m pytest tests/...`).
- Frontend : pas de `node_modules` en local ; vérifier la syntaxe avec esbuild installé dans le scratchpad (Task 5, step 6).
- SQL : migrations et `compile.sh` s'exécutent **sur le serveur** (`ssh migration`, clone `/root/migration-Factory`, `PGPASSWORD=trimet2025 psql -h 10.190.100.58 -U postgres -d sap_migration_db`). Avant tout `git pull` serveur, faire `git fetch` et vérifier que le clone serveur n'est pas en avance sur le local.
- Lecture seule de la base depuis le poste : outil MCP `mcp__postgres__query`.
- Commits : terminer les messages par `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`.

---

## Fichiers

| Action | Fichier | Responsabilité |
|---|---|---|
| Créer | `migrations/077_pe_tools_import_organisation.sql` | Colonnes, table de paramétrage, fonctions, seed, assertions |
| Créer | `backend/services/pe_tools_import_service.py` | Parsing CSV pur (sans Flask ni base) |
| Créer | `backend/tests/test_pe_tools_import_service.py` | Tests du parsing |
| Créer | `backend/tests/fixtures/petool_mcar_extrait.csv` | 3 lignes réelles en cp850 |
| Modifier | `backend/api/maintenance_pe_tools.py` | Colonnes calculées + route import |
| Modifier | `frontend/src/pages/MaintenancePeToolsPage.tsx` | Bouton/dialog Importer, colonnes calculées |
| Modifier | `sql/pm_actions/00_pm_helpers.sql` | Définition de `v_pm_source` avec `organisation_maintenance` |
| Modifier | `sql/pm_actions/01_populate_pm_action.sql` | `org_code` depuis le fichier |
| Modifier | `sql/pm_actions/04_populate_pm_action_role.sql` | `org_code` depuis `pm_action` |
| Modifier | `CLAUDE.md` | Puce de synthèse |

---

### Task 1 : Migration 077 (colonnes, table de paramétrage, fonctions)

**Files:**
- Create: `migrations/077_pe_tools_import_organisation.sql`

- [ ] **Step 1 : Écrire la migration**

```sql
-- ============================================================================
-- 077 : Import PE Tools par fichier + organisation de maintenance
--
-- raw_data.pe_tools a ete chargee une fois, hors application, par fusion des
-- CSV "PeTool - 7.<CODE>.csv" : rien ne trace le fichier d'origine, et
-- pm_action.org_code est une constante (FR_MAINT). Le metier veut que
-- l'organisation IFS soit deduite du fichier :
--   MSJ -> FR-MSJ, MNRJ -> SJ-MSST, et SJ-<CODE> pour les autres.
--
-- Cette migration :
--   1. ajoute nom_fichier / organisation_maintenance / imported_at a pe_tools
--      (les 1 760 lignes historiques restent a NULL : jamais touchees par
--      l'import "remplacer par fichier") ;
--   2. cree public.pe_tools_organisation (code fichier -> org IFS), seedee ;
--      un code absent de la table donne une organisation NULL a l'import
--      (pas de repli generique SJ-<CODE> : on veut voir le trou) ;
--   3. cree les 2 fonctions de resolution, seule implementation de la regle,
--      utilisees par l'import et rejouables en SQL si le parametrage change :
--        UPDATE raw_data.pe_tools
--           SET organisation_maintenance = public.pe_tools_org_code(nom_fichier)
--         WHERE nom_fichier IS NOT NULL;
--
-- Idempotente : rejouable sans risque (le seed ne reecrit pas une ligne
-- modifiee a la main).
-- ============================================================================

BEGIN;

-- 1. Colonnes de tracabilite de l'import -------------------------------------
ALTER TABLE raw_data.pe_tools ADD COLUMN IF NOT EXISTS nom_fichier              TEXT;
ALTER TABLE raw_data.pe_tools ADD COLUMN IF NOT EXISTS organisation_maintenance TEXT;
ALTER TABLE raw_data.pe_tools ADD COLUMN IF NOT EXISTS imported_at              TIMESTAMPTZ;

COMMENT ON COLUMN raw_data.pe_tools.nom_fichier IS
    'Nom du CSV depose via l''ecran Maintenance / PE Tools (ex. PeTool - 7.MCAR.csv). NULL = chargement historique hors application';
COMMENT ON COLUMN raw_data.pe_tools.organisation_maintenance IS
    'Organisation de maintenance IFS deduite du nom de fichier via public.pe_tools_org_code() ; NULL si code fichier inconnu de public.pe_tools_organisation';
COMMENT ON COLUMN raw_data.pe_tools.imported_at IS
    'Horodatage de l''import du fichier';

CREATE INDEX IF NOT EXISTS idx_pe_tools_nom_fichier ON raw_data.pe_tools (nom_fichier);
CREATE INDEX IF NOT EXISTS idx_pe_tools_organisation ON raw_data.pe_tools (organisation_maintenance);

-- 2. Table de parametrage code fichier -> organisation -----------------------
CREATE TABLE IF NOT EXISTS public.pe_tools_organisation (
    code_fichier TEXT PRIMARY KEY,
    org_code     TEXT NOT NULL,
    description  TEXT,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by   TEXT
);

COMMENT ON TABLE public.pe_tools_organisation IS
    'Regle fichier PE Tools -> organisation de maintenance IFS : le code est le segment "PeTool - 7.<CODE>.csv". Lue par public.pe_tools_org_code().';

INSERT INTO public.pe_tools_organisation (code_fichier, org_code, description) VALUES ('MSJ',  'FR-MSJ',  'Maintenance Saint-Jean (organisation France)') ON CONFLICT (code_fichier) DO NOTHING;
INSERT INTO public.pe_tools_organisation (code_fichier, org_code, description) VALUES ('MCAR', 'SJ-MCAR', NULL) ON CONFLICT (code_fichier) DO NOTHING;
INSERT INTO public.pe_tools_organisation (code_fichier, org_code, description) VALUES ('MATC', 'SJ-MATC', NULL) ON CONFLICT (code_fichier) DO NOTHING;
INSERT INTO public.pe_tools_organisation (code_fichier, org_code, description) VALUES ('MELY', 'SJ-MELY', NULL) ON CONFLICT (code_fichier) DO NOTHING;
INSERT INTO public.pe_tools_organisation (code_fichier, org_code, description) VALUES ('MFIE', 'SJ-MFIE', NULL) ON CONFLICT (code_fichier) DO NOTHING;
INSERT INTO public.pe_tools_organisation (code_fichier, org_code, description) VALUES ('MSGX', 'SJ-MSGX', NULL) ON CONFLICT (code_fichier) DO NOTHING;
INSERT INTO public.pe_tools_organisation (code_fichier, org_code, description) VALUES ('MSCT', 'SJ-MSCT', NULL) ON CONFLICT (code_fichier) DO NOTHING;
INSERT INTO public.pe_tools_organisation (code_fichier, org_code, description) VALUES ('MNRJ', 'SJ-MSST', 'Fichier MNRJ -> organisation MSST (exception metier)') ON CONFLICT (code_fichier) DO NOTHING;
INSERT INTO public.pe_tools_organisation (code_fichier, org_code, description) VALUES ('MTRO', 'SJ-MTRO', NULL) ON CONFLICT (code_fichier) DO NOTHING;

-- 3. Fonctions de resolution --------------------------------------------------
-- Code = segment entre le dernier '.' precedant l'extension et l'extension,
-- en majuscules : 'PeTool - 7.MCAR.csv' -> 'MCAR', 'petool - 7.msgx.CSV' -> 'MSGX'.
-- Sans extension ou sans point intermediaire -> NULL.
CREATE OR REPLACE FUNCTION public.pe_tools_code_fichier(p_nom_fichier TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT upper(NULLIF(btrim((regexp_match(COALESCE(p_nom_fichier, ''), '\.([^.\\/]+)\.[^.\\/]+$'))[1]), ''));
$$;

CREATE OR REPLACE FUNCTION public.pe_tools_org_code(p_nom_fichier TEXT)
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
    SELECT o.org_code
    FROM public.pe_tools_organisation o
    WHERE o.code_fichier = public.pe_tools_code_fichier(p_nom_fichier)
      AND o.is_active;
$$;

COMMENT ON FUNCTION public.pe_tools_code_fichier(TEXT) IS
    'Extrait le code de service d''un nom de fichier PE Tools ("PeTool - 7.MCAR.csv" -> "MCAR")';
COMMENT ON FUNCTION public.pe_tools_org_code(TEXT) IS
    'Organisation de maintenance IFS d''un nom de fichier PE Tools (via public.pe_tools_organisation) ; NULL si inconnu';

-- 4. Assertions ---------------------------------------------------------------
DO $$
BEGIN
    IF public.pe_tools_code_fichier('PeTool - 7.MCAR.csv') IS DISTINCT FROM 'MCAR' THEN
        RAISE EXCEPTION 'pe_tools_code_fichier : cas nominal KO';
    END IF;
    IF public.pe_tools_code_fichier('petool - 7.msgx.CSV') IS DISTINCT FROM 'MSGX' THEN
        RAISE EXCEPTION 'pe_tools_code_fichier : casse KO';
    END IF;
    IF public.pe_tools_code_fichier('PeTool - 7.MSJ.xlsm') IS DISTINCT FROM 'MSJ' THEN
        RAISE EXCEPTION 'pe_tools_code_fichier : extension xlsm KO';
    END IF;
    IF public.pe_tools_code_fichier('fusion.csv') IS NOT NULL THEN
        RAISE EXCEPTION 'pe_tools_code_fichier : nom sans point intermediaire doit donner NULL';
    END IF;
    IF public.pe_tools_code_fichier('sans_extension') IS NOT NULL THEN
        RAISE EXCEPTION 'pe_tools_code_fichier : nom sans extension doit donner NULL';
    END IF;
    IF public.pe_tools_code_fichier(NULL) IS NOT NULL THEN
        RAISE EXCEPTION 'pe_tools_code_fichier : NULL doit donner NULL';
    END IF;
    IF public.pe_tools_org_code('PeTool - 7.MSJ.csv') IS DISTINCT FROM 'FR-MSJ' THEN
        RAISE EXCEPTION 'pe_tools_org_code : exception MSJ KO';
    END IF;
    IF public.pe_tools_org_code('PeTool - 7.MNRJ.csv') IS DISTINCT FROM 'SJ-MSST' THEN
        RAISE EXCEPTION 'pe_tools_org_code : exception MNRJ KO';
    END IF;
    IF public.pe_tools_org_code('PeTool - 7.MCAR.csv') IS DISTINCT FROM 'SJ-MCAR' THEN
        RAISE EXCEPTION 'pe_tools_org_code : cas nominal KO';
    END IF;
    IF public.pe_tools_org_code('PeTool - 7.MENG.csv') IS NOT NULL THEN
        RAISE EXCEPTION 'pe_tools_org_code : code inconnu doit donner NULL';
    END IF;
    RAISE NOTICE '077 : assertions OK';
END $$;

COMMIT;
```

- [ ] **Step 2 : Vérifier la regex avant de jouer la migration (lecture seule, depuis le poste)**

Via l'outil `mcp__postgres__query` :

```sql
SELECT n, upper(NULLIF(btrim((regexp_match(n, '\.([^.\\/]+)\.[^.\\/]+$'))[1]), '')) AS code
FROM (VALUES ('PeTool - 7.MCAR.csv'), ('petool - 7.msgx.CSV'), ('PeTool - 7.MSJ.xlsm'), ('fusion.csv'), ('sans_extension')) v(n)
```

Attendu : `MCAR`, `MSGX`, `MSJ`, `NULL`, `NULL`.

- [ ] **Step 3 : Commit**

```bash
git add migrations/077_pe_tools_import_organisation.sql
git commit -m "Migration 077 : tracabilite fichier + organisation de maintenance sur pe_tools

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2 : Service de parsing CSV (TDD)

**Files:**
- Create: `backend/tests/fixtures/petool_mcar_extrait.csv`
- Create: `backend/tests/test_pe_tools_import_service.py`
- Create: `backend/services/pe_tools_import_service.py`

- [ ] **Step 1 : Créer la fixture (3 premières lignes du fichier réel, encodage cp850 conservé)**

```bash
mkdir -p backend/tests/fixtures
head -n 3 "/c/document/Export/PETools/PeTool - 7.MCAR.csv" > backend/tests/fixtures/petool_mcar_extrait.csv
head -c 200 backend/tests/fixtures/petool_mcar_extrait.csv | od -c | head -5
```

Attendu : l'en-tête commence par `Localisation / Classement;Gamme en DMS;` et « Désignation » apparaît avec l'octet `0x82` (`D 202 s i g n a t i o n` dans `od -c`), signe que le cp850 est conservé.

- [ ] **Step 2 : Écrire les tests (échec attendu : module absent)**

`backend/tests/test_pe_tools_import_service.py` :

```python
"""Parsing des CSV PE Tools ("PeTool - 7.<CODE>.csv") vers raw_data.pe_tools.

Format constate sur les exports du 2026-07-06 : cp850, separateur ';', en-tetes
metier accentues ("Désignation", "Date rév."), guillemets parfois non fermes,
lignes parfois plus larges que l'en-tete. Le service est pur (sans Flask ni
base) pour etre teste ici tel quel.
"""
import os

import pytest

from services.pe_tools_import_service import (
    PE_TOOLS_COLUMNS,
    cle,
    parse_pe_tools_csv,
)

FIXTURE = os.path.join(os.path.dirname(__file__), 'fixtures', 'petool_mcar_extrait.csv')

ENTETE = ('Localisation / Classement;Gamme en DMS;Poste technique;Niveau SAP;Plan Entretien;'
          'Poste entretien;Groupe de Gamme;Compteur de Gamme;Frequence;Désignation;Type;Criticité;'
          'Parité semaine;Jour;Décal.;Date de validation;Lien Fichier de gamme Source;'
          'Lien Fichier DMS SAP en PDF;DMS_SAP;Charge;Nombre intervenants;Date rév.;'
          'Nb jours depuis la dernière rév.')


def _cp850(texte: str) -> bytes:
    return texte.encode('cp850')


def test_cle_normalise_accents_casse_espaces_et_ponctuation_finale():
    assert cle('Date rév.') == 'date rev'
    assert cle('DATE  REV') == 'date rev'
    assert cle('Désignation ') == 'designation'
    assert cle('Nb jours depuis la dernière rév.') == 'nb jours depuis la derniere rev'


def test_les_23_colonnes_sont_declarees_dans_l_ordre_de_la_table():
    assert len(PE_TOOLS_COLUMNS) == 23
    assert PE_TOOLS_COLUMNS[0] == ('localisation_classement', 'Localisation / Classement')
    assert PE_TOOLS_COLUMNS[-1] == ('nb_jours_depuis_derniere_rev', 'Nb jours depuis la dernière rév.')


def test_fichier_reel_cp850_mappe_les_23_colonnes():
    with open(FIXTURE, 'rb') as f:
        parsed = parse_pe_tools_csv(f.read())
    assert parsed.missing_columns == []
    assert parsed.unknown_columns == []
    assert parsed.repaired_lines == 0
    assert len(parsed.rows) == 2
    premiere = parsed.rows[0]
    assert set(premiere) == {c for c, _ in PE_TOOLS_COLUMNS}
    assert premiere['poste_technique'] == 'T120-L020'
    assert premiere['plan_entretien'] == '34125'
    assert premiere['designation'] == 'PREV 12S 2MEx4 ON CT CAPTEURS MSA2'
    assert premiere['criticite'] is None          # champ vide -> NULL
    assert premiere['nb_jours_depuis_derniere_rev'] == '663'


def test_utf8_bom_accepte_le_propre_export_de_l_ecran():
    contenu = ('﻿' + ENTETE + '\r\n' + 'Voie ferrée;OUI;T410-C;RESEAU;35553;70453;523240;1;4S;'
               'P/4S CONTRÔLE RAILS;CTRL MEC;;;;O;44952;;;;2;2;;\r\n').encode('utf-8')
    parsed = parse_pe_tools_csv(contenu)
    assert parsed.missing_columns == []
    assert parsed.rows[0]['localisation_classement'] == 'Voie ferrée'
    assert parsed.rows[0]['designation'] == 'P/4S CONTRÔLE RAILS'


def test_colonne_manquante_et_colonne_inconnue_sont_signalees():
    entete = ENTETE.replace('Décal.;', '') + ';Commentaire libre'
    contenu = _cp850(entete + '\r\n' + 'A;OUI;T1;N;1;2;3;1;4S;D;T;;;;N;;;;1;1;;;;blabla\r\n')
    parsed = parse_pe_tools_csv(contenu)
    assert parsed.missing_columns == ['Décal.']
    assert parsed.unknown_columns == ['Commentaire libre']
    assert parsed.rows[0]['decalage'] is None
    assert 'Commentaire libre' not in parsed.rows[0]


def test_guillemet_non_ferme_est_repare_et_ligne_trop_large_tronquee():
    contenu = _cp850(
        ENTETE + '\r\n'
        + 'A;OUI;T1;Niveau 12" pouces;1;2;3;1;4S;D;T;;;;N;;;;1;1;;;\r\n'   # 1 seul guillemet -> repare
        + 'B;OUI;T2;N;1;2;3;1;4S;D;T;;;;N;;;;1;1;;;;surplus1;surplus2\r\n'
    )
    parsed = parse_pe_tools_csv(contenu)
    assert parsed.repaired_lines == 1
    assert len(parsed.rows) == 2
    assert parsed.rows[1]['poste_technique'] == 'T2'
    assert parsed.rows[1]['nb_jours_depuis_derniere_rev'] is None


def test_lignes_vides_ignorees():
    contenu = _cp850(ENTETE + '\r\n;;;;;;;;;;;;;;;;;;;;;;\r\n\r\nA;OUI;T1;N;1;2;3;1;4S;D;T;;;;N;;;;1;1;;;\r\n')
    parsed = parse_pe_tools_csv(contenu)
    assert len(parsed.rows) == 1


def test_contenu_vide_refuse():
    with pytest.raises(ValueError, match='vide'):
        parse_pe_tools_csv(b'')


def test_en_tete_hors_format_refusee():
    contenu = _cp850('col1;col2;col3\r\n1;2;3\r\n')
    with pytest.raises(ValueError, match='Poste technique'):
        parse_pe_tools_csv(contenu)
```

- [ ] **Step 3 : Lancer les tests, vérifier l'échec**

```bash
cd backend && python -m pytest tests/test_pe_tools_import_service.py -q
```

Attendu : `ModuleNotFoundError: No module named 'services.pe_tools_import_service'`.

- [ ] **Step 4 : Écrire le service**

`backend/services/pe_tools_import_service.py` :

```python
"""
Parsing des fichiers CSV PE Tools ("PeTool - 7.<CODE>.csv") vers les colonnes
de raw_data.pe_tools.

Module pur : ni Flask ni base, pour etre testable seul. La logique (encodage
cp850, cle de rapprochement sans accents, reparation des guillemets, surplus de
champs ignore) est reprise du script externe fusion_csv.py qui a servi au
chargement initial de la table.
"""
import csv
import io
import re
import unicodedata
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

csv.field_size_limit(50 * 1024 * 1024)

# (colonne SQL, intitule dans les CSV), dans l'ordre de raw_data.pe_tools.
PE_TOOLS_COLUMNS: List[Tuple[str, str]] = [
    ('localisation_classement',      'Localisation / Classement'),
    ('gamme_en_dms',                 'Gamme en DMS'),
    ('poste_technique',              'Poste technique'),
    ('niveau_sap',                   'Niveau SAP'),
    ('plan_entretien',               'Plan Entretien'),
    ('poste_entretien',              'Poste entretien'),
    ('groupe_de_gamme',              'Groupe de Gamme'),
    ('compteur_de_gamme',            'Compteur de Gamme'),
    ('frequence',                    'Frequence'),
    ('designation',                  'Désignation'),
    ('type',                         'Type'),
    ('criticite',                    'Criticité'),
    ('parite_semaine',               'Parité semaine'),
    ('jour',                         'Jour'),
    ('decalage',                     'Décal.'),
    ('date_validation',              'Date de validation'),
    ('lien_fichier_gamme_source',    'Lien Fichier de gamme Source'),
    ('lien_fichier_dms_sap_pdf',     'Lien Fichier DMS SAP en PDF'),
    ('dms_sap',                      'DMS_SAP'),
    ('charge',                       'Charge'),
    ('nb_intervenants',              'Nombre intervenants'),
    ('date_rev',                     'Date rév.'),
    ('nb_jours_depuis_derniere_rev', 'Nb jours depuis la dernière rév.'),
]

# Sans ces deux colonnes le fichier n'est pas un export PE Tools.
COLONNES_OBLIGATOIRES = ('Poste technique', 'Plan Entretien')

SEPARATEUR = ';'
BOM_UTF8 = b'\xef\xbb\xbf'


@dataclass
class ParsedFile:
    rows: List[Dict[str, Optional[str]]] = field(default_factory=list)
    missing_columns: List[str] = field(default_factory=list)
    unknown_columns: List[str] = field(default_factory=list)
    repaired_lines: int = 0


def cle(nom: str) -> str:
    """Cle de rapprochement d'un intitule : sans accents, sans casse, espaces
    normalises, ponctuation finale retiree ('Date rév.' == 'DATE  REV')."""
    nom = unicodedata.normalize('NFKD', nom or '')
    nom = ''.join(c for c in nom if not unicodedata.combining(c))
    nom = re.sub(r'\s+', ' ', nom.replace('\n', ' ').replace('\r', ' ')).strip()
    return nom.lower().rstrip(' .:')


def _decoder(content: bytes) -> str:
    # L'export CSV de l'ecran est en UTF-8 BOM : on accepte son propre export
    # en retour. Sinon, les exports Excel PE Tools sont en cp850.
    if content.startswith(BOM_UTF8):
        return content.decode('utf-8-sig', errors='replace')
    return content.decode('cp850', errors='replace')


def _lire_lignes(texte: str) -> Tuple[List[List[str]], int]:
    """Parse ligne physique par ligne physique en equilibrant les guillemets :
    un guillemet ouvrant jamais referme ferait avaler tout le reste du fichier
    dans un seul champ."""
    lignes: List[List[str]] = []
    reparees = 0
    for ligne in texte.splitlines():
        if not ligne.strip():
            continue
        if ligne.count('"') % 2:
            ligne += '"'
            reparees += 1
        lignes.append(next(csv.reader(io.StringIO(ligne), delimiter=SEPARATEUR)))
    return lignes, reparees


def parse_pe_tools_csv(content: bytes) -> ParsedFile:
    """Transforme le contenu binaire d'un CSV PE Tools en lignes pretes a
    inserer (cles = colonnes SQL, '' -> None).

    Leve ValueError (message en francais) si le contenu est vide ou si
    l'en-tete ne ressemble pas a un export PE Tools.
    """
    if not content or not content.strip():
        raise ValueError('Fichier vide')

    lignes, reparees = _lire_lignes(_decoder(content))
    if not lignes:
        raise ValueError('Fichier vide')

    entete = [cle(nom) for nom in lignes[0]]
    attendues = {cle(intitule): col_sql for col_sql, intitule in PE_TOOLS_COLUMNS}

    for intitule in COLONNES_OBLIGATOIRES:
        if cle(intitule) not in entete:
            raise ValueError(
                f"En-tete non reconnue : colonne « {intitule} » absente "
                f"(le fichier n'est pas un export PE Tools ?)"
            )

    result = ParsedFile(repaired_lines=reparees)
    result.missing_columns = [intitule for _, intitule in PE_TOOLS_COLUMNS if cle(intitule) not in entete]
    result.unknown_columns = [
        nom.strip() for nom in lignes[0] if cle(nom) not in attendues and nom.strip()
    ]

    # position dans la ligne -> colonne SQL (les colonnes inconnues et le
    # surplus de champs au-dela de l'en-tete sont ignores)
    position = {i: attendues[k] for i, k in enumerate(entete) if k in attendues}

    for champs in lignes[1:]:
        if not any(c.strip() for c in champs):
            continue
        ligne: Dict[str, Optional[str]] = {col_sql: None for col_sql, _ in PE_TOOLS_COLUMNS}
        for i, valeur in enumerate(champs):
            col_sql = position.get(i)
            if col_sql is None:
                continue
            valeur = valeur.strip()
            ligne[col_sql] = valeur if valeur else None
        result.rows.append(ligne)

    return result
```

- [ ] **Step 5 : Lancer les tests, vérifier le succès**

```bash
cd backend && python -m pytest tests/test_pe_tools_import_service.py -q
```

Attendu : `9 passed`.

- [ ] **Step 6 : Commit**

```bash
git add backend/services/pe_tools_import_service.py backend/tests/test_pe_tools_import_service.py backend/tests/fixtures/petool_mcar_extrait.csv
git commit -m "PE Tools : service de parsing des CSV PeTool (cp850, en-tetes metier)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3 : API — colonnes calculées dans la liste, le détail, les filtres et l'export

**Files:**
- Modify: `backend/api/maintenance_pe_tools.py`

- [ ] **Step 1 : Déclarer les colonnes calculées et leur détection**

Dans `backend/api/maintenance_pe_tools.py`, après le bloc `COLUMNS = [...]` (ligne ~52) et avant `FILTER_COLUMNS`, ajouter :

```python
# Colonnes renseignees par l'import de fichiers (migration 077). Jamais
# editables : PUT/POST les ignorent, seul POST /pe-tools/import les ecrit.
COMPUTED_COLUMNS = [
    'nom_fichier',
    'organisation_maintenance',
]
```

Remplacer la liste `FILTER_COLUMNS` par :

```python
# Colonnes proposees en liste deroulante (cardinalite faible / usage de filtre).
FILTER_COLUMNS = [
    'localisation_classement',
    'poste_technique',
    'type',
    'frequence',
    'criticite',
    'gamme_en_dms',
    'nom_fichier',
    'organisation_maintenance',
]
```

Remplacer `ORDERABLE = set(COLUMNS) | {'raw_id'}` par :

```python
ORDERABLE = set(COLUMNS) | set(COMPUTED_COLUMNS) | {'raw_id'}
```

Après `_audit_available = None`, ajouter :

```python
# Colonnes de la migration 077 (import par fichier). Meme logique de detection
# que pour l'audit : sans la migration, l'ecran fonctionne comme avant.
_import_columns_available = None
```

Après la fonction `_has_audit_columns`, ajouter :

```python
def _has_import_columns(cursor) -> bool:
    global _import_columns_available
    if _import_columns_available is None:
        cursor.execute("""
            SELECT COUNT(*) AS nb
            FROM information_schema.columns
            WHERE table_schema = 'raw_data' AND table_name = 'pe_tools'
              AND column_name IN ('nom_fichier', 'organisation_maintenance', 'imported_at')
        """)
        _import_columns_available = cursor.fetchone()['nb'] == 3
    return _import_columns_available


def _selected_columns(cursor):
    """Colonnes lues par la liste, le detail et l'export : les colonnes
    calculees en tete (si la migration 077 est jouee) puis les colonnes metier."""
    if _has_import_columns(cursor):
        return COMPUTED_COLUMNS + COLUMNS
    return list(COLUMNS)


def _filter_columns(cursor):
    if _has_import_columns(cursor):
        return FILTER_COLUMNS
    return [c for c in FILTER_COLUMNS if c not in COMPUTED_COLUMNS]
```

- [ ] **Step 2 : Faire passer la clause WHERE et la signature de filtres par `_filter_columns`**

`_build_where(args)` devient `_build_where(args, filter_columns)` et `_filters_signature(args)` devient `_filters_signature(args, filter_columns)` :

```python
def _build_where(args, filter_columns):
    """Construit la clause WHERE commune (liste, export, stats) a partir des
    parametres de query string. Retourne (sql, params)."""
    clauses = []
    params = []

    search = (args.get('search') or '').strip()
    if search:
        sp = f'%{search}%'
        ors = ' OR '.join(f"{c} ILIKE %s" for c in SEARCH_COLUMNS)
        clauses.append(f"({ors})")
        params.extend([sp] * len(SEARCH_COLUMNS))

    for col in filter_columns:
        val = (args.get(col) or '').strip()
        if val:
            clauses.append(f"COALESCE(TRIM({col}), '') = %s")
            params.append(val)

    where_sql = ("WHERE " + " AND ".join(clauses)) if clauses else ""
    return where_sql, params


def _filters_signature(args, filter_columns) -> str:
    parts = [f"search={(args.get('search') or '').strip()}"]
    parts += [f"{c}={(args.get(c) or '').strip()}" for c in filter_columns]
    return '|'.join(parts)
```

- [ ] **Step 3 : Réécrire `list_pe_tools`**

Les appels à `_build_where` / `_filters_signature` doivent désormais se faire **après** l'ouverture de la connexion (la détection des colonnes a besoin d'un curseur). Nouvelle version complète de la route :

```python
@maintenance_pe_tools_blueprint.route('/pe-tools', methods=['GET'])
def list_pe_tools():
    """Liste paginee des gammes PE Tools + options de filtres."""
    try:
        page = max(1, request.args.get('page', 1, type=int))
        per_page = min(max(1, request.args.get('per_page', 25, type=int)), 200)
        order_by = request.args.get('order_by', 'poste_technique', type=str)
        order = request.args.get('order', 'asc', type=str)
        if order_by not in ORDERABLE:
            order_by = 'poste_technique'
        order_dir = 'DESC' if order.lower() == 'desc' else 'ASC'
        offset = (page - 1) * per_page

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            filter_columns = _filter_columns(cursor)
            columns = _selected_columns(cursor)
            if order_by not in columns and order_by != 'raw_id':
                order_by = 'poste_technique'

            where_sql, params = _build_where(request.args, filter_columns)

            cache_key = (f"{CACHE_PREFIX}list:{page}:{per_page}:{order_by}:{order_dir}:"
                         f"{_filters_signature(request.args, filter_columns)}")
            cached = cache_get(cache_key)
            if cached is not None:
                return Response(cached, mimetype='application/json')

            cols_sql = ', '.join(columns)

            cursor.execute(f"SELECT COUNT(*) AS total FROM raw_data.pe_tools {where_sql}", params)
            total = cursor.fetchone()['total']

            cursor.execute(
                f"""
                SELECT raw_id, {cols_sql}
                FROM raw_data.pe_tools
                {where_sql}
                ORDER BY {order_by} {order_dir} NULLS LAST, raw_id ASC
                LIMIT %s OFFSET %s
                """,
                params + [per_page, offset]
            )
            rows = cursor.fetchall()

            # Options de filtres : valeurs distinctes sur l'ensemble de la table
            # (independantes des filtres courants, pour rester selectionnables).
            filter_options = {}
            for col in filter_columns:
                cursor.execute(f"""
                    SELECT DISTINCT TRIM({col}) AS value
                    FROM raw_data.pe_tools
                    WHERE {col} IS NOT NULL AND TRIM({col}) <> ''
                    ORDER BY 1
                """)
                filter_options[col] = [r['value'] for r in cursor.fetchall()]

            payload = json.dumps({
                'success': True,
                'data': rows,
                'total': total,
                'page': page,
                'per_page': per_page,
                'columns': columns,
                'filter_options': filter_options,
            }, default=str)
            cache_set(cache_key, payload, Config.MAINTENANCE_CACHE_TTL)
            return Response(payload, mimetype='application/json')

    except Exception as e:
        current_app.logger.error(f"Erreur liste pe_tools: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
```

- [ ] **Step 4 : Adapter `pe_tools_stats`**

Déplacer `where_sql, params = _build_where(...)` et le calcul de `cache_key` à l'intérieur du `with get_db_connection() as conn:` après la création du curseur :

```python
@maintenance_pe_tools_blueprint.route('/pe-tools/stats', methods=['GET'])
def pe_tools_stats():
    """Compteurs de tete de page, calcules sur le perimetre filtre."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            filter_columns = _filter_columns(cursor)
            where_sql, params = _build_where(request.args, filter_columns)

            cache_key = f"{CACHE_PREFIX}stats:{_filters_signature(request.args, filter_columns)}"
            cached = cache_get(cache_key)
            if cached is not None:
                return Response(cached, mimetype='application/json')

            cursor.execute(f"""
                SELECT
                    COUNT(*) AS total,
                    COUNT(DISTINCT NULLIF(TRIM(poste_technique), '')) AS nb_postes_techniques,
                    COUNT(DISTINCT NULLIF(TRIM(plan_entretien), ''))  AS nb_plans_entretien,
                    COUNT(DISTINCT NULLIF(TRIM(groupe_de_gamme), '')) AS nb_gammes,
                    COALESCE(SUM(
                        CASE WHEN TRIM(COALESCE(charge, '')) ~ '^[0-9]+([.,][0-9]+)?$'
                             THEN REPLACE(TRIM(charge), ',', '.')::numeric END
                    ), 0) AS charge_totale
                FROM raw_data.pe_tools
                {where_sql}
            """, params)
            stats = cursor.fetchone()

            cursor.execute(f"""
                SELECT COALESCE(NULLIF(TRIM(frequence), ''), '(vide)') AS frequence,
                       COUNT(*) AS nb
                FROM raw_data.pe_tools
                {where_sql}
                GROUP BY 1
                ORDER BY nb DESC, 1
                LIMIT 12
            """, params)
            by_frequence = cursor.fetchall()

            payload = json.dumps({
                'success': True,
                'data': {**stats, 'by_frequence': by_frequence},
            }, default=str)
            cache_set(cache_key, payload, Config.MAINTENANCE_CACHE_TTL)
            return Response(payload, mimetype='application/json')

    except Exception as e:
        current_app.logger.error(f"Erreur stats pe_tools: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
```

- [ ] **Step 5 : Adapter `export_pe_tools` (colonnes calculées en tête du CSV)**

```python
@maintenance_pe_tools_blueprint.route('/pe-tools/export', methods=['GET'])
def export_pe_tools():
    """Export CSV (';', BOM UTF-8 pour Excel) du perimetre filtre courant."""
    try:
        order_by = request.args.get('order_by', 'poste_technique', type=str)
        if order_by not in ORDERABLE:
            order_by = 'poste_technique'
        order_dir = 'DESC' if (request.args.get('order') or '').lower() == 'desc' else 'ASC'

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            columns = _selected_columns(cursor)
            if order_by not in columns and order_by != 'raw_id':
                order_by = 'poste_technique'
            where_sql, params = _build_where(request.args, _filter_columns(cursor))
            cols_sql = ', '.join(columns)
            cursor.execute(
                f"""
                SELECT {cols_sql}
                FROM raw_data.pe_tools
                {where_sql}
                ORDER BY {order_by} {order_dir} NULLS LAST, raw_id ASC
                """,
                params
            )
            rows = cursor.fetchall()

        output = io.StringIO()
        writer = csv.DictWriter(output, fieldnames=columns, delimiter=';', extrasaction='ignore')
        writer.writeheader()
        for r in rows:
            writer.writerow({c: (r.get(c) if r.get(c) is not None else '') for c in columns})

        # BOM : sans lui Excel casse les accents des designations.
        body = '﻿' + output.getvalue()
        return Response(
            body,
            mimetype='text/csv',
            headers={
                'Content-Disposition': 'attachment; filename=pe_tools.csv',
                'Content-Type': 'text/csv; charset=utf-8',
            }
        )

    except Exception as e:
        current_app.logger.error(f"Erreur export pe_tools: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
```

Attention : le fichier actuel contient le BOM en littéral (`'﻿'`) ; l'écrire `'﻿'` est équivalent et lisible.

- [ ] **Step 6 : Adapter `get_pe_tool` (détail)**

Remplacer `cols_sql = ', '.join(COLUMNS)` (avant le `with`) par, à l'intérieur du `with` après la création du curseur :

```python
            cols_sql = ', '.join(_selected_columns(cursor))
            audit_sql = ', updated_at, updated_by' if _has_audit_columns(cursor) else ''
            if _has_import_columns(cursor):
                audit_sql += ', imported_at'
```

(le reste de la route est inchangé : `SELECT raw_id, {cols_sql}{audit_sql} FROM raw_data.pe_tools WHERE raw_id = %s LIMIT 1`).

- [ ] **Step 7 : Vérification syntaxique + tests existants**

```bash
cd backend && python -c "import ast,sys; ast.parse(open('api/maintenance_pe_tools.py', encoding='utf-8').read()); print('OK')" && python -m pytest tests/test_pe_tools_import_service.py -q
```

Attendu : `OK` puis `9 passed`.

- [ ] **Step 8 : Commit**

```bash
git add backend/api/maintenance_pe_tools.py
git commit -m "PE Tools API : colonnes nom_fichier / organisation_maintenance (liste, detail, filtres, export)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4 : API — route `POST /pe-tools/import`

**Files:**
- Modify: `backend/api/maintenance_pe_tools.py`

- [ ] **Step 1 : Ajouter l'import du service**

En tête de fichier, après `from services.cache_service import ...` :

```python
from services.pe_tools_import_service import PE_TOOLS_COLUMNS, parse_pe_tools_csv
```

- [ ] **Step 2 : Ajouter la fonction d'import d'un fichier**

Avant la route `create_pe_tool` (ou en fin de fichier), ajouter :

```python
def _import_one_file(conn, nom_fichier: str, content: bytes, user: str) -> dict:
    """Importe UN fichier PE Tools en mode "remplacer par fichier" : les lignes
    portant deja ce nom_fichier sont supprimees puis rechargees, les autres
    (autres fichiers, lignes historiques sans nom_fichier) ne bougent pas.

    Une transaction par fichier : commit en fin, rollback sur toute erreur
    (le resultat porte alors status='error'). Ne leve jamais."""
    resultat = {
        'fichier': nom_fichier,
        'status': 'ok',
        'code_fichier': None,
        'organisation_maintenance': None,
        'lignes_supprimees': 0,
        'lignes_inserees': 0,
        'avertissements': [],
    }
    try:
        if not nom_fichier.lower().endswith('.csv'):
            raise ValueError('Extension attendue : .csv')

        parsed = parse_pe_tools_csv(content)
        if parsed.missing_columns:
            resultat['avertissements'].append(
                'Colonne(s) absente(s) du fichier (valeurs NULL) : ' + ', '.join(parsed.missing_columns))
        if parsed.unknown_columns:
            resultat['avertissements'].append(
                'Colonne(s) ignorée(s), sans équivalent dans pe_tools : ' + ', '.join(parsed.unknown_columns))
        if parsed.repaired_lines:
            resultat['avertissements'].append(
                f'{parsed.repaired_lines} ligne(s) aux guillemets non fermés réparée(s)')

        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cursor.execute(
            "SELECT public.pe_tools_code_fichier(%s) AS code, public.pe_tools_org_code(%s) AS org",
            [nom_fichier, nom_fichier])
        r = cursor.fetchone()
        resultat['code_fichier'] = r['code']
        resultat['organisation_maintenance'] = r['org']
        if r['org'] is None:
            resultat['avertissements'].append(
                f"Code {r['code'] or '?'} absent de public.pe_tools_organisation : organisation non renseignée")

        cursor.execute("DELETE FROM raw_data.pe_tools WHERE nom_fichier = %s", [nom_fichier])
        resultat['lignes_supprimees'] = cursor.rowcount

        if parsed.rows:
            cursor.execute("SELECT COALESCE(MAX(raw_id), 0) AS max_id FROM raw_data.pe_tools")
            next_id = cursor.fetchone()['max_id'] + 1

            col_sql = [c for c, _ in PE_TOOLS_COLUMNS]
            cols = ['raw_id'] + col_sql + ['nom_fichier', 'organisation_maintenance', 'imported_at']
            audit = _has_audit_columns(cursor)
            if audit:
                cols += ['updated_at', 'updated_by']

            # imported_at / updated_at sont des NOW() litteraux dans le template
            # (pas des parametres) : le tuple ne porte que les valeurs.
            template = '(' + ', '.join(['%s'] * (1 + len(col_sql) + 2)) + ', NOW()'
            if audit:
                template += ', NOW(), %s'
            template += ')'

            rows_sql = []
            for i, row in enumerate(parsed.rows):
                t = [next_id + i] + [row[c] for c in col_sql] + [nom_fichier, r['org']]
                if audit:
                    t.append(user)
                rows_sql.append(tuple(t))

            psycopg2.extras.execute_values(
                cursor,
                f"INSERT INTO raw_data.pe_tools ({', '.join(cols)}) VALUES %s",
                rows_sql,
                template=template,
                page_size=500,
            )
            resultat['lignes_inserees'] = len(rows_sql)

        conn.commit()
    except Exception as exc:
        conn.rollback()
        resultat['status'] = 'error'
        resultat['error'] = str(exc)
        current_app.logger.error(f"Import pe_tools {nom_fichier}: {exc}")
    return resultat


@maintenance_pe_tools_blueprint.route('/pe-tools/import', methods=['POST'])
def import_pe_tools():
    """Import multi-fichiers des CSV PE Tools (champ multipart `files`).

    Mode "remplacer par fichier" : voir _import_one_file. Un fichier en erreur
    n'annule pas les autres ; la reponse detaille chaque fichier."""
    try:
        fichiers = request.files.getlist('files')
        if not fichiers:
            return jsonify({'success': False, 'error': 'Aucun fichier fourni (champ multipart « files »)'}), 400

        user = _user()
        results = []
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            if not _has_import_columns(cursor):
                return jsonify({
                    'success': False,
                    'error': 'Migration 077 non jouée : colonnes nom_fichier / organisation_maintenance absentes',
                }), 503
            for f in fichiers:
                nom = (f.filename or '').strip()
                if not nom:
                    continue
                results.append(_import_one_file(conn, nom, f.read(), user))

        cache_invalidate(CACHE_PREFIX)
        return jsonify({
            'success': any(r['status'] == 'ok' for r in results),
            'results': results,
        }), 200

    except Exception as e:
        current_app.logger.error(f"Erreur import pe_tools: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
```

- [ ] **Step 3 : Vérification syntaxique et cohérence template/tuple**

```bash
cd backend && python - <<'EOF'
import ast
src = open('api/maintenance_pe_tools.py', encoding='utf-8').read()
ast.parse(src)
from services.pe_tools_import_service import PE_TOOLS_COLUMNS
nb_params = 1 + len(PE_TOOLS_COLUMNS) + 2
template = '(' + ', '.join(['%s'] * nb_params) + ', NOW(), NOW(), %s)'
print('placeholders =', template.count('%s'), '; attendu =', nb_params + 1)
EOF
```

Attendu : `placeholders = 27 ; attendu = 27`.

- [ ] **Step 4 : Test d'intégration manuel (après déploiement, Task 7) — noter ici la commande**

```bash
# depuis le poste, JWT recupere via /api/v1/auth/login
curl -s -H "Authorization: Bearer $TOKEN" \
  -F "files=@/c/document/Export/PETools/PeTool - 7.MSGX.csv" \
  http://10.190.100.58:8081/api/v1/maintenance/pe-tools/import | python -m json.tool
```

Attendu : `"status": "ok"`, `"organisation_maintenance": "SJ-MSGX"`, `"lignes_inserees": 20`.

- [ ] **Step 5 : Commit**

```bash
git add backend/api/maintenance_pe_tools.py
git commit -m "PE Tools API : import multi-fichiers en mode remplacer par fichier

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5 : Frontend — bouton Importer, dialog de résultat, colonnes calculées

**Files:**
- Modify: `frontend/src/pages/MaintenancePeToolsPage.tsx`

- [ ] **Step 1 : Imports MUI supplémentaires**

Dans le bloc `import { ... } from '@mui/material'`, ajouter `List`, `ListItem`, `ListItemText` (déjà présents : `Alert`, `Chip`, `Dialog*`, `Table*`, `CircularProgress`, `Typography`). Dans le bloc `@mui/icons-material`, ajouter `Upload as UploadIcon`.

- [ ] **Step 2 : Colonnes calculées dans `FIELDS`, `SELECT_FILTERS` et un type de résultat**

Ajouter la propriété `readOnly?: boolean` au type de `FIELDS` et insérer en **tête** du tableau (avant `poste_technique`) :

```ts
  { key: 'nom_fichier', label: 'Fichier', inTable: true, monospace: true, readOnly: true },
  { key: 'organisation_maintenance', label: 'Organisation', inTable: true, monospace: true, readOnly: true },
```

Les deux `Divider` du panneau de détail sont positionnés par index (`idx === 7`, `idx === 19`) : les décaler à `idx === 9` et `idx === 21`.

Dans `SELECT_FILTERS`, ajouter en fin :

```ts
  { key: 'nom_fichier', label: 'Fichier' },
  { key: 'organisation_maintenance', label: 'Organisation' },
```

Après l'interface `Stats`, ajouter :

```ts
interface ImportResult {
  fichier: string;
  status: 'ok' | 'error';
  code_fichier: string | null;
  organisation_maintenance: string | null;
  lignes_supprimees: number;
  lignes_inserees: number;
  avertissements: string[];
  error?: string;
}
```

- [ ] **Step 3 : Champs en lecture seule dans le formulaire d'édition**

Dans `renderDetails`, la branche `isEditing ? <TextField .../> : <Typography .../>` devient `isEditing && !f.readOnly ? ... : ...`. En création, les champs `readOnly` ne sont pas affichés : ajouter au début du `FIELDS.map((f, idx) => {` :

```tsx
              if (isCreating && f.readOnly) return null;
```

- [ ] **Step 4 : État et handler d'import**

Après `const [confirmDelete, ...]`, ajouter :

```ts
  const [importOpen, setImportOpen] = useState(false);
  const [importFiles, setImportFiles] = useState<File[]>([]);
  const [importing, setImporting] = useState(false);
  const [importResults, setImportResults] = useState<ImportResult[] | null>(null);
```

Après `exportCsv`, ajouter :

```ts
  const openImport = () => {
    setImportFiles([]);
    setImportResults(null);
    setImportOpen(true);
  };

  const closeImport = async () => {
    setImportOpen(false);
    if (importResults) {
      await loadRows();
      await loadStats();
    }
  };

  /** Import multi-fichiers : chaque fichier remplace ses propres lignes. */
  const runImport = async () => {
    if (importFiles.length === 0) return;
    const form = new FormData();
    importFiles.forEach((f) => form.append('files', f, f.name));
    try {
      setImporting(true);
      const response = await api.post('/maintenance/pe-tools/import', form, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      setImportResults(response.data.results || []);
    } catch (err: any) {
      setSnackbar({
        open: true,
        message: err?.response?.data?.error || 'Erreur lors de l\'import',
        severity: 'error',
      });
    } finally {
      setImporting(false);
    }
  };
```

- [ ] **Step 5 : Bouton et dialog**

Dans l'en-tête, entre le bouton « Nouvelle gamme » et « Exporter CSV », ajouter :

```tsx
        <Button variant="outlined" size="small" startIcon={<UploadIcon />} onClick={openImport} sx={{ mr: 1 }}>
          Importer
        </Button>
```

Avant le `<Dialog open={!!confirmDelete} ...>`, ajouter :

```tsx
      <Dialog open={importOpen} onClose={importing ? undefined : closeImport} maxWidth="md" fullWidth>
        <DialogTitle>Importer des fichiers PE Tools</DialogTitle>
        <DialogContent>
          {!importResults ? (
            <>
              <DialogContentText sx={{ mb: 2 }}>
                Fichiers <code>PeTool - 7.&lt;CODE&gt;.csv</code> (export Excel, séparateur « ; »).
                Les lignes déjà importées depuis un fichier du même nom sont remplacées ; les autres
                ne bougent pas. L'organisation de maintenance est déduite du nom du fichier.
              </DialogContentText>
              <Box
                component="input"
                type="file"
                multiple
                accept=".csv"
                disabled={importing}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
                  setImportFiles(Array.from(e.target.files || []))
                }
                sx={{ display: 'block', mb: 2 }}
              />
              {importFiles.length > 0 && (
                <List dense>
                  {importFiles.map((f) => (
                    <ListItem key={f.name}>
                      <ListItemText
                        primary={f.name}
                        secondary={`${Math.round(f.size / 1024)} Ko`}
                        primaryTypographyProps={{ fontFamily: 'monospace' }}
                      />
                    </ListItem>
                  ))}
                </List>
              )}
              {importing && <LinearProgress sx={{ mt: 1 }} />}
            </>
          ) : (
            <TableContainer>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Fichier</TableCell>
                    <TableCell>Organisation</TableCell>
                    <TableCell align="right">Supprimées</TableCell>
                    <TableCell align="right">Insérées</TableCell>
                    <TableCell>Statut</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {importResults.map((r) => (
                    <React.Fragment key={r.fichier}>
                      <TableRow>
                        <TableCell sx={{ fontFamily: 'monospace' }}>{r.fichier}</TableCell>
                        <TableCell>
                          {r.organisation_maintenance ? (
                            <Chip size="small" label={r.organisation_maintenance} sx={{ fontFamily: 'monospace' }} />
                          ) : (
                            <Chip size="small" color="warning" label="non résolue" />
                          )}
                        </TableCell>
                        <TableCell align="right">{r.lignes_supprimees}</TableCell>
                        <TableCell align="right">{r.lignes_inserees}</TableCell>
                        <TableCell>
                          <Chip
                            size="small"
                            color={r.status === 'ok' ? 'success' : 'error'}
                            label={r.status === 'ok' ? 'OK' : 'Erreur'}
                          />
                        </TableCell>
                      </TableRow>
                      {(r.error || r.avertissements.length > 0) && (
                        <TableRow>
                          <TableCell colSpan={5} sx={{ pt: 0 }}>
                            {r.error && <Alert severity="error" sx={{ mb: 0.5 }}>{r.error}</Alert>}
                            {r.avertissements.map((a) => (
                              <Alert key={a} severity="warning" sx={{ mb: 0.5 }}>{a}</Alert>
                            ))}
                          </TableCell>
                        </TableRow>
                      )}
                    </React.Fragment>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          )}
        </DialogContent>
        <DialogActions>
          {!importResults ? (
            <>
              <Button onClick={closeImport} disabled={importing}>Annuler</Button>
              <Button
                variant="contained"
                onClick={runImport}
                disabled={importing || importFiles.length === 0}
                startIcon={importing ? <CircularProgress size={16} /> : <UploadIcon />}
              >
                Lancer l'import
              </Button>
            </>
          ) : (
            <Button variant="contained" onClick={closeImport}>Fermer</Button>
          )}
        </DialogActions>
      </Dialog>
```

- [ ] **Step 6 : Vérifier la syntaxe avec esbuild (pas de node_modules en local)**

```bash
SCRATCH="$(cygpath -u "$TEMP")/claude/c--Users-samir-chibout-Documents-Projets-migration-Factory/c02ca51c-6e22-4a06-bfe9-d8d13f9100fe/scratchpad"
cd "$SCRATCH" && [ -x node_modules/.bin/esbuild ] || npm install esbuild --silent
cd /c/Users/samir.chibout/Documents/Projets/migration-Factory/frontend
"$SCRATCH/node_modules/.bin/esbuild" src/pages/MaintenancePeToolsPage.tsx --outdir="$SCRATCH/out" --log-level=error; echo "exit=$?"
```

Attendu : `exit=0` (esbuild écrit son résumé sur stderr ; seul le code de sortie compte).

- [ ] **Step 7 : Commit**

```bash
git add frontend/src/pages/MaintenancePeToolsPage.tsx
git commit -m "PE Tools : bouton Importer (multi-fichiers) + colonnes Fichier / Organisation

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6 : ETL PM Actions — `org_code` depuis le fichier

**Files:**
- Modify: `sql/pm_actions/00_pm_helpers.sql`
- Modify: `sql/pm_actions/01_populate_pm_action.sql`
- Modify: `sql/pm_actions/04_populate_pm_action_role.sql`

- [ ] **Step 1 : Ajouter `v_pm_source` dans `00_pm_helpers.sql`**

La vue n'existait qu'en base (créée hors dépôt) ; on la versionne ici, à l'identique de `pg_get_viewdef` du 2026-09-15, plus la colonne `organisation_maintenance`. Ajouter en fin de fichier :

```sql
-- Vue source des procedures pm_action* : 1 ligne = 1 operation de pe_tools,
-- avec le pm_no calcule (plan d'entretien, suffixe si plusieurs combinaisons
-- poste/frequence pour un meme plan, repli 900000+raw_id sans plan).
-- organisation_maintenance (migration 077) : organisation IFS deduite du
-- fichier importe, NULL pour les lignes historiques.
CREATE OR REPLACE VIEW clean_data.v_pm_source AS
WITH base AS (
    SELECT t.raw_id,
           t.poste_technique,
           t.groupe_de_gamme,
           t.compteur_de_gamme,
           t.frequence,
           t.designation,
           t.charge,
           t.nb_intervenants,
           t.organisation_maintenance,
           clean_data.pe_num(t.plan_entretien)          AS plan_num,
           upper(btrim(COALESCE(t.frequence, '')))      AS freq_norm
    FROM raw_data.pe_tools t
), ranked AS (
    SELECT b.*,
           dense_rank() OVER (PARTITION BY b.plan_num
                              ORDER BY b.poste_technique NULLS FIRST, b.freq_norm NULLS FIRST) AS combi_rang
    FROM base b
), counted AS (
    SELECT r.*,
           max(r.combi_rang) OVER (PARTITION BY r.plan_num) AS nb_combi
    FROM ranked r
)
SELECT c.raw_id, c.poste_technique, c.groupe_de_gamme, c.compteur_de_gamme, c.frequence,
       c.freq_norm, c.designation, c.charge, c.nb_intervenants, c.plan_num, c.combi_rang, c.nb_combi,
       CASE
           WHEN c.plan_num IS NULL THEN (900000 + c.raw_id)::numeric
           WHEN c.nb_combi = 1     THEN c.plan_num
           ELSE c.plan_num * 1000::numeric + c.combi_rang::numeric
       END AS pm_no,
       -- en DERNIERE position : CREATE OR REPLACE VIEW refuse d'inserer une
       -- colonne au milieu ("cannot change name of view column")
       c.organisation_maintenance
FROM counted c;
```

- [ ] **Step 2 : `01_populate_pm_action.sql` — org_code du fichier**

Dans le **second** CTE `agg` (celui de l'`INSERT INTO clean_data.pm_action`), ajouter la colonne :

```sql
    agg AS (
        SELECT
            s.pm_no,
            NULLIF(btrim(min(s.poste_technique)), '') AS mch_code,
            min(s.freq_norm)                          AS freq_norm,
            -- Organisation IFS du fichier importe (migration 077) ; une pm_no
            -- ne vient que d'un seul fichier, min() est une simple garde.
            min(s.organisation_maintenance)           AS org_code_fichier
        FROM src s
        GROUP BY s.pm_no
    ),
```

Dans le `SELECT` final de l'INSERT, remplacer la ligne `v_org_code,` par :

```sql
        COALESCE(a.org_code_fichier, v_org_code),
```

(les lignes historiques sans fichier gardent `FR_MAINT`).

- [ ] **Step 3 : `04_populate_pm_action_role.sql` — org_code cohérent avec l'action**

Dans le `SELECT`, remplacer `v_org_code` par `p.org_code` (la jointure `clean_data.pm_action p` est déjà là). Conserver la déclaration `v_org_code` uniquement si elle est encore utilisée ailleurs ; sinon la supprimer du `DECLARE` :

```sql
    SELECT
        s.pm_no,
        v_pm_revision,
        row_number() OVER (ORDER BY s.pm_no, s.raw_id)  AS row_no,
        left(s.designation, 200)                        AS description,
        clean_data.pe_num(s.charge)                     AS duration,
        v_org_contract,
        p.org_code
    FROM clean_data.v_pm_source s
    JOIN clean_data.pm_action p
      ON p.pm_no = s.pm_no
     AND p.pm_revision = v_pm_revision;
```

- [ ] **Step 4 : Vérifier la lecture de la base avant modification (pas d'écart entre la vue en base et le dépôt)**

Via `mcp__postgres__query` :

```sql
SELECT pg_get_viewdef('clean_data.v_pm_source', true)
```

Comparer visuellement avec le corps écrit au step 1 (hors `organisation_maintenance`) : si la vue en base a évolué depuis le 2026-09-15, reprendre sa version.

- [ ] **Step 5 : Commit**

```bash
git add sql/pm_actions/00_pm_helpers.sql sql/pm_actions/01_populate_pm_action.sql sql/pm_actions/04_populate_pm_action_role.sql
git commit -m "PM Actions : org_code deduit du fichier PE Tools importe (repli valeur par defaut)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7 : Déploiement et vérification sur le serveur

**Files:** aucun (opérations serveur).

- [ ] **Step 1 : Pousser et vérifier que le clone serveur n'est pas en avance**

```bash
git push
ssh migration "cd /root/migration-Factory && git fetch -q && git status -sb | head -1 && git log --oneline HEAD..origin/master | wc -l && git log --oneline origin/master..HEAD"
```

Attendu : la dernière ligne (commits serveur non poussés) est vide. Sinon **s'arrêter** et remonter à l'utilisateur.

- [ ] **Step 2 : Jouer la migration 077 et compiler PM Actions**

```bash
ssh migration "cd /root/migration-Factory && git pull -q && PGPASSWORD=trimet2025 psql -h 10.190.100.58 -U postgres -d sap_migration_db -v ON_ERROR_STOP=1 -f migrations/077_pe_tools_import_organisation.sql 2>&1 | tail -3 && cd sql/pm_actions && ./compile.sh 2>&1 | tail -4"
```

Attendu : `NOTICE: 077 : assertions OK`, `COMMIT`, puis `✅ Toutes les procédures ont été compilées avec succès!`.

- [ ] **Step 3 : Déployer backend et frontend**

```bash
ssh migration "cd /root/migration-Factory && ./deploybackend.sh 2>&1 | tail -5 && ./deployfrontend.sh 2>&1 | tail -5"
```

Attendu : conteneurs recréés, tests de santé `127.0.0.1:5000` / `127.0.0.1:3100` OK.

- [ ] **Step 4 : Importer les 8 CSV depuis l'écran** (`http://10.190.100.58:8081/maintenance/pe-tools` → Importer) et comparer :

| Fichier | Insérées attendues |
|---|---|
| MATC | 120 |
| MCAR | 109 |
| MELY | 440 |
| MFIE | 596 |
| MNRJ | 179 (org `SJ-MSST`) |
| MSCT | 168 |
| MSGX | 20 |

Puis réimporter `PeTool - 7.MCAR.csv` seul : `lignes_supprimees = 109`, `lignes_inserees = 109`.

Contrôle via `mcp__postgres__query` :

```sql
SELECT nom_fichier, organisation_maintenance, count(*)
FROM raw_data.pe_tools GROUP BY 1, 2 ORDER BY 1 NULLS FIRST
```

Attendu : une ligne `NULL / NULL / 1760` (historique) + 7 lignes fichiers avec les comptes ci-dessus.

- [ ] **Step 5 : Rejouer l'ETL PM Actions et vérifier la répartition**

Seulement après accord de l'utilisateur sur la purge de l'historique (spec §8) :

```sql
-- serveur, psql
DELETE FROM raw_data.pe_tools WHERE nom_fichier IS NULL;
CALL clean_data.populate_all_pm_actions();
SELECT org_code, count(*) FROM clean_data.pm_action GROUP BY 1 ORDER BY 1;
SELECT org_code, count(*) FROM clean_data.pm_action_role GROUP BY 1 ORDER BY 1;
```

Attendu : plus de `FR_MAINT` (sauf lignes sans organisation résolue), une ligne par organisation `SJ-*`, et les mêmes codes dans `pm_action_role`.

---

### Task 8 : Documentation

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1 : Ajouter une puce dans « Points d'attention »** (après la puce Module Maintenance) :

```markdown
- **Import PE Tools par fichier (migration 077, `POST /api/v1/maintenance/pe-tools/import`, 2026-09-15)** : les CSV `PeTool - 7.<CODE>.csv` (cp850, `;`, en-têtes métier mappées par `services/pe_tools_import_service.py`) se déposent depuis l'écran `/maintenance/pe-tools`, en mode **remplacer par fichier** (`DELETE WHERE nom_fichier = ...` puis INSERT, une transaction par fichier). Chaque ligne porte `nom_fichier` et `organisation_maintenance` = `public.pe_tools_org_code(nom_fichier)`, qui lit la table de paramétrage `public.pe_tools_organisation` (code = segment `7.<CODE>.csv` ; `MSJ -> FR-MSJ`, `MNRJ -> SJ-MSST`, sinon `SJ-<CODE>` seedés ; code inconnu -> NULL + avertissement, pas de repli générique). L'ETL PM Actions prend `pm_action.org_code = COALESCE(org du fichier, get_default_value)` et `pm_action_role.org_code = pm_action.org_code`. Les 1 760 lignes historiques (sans `nom_fichier`) ne sont jamais touchées par l'import : les supprimer manuellement une fois les 9 fichiers réimportés, sinon `pm_no` en double. `clean_data.v_pm_source` est désormais versionnée dans `sql/pm_actions/00_pm_helpers.sql` (colonne `organisation_maintenance` en dernière position : `CREATE OR REPLACE VIEW` interdit d'insérer une colonne au milieu).
```

- [ ] **Step 2 : Mettre à jour le numéro de dernière migration** dans la section « Base de données » : `dernier numero utilise : 077`.

- [ ] **Step 3 : Commit**

```bash
git add CLAUDE.md
git commit -m "Doc : import PE Tools par fichier et organisation de maintenance

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```
