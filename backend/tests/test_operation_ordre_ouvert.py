"""
Module Operations (2026-09-18, demande explicite) : ne charger que les
operations EN COURS OU FUTURES, c'est-a-dire celles d'un ordre SAP non clos.

Un ordre est clos quand il porte, actif dans raw_data.jest (objet AUFK.OBJNR),
un statut I0045 (TECO), I0046 (CLSD) ou I0076 (DLFL). L'ancien filtre
« annee de AFKO.GSTRP = 2026 » est abandonne : il gardait 8 648 operations
d'ordres deja clos et excluait les ordres 2027+ ainsi que les ordres anciens
jamais clotures.

Vraie base, transaction jamais validee : les procedures du depot sont rejouees
dans la transaction, puis les 3 tables sont rechargees dans cette meme
transaction.
"""
import os
import sys

import psycopg2
import psycopg2.extras
import pytest

BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(BACKEND)
SQL_DIR = os.path.join(ROOT, 'sql', 'operation')
if BACKEND not in sys.path:
    sys.path.insert(0, BACKEND)

FICHIERS = (
    os.path.join(ROOT, 'sql', 'functions', 'get_vendor_no_ifs.sql'),
    os.path.join(SQL_DIR, '00_operation_helpers.sql'),
    os.path.join(SQL_DIR, 'create_alimenter_jt_task.sql'),
    os.path.join(SQL_DIR, 'create_alimenter_jt_task_resource.sql'),
    os.path.join(SQL_DIR, 'create_clean_data_maint_material_req_line.sql'),
)

# Referentiels calcules UNE fois dans la transaction (les index SAP commencent
# par mandt : un EXISTS correle par aufnr seul balaie aufk a chaque ligne).
REFERENTIELS = """
    CREATE TEMP TABLE t_ordre_clos AS
    SELECT DISTINCT a.mandt, trim(a.aufnr) AS aufnr_txt,
           CASE WHEN trim(a.aufnr) ~ '^[0-9]+$' THEN trim(a.aufnr)::numeric END AS aufnr
    FROM raw_data.aufk a
    JOIN raw_data.jest j ON j.mandt = a.mandt AND j.objnr = a.objnr
    WHERE (j.inact IS NULL OR trim(j.inact) <> 'X')
      AND j.stat IN ('I0045', 'I0046', 'I0076');
    CREATE TEMP TABLE t_ordre_annee AS
    SELECT trim(k.aufnr)::numeric AS aufnr, left(trim(k.gstrp), 4) AS annee
    FROM raw_data.afko k WHERE trim(k.aufnr) ~ '^[0-9]+$';
    CREATE INDEX ON t_ordre_clos (aufnr);
    CREATE INDEX ON t_ordre_clos (aufnr_txt);
    CREATE INDEX ON t_ordre_annee (aufnr);
    ANALYZE t_ordre_clos;
    ANALYZE t_ordre_annee;
"""

ORDRE_CLOS = "EXISTS (SELECT 1 FROM t_ordre_clos oc WHERE oc.aufnr = {aufnr})"
# Cote source SAP on compare en texte : les AUFNR non numeriques (F22330010501)
# ont wo_no NULL dans la cible mais doivent quand meme etre exclus s'ils sont clos.
ORDRE_CLOS_TXT = "EXISTS (SELECT 1 FROM t_ordre_clos oc WHERE oc.aufnr_txt = trim({col}))"
ANNEE_GSTRP = "(SELECT annee FROM t_ordre_annee oa WHERE oa.aufnr = {aufnr} LIMIT 1)"
# Certains AUFNR ne sont pas numeriques (ex. F22330010501) : les loaders y
# mettent wo_no NULL mais gardent l'operation.
NUM = "(CASE WHEN trim({col}) ~ '^[0-9]+$' THEN trim({col})::numeric END)"


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


def _preparer(cur):
    for chemin in FICHIERS:
        if not os.path.exists(chemin):
            continue  # RED : le fichier d'aide n'existe pas encore
        with open(chemin, encoding='utf-8') as f:
            cur.execute(f.read())


@pytest.fixture(scope='module')
def cur():
    conn = _connect()
    try:
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        _preparer(cur)
        cur.execute(REFERENTIELS)
        cur.execute("SELECT clean_data.alimenter_jt_task()")
        cur.execute("SELECT clean_data.alimenter_jt_task_resource()")
        # Rechargement complet attendu (2026-09-19) : la ligne temoin doit
        # disparaitre et un second appel ne doit rien doubler.
        cur.execute("""INSERT INTO clean_data.maint_material_req_line
                       (maint_material_order_no, line_item_no, part_no) VALUES (-1, -1, 'TEMOIN')""")
        cur.execute("SELECT clean_data.alimenter_maint_material_req_line()")
        cur.execute("SELECT clean_data.alimenter_maint_material_req_line()")
        # Tables tronquees puis rechargees dans la transaction : sans ANALYZE le
        # planificateur les croit vides et choisit des boucles imbriquees.
        cur.execute("ANALYZE clean_data.jt_task; ANALYZE clean_data.jt_task_resource; "
                    "ANALYZE clean_data.maint_material_req_line")
        yield cur
    finally:
        conn.rollback()
        conn.close()


def _one(cur, sql, params=None):
    cur.execute(sql, params or [])
    return cur.fetchone()


# ---------------------------------------------------------------- jt_task

def test_jt_task_aucune_operation_d_ordre_clos(cur):
    r = _one(cur, "SELECT count(*) AS n FROM clean_data.jt_task t WHERE "
             + ORDRE_CLOS.format(aufnr='t.wo_no'))
    assert r['n'] == 0, f"{r['n']} operations d'ordres TECO/CLSD/DLFL chargees"


def test_jt_task_garde_les_ordres_futurs(cur):
    r = _one(cur, "SELECT count(*) AS n FROM clean_data.jt_task t WHERE "
             + ANNEE_GSTRP.format(aufnr='t.wo_no') + " >= '2027'")
    assert r['n'] > 0, "aucune operation d'ordre 2027+ chargee"


def test_jt_task_garde_les_ordres_anciens_encore_ouverts(cur):
    r = _one(cur, "SELECT count(*) AS n FROM clean_data.jt_task t WHERE "
             + ANNEE_GSTRP.format(aufnr='t.wo_no') + " < '2026'")
    assert r['n'] > 0, "aucune operation d'ordre anterieur a 2026 encore ouvert"


def test_jt_task_couvre_toutes_les_operations_d_ordres_ouverts(cur):
    """Le nouveau critere est le SEUL filtre de perimetre : pas de date residuelle."""
    r = _one(cur, """
        SELECT count(*) AS n
        FROM raw_data.afvc v
        JOIN raw_data.afko k ON k.mandt = v.mandt AND k.aufpl = v.aufpl
        WHERE (v.loekz IS NULL OR trim(v.loekz) = '')
          AND trim(v.aufpl) ~ '^[0-9]+$' AND trim(v.aplzl) ~ '^[0-9]+$'
          AND NOT """ + ORDRE_CLOS_TXT.format(col='k.aufnr'))
    charge = _one(cur, "SELECT count(*) AS n FROM clean_data.jt_task")['n']
    assert charge == r['n'], f"jt_task = {charge}, attendu {r['n']} operations d'ordres ouverts"


# ------------------------------------------------------- jt_task_resource

def test_jt_task_resource_aucun_ordre_clos(cur):
    r = _one(cur, "SELECT count(*) AS n FROM clean_data.jt_task_resource t WHERE "
             + ORDRE_CLOS.format(aufnr='t.wo_no'))
    assert r['n'] == 0


def test_jt_task_resource_hors_2026(cur):
    r = _one(cur, "SELECT count(*) AS n FROM clean_data.jt_task_resource t WHERE "
             + ANNEE_GSTRP.format(aufnr='t.wo_no') + " <> '2026'")
    assert r['n'] > 0, "le loader ressources garde un filtre sur l'annee 2026"


# ------------------------------------------------ maint_material_req_line

def test_maint_material_req_line_aucun_ordre_clos(cur):
    r = _one(cur, """
        SELECT count(*) AS n
        FROM clean_data.maint_material_req_line c
        JOIN raw_data.resb r ON trim(r.rsnum)::numeric = c.maint_material_order_no
                            AND trim(r.rspos)::numeric = c.line_item_no
        WHERE """ + ORDRE_CLOS_TXT.format(col='r.aufnr'))
    assert r['n'] == 0


def test_maint_material_req_line_rechargement_complet(cur):
    """Le module vide la table puis la recharge : pas de ligne d'un chargement
    precedent (temoin), pas de doublon apres deux appels."""
    r = _one(cur, "SELECT count(*) AS n FROM clean_data.maint_material_req_line WHERE part_no = 'TEMOIN'")
    assert r['n'] == 0, "la table n'est pas videe avant rechargement"
    r = _one(cur, """SELECT count(*) AS n, count(DISTINCT (maint_material_order_no, line_item_no)) AS d
                     FROM clean_data.maint_material_req_line""")
    assert r['n'] == r['d'], f"{r['n'] - r['d']} doublons apres deux chargements"


def test_maint_material_req_line_exige_un_ordre_afko(cur):
    """L'ancien filtre de date excluait implicitement les reservations sans
    en-tete d'ordre (134 lignes RESB, dont 94 sans AUFNR) : elles restent exclues."""
    r = _one(cur, """
        SELECT count(*) AS n
        FROM clean_data.maint_material_req_line c
        JOIN raw_data.resb r ON trim(r.rsnum)::numeric = c.maint_material_order_no
                            AND trim(r.rspos)::numeric = c.line_item_no
        WHERE NOT EXISTS (SELECT 1 FROM raw_data.afko k
                          WHERE k.mandt = r.mandt AND k.aufnr = r.aufnr)""")
    assert r['n'] == 0, f"{r['n']} besoins matiere sans en-tete d'ordre AFKO"


def test_maint_material_req_line_hors_2026(cur):
    r = _one(cur, """
        SELECT count(*) AS n
        FROM clean_data.maint_material_req_line c
        JOIN raw_data.resb r ON trim(r.rsnum)::numeric = c.maint_material_order_no
                            AND trim(r.rspos)::numeric = c.line_item_no
        WHERE """ + ANNEE_GSTRP.format(aufnr=NUM.format(col='r.aufnr')) + " <> '2026'")
    assert r['n'] > 0, "le loader besoins matiere garde un filtre sur l'annee 2026"
