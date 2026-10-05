"""
POST /api/v1/extraction/start (2026-10-05) : le choix « Recharger depuis le début »
est relayé à l'API :8000 sous la seule forme `rechargement_complet: <bool>`.
Aucun synonyme de complet (truncate_before, clean, mode complet/complete) ne doit
partir, sinon toutes les extractions resteraient en complet.

Sans SAP ni base : `requests` et le moteur SQLAlchemy sont doublés.

    docker exec migration-app-backend python -m pytest tests/test_extraction_rechargement_complet.py -q
"""
import os
import sys
from unittest import mock

import pytest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_extraction_textes_routes import BASE, _Resp, client  # noqa: E402,F401 (fixture)


def _lancer(client, body):
    from services.extraction_service import extraction_service
    with mock.patch.object(extraction_service, 'engine', mock.MagicMock()), \
         mock.patch('services.extraction_service.requests.post',
                    return_value=_Resp(200, {'extraction_id': 'j1', 'persisted_db': True})) as post:
        r = client.post(f'{BASE}/start', json=body)
    return r, post


def _sans_synonyme(payload):
    assert 'truncate_before' not in payload and 'clean' not in payload
    assert payload['mode'] not in ('complet', 'complete')


@pytest.mark.parametrize('body, attendu', [
    ({'tables': ['AUFK']}, False),                                               # absent -> delta
    ({'tables': ['AUFK'], 'options': {'rechargement_complet': False}}, False),
    ({'tables': ['AUFK'], 'options': {'rechargement_complet': True}}, True),
    ({'tables': ['AUFK'], 'rechargement_complet': True}, True),                  # premier niveau
    ({'tables': ['AUFK'], 'rechargement_complet': True,
      'options': {'rechargement_complet': False}}, False),                       # options prime
    # anciens synonymes envoyés par un vieux front : ignorés
    ({'tables': ['AUFK'], 'options': {'clean': True, 'mode': 'complet'}}, False),
])
def test_body_relaye(client, body, attendu):
    r, post = _lancer(client, body)
    assert r.status_code == 202
    payload = post.call_args.kwargs['json']
    assert payload['rechargement_complet'] is attendu
    _sans_synonyme(payload)


def test_valeur_non_booleenne_refusee(client):
    r, post = _lancer(client, {'tables': ['AUFK'], 'options': {'rechargement_complet': 'oui'}})
    assert r.status_code == 400
    post.assert_not_called()
