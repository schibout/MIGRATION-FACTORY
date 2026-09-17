"""
Arbre IH02 : les lignes de nomenclature exposent le cas IBAU de l'article
qu'elles referencent (cas_ibau + compteurs), pour la pastille de couleur.

Vraie base, transaction jamais validee, migration 079 rejouee dedans.
"""
import importlib.util
import os
import sys

import psycopg2
import psycopg2.extras
import pytest
from flask import Flask

BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODULE_PATH = os.path.join(BACKEND, 'api', 'ih02_hierarchy.py')
if BACKEND not in sys.path:
    sys.path.insert(0, BACKEND)

from tests.ibau_schema_helper import charger_migration_079  # noqa: E402

MO = 'clean_data.maintenance_object'


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
def client(tx, monkeypatch):
    spec = importlib.util.spec_from_file_location('ih02_hierarchy_bom_sous_test', MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    monkeypatch.setattr(module, 'get_db_connection', lambda: tx)
    app = Flask('test_ih02_bom_cas')
    app.register_blueprint(module.ih02_hierarchy_blueprint, url_prefix='/api/v1/ih02')
    return app.test_client()


def _jaune(tx):
    """Un IBAU CONSERVER reel avec un poste porteur et sa propre nomenclature."""
    cur = tx.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute(f"""
        SELECT a.sap_key AS matnr, fl.sap_key AS tplnr
        FROM {MO} a
        JOIN {MO} b  ON b.ref_object_id = a.id AND b.object_type = 'BOM_ITEM' AND b.is_active
        JOIN {MO} fl ON fl.id = b.parent_id AND fl.object_type = 'FUNC_LOC' AND fl.is_active
        WHERE a.object_type = 'ARTICLE' AND a.cas_ibau = 'CONSERVER'
          AND EXISTS (SELECT 1 FROM {MO} c WHERE c.parent_id = a.id AND c.is_active
                        AND c.attributes->>'stlty' = 'M')
        LIMIT 1""")
    return cur.fetchone()


def test_bom_du_poste_expose_le_cas_de_l_ibau(client, tx):
    ex = _jaune(tx)
    r = client.get(f"/api/v1/ih02/bom/{ex['tplnr']}")
    assert r.status_code == 200
    ligne = next(l for l in r.get_json()['data'] if l['idnrk'] == ex['matnr'])
    assert ligne['cas_ibau'] == 'CONSERVER'
    assert ligne['ibau_nb_enfants'] >= 1 and ligne['ibau_nb_occurrences'] >= 2


def test_bom_d_article_expose_le_cas_des_composants(client, tx):
    ex = _jaune(tx)
    r = client.get(f"/api/v1/ih02/article-bom/{ex['matnr']}")
    assert r.status_code == 200
    lignes = r.get_json()['data']
    assert lignes and all('cas_ibau' in l for l in lignes)
