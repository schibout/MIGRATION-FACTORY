"""Tests du proxy Hermes (api/hermes.py) : validation, erreurs config/reseau,
construction du message system, relai non-stream. App Flask minimale (pas de DB)."""
import os
import importlib.util
from unittest.mock import patch, MagicMock

import pytest
from flask import Flask
from flask_jwt_extended import JWTManager, create_access_token

# Import du module PAR CHEMIN pour ne pas déclencher api/__init__.py (qui importe
# toute la pile de blueprints, dont des dépendances absentes hors serveur).
_HERMES_PATH = os.path.join(os.path.dirname(__file__), '..', 'api', 'hermes.py')
_spec = importlib.util.spec_from_file_location('hermes_module', _HERMES_PATH)
hermes_module = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(hermes_module)
hermes_blueprint = hermes_module.hermes_blueprint


_CFG_OK = {'base_url': 'http://hermes.test/v1', 'api_key': 'k-test', 'read_timeout': 300}
_CFG_SANS_CLE = {'base_url': 'http://hermes.test/v1', 'api_key': '', 'read_timeout': 300}


@pytest.fixture()
def client():
    app = Flask(__name__)
    app.config['JWT_SECRET_KEY'] = 'test-secret'
    JWTManager(app)
    app.register_blueprint(hermes_blueprint, url_prefix='/api/v1/hermes')
    with app.app_context():
        token = create_access_token(identity='tester')
    c = app.test_client()
    c.environ_base['HTTP_AUTHORIZATION'] = f'Bearer {token}'
    return c


def _upstream(status=200, body=None, text=''):
    resp = MagicMock()
    resp.status_code = status
    resp.json.return_value = body if body is not None else {}
    resp.text = text
    return resp


# --------------------------------------------------------------------------- #
# Validation / configuration
# --------------------------------------------------------------------------- #
def test_messages_vides_renvoie_400(client):
    r = client.post('/api/v1/hermes/chat', json={'messages': []})
    assert r.status_code == 400


def test_role_inconnu_renvoie_400(client):
    r = client.post('/api/v1/hermes/chat',
                    json={'messages': [{'role': 'robot', 'content': 'x'}]})
    assert r.status_code == 400


def test_sans_jwt_renvoie_401(client):
    r = client.post('/api/v1/hermes/chat',
                    json={'messages': [{'role': 'user', 'content': 'x'}]},
                    headers={'Authorization': ''})
    assert r.status_code == 401


def test_cle_manquante_renvoie_500_explicite(client):
    with patch.object(hermes_module, '_hermes_config', return_value=_CFG_SANS_CLE):
        r = client.post('/api/v1/hermes/chat',
                        json={'messages': [{'role': 'user', 'content': 'x'}]})
    assert r.status_code == 500
    assert 'HERMES_API_KEY' in r.get_json()['error']


# --------------------------------------------------------------------------- #
# Construction des messages (instructions -> system en tete)
# --------------------------------------------------------------------------- #
def test_instructions_prefixees_en_system(client):
    with patch.object(hermes_module, '_hermes_config', return_value=_CFG_OK), \
         patch.object(hermes_module.requests, 'post',
                      return_value=_upstream(body={'ok': True})) as post:
        r = client.post('/api/v1/hermes/chat', json={
            'messages': [{'role': 'system', 'content': 'ancien system a retirer'},
                         {'role': 'user', 'content': 'salut'}],
            'instructions': 'Réponds en français.',
            'stream': False,
        })
    assert r.status_code == 200
    envoye = post.call_args.kwargs['json']['messages']
    assert envoye[0] == {'role': 'system', 'content': 'Réponds en français.'}
    assert all(m['role'] != 'system' for m in envoye[1:])  # l'ancien system est retiré


def test_sans_instructions_pas_de_system(client):
    with patch.object(hermes_module, '_hermes_config', return_value=_CFG_OK), \
         patch.object(hermes_module.requests, 'post',
                      return_value=_upstream(body={'ok': True})) as post:
        client.post('/api/v1/hermes/chat', json={
            'messages': [{'role': 'user', 'content': 'salut'}], 'stream': False,
        })
    envoye = post.call_args.kwargs['json']['messages']
    assert all(m['role'] != 'system' for m in envoye)


# --------------------------------------------------------------------------- #
# Erreurs upstream
# --------------------------------------------------------------------------- #
def test_hermes_injoignable_renvoie_502(client):
    import requests as _rq
    with patch.object(hermes_module, '_hermes_config', return_value=_CFG_OK), \
         patch.object(hermes_module.requests, 'post',
                      side_effect=_rq.exceptions.ConnectionError('down')):
        r = client.post('/api/v1/hermes/chat',
                        json={'messages': [{'role': 'user', 'content': 'x'}]})
    assert r.status_code == 502


def test_timeout_renvoie_504(client):
    import requests as _rq
    with patch.object(hermes_module, '_hermes_config', return_value=_CFG_OK), \
         patch.object(hermes_module.requests, 'post',
                      side_effect=_rq.exceptions.Timeout()):
        r = client.post('/api/v1/hermes/chat',
                        json={'messages': [{'role': 'user', 'content': 'x'}]})
    assert r.status_code == 504


def test_cle_refusee_par_hermes_renvoie_502(client):
    with patch.object(hermes_module, '_hermes_config', return_value=_CFG_OK), \
         patch.object(hermes_module.requests, 'post',
                      return_value=_upstream(status=401, text='unauthorized')):
        r = client.post('/api/v1/hermes/chat',
                        json={'messages': [{'role': 'user', 'content': 'x'}]})
    assert r.status_code == 502
    assert 'HERMES_API_KEY' in r.get_json()['error']


# --------------------------------------------------------------------------- #
# Streaming : relai des octets + en-tetes SSE
# --------------------------------------------------------------------------- #
def test_save_conversation_sans_messages_renvoie_400(client):
    # La validation précède _ensure_schema() -> pas d'accès DB dans ce cas.
    r = client.post('/api/v1/hermes/conversations', json={'messages': []})
    assert r.status_code == 400


def test_save_conversation_sans_role_persistable_renvoie_400(client):
    # Seulement un system (= instructions, non persisté) -> aucun message valide.
    r = client.post('/api/v1/hermes/conversations',
                    json={'messages': [{'role': 'system', 'content': 'x'}]})
    assert r.status_code == 400


# --------------------------------------------------------------------------- #
# Jobs (proxy vers {origin}/api/jobs) + dérivation d'origine
# --------------------------------------------------------------------------- #
def test_hermes_origin_retire_v1():
    assert hermes_module._hermes_origin({'base_url': 'http://10.0.0.1:8642/v1'}) == 'http://10.0.0.1:8642'
    assert hermes_module._hermes_origin({'base_url': 'https://h:9/v1'}) == 'https://h:9'


def test_create_job_body_vide_renvoie_400(client):
    r = client.post('/api/v1/hermes/jobs', json={})
    assert r.status_code == 400


def test_create_job_sans_schedule_renvoie_400(client):
    r = client.post('/api/v1/hermes/jobs', json={'prompt': 'x'})
    assert r.status_code == 400


def test_job_action_invalide_renvoie_400(client):
    r = client.post('/api/v1/hermes/jobs/job_1/explode')
    assert r.status_code == 400


def test_list_jobs_cle_manquante_renvoie_500(client):
    with patch.object(hermes_module, '_hermes_config', return_value=_CFG_SANS_CLE):
        r = client.get('/api/v1/hermes/jobs')
    assert r.status_code == 500


def test_list_jobs_relaie_reponse_hermes(client):
    with patch.object(hermes_module, '_hermes_config', return_value=_CFG_OK), \
         patch.object(hermes_module.requests, 'request',
                      return_value=_upstream(body={'jobs': []})) as req:
        r = client.get('/api/v1/hermes/jobs')
    assert r.status_code == 200
    assert r.get_json() == {'jobs': []}
    # URL appelée = origine SANS /v1
    assert req.call_args.args[1] == 'http://hermes.test/api/jobs'


def test_execute_job_cle_manquante_renvoie_500(client):
    with patch.object(hermes_module, '_hermes_config', return_value=_CFG_SANS_CLE):
        r = client.post('/api/v1/hermes/jobs/job_1/execute')
    assert r.status_code == 500


def test_execute_job_sans_prompt_renvoie_400(client):
    # GET du job renvoie un job sans prompt -> 400 (avant tout appel chat / DB).
    with patch.object(hermes_module, '_hermes_config', return_value=_CFG_OK), \
         patch.object(hermes_module.requests, 'get',
                      return_value=_upstream(body={'job': {'name': 'Sans prompt'}})):
        r = client.post('/api/v1/hermes/jobs/job_1/execute')
    assert r.status_code == 400


def test_agent_status_agrege_capabilities_et_health(client):
    caps = {'features': {'chat_completions': True}}
    health = {'status': 'ok', 'version': '0.18.0'}
    with patch.object(hermes_module, '_hermes_config', return_value=_CFG_OK), \
         patch.object(hermes_module.requests, 'get',
                      side_effect=[_upstream(body=caps), _upstream(body=health)]):
        r = client.get('/api/v1/hermes/agent-status')
    data = r.get_json()
    assert r.status_code == 200 and data['reachable'] is True
    assert data['capabilities'] == caps and data['health'] == health


# --------------------------------------------------------------------------- #
# Ciblage du profil Hermes (/p/<profil>/v1/...)
#
# Le profil est selectionne par l'URL, jamais par le champ "model" du corps :
# cibler le profil par "model" renvoie un 404 (cf. docs/APPEL_HERMES_PROFIL.md).
# --------------------------------------------------------------------------- #
_CFG_PROFIL = {'base_url': 'http://hermes.test/v1', 'api_key': 'k-test',
               'read_timeout': 300, 'profile': 'migration'}


def test_chat_url_insere_le_profil_avant_v1():
    assert (hermes_module._chat_url(_CFG_PROFIL)
            == 'http://hermes.test/p/migration/v1/chat/completions')


def test_chat_url_sans_profil_garde_l_url_historique():
    cfg = dict(_CFG_PROFIL, profile='')
    assert hermes_module._chat_url(cfg) == 'http://hermes.test/v1/chat/completions'


def test_chat_url_tolere_un_profil_absent_de_la_config():
    # Config heritee (sans clef 'profile') : on ne casse pas l'appel par defaut.
    assert hermes_module._chat_url(_CFG_OK) == 'http://hermes.test/v1/chat/completions'


def test_chat_poste_sur_l_url_du_profil(client):
    with patch.object(hermes_module, '_hermes_config', return_value=_CFG_PROFIL), \
         patch.object(hermes_module.requests, 'post',
                      return_value=_upstream(body={'ok': True})) as post:
        r = client.post('/api/v1/hermes/chat', json={
            'messages': [{'role': 'user', 'content': 'x'}], 'stream': False})
    assert r.status_code == 200
    assert post.call_args.args[0] == 'http://hermes.test/p/migration/v1/chat/completions'


def test_model_porte_le_nom_du_profil(client):
    # Champ decoratif : sert a rendre les journaux du gateway lisibles.
    with patch.object(hermes_module, '_hermes_config', return_value=_CFG_PROFIL), \
         patch.object(hermes_module.requests, 'post',
                      return_value=_upstream(body={'ok': True})) as post:
        client.post('/api/v1/hermes/chat', json={
            'messages': [{'role': 'user', 'content': 'x'}], 'stream': False})
    assert post.call_args.kwargs['json']['model'] == 'migration'


def test_corps_limite_a_trois_clefs(client):
    with patch.object(hermes_module, '_hermes_config', return_value=_CFG_PROFIL), \
         patch.object(hermes_module.requests, 'post',
                      return_value=_upstream(body={'ok': True})) as post:
        client.post('/api/v1/hermes/chat', json={
            'messages': [{'role': 'user', 'content': 'x'}], 'stream': False})
    assert set(post.call_args.kwargs['json']) == {'model', 'messages', 'stream'}


def test_profil_inconnu_renvoie_502_avec_diagnostic(client):
    with patch.object(hermes_module, '_hermes_config', return_value=_CFG_PROFIL), \
         patch.object(hermes_module.requests, 'post',
                      return_value=_upstream(status=404, text='404: Not Found')):
        r = client.post('/api/v1/hermes/chat',
                        json={'messages': [{'role': 'user', 'content': 'x'}]})
    assert r.status_code == 502
    erreur = r.get_json()['error']
    assert 'migration' in erreur and 'HERMES_PROFILE' in erreur


def test_404_sans_profil_pointe_vers_l_url(client):
    cfg = dict(_CFG_PROFIL, profile='')
    with patch.object(hermes_module, '_hermes_config', return_value=cfg), \
         patch.object(hermes_module.requests, 'post',
                      return_value=_upstream(status=404, text='404: Not Found')):
        r = client.post('/api/v1/hermes/chat',
                        json={'messages': [{'role': 'user', 'content': 'x'}]})
    assert r.status_code == 502
    assert 'HERMES_API_URL' in r.get_json()['error']


def test_execute_job_utilise_aussi_l_url_du_profil(client):
    with patch.object(hermes_module, '_hermes_config', return_value=_CFG_PROFIL), \
         patch.object(hermes_module.requests, 'get',
                      return_value=_upstream(body={'job': {'name': 'J', 'prompt': 'fais x'}})), \
         patch.object(hermes_module.requests, 'post',
                      return_value=_upstream(status=502, text='amont hs')) as post:
        client.post('/api/v1/hermes/jobs/job_1/execute')
    assert post.call_args.args[0] == 'http://hermes.test/p/migration/v1/chat/completions'


# --------------------------------------------------------------------------- #
# Etancheite : un corps d'erreur amont peut contenir l'URL interne, la cle ou
# une trace. Il part au journal, jamais dans la reponse client.
# --------------------------------------------------------------------------- #
_FUITE = "Traceback: connect http://hermes-interne:8642 Bearer sk-secret-42"


def test_corps_d_erreur_amont_ne_fuit_pas_au_client(client):
    with patch.object(hermes_module, '_hermes_config', return_value=_CFG_PROFIL), \
         patch.object(hermes_module.requests, 'post',
                      return_value=_upstream(status=500, text=_FUITE)):
        r = client.post('/api/v1/hermes/chat',
                        json={'messages': [{'role': 'user', 'content': 'x'}]})
    assert r.status_code == 502
    erreur = r.get_json()['error']
    assert 'sk-secret-42' not in erreur and 'hermes-interne' not in erreur
    assert '500' in erreur  # le statut reste, il est utile et non sensible


def test_execute_job_corps_d_erreur_amont_ne_fuit_pas(client):
    with patch.object(hermes_module, '_hermes_config', return_value=_CFG_PROFIL), \
         patch.object(hermes_module.requests, 'get',
                      return_value=_upstream(body={'job': {'name': 'J', 'prompt': 'p'}})), \
         patch.object(hermes_module.requests, 'post',
                      return_value=_upstream(status=500, text=_FUITE)):
        r = client.post('/api/v1/hermes/jobs/job_1/execute')
    assert r.status_code == 502
    assert 'sk-secret-42' not in r.get_json()['error']


def test_proxy_reponse_non_json_ne_relaie_pas_le_corps(client):
    reponse = _upstream(status=502, text=_FUITE)
    reponse.json.side_effect = ValueError('pas du JSON')
    with patch.object(hermes_module, '_hermes_config', return_value=_CFG_PROFIL), \
         patch.object(hermes_module.requests, 'request', return_value=reponse):
        r = client.get('/api/v1/hermes/jobs')
    assert 'sk-secret-42' not in r.get_data(as_text=True)


def test_execute_job_reponse_vide_renvoie_502(client):
    # Un contenu vide est une erreur, pas un resultat a stocker.
    vide = {'choices': [{'message': {'content': '   '}}]}
    with patch.object(hermes_module, '_hermes_config', return_value=_CFG_PROFIL), \
         patch.object(hermes_module.requests, 'get',
                      return_value=_upstream(body={'job': {'name': 'J', 'prompt': 'p'}})), \
         patch.object(hermes_module.requests, 'post',
                      return_value=_upstream(body=vide)):
        r = client.post('/api/v1/hermes/jobs/job_1/execute')
    assert r.status_code == 502


def test_stream_relaye_octets_et_entetes_sse(client):
    upstream = _upstream()
    chunks = [b'data: {"choices":[{"delta":{"content":"Bon"}}]}\n\n',
              b'data: [DONE]\n\n']
    upstream.iter_content.return_value = iter(chunks)
    with patch.object(hermes_module, '_hermes_config', return_value=_CFG_OK), \
         patch.object(hermes_module.requests, 'post', return_value=upstream):
        r = client.post('/api/v1/hermes/chat',
                        json={'messages': [{'role': 'user', 'content': 'x'}], 'stream': True})
    assert r.status_code == 200
    assert r.mimetype == 'text/event-stream'
    assert r.headers['X-Accel-Buffering'] == 'no'
    assert b''.join(chunks) == r.data
    upstream.close.assert_called()
