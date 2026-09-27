"""
Routes proxy /api/v1/extraction/textes/* (2026-09-20) : relais vers l'API
sap-extraction (conteneur pyrfc_app, routes /textes/*) qui lit les textes
longs STXH/STXL par RFC_READ_TEXT dans raw_data.sap_long_text.

Sans SAP ni base : `requests` est double dans services.extraction_service.
Le statut HTTP amont (409 job deja en cours, 400 objet invalide) est relaye
tel quel au front, avec le detail renvoye par l'API SAP.

    docker exec migration-app-backend python -m pytest tests/test_extraction_textes_routes.py -q
"""
import os
import sys
from unittest import mock

import pytest
from flask import Flask
from flask_jwt_extended import JWTManager

BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BACKEND not in sys.path:
    sys.path.insert(0, BACKEND)

BASE = '/api/v1/extraction'


class _Resp:
    def __init__(self, status=200, payload=None):
        self.status_code = status
        self._payload = payload if payload is not None else {}

    def json(self):
        return self._payload

    def raise_for_status(self):
        if self.status_code >= 400:
            import requests
            err = requests.HTTPError(f'{self.status_code}')
            err.response = self
            raise err


@pytest.fixture
def client():
    app = Flask(__name__)
    app.config['JWT_SECRET_KEY'] = 'test'
    app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('SQLALCHEMY_DATABASE_URI', 'postgresql://x:y@localhost:1/z')
    JWTManager(app)
    with mock.patch('services.extraction_service.ExtractionService.initialize'):
        from api.extraction import extraction_blueprint
        app.register_blueprint(extraction_blueprint, url_prefix=BASE)
    return app.test_client()


def test_lancement_relaye_en_202_avec_l_objet_normalise(client):
    with mock.patch('services.extraction_service.requests.post',
                    return_value=_Resp(200, {'textes_job_id': 'j1', 'status': 'pending', 'objet': 'EINA'})) as post:
        r = client.post(f'{BASE}/textes/extract', json={'objet': 'eina', 'tdids': ['at'], 'purge': False})
    assert r.status_code == 202
    assert r.get_json()['textes_job_id'] == 'j1'
    assert post.call_args.args[0].endswith('/textes/extract')
    assert post.call_args.kwargs['json'] == {'objet': 'EINA', 'tdids': ['AT'], 'langues': None, 'purge': False}


def test_objet_manquant_refuse_sans_appeler_l_api_sap(client):
    with mock.patch('services.extraction_service.requests.post') as post:
        r = client.post(f'{BASE}/textes/extract', json={'tdids': ['AT']})
    assert r.status_code == 400
    post.assert_not_called()


def test_statut_amont_409_relaye_avec_son_detail(client):
    with mock.patch('services.extraction_service.requests.post',
                    return_value=_Resp(409, {'detail': 'Une extraction de textes est deja en cours'})):
        r = client.post(f'{BASE}/textes/extract', json={'objet': 'EINE'})
    assert r.status_code == 409
    assert 'deja en cours' in r.get_json()['error']


def test_inventaire_statut_logs_et_annulation_relayes(client):
    inventaire = [{'objet': 'EINA', 'tdid': 'AT', 'langue': 'F', 'entetes': 8472, 'charges': 8472, 'loadedAt': None}]
    with mock.patch('services.extraction_service.requests.get', return_value=_Resp(200, inventaire)) as get:
        r = client.get(f'{BASE}/textes/objets?objet=EINA')
    assert r.status_code == 200 and r.get_json() == inventaire
    assert get.call_args.kwargs['params'] == {'objet': 'EINA'}

    statut = {'id': 'j1', 'status': 'running', 'progress': 40}
    with mock.patch('services.extraction_service.requests.get', return_value=_Resp(200, statut)):
        assert client.get(f'{BASE}/textes/status/j1').get_json() == statut
        assert client.get(f'{BASE}/textes/jobs').get_json() == statut  # meme doublure, on verifie le relais

    logs = {'logs': ['2026-09-20T00:11:34 [INFO] Inventaire EINA : 8648 cles']}
    with mock.patch('services.extraction_service.requests.get', return_value=_Resp(200, logs)):
        r = client.get(f'{BASE}/textes/jobs/j1/logs')
    assert r.status_code == 200
    assert r.get_json()[0]['message'] == 'Inventaire EINA : 8648 cles'

    with mock.patch('services.extraction_service.requests.post', return_value=_Resp(200, {'message': 'ok'})) as post:
        r = client.post(f'{BASE}/textes/jobs/j1/cancel')
    assert r.status_code == 200
    assert post.call_args.args[0].endswith('/textes/jobs/j1/cancel')
