"""
clean_data.alimenter_historique_cout_projet : reconstitution de l'historique des
couts par projet (ZCOA requete 3) depuis raw_data.rpsco. Vraie base, transaction
jamais validee ; la table et la fonction du depot sont recompilees dans la
transaction. Repertoire SQL surchargeable par HCP_SQL_DIR (depot non monte dans
le conteneur).
"""
import os
import sys

import psycopg2
import psycopg2.extras
import pytest

BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SQL_DIR = os.environ.get('HCP_SQL_DIR') or os.path.join(
    os.path.dirname(BACKEND), 'sql', 'historiqueCoutProjet')
if BACKEND not in sys.path:
    sys.path.insert(0, BACKEND)

HCP = 'clean_data.historique_cout_projet'


@pytest.fixture
def cur():
    try:
        from config.database import get_db_params
        conn = psycopg2.connect(**get_db_params())
    except Exception as exc:  # pragma: no cover
        pytest.skip(f'base injoignable : {exc}')
    try:
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        for name in ('01_create_clean_data_historique_cout_projet.sql',
                     '02_alimenter_historique_cout_projet.sql'):
            with open(os.path.join(SQL_DIR, name), encoding='utf-8') as f:
                cur.execute(f.read())
        cur.execute('SELECT clean_data.alimenter_historique_cout_projet() AS n')
        assert cur.fetchone()['n'] > 0
        yield cur
    finally:
        conn.rollback()
        conn.close()


def test_aucune_ligne_vide(cur):
    cur.execute(f'SELECT count(*) AS n FROM {HCP} '
                'WHERE reel = 0 AND plan = 0 AND budget_annuel = 0 AND engag_cde = 0 AND engag_da = 0')
    assert cur.fetchone()['n'] == 0


def test_reel_projet_egal_rpsco(cur):
    """Le reel d'un projet = somme RPSCO WRTTP 04 hors KOAO de ses OTP, toutes periodes."""
    cur.execute(f'SELECT projet FROM {HCP} GROUP BY projet ORDER BY sum(reel) DESC LIMIT 1')
    projet = cur.fetchone()['projet']
    cur.execute(f'SELECT round(sum(reel), 2) AS t FROM {HCP} WHERE projet = %s', (projet,))
    attendu = cur.fetchone()['t']
    cur.execute("""
        SELECT round(sum(COALESCE(NULLIF(REPLACE(TRIM(v.val), ',', '.'), '')::numeric, 0)), 2) AS t
        FROM raw_data.rpsco r
        JOIN raw_data.prps p ON p.objnr = r.objnr
        JOIN raw_data.proj j ON j.mandt = p.mandt AND j.pspnr = p.psphi
        CROSS JOIN LATERAL (VALUES (r.wlp00),(r.wlp01),(r.wlp02),(r.wlp03),(r.wlp04),(r.wlp05),
            (r.wlp06),(r.wlp07),(r.wlp08),(r.wlp09),(r.wlp10),(r.wlp11),(r.wlp12),(r.wlp13),
            (r.wlp14),(r.wlp15),(r.wlp16)) AS v(val)
        WHERE j.pspid = %s AND p.pbukr = 'STJN'
          AND r.lednr = '0003' AND r.versn = '000' AND r.wrttp = '04'
          AND r.vorga <> 'KOAO' AND r.gjahr <> '0000'
    """, (projet,))
    assert cur.fetchone()['t'] == attendu


def test_rpsco_vide_ne_purge_pas(cur):
    """Extraction SAP en cours (rpsco vide) : la table garde son contenu."""
    cur.execute(f'SELECT count(*) AS n FROM {HCP}')
    avant = cur.fetchone()['n']
    cur.execute('DELETE FROM raw_data.rpsco')
    cur.execute('SELECT clean_data.alimenter_historique_cout_projet() AS n')
    assert cur.fetchone()['n'] == 0
    cur.execute(f'SELECT count(*) AS n FROM {HCP}')
    assert cur.fetchone()['n'] == avant


def test_numero_projet_meme_regle_que_commandes_achat(cur):
    """N° projet SharePoint : cle sans points ni suffixe alphabetique (OTP puis projet),
    une seule valeur par projet."""
    cur.execute(f"""SELECT count(*) AS n FROM (SELECT projet FROM {HCP}
                    GROUP BY projet HAVING count(DISTINCT numero_projet) > 1) x""")
    assert cur.fetchone()['n'] == 0
    cur.execute(f"""SELECT h.numero_projet, s.project_number
                    FROM {HCP} h JOIN raw_data.sharepoint_projets s
                      ON REGEXP_REPLACE(REPLACE(UPPER(TRIM(s.code)), '.', ''), '[A-Z]+$', '') = h.projet
                    WHERE h.projet LIKE 'SN%%' AND h.numero_projet IS NOT NULL LIMIT 1""")
    r = cur.fetchone()
    assert r is not None and r['numero_projet'] == r['project_number']
