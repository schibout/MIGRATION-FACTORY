"""
Garde-fou sur la connexion des modules ETL.

Chaque module de `etl_modules/` resolvait lui-meme `PG_HOST` avec « localhost »
par defaut. docker-compose ne transmettant pas cette variable au conteneur, TOUS
les chargements echouaient sur :

    connection to server at "localhost" (::1), port 5432 failed: Connection refused

Depuis le conteneur, localhost designe le conteneur lui-meme et non le serveur
PostgreSQL. Ces tests verrouillent la resolution et l'absence de retour en
arriere dans les modules.
"""
import os
import pathlib
import re

import pytest

from config.database import get_etl_db_params

ETL_DIR = pathlib.Path(__file__).resolve().parent.parent / 'etl_modules'
_PG_VARS = ('PG_HOST', 'PG_PORT', 'PG_DATABASE', 'PG_USER', 'PG_PASSWORD')


@pytest.fixture()
def env_conteneur(monkeypatch):
    """Environnement du conteneur : aucune variable PG_* n'est fournie."""
    for var in _PG_VARS:
        monkeypatch.delenv(var, raising=False)
    return monkeypatch


# --------------------------------------------------------------------------- #
# Resolution
# --------------------------------------------------------------------------- #
def test_ne_retombe_jamais_sur_localhost(env_conteneur):
    """Le defaut doit viser le serveur PostgreSQL, jamais le conteneur."""
    assert get_etl_db_params()['host'] not in ('localhost', '127.0.0.1', '::1')


def test_reprend_les_identifiants_de_la_source_unique(env_conteneur):
    from config.database import get_db_params

    attendu = get_db_params()
    obtenu = get_etl_db_params()
    for cle in ('host', 'port', 'database', 'user', 'password'):
        assert obtenu[cle] == attendu[cle]


def test_db_host_de_l_environnement_est_respecte(env_conteneur):
    env_conteneur.setenv('DB_HOST', '10.0.0.42')
    assert get_etl_db_params()['host'] == '10.0.0.42'


def test_surcharge_pg_host_explicite_prioritaire(env_conteneur):
    """Utile pour lancer un module ETL a la main, hors conteneur."""
    env_conteneur.setenv('DB_HOST', '10.0.0.42')
    env_conteneur.setenv('PG_HOST', 'localhost')
    assert get_etl_db_params()['host'] == 'localhost'


def test_toutes_les_cles_attendues_sont_presentes(env_conteneur):
    assert set(get_etl_db_params()) == {'host', 'port', 'database', 'user', 'password'}


# --------------------------------------------------------------------------- #
# Aucun module ne doit reintroduire sa propre resolution
# --------------------------------------------------------------------------- #
def _modules_etl():
    return sorted(ETL_DIR.glob('etl_*.py'))


def test_le_repertoire_etl_est_bien_trouve():
    assert _modules_etl(), f'aucun module ETL sous {ETL_DIR}'


@pytest.mark.parametrize('module', _modules_etl(), ids=lambda p: p.name)
def test_aucun_module_ne_code_localhost_en_defaut(module):
    source = module.read_text(encoding='utf-8')
    fautes = re.findall(r'os\.environ\.get\(\s*"PG_\w+"\s*,\s*"localhost"', source)
    assert not fautes, (
        f'{module.name} retombe sur localhost : utiliser get_etl_db_params()'
    )


@pytest.mark.parametrize('module', _modules_etl(), ids=lambda p: p.name)
def test_aucun_mot_de_passe_en_dur(module):
    """Le mot de passe doit venir de l'environnement, pas du code."""
    source = module.read_text(encoding='utf-8')
    fautes = re.findall(r'os\.environ\.get\(\s*"PG_PASSWORD"\s*,\s*"[^"]+"', source)
    assert not fautes, f'{module.name} contient un mot de passe par defaut en dur'
