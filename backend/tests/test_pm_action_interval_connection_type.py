"""
clean_data.populate_pm_action() (2026-09-18, demandes explicites) :

- "interval" est obligatoire cote IFS : '0' quand la frequence PE Tools est vide ;
- pm_interval_unit (libelle) n'est plus alimente ;
- pm_interval_unit_db passe par la transcodification PM_INTERVAL_UNIT
  (PETOOLS -> IFS, seedee par la migration 080), sans repli code en dur ;
- connection_type_db doit appartenir au domaine IFS (EQUIPMENT, VIM, CATEGORY,
  PLD, CMPUNT, LINAST, TOOLEQ, PRJWORKPACKAGE, MODEL), le libelle client en est
  derive, et toute autre valeur fait echouer le chargement.

Vraie base, transaction jamais validee : la migration 080 (sans son BEGIN/COMMIT)
et les procedures du depot sont rejouees dans la transaction, puis pm_action est
rechargee dans cette meme transaction.
"""
import os
import sys

import psycopg2
import psycopg2.extras
import pytest

BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(BACKEND)
SQL_DIR = os.path.join(ROOT, 'sql', 'pm_actions')
MIGRATION = os.path.join(ROOT, 'migrations', '080_pm_action_interval_unit_transco_connection_type.sql')
if BACKEND not in sys.path:
    sys.path.insert(0, BACKEND)

DOMAINE = {'EQUIPMENT', 'VIM', 'CATEGORY', 'PLD', 'CMPUNT', 'LINAST', 'TOOLEQ', 'PRJWORKPACKAGE', 'MODEL'}


def _connect():
    try:
        try:
            from config.database import get_db_params
            params = get_db_params()
        except ImportError:
            params = {'host': os.getenv('DB_HOST', '10.190.100.58'), 'port': os.getenv('DB_PORT', '5432'),
                      'database': os.getenv('DB_NAME', 'sap_migration_db'),
                      'user': os.getenv('DB_USER', 'postgres'), 'password': os.getenv('DB_PASSWORD', '')}
        return psycopg2.connect(**params)
    except Exception as exc:  # pragma: no cover
        pytest.skip(f'base injoignable : {exc}')


def _migration_sans_transaction():
    with open(MIGRATION, encoding='utf-8') as f:
        lignes = [l for l in f if l.strip() not in ('BEGIN;', 'COMMIT;')]
    return ''.join(lignes)


def _preparer(cur):
    cur.execute(_migration_sans_transaction())
    for name in ('00_pm_helpers.sql', '01_populate_pm_action.sql', '02_populate_pm_action_work_step.sql'):
        with open(os.path.join(SQL_DIR, name), encoding='utf-8') as f:
            cur.execute(f.read())


@pytest.fixture(scope='module')
def cur():
    conn = _connect()
    try:
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        _preparer(cur)
        cur.execute("CALL clean_data.populate_pm_action()")
        cur.execute("CALL clean_data.populate_pm_action_work_step()")
        yield cur
    finally:
        conn.rollback()
        conn.close()


def _one(cur, sql, params=None):
    cur.execute(sql, params or [])
    return cur.fetchone()


def test_interval_jamais_vide(cur):
    r = _one(cur, """
        SELECT count(*) AS total,
               count(*) FILTER (WHERE "interval" IS NULL OR "interval" = '') AS vides,
               count(*) FILTER (WHERE "interval" = '0') AS zeros
        FROM clean_data.pm_action""")
    assert r['total'] > 0
    assert r['vides'] == 0
    assert r['zeros'] > 0, "les frequences vides doivent sortir a '0'"


def test_libelle_unite_vide(cur):
    r = _one(cur, "SELECT count(*) AS n FROM clean_data.pm_action WHERE pm_interval_unit IS NOT NULL")
    assert r['n'] == 0


def test_unite_db_vient_de_la_transcodification(cur):
    r = _one(cur, """
        SELECT count(*) FILTER (WHERE pm_interval_unit_db IS NOT NULL) AS renseignes,
               count(*) FILTER (WHERE pm_interval_unit_db IS NOT NULL
                                  AND pm_interval_unit_db NOT IN (
                                      SELECT target_value FROM public."TranscodificationTable"
                                      WHERE category = 'PM_INTERVAL_UNIT' AND source_system = 'PETOOLS' AND is_active)) AS hors_transco
        FROM clean_data.pm_action""")
    assert r['renseignes'] > 0
    assert r['hors_transco'] == 0


def test_unite_db_suit_une_modification_de_la_transcodification(cur):
    """Changer la cible dans la table de transcodification change le chargement :
    preuve que la procedure lit la table et non un CASE code en dur."""
    cur.execute("""UPDATE public."TranscodificationTable" SET target_value = 'DAYS'
                   WHERE category = 'PM_INTERVAL_UNIT' AND source_system = 'PETOOLS' AND source_value = 'S'""")
    cur.execute("SAVEPOINT transco")
    try:
        cur.execute("CALL clean_data.populate_pm_action()")
        r = _one(cur, "SELECT count(*) AS n FROM clean_data.pm_action WHERE pm_interval_unit_db = 'DAYS'")
        assert r['n'] > 0
        r = _one(cur, "SELECT count(*) AS n FROM clean_data.pm_action WHERE pm_interval_unit_db = 'WEEKS'")
        assert r['n'] == 0
    finally:
        cur.execute("ROLLBACK TO SAVEPOINT transco")
        cur.execute("""UPDATE public."TranscodificationTable" SET target_value = 'WEEKS'
                       WHERE category = 'PM_INTERVAL_UNIT' AND source_system = 'PETOOLS' AND source_value = 'S'""")


def test_connection_type_dans_le_domaine_ifs(cur):
    for table in ('pm_action', 'pm_action_work_step'):
        cur.execute(f"SELECT DISTINCT connection_type, connection_type_db FROM clean_data.{table}")
        rows = cur.fetchall()
        assert rows, table
        for r in rows:
            assert r['connection_type_db'] in DOMAINE, (table, r)
            assert r['connection_type'] == 'EQUIPMENT', (table, r)


def test_valeur_hors_domaine_refusee(cur):
    cur.execute("SAVEPOINT domaine")
    try:
        cur.execute("""UPDATE public.etl_default_values SET valeur = 'FUNCTIONAL'
                       WHERE table_cible = 'clean_data.pm_action' AND colonne = 'connection_type_db' AND variante = 'STANDARD'""")
        with pytest.raises(psycopg2.Error) as exc:
            cur.execute("CALL clean_data.populate_pm_action()")
        assert 'hors domaine IFS' in str(exc.value)
    finally:
        cur.execute("ROLLBACK TO SAVEPOINT domaine")


def test_libelle_client_du_domaine(cur):
    r = _one(cur, "SELECT clean_data.pm_connection_type_client('PLD') AS pld, clean_data.pm_connection_type_client('TOOLEQ') AS tooleq")
    assert (r['pld'], r['tooleq']) == ('DESIGN OBJECT', 'TOOL/EQUIPMENT')
