"""Colonnes et tables lues d'une vue Oracle (sans base)."""
from services.ifs_dictionary_service import build_report, view_columns, view_tables

SQL = """WITH x AS (SELECT a, b FROM t1)
SELECT DISTINCT p.part_no, Fnd_Boolean_API.Decode(q, 'a,b') qualified_supplier,
       to_char(rowversion,'YYYYMMDDHH24MISS') objversion, rowid objid, "Mixed" , x.*
FROM purchase_part_tab p JOIN x ON x.a = p.a -- commentaire, avec virgule
WHERE EXISTS (SELECT 1 FROM user_allowed_site_pub)
UNION SELECT 1, 2, 3, 4, 5 FROM dual"""


def test_view_columns():
    assert view_columns(SQL) == ['PART_NO', 'QUALIFIED_SUPPLIER', 'OBJVERSION', 'OBJID', 'Mixed']
    assert view_columns('(select a from t)') == ['A']
    assert view_columns(None) == []
    assert view_columns('SELECT a x, b y, Decode(c, NULL') == ['X', 'Y']


def test_view_tables_et_rapport():
    assert view_tables(SQL) == ['T1', 'PURCHASE_PART_TAB', 'X', 'USER_ALLOWED_SITE_PUB']
    cols = [{'column_name': c, 'column_id': i + 1} for i, c in enumerate(view_columns(SQL))]
    sql = build_report({'owner': 'IFSAPP', 'table_name': 'V'}, cols, ['PART_NO', 'OBJID'], True)
    assert 'FROM IFSAPP.V' in sql and '"PART_NO"' in sql and 'OBJVERSION' not in sql
