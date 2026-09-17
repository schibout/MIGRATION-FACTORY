"""
Les modules ETL prennent leurs identifiants de base dans
config.database.get_etl_db_params() (source unique, lit DB_* du .env), jamais
en dur dans le code : le mot de passe a ete trouve en clair dans
etl_equipment_functional.py le 2026-09-18.
"""
import glob
import importlib.util
import os
import re
import sys

import pytest

BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ETL_DIR = os.path.join(BACKEND, 'etl_modules')
if BACKEND not in sys.path:
    sys.path.insert(0, BACKEND)

MODULES = sorted(glob.glob(os.path.join(ETL_DIR, 'etl_*.py')))

# Un repli de mot de passe litteral, quelle qu'en soit la valeur :
#   os.environ.get("DB_PASSWORD", "xxx") / os.getenv("PG_PASSWORD", "xxx")
MOT_DE_PASSE_EN_DUR = re.compile(r"""PASSWORD["']\s*,\s*["'][^"']+["']""")


@pytest.mark.parametrize('chemin', MODULES, ids=os.path.basename)
def test_aucun_mot_de_passe_en_dur(chemin):
    with open(chemin, encoding='utf-8') as f:
        source = f.read()
    assert not MOT_DE_PASSE_EN_DUR.search(source), 'repli de mot de passe litteral dans le module'


def test_equipment_functional_lit_les_identifiants_de_config_database(monkeypatch):
    attendu = {'host': 'h', 'port': '1', 'database': 'd', 'user': 'u', 'password': 'p'}
    import config.database as database
    monkeypatch.setattr(database, 'get_etl_db_params', lambda: attendu)

    spec = importlib.util.spec_from_file_location(
        'etl_equipment_functional_sous_test', os.path.join(ETL_DIR, 'etl_equipment_functional.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    etl = module.EquipmentFunctionalETL()
    assert (etl.pg_host, etl.pg_port, etl.pg_database, etl.pg_user, etl.pg_password) == ('h', '1', 'd', 'u', 'p')
