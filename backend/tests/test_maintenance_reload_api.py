"""
Tests de l'API des etats maintenance (api/maintenance_snapshots.py) et de
l'orchestration des jobs (services/maintenance_reload_service.py).

App Flask minimale, aucune base : les services sont simules. On verifie surtout
ce qui protege les donnees — authentification exigee, refus des operations
concurrentes (409), validation des modes, sauvegarde automatique avant
rechargement.
"""
import os
import importlib.util
from unittest.mock import MagicMock, patch

import pytest
from flask import Flask
from flask_jwt_extended import JWTManager, create_access_token

from services import maintenance_reload_service as jobs

# Import PAR CHEMIN : evite api/__init__.py qui charge toute la pile de blueprints.
_API_PATH = os.path.join(os.path.dirname(__file__), '..', 'api', 'maintenance_snapshots.py')
_spec = importlib.util.spec_from_file_location('maintenance_snapshots_module', _API_PATH)
api_module = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(api_module)
maintenance_snapshots_blueprint = api_module.maintenance_snapshots_blueprint

BASE = '/api/v1/maintenance'


def _make_app():
    app = Flask(__name__)
    app.config['JWT_SECRET_KEY'] = 'test-secret'
    JWTManager(app)
    app.register_blueprint(maintenance_snapshots_blueprint, url_prefix=BASE)
    return app


@pytest.fixture()
def app():
    return _make_app()


@pytest.fixture()
def client(app):
    with app.app_context():
        token = create_access_token(identity='samir')
    c = app.test_client()
    c.environ_base['HTTP_AUTHORIZATION'] = f'Bearer {token}'
    return c


@pytest.fixture()
def anon(app):
    """Client sans jeton JWT."""
    return app.test_client()


# --------------------------------------------------------------------------- #
# Authentification : toutes les routes sont protegees
# --------------------------------------------------------------------------- #
@pytest.mark.parametrize('method,path', [
    ('get', f'{BASE}/snapshots'),
    ('post', f'{BASE}/snapshots'),
    ('delete', f'{BASE}/snapshots/1'),
    ('post', f'{BASE}/snapshots/1/restore'),
    ('post', f'{BASE}/reload'),
    ('get', f'{BASE}/jobs'),
    ('get', f'{BASE}/jobs/1'),
    ('get', f'{BASE}/jobs/active'),
])
def test_toutes_les_routes_exigent_un_jwt(anon, method, path):
    response = getattr(anon, method)(path)
    assert response.status_code == 401, f"{method.upper()} {path} doit exiger un JWT"


# --------------------------------------------------------------------------- #
# Creation d'un etat
# --------------------------------------------------------------------------- #
def test_creation_sans_nom_renvoie_400(client):
    r = client.post(f'{BASE}/snapshots', json={'name': '  '})
    assert r.status_code == 400


def test_creation_transmet_le_nom_et_l_utilisateur(client):
    with patch.object(api_module.jobs, 'peek_active_job', return_value=False), \
            patch.object(api_module.snapshots, 'create_snapshot',
                         return_value={'id': 1}) as create:
        r = client.post(f'{BASE}/snapshots',
                        json={'name': 'Avant reprise', 'description': 'atelier 3'})

    assert r.status_code == 201
    assert create.call_args.kwargs['name'] == 'Avant reprise'
    assert create.call_args.kwargs['kind'] == 'MANUAL'
    assert create.call_args.kwargs['user'] == 'samir'


def test_creation_refusee_pendant_une_operation(client):
    actif = {'id': 4, 'job_type': 'RELOAD', 'current_step': 'Extraction SAP en cours'}
    with patch.object(api_module.jobs, 'peek_active_job', return_value=True), \
            patch.object(api_module.jobs, 'get_active_job', return_value=actif):
        r = client.post(f'{BASE}/snapshots', json={'name': 'x'})

    assert r.status_code == 409


# --------------------------------------------------------------------------- #
# Restauration
# --------------------------------------------------------------------------- #
def test_restauration_d_un_etat_inconnu_renvoie_404(client):
    with patch.object(api_module.snapshots, 'get_snapshot', return_value=None):
        r = client.post(f'{BASE}/snapshots/42/restore')
    assert r.status_code == 404


def test_restauration_d_un_etat_en_echec_renvoie_400(client):
    snap = {'id': 42, 'name': 'x', 'status': 'FAILED'}
    with patch.object(api_module.snapshots, 'get_snapshot', return_value=snap):
        r = client.post(f'{BASE}/snapshots/42/restore')
    assert r.status_code == 400


def test_restauration_cree_un_job_et_repond_202(client):
    snap = {'id': 42, 'name': 'x', 'status': 'READY'}
    job = {'id': 9, 'job_type': 'RESTORE', 'status': 'PENDING'}
    with patch.object(api_module.snapshots, 'get_snapshot', return_value=snap), \
            patch.object(api_module.jobs, 'create_job', return_value=job) as create, \
            patch.object(api_module.jobs, 'start_job') as start:
        r = client.post(f'{BASE}/snapshots/42/restore')

    assert r.status_code == 202
    assert r.get_json()['data']['id'] == 9
    assert create.call_args[0][0] == 'RESTORE'
    assert create.call_args[0][1] == {'snapshot_id': 42}
    assert start.called


def test_restauration_refusee_si_operation_en_cours(client):
    snap = {'id': 42, 'name': 'x', 'status': 'READY'}
    with patch.object(api_module.snapshots, 'get_snapshot', return_value=snap), \
            patch.object(api_module.jobs, 'create_job',
                         side_effect=jobs.JobConflictError('deja en cours')):
        r = client.post(f'{BASE}/snapshots/42/restore')
    assert r.status_code == 409


# --------------------------------------------------------------------------- #
# Rechargement depuis SAP
# --------------------------------------------------------------------------- #
def test_reload_refuse_un_mode_inconnu(client):
    r = client.post(f'{BASE}/reload', json={'mode': 'ecraser-tout'})
    assert r.status_code == 400


def test_reload_par_defaut_en_fusion_avec_extraction(client):
    """Le defaut doit etre le mode non destructif."""
    job = {'id': 3, 'job_type': 'RELOAD', 'status': 'PENDING'}
    with patch.object(api_module.jobs, 'create_job', return_value=job) as create, \
            patch.object(api_module.jobs, 'start_job'):
        r = client.post(f'{BASE}/reload', json={})

    assert r.status_code == 202
    params = create.call_args[0][1]
    assert params['mode'] == 'merge'
    assert params['with_extraction'] is True


def test_reload_transmet_le_mode_reset_sans_extraction(client):
    job = {'id': 3, 'job_type': 'RELOAD', 'status': 'PENDING'}
    with patch.object(api_module.jobs, 'create_job', return_value=job) as create, \
            patch.object(api_module.jobs, 'start_job'):
        r = client.post(f'{BASE}/reload',
                        json={'mode': 'reset', 'with_extraction': False})

    assert r.status_code == 202
    params = create.call_args[0][1]
    assert params['mode'] == 'reset'
    assert params['with_extraction'] is False


def test_reload_refuse_si_operation_en_cours(client):
    with patch.object(api_module.jobs, 'create_job',
                      side_effect=jobs.JobConflictError('deja en cours')), \
            patch.object(api_module.jobs, 'start_job') as start:
        r = client.post(f'{BASE}/reload', json={'mode': 'merge'})

    assert r.status_code == 409
    assert not start.called, "aucun traitement ne doit demarrer en cas de conflit"


# --------------------------------------------------------------------------- #
# Garde-fou reutilise par les blueprints d'edition
# --------------------------------------------------------------------------- #
def test_garde_fou_transparent_quand_aucune_operation(app):
    with app.test_request_context():
        with patch.object(api_module.jobs, 'peek_active_job', return_value=False):
            assert api_module.active_job_conflict() is None


def test_garde_fou_renvoie_409_pendant_une_operation(app):
    actif = {'id': 1, 'job_type': 'RESTORE', 'current_step': 'Restauration'}
    with app.test_request_context():
        with patch.object(api_module.jobs, 'peek_active_job', return_value=True), \
                patch.object(api_module.jobs, 'get_active_job', return_value=actif):
            payload, status = api_module.active_job_conflict()
    assert status == 409
    assert payload.get_json()['job']['id'] == 1


def test_garde_fou_ne_bloque_pas_l_ui_si_la_verification_echoue(app):
    """Une panne du garde-fou ne doit pas empecher de travailler."""
    with app.test_request_context():
        with patch.object(api_module.jobs, 'peek_active_job',
                          side_effect=RuntimeError('base injoignable')):
            assert api_module.active_job_conflict() is None


# --------------------------------------------------------------------------- #
# Orchestration : validation et enchainement
# --------------------------------------------------------------------------- #
def test_create_job_refuse_un_type_inconnu():
    with pytest.raises(jobs.JobError):
        jobs.create_job('BOGUS', {})


def test_reload_refuse_un_mode_inconnu_cote_service():
    with pytest.raises(jobs.JobError):
        jobs._run_reload(1, {'mode': 'bogus'}, 'samir')


def test_restore_sans_snapshot_leve_une_erreur():
    with pytest.raises(jobs.JobError):
        jobs._run_restore(1, {}, 'samir')


def test_le_perimetre_d_extraction_couvre_les_sources_de_l_ecran_ih02():
    for table in ('IFLOT', 'IFLOTX', 'ITOB', 'EQUZ', 'MARA', 'MAKT', 'STPO', 'TPST'):
        assert table in jobs.MAINTENANCE_SAP_TABLES


def test_rechargement_sauvegarde_avant_de_reconstruire():
    """Le snapshot de securite doit preceder toute modification des donnees."""
    ordre = []

    def _snapshot(**kwargs):
        ordre.append(('snapshot', kwargs.get('kind')))
        return {'id': 50}

    with patch.object(jobs, '_step'), \
            patch.object(jobs, '_attach_snapshot'), \
            patch.object(jobs, '_refresh_downstream'), \
            patch.object(jobs, '_last_etl_message', return_value=''), \
            patch.object(jobs.snapshots, 'create_snapshot', side_effect=_snapshot), \
            patch.object(jobs, 'get_db_connection') as conn_factory:
        cursor = MagicMock()
        conn_factory.return_value.__enter__.return_value.cursor.return_value \
            .__enter__.return_value = cursor
        cursor.execute.side_effect = lambda q, *a: ordre.append(('sql', q))

        jobs._run_reload(1, {'mode': 'merge', 'with_extraction': False}, 'samir')

    assert ordre[0] == ('snapshot', 'AUTO_PRE_RELOAD')
    appels_sql = [q for kind, q in ordre if kind == 'sql']
    assert any('load_maintenance_object_merge' in q for q in appels_sql)


def test_mode_reset_appelle_la_procedure_destructive():
    with patch.object(jobs, '_step'), \
            patch.object(jobs, '_attach_snapshot'), \
            patch.object(jobs, '_refresh_downstream'), \
            patch.object(jobs, '_last_etl_message', return_value=''), \
            patch.object(jobs.snapshots, 'create_snapshot', return_value={'id': 50}), \
            patch.object(jobs, 'get_db_connection') as conn_factory:
        cursor = MagicMock()
        conn_factory.return_value.__enter__.return_value.cursor.return_value \
            .__enter__.return_value = cursor

        jobs._run_reload(1, {'mode': 'reset', 'with_extraction': False}, 'samir')

    appels = [c.args[0] for c in cursor.execute.call_args_list]
    assert any('CALL clean_data.load_maintenance_object()' in q for q in appels)
    assert not any('merge' in q for q in appels)


def test_job_to_dict_tolere_l_absence_de_ligne():
    assert jobs._job_to_dict(None) is None
