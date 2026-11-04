"""Option truncate de /import-generic/execute, base simulee : ordre des requetes, annulations, JWT."""
import pandas as pd
import pytest
from flask import Flask
from flask_jwt_extended import JWTManager, create_access_token

from api import import_generic as ig


class Curseur:
    def __init__(self, base):
        self.base = base
        self.resultat = []
        self.rowcount = 1

    def execute(self, sql, params=None):
        self.base.sql.append(' '.join(sql.split()))
        if sql.lstrip().startswith('INSERT') and params[0] in self.base.valeurs_rejetees:
            raise ValueError('rejet')
        if 'information_schema.columns' in sql:
            self.resultat = [('code', 'character varying')] if self.base.table_existe else []
        elif 'sap_table_fields' in sql:
            self.resultat = [(self.base.table_sap,)]
        elif 'count(*)' in sql:
            self.resultat = [(7,)]

    def fetchall(self):
        return self.resultat

    def fetchone(self):
        return self.resultat[0]


class Base:
    def __init__(self, valeurs_rejetees=(), table_sap=False, table_existe=True):
        self.sql, self.commits, self.rollbacks = [], 0, 0
        self.valeurs_rejetees, self.table_sap, self.table_existe = valeurs_rejetees, table_sap, table_existe

    def cursor(self, **_):
        return Curseur(self)

    def commit(self):
        self.commits += 1

    def rollback(self):
        self.rollbacks += 1

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False


@pytest.fixture
def appeler(monkeypatch):
    app = Flask(__name__)
    app.config.update(JWT_SECRET_KEY='x' * 32, TESTING=True)
    JWTManager(app)
    app.register_blueprint(ig.import_generic_blueprint, url_prefix='/i')

    def _appeler(base, jwt=True, schema='raw_data', **options):
        monkeypatch.setattr(ig, 'get_db_connection', lambda: base)
        ig.temp_file_storage['f'] = {'dataframe': pd.DataFrame({'c': ['a', 'b']}), 'filename': 'f.csv'}
        with app.app_context():
            entetes = {'Authorization': 'Bearer ' + create_access_token('samir')} if jwt else {}
        return app.test_client().post('/i/execute', headers=entetes, json={
            'fileId': 'f', 'targetTable': 't', 'schema': schema,
            'mappings': [{'source': 'c', 'target': 'code'}], 'options': options})
    return _appeler


def vidages(base):
    return [i for i, s in enumerate(base.sql) if s.startswith('TRUNCATE')]


def test_vide_avant_insertion_sans_cascade(appeler):
    base = Base()
    rep = appeler(base, truncate=True)
    assert rep.status_code == 200 and '7 ligne' in rep.get_json()['message']
    insertions = [i for i, s in enumerate(base.sql) if s.startswith('INSERT')]
    assert vidages(base)[0] < insertions[0] and base.commits == 1
    assert 'CASCADE' not in base.sql[vidages(base)[0]]


def test_sans_option_aucun_vidage_ni_jwt(appeler):
    base = Base()
    assert appeler(base, jwt=False).status_code == 200
    assert not vidages(base)


def test_jwt_exige_pour_vider(appeler):
    base = Base()
    assert appeler(base, jwt=False, truncate=True).status_code == 401
    assert base.sql == []


def test_erreur_de_ligne_restaure_la_table(appeler):
    base = Base(valeurs_rejetees=('a',))
    assert appeler(base, truncate=True).status_code == 400
    assert base.commits == 0 and base.rollbacks == 1


def test_commit_partiel_sans_aucune_ligne_ne_vide_pas(appeler):
    base = Base(valeurs_rejetees=('a', 'b'))
    assert appeler(base, truncate=True, commitPartial=True).status_code == 400
    assert base.commits == 0 and base.rollbacks == 1


def test_commit_partiel_garde_les_lignes_reussies(appeler):
    base = Base(valeurs_rejetees=('a',))
    assert appeler(base, truncate=True, commitPartial=True).status_code == 200
    assert base.commits == 1 and vidages(base)


@pytest.mark.parametrize('base,schema', [
    (Base(), 'public'), (Base(table_sap=True), 'raw_data'), (Base(table_existe=False), 'clean_data')])
def test_tables_protegees_jamais_videes(appeler, base, schema):
    assert appeler(base, truncate=True, schema=schema).status_code == 400
    assert not vidages(base) and base.commits == 0
