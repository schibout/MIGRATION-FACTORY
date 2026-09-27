"""
Textes longs SAP (raw_data.sap_long_text, lus par RFC_READ_TEXT) -> IFS
(2026-09-20).

1. clean_data.texte_long_sap(objet, id, nom, langues[]) recompose un texte
   SAPscript : '*', '/' et format vide = nouvelle ligne, '=' = suite de la
   ligne precedente (sans saut), '/:' et '/*' ignores ; espaces de fin de
   ligne retires, btrim, LEFT 2000 ; NULL si aucune ligne. La langue retenue
   est la premiere du tableau qui a un texte.
2. clean_data.alimenter_purchase_part_supplier() : note_text = texte AT de la
   fiche-info (EINA, tdname = infnr) puis texte BT (EINE, tdname = infnr ||
   ekorg || esokz || werks), separes par un saut de ligne, langue F puis E, D,
   N ; NULL si aucun.

Vraie base, transaction jamais validee : fonctions recompilees dans la
transaction, lignes de texte de controle injectees, purchase_part_supplier
recharge (TRUNCATE + INSERT) dans cette meme transaction (~2 min).
"""
import os
import sys

import psycopg2
import psycopg2.extras
import pytest

BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SQL_ROOT = os.path.join(os.path.dirname(BACKEND), 'sql')
if BACKEND not in sys.path:
    sys.path.insert(0, BACKEND)

SLT = 'raw_data.sap_long_text'


def _lignes(objet, tdname, tdid, tdspras, lignes):
    return [(objet, tdname, tdid, tdspras, str(i), fmt, txt)
            for i, (fmt, txt) in enumerate(lignes, start=1)]


def _inserer(cur, lignes):
    psycopg2.extras.execute_values(
        cur, f"INSERT INTO {SLT} (tdobject, tdname, tdid, tdspras, line_no, tdformat, tdline) VALUES %s",
        lignes)


@pytest.fixture(scope='module')
def conn():
    try:
        try:
            from config.database import get_db_params
            params = get_db_params()
        except ImportError:
            params = {'host': os.getenv('DB_HOST', '10.190.100.58'), 'port': os.getenv('DB_PORT', '5432'),
                      'database': os.getenv('DB_NAME', 'sap_migration_db'),
                      'user': os.getenv('DB_USER', 'postgres'), 'password': os.getenv('DB_PASSWORD', '')}
        c = psycopg2.connect(**params)
    except Exception as exc:  # pragma: no cover
        pytest.skip(f'base injoignable : {exc}')
    try:
        cur = c.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cur.execute("SET statement_timeout = '900s'")
        for rel in ('functions/texte_long_sap.sql', 'inventory/alimenter_purchase_part_supplier.sql'):
            with open(os.path.join(SQL_ROOT, rel), encoding='utf-8') as f:
                cur.execute(f.read())
        yield c
    finally:
        c.rollback()
        c.close()


@pytest.fixture(scope='module')
def cur(conn):
    return conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)


def _texte(cur, objet, tdid, nom, langues):
    cur.execute("SELECT clean_data.texte_long_sap(%s, %s, %s, %s) AS t", (objet, tdid, nom, langues))
    return cur.fetchone()['t']


# --------------------------------------------------------- texte_long_sap

def test_recomposition_sapscript(cur):
    _inserer(cur, _lignes('TEST', 'K1', 'X', 'F', [
        ('*', 'ligne 1'), ('/:', 'INCLUDE ...'), ('/', 'ligne 2 '), ('=', 'suite'),
        ('/*', 'commentaire'), ('', 'ligne 3'),
    ]))
    assert _texte(cur, 'TEST', 'X', 'K1', ['F']) == 'ligne 1\nligne 2 suite\nligne 3'


def test_premiere_langue_disponible_dans_l_ordre_demande(cur):
    _inserer(cur, _lignes('TEST', 'K2', 'X', 'E', [('*', 'english')])
             + _lignes('TEST', 'K2', 'X', 'D', [('*', 'deutsch')]))
    assert _texte(cur, 'TEST', 'X', 'K2', ['F', 'E', 'D']) == 'english'
    assert _texte(cur, 'TEST', 'X', 'K2', ['F', 'D', 'E']) == 'deutsch'
    assert _texte(cur, 'TEST', 'X', 'K2', ['F']) is None


def test_tronque_a_2000_et_null_sans_texte(cur):
    _inserer(cur, _lignes('TEST', 'K3', 'X', 'F', [('*', 'X' * 132)] * 20))
    assert len(_texte(cur, 'TEST', 'X', 'K3', ['F'])) == 2000
    assert _texte(cur, 'TEST', 'X', 'INCONNU', ['F']) is None


# ------------------------------------------- purchase_part_supplier.note_text

@pytest.fixture(scope='module')
def pps(conn, cur):
    """Trois liens fournisseur-article du perimetre, textes de controle, rechargement."""
    cur.execute("""
        SELECT eina.infnr, eine.ekorg, eine.esokz, COALESCE(eine.werks, '') AS werks,
               SUBSTRING(TRIM(LTRIM(eina.matnr, '0')), 1, 25) AS part_no,
               CASE WHEN eine.ekorg = '9000' THEN 'CS' ELSE 'SJ' END AS contract
        FROM raw_data.eina eina
        JOIN raw_data.eine eine ON eine.infnr = eina.infnr AND eine.mandt = '700'
        JOIN clean_data.purchase_part_supplier p
          ON p.part_no = SUBSTRING(TRIM(LTRIM(eina.matnr, '0')), 1, 25)
         AND p.contract = CASE WHEN eine.ekorg = '9000' THEN 'CS' ELSE 'SJ' END
        WHERE eine.ekorg IN ('9200', '9000')
        ORDER BY eina.infnr LIMIT 3""")
    liens = cur.fetchall()
    assert len(liens) == 3
    at_bt, at_seul, sans = liens
    cle_bt = lambda l: (l['infnr'] + l['ekorg'] + l['esokz'] + l['werks']).strip()

    cur.execute(f"DELETE FROM {SLT} WHERE tdobject IN ('EINA', 'EINE') AND tdname = ANY(%s)",
                ([l['infnr'] for l in liens] + [cle_bt(l) for l in liens],))
    _inserer(cur, _lignes('EINA', at_bt['infnr'], 'AT', 'F', [('*', 'Texte fiche-info')])
             + _lignes('EINE', cle_bt(at_bt), 'BT', 'F', [('*', 'Texte de commande'), ('/', 'ligne 2')])
             + _lignes('EINA', at_seul['infnr'], 'AT', 'E', [('*', 'Info record text (EN only)')]))
    cur.execute("SELECT clean_data.alimenter_purchase_part_supplier()")

    def note(l):
        cur.execute("SELECT note_text FROM clean_data.purchase_part_supplier WHERE contract=%s AND part_no=%s",
                    (l['contract'], l['part_no']))
        rows = cur.fetchall()
        assert rows, f"lien {l} absent apres rechargement"
        return rows
    return {'at_bt': note(at_bt), 'at_seul': note(at_seul), 'sans': note(sans)}


def test_note_text_concatene_at_puis_bt(pps):
    assert any(r['note_text'] == 'Texte fiche-info\nTexte de commande\nligne 2' for r in pps['at_bt'])


def test_note_text_replie_sur_l_anglais(pps):
    assert any(r['note_text'] == 'Info record text (EN only)' for r in pps['at_seul'])


def test_note_text_null_sans_texte(pps):
    assert all(r['note_text'] is None for r in pps['sans'])
