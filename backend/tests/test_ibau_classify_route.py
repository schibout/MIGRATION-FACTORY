"""
POST /maintenance/ibau/classify : recalcul de la classification IBAU
(bouton « Classifier les IBAU » des ecrans IH02 et Referentiel IBAU) et
exposition du cas dans la liste / le filtre / les stats du referentiel.

Vraie base, transaction jamais validee (commit neutralise), migration 079
rejouee dans la transaction ; cache Redis remplace par un dictionnaire.
"""
import importlib.util
import os
import sys

import psycopg2
import psycopg2.extras
import pytest
from flask import Flask
from flask_jwt_extended import JWTManager, create_access_token

BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODULE_PATH = os.path.join(BACKEND, 'api', 'maintenance_ibau.py')
if BACKEND not in sys.path:
    sys.path.insert(0, BACKEND)

from tests.ibau_schema_helper import charger_migration_079  # noqa: E402

BASE = '/api/v1/maintenance'


class _TxConnection:
    def __init__(self, conn):
        self._conn = conn

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def cursor(self, *args, **kwargs):
        return self._conn.cursor(*args, **kwargs)

    def commit(self):
        pass

    def rollback(self):
        self._conn.rollback()


@pytest.fixture
def tx():
    try:
        from config.database import get_db_params
        conn = psycopg2.connect(**get_db_params())
    except Exception as exc:  # pragma: no cover
        pytest.skip(f'base injoignable : {exc}')
    cur = conn.cursor()
    charger_migration_079(cur)
    yield _TxConnection(conn)
    conn.rollback()
    conn.close()


@pytest.fixture
def cache():
    return {}


@pytest.fixture
def ibau_api(tx, cache, monkeypatch):
    spec = importlib.util.spec_from_file_location('maintenance_ibau_sous_test', MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    monkeypatch.setattr(module, 'get_db_connection', lambda: tx)
    monkeypatch.setattr(module, 'cache_get', lambda key: cache.get(key))
    monkeypatch.setattr(module, 'cache_set', lambda key, value, ttl=None: cache.__setitem__(key, value))
    monkeypatch.setattr(module, 'cache_invalidate',
                        lambda prefix: [cache.pop(k) for k in list(cache) if k.startswith(prefix)])
    return module


@pytest.fixture
def client(ibau_api):
    app = Flask('test_ibau_classify')
    app.config['JWT_SECRET_KEY'] = 'test-secret'
    JWTManager(app)
    app.register_blueprint(ibau_api.maintenance_ibau_blueprint, url_prefix=BASE)
    with app.app_context():
        token = create_access_token(identity='samir')
    c = app.test_client()
    c.environ_base['HTTP_AUTHORIZATION'] = f'Bearer {token}'
    return c


@pytest.fixture
def anon(ibau_api):
    app = Flask('test_ibau_classify_anon')
    app.config['JWT_SECRET_KEY'] = 'test-secret'
    JWTManager(app)
    app.register_blueprint(ibau_api.maintenance_ibau_blueprint, url_prefix=BASE)
    return app.test_client()


def test_classify_exige_un_jeton(anon):
    assert anon.post(f'{BASE}/ibau/classify').status_code == 401


def test_classify_renvoie_les_compteurs_et_la_date(client):
    r = client.post(f'{BASE}/ibau/classify')
    assert r.status_code == 200, r.get_json()
    data = r.get_json()['data']
    assert set(data['compteurs']) == {'CONSERVER', 'POSTE_TECHNIQUE', 'ARTICLE'}
    assert sum(data['compteurs'].values()) > 8000, 'ordre de grandeur des IBAU de la structure'
    assert data['cas_calcule_at']


def test_classify_invalide_le_cache_du_referentiel(client, cache):
    client.get(f'{BASE}/ibau/stats')
    assert any(k.startswith('maint:ibau:') for k in cache), 'les stats sont mises en cache'
    client.post(f'{BASE}/ibau/classify')
    assert not any(k.startswith('maint:ibau:') for k in cache)


def test_la_liste_expose_le_cas_et_se_filtre_dessus(client):
    client.post(f'{BASE}/ibau/classify')
    r = client.get(f'{BASE}/ibau?cas_ibau=CONSERVER&per_page=5')
    data = r.get_json()
    assert data['total'] > 0
    assert {row['cas_ibau'] for row in data['data']} == {'CONSERVER'}
    assert 'nb_enfants' in data['data'][0] and 'nb_occurrences' in data['data'][0]


def test_le_filtre_hors_structure(client):
    """cas_ibau=NONE : IBAU de la liste absents de la structure (cas NULL)."""
    client.post(f'{BASE}/ibau/classify')
    r = client.get(f'{BASE}/ibau?cas_ibau=NONE&per_page=5')
    data = r.get_json()
    assert all(row['cas_ibau'] is None for row in data['data'])


def test_les_stats_comptent_par_cas(client):
    client.post(f'{BASE}/ibau/classify')
    stats = client.get(f'{BASE}/ibau/stats').get_json()['data']
    assert stats['nb_conserver'] > 0 and stats['nb_poste_technique'] > 0 and stats['nb_article'] > 0
    assert stats['cas_calcule_at']


def test_export_csv_porte_le_cas(client):
    client.post(f'{BASE}/ibau/classify')
    r = client.get(f'{BASE}/ibau/export?cas_ibau=ARTICLE')
    assert r.status_code == 200
    lignes = r.get_data(as_text=True).splitlines()
    assert 'cas_ibau' in lignes[0].split(';')
    assert len(lignes) > 1 and all(';ARTICLE;' in l or l.endswith(';ARTICLE') or 'ARTICLE' in l for l in lignes[1:3])
