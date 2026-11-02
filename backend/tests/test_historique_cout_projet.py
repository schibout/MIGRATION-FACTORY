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
MIGRATIONS_DIR = os.environ.get('HCP_MIGRATIONS_DIR') or os.path.join(os.path.dirname(BACKEND), 'migrations')
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
        with open(os.path.join(MIGRATIONS_DIR, '126_reprise_cout_projet_ifs.sql'), encoding='utf-8') as f:
            cur.execute(f.read())
        for name in ('01_create_clean_data_historique_cout_projet.sql',
                     '02_alimenter_historique_cout_projet.sql',
                     '03_reprise_cout_projet.sql'):
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


def test_a_migrer_si_projet_dans_project_base(cur):
    """a_migrer = numero_projet present dans clean_data.project_base, sinon FALSE."""
    cur.execute(f"""SELECT count(*) AS n FROM {HCP} h
                    WHERE h.a_migrer IS DISTINCT FROM EXISTS (
                        SELECT 1 FROM clean_data.project_base pb WHERE pb.project_id = h.numero_projet)""")
    assert cur.fetchone()['n'] == 0
    cur.execute(f'SELECT count(*) FILTER (WHERE a_migrer) AS oui, count(*) FILTER (WHERE NOT a_migrer) AS non FROM {HCP}')
    r = cur.fetchone()
    assert r['oui'] > 0 and r['non'] > 0


# --- Reprise IFS (migration 126, 03_reprise_cout_projet.sql) ----------------

def test_calendrier_fiscal_juillet_juin(cur):
    """Exercice STJN Z2 : juillet = periode 1, juin = 12 ; exercice 2027 = 07/2026 -> 06/2027."""
    for d, attendu in (('2026-07-31', (2027, 1)), ('2026-10-31', (2027, 4)), ('2026-12-31', (2027, 6)),
                       ('2027-01-31', (2027, 7)), ('2027-06-30', (2027, 12)), ('2026-06-30', (2026, 12))):
        cur.execute('SELECT exercice, periode FROM clean_data.exercice_periode_stjn(%s)', (d,))
        r = cur.fetchone()
        assert (r['exercice'], r['periode']) == attendu, d


def test_nature_par_suffixe(cur):
    for otp, nature in (('SN26052IM', 'CAPEX'), ('SN.26052.IM', 'CAPEX'), ('sn26052ex ', 'OPEX'),
                        ('SN.26052.EX', 'OPEX'), ('SN19031', None), ('CS.21002', None)):
        cur.execute('SELECT clean_data.nature_suffixe_otp(%s) AS n', (otp,))
        assert cur.fetchone()['n'] == nature, otp


def test_ventilation_capex_opex_sans_cumul(cur):
    """Reel CAPEX + OPEX + a qualifier = reel de la periode, ligne a ligne."""
    cur.execute("""SELECT count(*) AS n FROM clean_data.v_historique_cout_projet
                   WHERE reel_capex + reel_opex + reel_a_qualifier <> reel
                      OR (reel_capex <> 0)::int + (reel_opex <> 0)::int + (reel_a_qualifier <> 0)::int > 1""")
    assert cur.fetchone()['n'] == 0


def test_arrete_mensuel_seulement(cur):
    cur.execute('SAVEPOINT s')
    with pytest.raises(psycopg2.Error):
        cur.execute("SELECT * FROM clean_data.reprise_cout_projet('2026-09-15')")
    cur.execute('ROLLBACK TO SAVEPOINT s')


def test_montant_somme_des_periodes_jusqu_a_l_arrete(cur):
    """Arrete 31/10/2026 = exercice 2027 periode 4 : exercices anterieurs + 2027 periodes 0..4,
    projets a migrer seulement, ni plan ni engagements."""
    cur.execute("SELECT * FROM clean_data.reprise_cout_projet('2026-10-31')")
    rows = cur.fetchall()
    assert rows and {(r['exercice'], r['periode']) for r in rows} == {(2027, 4)}
    # Tous les OTP a migrer sont listes, y compris ceux dont le reel est posterieur (montant 0)
    cur.execute(f"""SELECT count(DISTINCT element_otp) AS otp,
                           round(sum(reel) FILTER (WHERE annee < 2027 OR (annee = 2027 AND periode <= 4)), 2) AS t
                    FROM {HCP} WHERE a_migrer""")
    attendu = cur.fetchone()
    assert len(rows) == attendu['otp']
    assert round(sum(r['montant'] for r in rows), 2) == attendu['t']
    cur.execute(f'SELECT count(DISTINCT projet) AS n FROM {HCP} WHERE NOT a_migrer')
    assert cur.fetchone()['n'] > 0  # des projets exclus existent...
    cur.execute(f'SELECT DISTINCT projet FROM {HCP} WHERE a_migrer')
    assert {r['projet'] for r in rows} <= {x['projet'] for x in cur.fetchall()}  # ...et n'y sont pas


def test_aucun_cumul_parent_enfant_ni_doublon(cur):
    cur.execute("""SELECT count(*) AS n FROM clean_data.reprise_cout_projet('2099-06-30')
                   WHERE anomalies && ARRAY['CUMUL_PARENT_ENFANTS', 'OTP_EN_DOUBLE']""")
    assert cur.fetchone()['n'] == 0


def test_qualification_et_sequences_levent_les_anomalies(cur):
    cur.execute("""SELECT * FROM clean_data.reprise_cout_projet('2099-06-30')
                   WHERE 'NATURE_A_QUALIFIER' = ANY(anomalies) AND EXISTS (
                       SELECT 1 FROM clean_data.activity a WHERE a.project_id = project_id_ifs) LIMIT 1""")
    r = cur.fetchone()
    assert r is not None and r['nature'] is None and not r['exporte']
    cur.execute("""INSERT INTO clean_data.reprise_cout_otp_nature (element_otp, nature, qualifie_par)
                   VALUES (%s, 'CAPEX', 'test')""", (r['element_otp'],))
    cur.execute("""SELECT activity_seq FROM clean_data.activity WHERE project_id = %s LIMIT 1""",
                (r['project_id_ifs'],))
    seq = cur.fetchone()['activity_seq']
    cur.execute("""INSERT INTO clean_data.reprise_cout_projet_ifs (numero_projet, activity_seq_capex, saisi_par)
                   VALUES (%s, %s, 'test')""", (r['numero_projet'], seq))
    cur.execute("""SELECT * FROM clean_data.reprise_cout_projet('2099-06-30')
                   WHERE numero_projet = %s AND element_otp = %s""", (r['numero_projet'], r['element_otp']))
    apres = cur.fetchone()
    assert apres['nature'] == 'CAPEX' and apres['nature_source'] == 'MANUELLE'
    assert apres['activity_seq'] == seq and apres['anomalies'] == [] and apres['exporte']
    cur.execute("UPDATE clean_data.reprise_cout_projet_ifs SET activity_seq_capex = -1 WHERE numero_projet = %s",
                (r['numero_projet'],))
    cur.execute("""SELECT anomalies FROM clean_data.reprise_cout_projet('2099-06-30')
                   WHERE numero_projet = %s AND element_otp = %s""", (r['numero_projet'], r['element_otp']))
    assert 'SEQUENCE_INCONNUE' in cur.fetchone()['anomalies']
