"""
Texte de commande SAP -> clean_data.part_catalog.info_text (2026-09-19).

Source : raw_data.sap_long_text (textes longs MATERIAL / BEST / F lus par
RFC_READ_TEXT, une ligne SAPscript par enregistrement, ordonnee par line_no).
clean_data.alimenter_part_catalog() recompose le texte via
clean_data.texte_long_sap (sql/functions/) :
  - '*' et '/'  : nouvelle ligne
  - '='         : suite de la ligne precedente (sans saut)
  - '/:' et '/*': commande / commentaire SAPscript, ignores
puis TRIM et LEFT(..., 2000) (taille de la colonne IFS). Article sans texte
-> NULL.

Vraie base, transaction jamais validee : la fonction du depot est recompilee
dans la transaction, des lignes de texte de controle sont injectees pour deux
articles du catalogue, puis part_catalog est recharge (TRUNCATE + INSERT) dans
cette meme transaction.
"""
import os
import sys

import psycopg2
import psycopg2.extras
import pytest

BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SQL_DIR = os.path.join(os.path.dirname(BACKEND), 'sql', 'inventory')
if BACKEND not in sys.path:
    sys.path.insert(0, BACKEND)

SMT = 'raw_data.sap_long_text'


def _lignes(tdname, lignes):
    """[(tdformat, tdline), ...] -> tuples (tdobject, tdname, tdid, tdspras, line_no, tdformat, tdline)."""
    return [('MATERIAL', tdname, 'BEST', 'F', str(i), fmt, txt)
            for i, (fmt, txt) in enumerate(lignes, start=1)]


@pytest.fixture(scope='module')
def ctx():
    try:
        try:
            from config.database import get_db_params
            params = get_db_params()
        except ImportError:
            params = {'host': os.getenv('DB_HOST', '10.190.100.58'), 'port': os.getenv('DB_PORT', '5432'),
                      'database': os.getenv('DB_NAME', 'sap_migration_db'),
                      'user': os.getenv('DB_USER', 'postgres'), 'password': os.getenv('DB_PASSWORD', '')}
        conn = psycopg2.connect(**params)
    except Exception as exc:  # pragma: no cover
        pytest.skip(f'base injoignable : {exc}')
    try:
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cur.execute("SET statement_timeout = '600s'")
        for path in (os.path.join(SQL_DIR, '..', 'functions', 'texte_long_sap.sql'),
                     os.path.join(SQL_DIR, 'alimenter_part_catalog.sql')):
            with open(path, encoding='utf-8') as f:
                cur.execute(f.read())

        # Trois articles du perimetre du catalogue (division 9200/9000), pris
        # dans la table pilote pour ne dependre d'aucune reference precise.
        cur.execute("""
            SELECT va.numero_article
            FROM clean_data.ifs_article_maitre va
            WHERE EXISTS (SELECT 1 FROM raw_data.marc c
                          WHERE c.matnr::text = va.numero_article AND c.mandt::text = '700'
                            AND c.werks::text IN ('9200', '9000'))
            ORDER BY va.numero_article
            LIMIT 3""")
        art = [r['numero_article'] for r in cur.fetchall()]
        assert len(art) == 3
        a_multi, a_long, a_sans = art

        # Les textes de controle remplacent, dans la transaction, ceux extraits de SAP
        cur.execute(f"DELETE FROM {SMT} WHERE tdname = ANY(%s)", (art,))
        lignes = _lignes(a_multi, [
            ('*', 'ALUMINIUM CALCIUM 4%'),
            ('/:', 'INCLUDE ZTEXT OBJECT TEXT ID ST'),   # commande SAPscript : ignoree
            ('/', 'ID 360 mm '),
            ('=', '+/- 25 mm'),                          # suite de la ligne precedente
            ('/*', 'commentaire interne'),               # commentaire : ignore
            ('*', 'OD 890 mm'),
        ])
        lignes += _lignes(a_long, [('*', 'X' * 132)] * 20)   # 20 x 132 + 19 sauts = 2 659 > 2 000
        psycopg2.extras.execute_values(
            cur,
            f"INSERT INTO {SMT} (tdobject, tdname, tdid, tdspras, line_no, tdformat, tdline) VALUES %s",
            lignes)

        cur.execute("SELECT clean_data.alimenter_part_catalog()")
        yield {'cur': cur, 'multi': a_multi.lstrip('0'), 'long': a_long.lstrip('0'),
               'sans': a_sans.lstrip('0')}
    finally:
        conn.rollback()
        conn.close()


def _info_text(ctx, part_no):
    ctx['cur'].execute("SELECT info_text FROM clean_data.part_catalog WHERE part_no = %s", (part_no,))
    row = ctx['cur'].fetchone()
    assert row is not None, f'article {part_no} absent de part_catalog'
    return row['info_text']


def test_texte_de_commande_recompose_selon_sapscript(ctx):
    assert _info_text(ctx, ctx['multi']) == 'ALUMINIUM CALCIUM 4%\nID 360 mm +/- 25 mm\nOD 890 mm'


def test_texte_tronque_a_2000_caracteres(ctx):
    texte = _info_text(ctx, ctx['long'])
    assert len(texte) == 2000
    assert texte.startswith('X' * 132 + '\n')


def test_article_sans_texte_reste_null(ctx):
    assert _info_text(ctx, ctx['sans']) is None
