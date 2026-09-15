"""Route POST /pe-tools/import : _import_one_file avec une connexion factice.

`api/__init__.py` importe requests_ntlm et `config.database` ouvre une vraie
connexion : le module api/maintenance_pe_tools.py est donc charge par son
chemin, avec `config.database`, `config.settings` et `services.cache_service`
remplaces par des stubs dans sys.modules. La base n'est jamais atteinte : la
connexion factice enregistre le SQL execute et rejoue les reponses attendues
(resolution du code fichier / organisation, DELETE, MAX(raw_id), detection
des colonnes d'audit) ; execute_values est monkeypatche pour capturer les
tuples et le template.
"""
import importlib.util
import os
import sys
import types

import psycopg2.extras
import pytest
from flask import Flask

BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODULE_PATH = os.path.join(BACKEND, 'api', 'maintenance_pe_tools.py')
FIXTURE = os.path.join(os.path.dirname(__file__), 'fixtures', 'petool_mcar_extrait.csv')

if BACKEND not in sys.path:
    sys.path.insert(0, BACKEND)


def _stub_module(name: str, **attrs):
    module = types.ModuleType(name)
    for key, value in attrs.items():
        setattr(module, key, value)
    return module


@pytest.fixture(scope='module')
def petools():
    """Charge api/maintenance_pe_tools.py hors du paquet `api`, avec ses
    dependances base/cache remplacees par des stubs."""
    saved = {n: sys.modules.get(n) for n in ('config.database', 'config.settings', 'services.cache_service')}

    class _Config:
        MAINTENANCE_CACHE_TTL = 60

    sys.modules['config.database'] = _stub_module(
        'config.database', get_db_connection=lambda: (_ for _ in ()).throw(RuntimeError('pas de base')))
    sys.modules['config.settings'] = _stub_module('config.settings', Config=_Config)
    sys.modules['services.cache_service'] = _stub_module(
        'services.cache_service',
        cache_get=lambda key: None, cache_set=lambda *a, **k: None, cache_invalidate=lambda *a, **k: None)

    spec = importlib.util.spec_from_file_location('maintenance_pe_tools_sous_test', MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    yield module

    for name, original in saved.items():
        if original is None:
            sys.modules.pop(name, None)
        else:
            sys.modules[name] = original


@pytest.fixture
def app_context():
    """current_app.logger est utilise dans le except de _import_one_file."""
    app = Flask('test_pe_tools_import')
    with app.app_context():
        yield app


class FakeCursor:
    """Enregistre le SQL execute et rejoue les reponses attendues par la route."""

    def __init__(self, journal, *, code='MCAR', org='SJ-MCAR', supprimees=3, max_id=1760, audit=2):
        self.journal = journal
        self._code = code
        self._org = org
        self._supprimees = supprimees
        self._max_id = max_id
        self._audit = audit
        self._reponse = None
        self.rowcount = -1

    def execute(self, sql, params=None):
        self.journal.append((' '.join(sql.split()), params))
        if 'pg_advisory_xact_lock' in sql:
            self._reponse = None
        elif sql.lstrip().upper().startswith('SELECT public.pe_tools_code_fichier'.upper()):
            self._reponse = {'code': self._code, 'org': self._org}
        elif sql.lstrip().upper().startswith('DELETE'):
            self.rowcount = self._supprimees
        elif 'MAX(raw_id)' in sql:
            self._reponse = {'max_id': self._max_id}
        elif 'information_schema.columns' in sql:
            self._reponse = {'nb': self._audit}
        else:
            raise AssertionError(f'SQL inattendu : {sql}')

    def fetchone(self):
        return self._reponse


class FakeConnection:
    def __init__(self, rollback_ko=False, **cursor_kwargs):
        self.journal = []
        self.commits = 0
        self.rollbacks = 0
        self._rollback_ko = rollback_ko
        self._cursor_kwargs = cursor_kwargs

    def cursor(self, cursor_factory=None):
        return FakeCursor(self.journal, **self._cursor_kwargs)

    def commit(self):
        self.commits += 1

    def rollback(self):
        self.rollbacks += 1
        if self._rollback_ko:
            raise RuntimeError('connexion perdue')


@pytest.fixture
def capture_execute_values(monkeypatch):
    captures = []

    def fake_execute_values(cursor, sql, rows, template=None, page_size=100):
        captures.append({'sql': sql, 'rows': list(rows), 'template': template, 'page_size': page_size})

    monkeypatch.setattr(psycopg2.extras, 'execute_values', fake_execute_values)
    return captures


@pytest.fixture
def audit_detecte(petools):
    """La detection des colonnes d'audit est memorisee au niveau module :
    on repart de zero pour chaque test."""
    petools._audit_available = None
    yield
    petools._audit_available = None


@pytest.fixture
def contenu_fixture():
    with open(FIXTURE, 'rb') as f:
        return f.read()


def test_import_ok_remplace_par_fichier(petools, app_context, capture_execute_values, audit_detecte, contenu_fixture):
    conn = FakeConnection()
    resultat = petools._import_one_file(conn, 'PeTool - 7.MCAR.csv', contenu_fixture, 'samir')

    assert resultat['status'] == 'ok', resultat
    assert 'error' not in resultat
    assert resultat['fichier'] == 'PeTool - 7.MCAR.csv'
    assert resultat['code_fichier'] == 'MCAR'
    assert resultat['organisation_maintenance'] == 'SJ-MCAR'
    assert resultat['lignes_supprimees'] == 3
    assert resultat['lignes_inserees'] == 2
    assert resultat['avertissements'] == []

    assert conn.commits == 1
    assert conn.rollbacks == 0

    # Ordre des requetes : verrou -> resolution org -> DELETE -> MAX -> detection audit.
    sqls = [sql for sql, _ in conn.journal]
    assert sqls[0] == 'SELECT pg_advisory_xact_lock(778814)'
    assert sqls[1].startswith('SELECT public.pe_tools_code_fichier')
    # Remplacement par CODE de fichier : "PeTool - 7.MCAR (1).csv" ou
    # "petool - 7.mcar.csv" remplacent les lignes de "PeTool - 7.MCAR.csv".
    assert sqls[2] == 'DELETE FROM raw_data.pe_tools WHERE public.pe_tools_code_fichier(nom_fichier) = %s'
    assert conn.journal[2][1] == ['MCAR']
    assert 'MAX(raw_id)' in sqls[3]
    assert 'information_schema.columns' in sqls[4]

    assert len(capture_execute_values) == 1
    capture = capture_execute_values[0]
    assert capture['sql'].startswith('INSERT INTO raw_data.pe_tools (raw_id, localisation_classement, ')
    assert capture['sql'].endswith('nom_fichier, organisation_maintenance, imported_at, updated_at, updated_by) VALUES %s')
    assert capture['template'].count('%s') == 27
    assert capture['template'].endswith(', NOW(), NOW(), %s)')
    assert capture['page_size'] == 500

    rows = capture['rows']
    assert len(rows) == 2
    assert rows[0][0] == 1761
    assert rows[1][0] == 1762
    assert rows[0][-1] == 'samir'
    assert rows[0][-2] == 'SJ-MCAR'
    assert rows[0][-3] == 'PeTool - 7.MCAR.csv'
    # 1 raw_id + 23 colonnes metier + nom_fichier + org + updated_by
    assert len(rows[0]) == 1 + len(petools.PE_TOOLS_COLUMNS) + 3
    # Colonnes metier dans l'ordre de PE_TOOLS_COLUMNS
    assert rows[0][1] == 'MSA2'
    assert rows[0][3] == 'T120-L020'


def test_import_sans_audit_ni_organisation(petools, app_context, capture_execute_values, audit_detecte, contenu_fixture):
    conn = FakeConnection(org=None, supprimees=0, max_id=0, audit=0)
    resultat = petools._import_one_file(conn, 'PeTool - 7.MCAR.csv', contenu_fixture, 'samir')

    assert resultat['status'] == 'ok', resultat
    assert resultat['organisation_maintenance'] is None
    assert resultat['lignes_supprimees'] == 0
    assert resultat['lignes_inserees'] == 2
    assert any('absent de public.pe_tools_organisation' in a for a in resultat['avertissements'])

    capture = capture_execute_values[0]
    assert 'updated_by' not in capture['sql']
    assert capture['template'].count('%s') == 26
    assert capture['template'].endswith(', NOW())')
    assert capture['rows'][0][0] == 1
    assert capture['rows'][0][-1] is None  # organisation non resolue
    assert len(capture['rows'][0]) == 1 + len(petools.PE_TOOLS_COLUMNS) + 2
    assert conn.commits == 1
    assert conn.rollbacks == 0


def test_import_extension_invalide(petools, app_context, capture_execute_values, audit_detecte, contenu_fixture):
    conn = FakeConnection()
    resultat = petools._import_one_file(conn, 'PeTool - 7.MCAR.xlsx', contenu_fixture, 'samir')

    assert resultat['status'] == 'error'
    assert resultat['error'] == 'Extension attendue : .csv'
    assert resultat['lignes_supprimees'] == 0
    assert resultat['lignes_inserees'] == 0
    assert conn.journal == []  # aucun SQL execute
    assert conn.commits == 0
    assert conn.rollbacks == 1
    assert capture_execute_values == []


def test_import_contenu_non_pe_tools(petools, app_context, capture_execute_values, audit_detecte):
    conn = FakeConnection()
    resultat = petools._import_one_file(conn, 'autre.csv', b'a;b;c\n1;2;3\n', 'samir')

    assert resultat['status'] == 'error'
    assert 'En-tete non reconnue' in resultat['error']
    assert conn.journal == []
    assert conn.commits == 0
    assert conn.rollbacks == 1


def test_import_erreur_sql_rollback(petools, app_context, audit_detecte, contenu_fixture, monkeypatch):
    def execute_values_ko(*args, **kwargs):
        raise RuntimeError('duplicate key value violates unique constraint')

    monkeypatch.setattr(psycopg2.extras, 'execute_values', execute_values_ko)
    conn = FakeConnection()
    resultat = petools._import_one_file(conn, 'PeTool - 7.MCAR.csv', contenu_fixture, 'samir')

    assert resultat['status'] == 'error'
    assert 'duplicate key' in resultat['error']
    # Le DELETE a ete annule par le rollback : les compteurs repartent a 0.
    assert resultat['lignes_supprimees'] == 0
    assert resultat['lignes_inserees'] == 0
    assert conn.commits == 0
    assert conn.rollbacks == 1


def test_import_fichier_sans_lignes_ne_purge_pas(petools, app_context, capture_execute_values, audit_detecte):
    entete = ('Localisation / Classement;Gamme en DMS;Poste technique;Niveau SAP;Plan Entretien;'
              'Poste entretien;Groupe de Gamme;Compteur de Gamme;Frequence;Désignation\n').encode('cp850')
    conn = FakeConnection()
    resultat = petools._import_one_file(conn, 'PeTool - 7.MCAR.csv', entete, 'samir')

    assert resultat['status'] == 'error'
    assert 'Aucune ligne de données' in resultat['error']
    assert conn.journal == []  # refuse AVANT tout SQL : rien n'est supprime
    assert conn.commits == 0
    assert conn.rollbacks == 1
    assert capture_execute_values == []


def test_import_nom_sans_code_remplace_a_l_identique(petools, app_context, capture_execute_values, audit_detecte, contenu_fixture):
    conn = FakeConnection(code=None, org=None)
    resultat = petools._import_one_file(conn, 'export_ecran.csv', contenu_fixture, 'samir')

    assert resultat['status'] == 'ok', resultat
    assert resultat['code_fichier'] is None
    sqls = [sql for sql, _ in conn.journal]
    assert sqls[2] == 'DELETE FROM raw_data.pe_tools WHERE nom_fichier = %s'
    assert conn.journal[2][1] == ['export_ecran.csv']
    assert any('Code ? absent' in a for a in resultat['avertissements'])


def test_import_rollback_impossible_ne_leve_pas(petools, app_context, audit_detecte, contenu_fixture, monkeypatch):
    def execute_values_ko(*args, **kwargs):
        raise RuntimeError('insert KO')

    monkeypatch.setattr(psycopg2.extras, 'execute_values', execute_values_ko)
    conn = FakeConnection(rollback_ko=True)
    resultat = petools._import_one_file(conn, 'PeTool - 7.MCAR.csv', contenu_fixture, 'samir')

    assert resultat['status'] == 'error'
    assert resultat['error'] == 'insert KO'
    assert resultat['lignes_supprimees'] == 0
    assert conn.rollbacks == 1
    assert conn.commits == 0
