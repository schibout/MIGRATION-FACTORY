"""Tests de la construction de l'URI de l'engine lecture seule de l'IA.
Garde-fou contre la régression 'fe_sendauth: no password supplied' : l'URI doit
réutiliser la même source d'identifiants que l'app (config.database)."""
from unittest.mock import patch

from services import ai_readonly_db


_PARAMS = {'host': 'h', 'port': '5432', 'database': 'db', 'user': 'postgres', 'password': 'secret'}


def test_build_uri_inclut_le_mot_de_passe():
    with patch('config.database.get_db_params', return_value=_PARAMS):
        uri = ai_readonly_db._build_uri()
    assert uri == 'postgresql+psycopg2://postgres:secret@h:5432/db'
    assert ':@' not in uri  # jamais de mot de passe vide


def test_build_uri_utilise_get_db_params():
    """Le mot de passe vient bien de config.database (source unique), pas d'un
    défaut vide local."""
    appele = {}

    def _fake():
        appele['ok'] = True
        return _PARAMS

    with patch('config.database.get_db_params', side_effect=_fake):
        ai_readonly_db._build_uri()
    assert appele.get('ok') is True


def test_get_db_params_defaut_mot_de_passe_non_vide(monkeypatch):
    """Sans DB_PASSWORD dans l'env, le défaut historique fonctionnel s'applique
    (c'est ce défaut, absent côté IA auparavant, qui causait la régression)."""
    from config.database import get_db_params
    monkeypatch.delenv('DB_PASSWORD', raising=False)
    assert get_db_params()['password'] != ''
