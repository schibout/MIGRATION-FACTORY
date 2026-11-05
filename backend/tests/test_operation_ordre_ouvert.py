"""
Module Operations : perimetre de reprise IW39 (sql/operation/repriseOperation.md).

Ordre repris = cree depuis le 01/01/2026 (AUFK.ERDAT), poste responsable
(AFIH.GEWRK -> CRHD) de la division 9200 et d'un des 9 secteurs, statut REL actif
et aucun statut actif TECO/CLSD/DLFL.

Les regles sont recontrolees directement sur raw_data, sans passer par la vue
clean_data.v_sap_ordre_repris, pour que le test echoue si la vue derive.

Vraie base, transaction jamais validee : les procedures du depot sont rejouees
dans la transaction, puis les 3 tables y sont rechargees. Le TRUNCATE verrouille
ces tables pendant le test : ne pas le lancer pendant un chargement.
"""
import os
import sys

import psycopg2
import psycopg2.extras
import pytest

BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(BACKEND)
SQL_DIR = os.path.join(ROOT, 'sql', 'operation')
SQL_FUNCTIONS = os.path.join(ROOT, 'sql', 'functions')
if BACKEND not in sys.path:
    sys.path.insert(0, BACKEND)

# Meme ordre que sql/operation/compile.sh (hors tables, qui existent deja).
FICHIERS = (
    os.path.join(SQL_FUNCTIONS, 'get_vendor_no_ifs.sql'),
    os.path.join(SQL_FUNCTIONS, 'get_username.sql'),
    os.path.join(SQL_FUNCTIONS, 'texte_long_sap.sql'),
    os.path.join(SQL_DIR, '00_operation_helpers.sql'),
    os.path.join(SQL_DIR, 'create_alimenter_jt_task.sql'),
    os.path.join(SQL_DIR, 'create_alimenter_jt_task_resource.sql'),
    os.path.join(SQL_DIR, 'create_alimenter_maint_material_req_line.sql'),
)

SECTEURS = ('7.MATC', '7.MCAR', '7.MSCT', '7.MENG', '7.MFIE', '7.MELY', '7.MNRJ', '7.MSGX', '7.MTRO')

# Ordres charges dans jt_task, avec leur ordre SAP. LEFT JOIN : un ordre absent
# d'AUFK ou un wo_no vide doit faire echouer les controles, pas disparaitre.
ORDRES_CHARGES = """
    (SELECT DISTINCT t.wo_no, a.mandt, a.aufnr, a.erdat, a.objnr
     FROM clean_data.jt_task t
     LEFT JOIN raw_data.aufk a ON a.aufnr = lpad(t.wo_no::text, 12, '0')) o
"""

STATUT_ACTIF = """
    EXISTS (SELECT 1 FROM raw_data.jest j
            WHERE j.mandt = o.mandt AND j.objnr = o.objnr AND j.stat = ANY(%s)
              AND (j.inact IS NULL OR trim(j.inact) <> 'X'))
"""


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


@pytest.fixture(scope='module')
def cur():
    conn = _connect()
    try:
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        for chemin in FICHIERS:
            with open(chemin, encoding='utf-8') as f:
                cur.execute(f.read())
        cur.execute("SELECT clean_data.alimenter_jt_task()")
        cur.execute("SELECT clean_data.alimenter_jt_task_resource()")
        # Rechargement complet attendu : la ligne temoin doit disparaitre et un
        # second appel ne doit rien doubler.
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


def _n(cur, sql, params=None):
    cur.execute(sql, params or [])
    return cur.fetchone()['n']


# ------------------------------------------------- perimetre des ordres (jt_task)

def test_jt_task_non_vide(cur):
    """Garde-fou : sans cela, tous les controles « = 0 » passent sur une table vide."""
    assert _n(cur, "SELECT count(*) AS n FROM clean_data.jt_task") > 0


def test_ordres_retrouves_dans_aufk(cur):
    n = _n(cur, f"SELECT count(*) AS n FROM {ORDRES_CHARGES} WHERE o.aufnr IS NULL")
    assert n == 0, f"{n} ordres charges introuvables dans AUFK (ou wo_no vide)"


def test_regle_date_creation_depuis_2026(cur):
    n = _n(cur, f"""SELECT count(*) AS n FROM {ORDRES_CHARGES}
                    WHERE o.erdat < '20260101' OR o.erdat > to_char(CURRENT_DATE, 'YYYYMMDD')""")
    assert n == 0, f"{n} ordres crees hors de la periode"


def test_regle_division_et_secteurs_du_poste_responsable(cur):
    n = _n(cur, f"""
        SELECT count(*) AS n
        FROM {ORDRES_CHARGES}
        LEFT JOIN raw_data.afih h ON h.mandt = o.mandt AND h.aufnr = o.aufnr
        LEFT JOIN raw_data.crhd c ON c.mandt = h.mandt AND c.objid = h.gewrk AND c.objty = 'A'
        WHERE c.werks IS DISTINCT FROM '9200' OR c.arbpl IS NULL OR c.arbpl <> ALL(%s)
    """, [list(SECTEURS)])
    assert n == 0, f"{n} ordres hors division 9200 ou hors secteurs"


def test_regle_statut_rel_actif(cur):
    n = _n(cur, f"SELECT count(*) AS n FROM {ORDRES_CHARGES} WHERE NOT {STATUT_ACTIF}", [['I0002']])
    assert n == 0, f"{n} ordres sans statut REL actif"


def test_regle_aucun_ordre_clos(cur):
    n = _n(cur, f"SELECT count(*) AS n FROM {ORDRES_CHARGES} WHERE {STATUT_ACTIF}",
           [['I0045', 'I0046', 'I0076']])
    assert n == 0, f"{n} ordres TECO/CLSD/DLFL charges"


# ------------------------------------------------------------ operations (jt_task)

def test_jt_task_cle_unique(cur):
    n = _n(cur, "SELECT count(*) - count(DISTINCT task_seq) AS n FROM clean_data.jt_task")
    assert n == 0, f"{n} doublons de task_seq"


def test_jt_task_operations_non_supprimees(cur):
    n = _n(cur, """
        SELECT count(*) AS n
        FROM clean_data.jt_task t
        JOIN raw_data.afvc v ON trim(v.aufpl)::numeric * 100000000 + trim(v.aplzl)::numeric = t.task_seq
        WHERE trim(v.loekz) <> ''
    """)
    assert n == 0, f"{n} operations supprimees dans SAP chargees"


def test_jt_task_seule_earliest_start_est_alimentee(cur):
    r = _n(cur, """
        SELECT count(*) FILTER (WHERE earliest_start IS NULL
                                   OR planned_start IS NOT NULL OR planned_finish IS NOT NULL
                                   OR latest_start IS NOT NULL OR latest_finish IS NOT NULL
                                   OR actual_start IS NOT NULL OR actual_finish IS NOT NULL) AS n
        FROM clean_data.jt_task
    """)
    assert r == 0, f"{r} operations ne respectent pas la regle des dates"


# ------------------------------------------------------- ressources (jt_task_resource)

def test_ressource_rattachee_a_une_operation(cur):
    n = _n(cur, """SELECT count(*) AS n FROM clean_data.jt_task_resource r
                   WHERE NOT EXISTS (SELECT 1 FROM clean_data.jt_task t WHERE t.task_seq = r.task_seq)""")
    assert n == 0, f"{n} ressources sans operation"


def test_une_ressource_par_operation(cur):
    n = _n(cur, "SELECT count(*) - count(DISTINCT task_seq) AS n FROM clean_data.jt_task_resource")
    assert n == 0, f"{n} operations avec plusieurs ressources"


# ------------------------------------------------ composants (maint_material_req_line)

def test_composant_rattache_a_une_operation(cur):
    n = _n(cur, """SELECT count(*) AS n FROM clean_data.maint_material_req_line m
                   WHERE NOT EXISTS (SELECT 1 FROM clean_data.jt_task t WHERE t.task_seq = m.task_seq)""")
    assert n == 0, f"{n} composants sans operation"


def test_composant_article_stocke_non_supprime(cur):
    n = _n(cur, """
        SELECT count(*) AS n
        FROM clean_data.maint_material_req_line c
        JOIN raw_data.resb r ON trim(r.rsnum)::numeric = c.maint_material_order_no
                            AND trim(r.rspos)::numeric = c.line_item_no
        WHERE r.postp <> 'L' OR trim(r.xloek) <> '' OR nullif(trim(r.matnr), '') IS NULL
    """)
    assert n == 0, f"{n} composants hors regle POSTP/XLOEK/MATNR"


def test_composant_rechargement_complet(cur):
    """Le module vide la table puis la recharge : pas de ligne d'un chargement
    precedent (temoin), pas de doublon apres deux appels."""
    n = _n(cur, "SELECT count(*) AS n FROM clean_data.maint_material_req_line WHERE part_no = 'TEMOIN'")
    assert n == 0, "la table n'est pas videe avant rechargement"
    n = _n(cur, """SELECT count(*) - count(DISTINCT (maint_material_order_no, line_item_no)) AS n
                   FROM clean_data.maint_material_req_line""")
    assert n == 0, f"{n} doublons apres deux chargements"
