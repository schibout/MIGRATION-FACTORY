"""
POST /add-node : recreer un poste technique supprime (soft delete).

Bug du 2026-09-17 (T630-S) : la suppression passe is_active=false mais la
contrainte uq_mo_type_key (object_type, sap_key) ignore is_active, et
_resolve_id aussi -> « L'identifiant existe deja » (409) pour toujours.
Comportement attendu : la ligne inactive est REACTIVEE avec les nouvelles
valeurs (parent, designation...), au lieu d'etre refusee.

Test d'integration sur la VRAIE base (schema, contraintes, index), dans une
transaction jamais validee : commit() est neutralise et tout est annule en
fin de test. Saute si la base est injoignable (hors conteneur backend).
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

# Cle SAP de test : prefixe improbable, jamais dans SAP ni dans l'ecran.
ROOT = 'T'
SAP_KEY = 'ZZTEST-REACT'


def _connect():
    try:
        from config.database import get_db_params
        return psycopg2.connect(**get_db_params())
    except Exception as exc:  # pragma: no cover - selon l'environnement
        pytest.skip(f'base injoignable : {exc}')


class _TxConnection:
    """Connexion reelle dont commit() ne fait rien et dont la sortie du `with`
    ne valide rien : la transaction reste ouverte jusqu'au rollback final."""

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
        # Le code appelle rollback() apres une UniqueViolation : on doit alors
        # revenir a l'etat d'avant l'INSERT sans perdre le reste du test.
        self._conn.rollback()


@pytest.fixture
def tx():
    conn = _connect()
    tx = _TxConnection(conn)
    yield tx
    conn.rollback()
    conn.close()


@pytest.fixture
def ih02(tx, monkeypatch):
    spec = importlib.util.spec_from_file_location('ih02_hierarchy_sous_test', MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    monkeypatch.setattr(module, 'get_db_connection', lambda: tx)
    monkeypatch.setattr(module, '_current_user', lambda: 'test-reactivation')
    return module


@pytest.fixture
def client(ih02, monkeypatch):
    app = Flask('test_ih02_add_node')
    app.register_blueprint(ih02.ih02_hierarchy_blueprint, url_prefix='/api/v1/ih02')
    # Le garde before_request importe active_job_conflict a chaque appel :
    # aucun job maintenance en cours pour ce test.
    import api.maintenance_snapshots as snapshots
    monkeypatch.setattr(snapshots, 'active_job_conflict', lambda: None)
    return app.test_client()


def _row(tx, sap_key):
    cur = tx.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute(
        "SELECT id, code, designation, is_active, source, updated_by, "
        "       (SELECT sap_key FROM clean_data.maintenance_object p WHERE p.id = m.parent_id) AS parent_key "
        "FROM clean_data.maintenance_object m WHERE object_type = 'FUNC_LOC' AND sap_key = %s",
        [sap_key])
    rows = cur.fetchall()
    assert len(rows) <= 1, rows
    return rows[0] if rows else None


def _add(client, node_id, designation, parent=ROOT):
    return client.post('/api/v1/ih02/add-node',
                       json={'parent_id': parent, 'node_id': node_id, 'designation': designation})


def test_recreer_un_poste_supprime_le_reactive(client, tx):
    assert _row(tx, SAP_KEY) is None, 'residu d un test precedent'

    r = _add(client, SAP_KEY, 'Premiere creation')
    assert r.status_code == 201, r.get_json()
    original = _row(tx, SAP_KEY)
    assert original['is_active'] is True

    r = client.delete(f'/api/v1/ih02/delete-node?node_id={SAP_KEY}')
    assert r.status_code == 200, r.get_json()
    assert _row(tx, SAP_KEY)['is_active'] is False

    # Le cas T630-S : meme identifiant, recree apres suppression.
    r = _add(client, SAP_KEY, 'Recree apres suppression')
    assert r.status_code == 201, r.get_json()

    row = _row(tx, SAP_KEY)
    assert row['is_active'] is True
    assert row['id'] == original['id'], 'la ligne inactive doit etre reutilisee, pas dupliquee'
    assert row['designation'] == 'Recree apres suppression'
    assert row['parent_key'] == ROOT
    assert row['updated_by'] == 'test-reactivation'


def test_un_poste_actif_reste_refuse(client, tx):
    r = _add(client, SAP_KEY, 'Premiere creation')
    assert r.status_code == 201, r.get_json()

    r = _add(client, SAP_KEY, 'Doublon')
    assert r.status_code == 409
    assert 'existe' in r.get_json()['error']
    assert _row(tx, SAP_KEY)['designation'] == 'Premiere creation'


def test_reactivation_sous_un_autre_parent(client, tx):
    """Le poste supprime peut etre recree ailleurs : le nouveau parent prime."""
    cur = tx.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute("SELECT sap_key FROM clean_data.maintenance_object "
                "WHERE object_type = 'FUNC_LOC' AND is_active AND sap_key <> %s "
                "  AND parent_id = (SELECT id FROM clean_data.maintenance_object "
                "                   WHERE object_type = 'FUNC_LOC' AND sap_key = %s) "
                "ORDER BY sap_key LIMIT 1", [ROOT, ROOT])
    autre_parent = cur.fetchone()['sap_key']

    assert _add(client, SAP_KEY, 'Sous la racine').status_code == 201
    assert client.delete(f'/api/v1/ih02/delete-node?node_id={SAP_KEY}').status_code == 200

    r = _add(client, SAP_KEY, 'Sous un autre parent', parent=autre_parent)
    assert r.status_code == 201, r.get_json()
    assert _row(tx, SAP_KEY)['parent_key'] == autre_parent
