"""Tests de la resolution de configuration (services/config_service.py).

Point sensible : l'ordre base > environnement. Il est correct en production
(la page Parametres doit gagner), mais empeche un poste de developpement de
surcharger une valeur, puisque la base est partagee avec le serveur. D'ou
CONFIG_ENV_PRIORITY, verrouille ici.
"""
from unittest.mock import MagicMock, patch

import pytest

from services import config_service
from services.config_service import get_config


def _db(valeur):
    """Connexion simulee renvoyant `valeur` pour n'importe quelle cle."""
    cur = MagicMock()
    cur.fetchone.return_value = (valeur,) if valeur is not None else None
    curseur_ctx = MagicMock()
    curseur_ctx.__enter__.return_value = cur
    conn = MagicMock()
    conn.cursor.return_value = curseur_ctx
    conn_ctx = MagicMock()
    conn_ctx.__enter__.return_value = conn
    return MagicMock(return_value=conn_ctx)


@pytest.fixture(autouse=True)
def env_propre(monkeypatch):
    monkeypatch.delenv('CONFIG_ENV_PRIORITY', raising=False)
    monkeypatch.delenv('HERMES_API_URL', raising=False)
    return monkeypatch


# --------------------------------------------------------------------------- #
# Comportement historique : la base prime
# --------------------------------------------------------------------------- #
def test_base_prime_sur_environnement(env_propre):
    env_propre.setenv('HERMES_API_URL', 'http://127.0.0.1:8642/v1')
    with patch.object(config_service, 'get_db_connection', _db('http://hermes:8642/v1')):
        assert get_config('HERMES_API_URL') == 'http://hermes:8642/v1'


def test_environnement_utilise_si_absent_de_la_base(env_propre):
    env_propre.setenv('HERMES_API_URL', 'http://127.0.0.1:8642/v1')
    with patch.object(config_service, 'get_db_connection', _db(None)):
        assert get_config('HERMES_API_URL') == 'http://127.0.0.1:8642/v1'


def test_defaut_si_ni_base_ni_environnement(env_propre):
    with patch.object(config_service, 'get_db_connection', _db(None)):
        assert get_config('HERMES_API_URL', 'defaut') == 'defaut'


# --------------------------------------------------------------------------- #
# Surcharge locale : CONFIG_ENV_PRIORITY inverse l'ordre, cle par cle
# --------------------------------------------------------------------------- #
def test_cle_listee_donne_priorite_a_l_environnement(env_propre):
    env_propre.setenv('CONFIG_ENV_PRIORITY', 'HERMES_API_URL')
    env_propre.setenv('HERMES_API_URL', 'http://127.0.0.1:8642/v1')
    with patch.object(config_service, 'get_db_connection', _db('http://hermes:8642/v1')):
        assert get_config('HERMES_API_URL') == 'http://127.0.0.1:8642/v1'


def test_cle_non_listee_reste_sur_la_base(env_propre):
    env_propre.setenv('CONFIG_ENV_PRIORITY', 'AUTRE_CLE')
    env_propre.setenv('HERMES_API_URL', 'http://127.0.0.1:8642/v1')
    with patch.object(config_service, 'get_db_connection', _db('http://hermes:8642/v1')):
        assert get_config('HERMES_API_URL') == 'http://hermes:8642/v1'


def test_liste_toleree_avec_espaces_et_casse(env_propre):
    env_propre.setenv('CONFIG_ENV_PRIORITY', ' autre ,  hermes_api_url ')
    env_propre.setenv('HERMES_API_URL', 'http://127.0.0.1:8642/v1')
    with patch.object(config_service, 'get_db_connection', _db('http://hermes:8642/v1')):
        assert get_config('HERMES_API_URL') == 'http://127.0.0.1:8642/v1'


def test_cle_listee_mais_env_vide_retombe_sur_la_base(env_propre):
    # Une variable vide ne doit pas effacer la configuration serveur.
    env_propre.setenv('CONFIG_ENV_PRIORITY', 'HERMES_API_URL')
    env_propre.setenv('HERMES_API_URL', '')
    with patch.object(config_service, 'get_db_connection', _db('http://hermes:8642/v1')):
        assert get_config('HERMES_API_URL') == 'http://hermes:8642/v1'
