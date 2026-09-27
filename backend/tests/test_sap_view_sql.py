"""Generateur CREATE VIEW d'une vue SAP (services/sap_view_sql.py), sans base."""
from services.sap_view_sql import build_view_sql


def _jl(t, f):
    return {'tabname': t, 'fieldname': f, 'negation': 'JL', 'operator': 'EQ', 'constants': None, 'and_or': None}


def _jr(t, f):
    return {'tabname': t, 'fieldname': f, 'negation': 'JR', 'operator': 'EQ', 'constants': None, 'and_or': 'AND'}


# Extrait reel de dd26s/dd27s/dd28s pour IFLO ; iloa sans mandt pour tester l'ignorance du mandant
IFLO_TABLES = ['IFLOT', 'ILOA', 'IFLOTX']
IFLO_FIELDS = [
    {'viewfield': 'TPLNR', 'tabname': 'IFLOT', 'fieldname': 'TPLNR'},
    {'viewfield': '*', 'tabname': 'IFLOTX', 'fieldname': '*'},
    {'viewfield': '-', 'tabname': 'IFLOTX', 'fieldname': 'MANDT'},
    {'viewfield': 'PLTXT', 'tabname': 'IFLOTX', 'fieldname': 'PLTXT'},
    {'viewfield': 'KOSTL', 'tabname': 'ILOA', 'fieldname': 'KOSTL'},
    {'viewfield': 'OWNER', 'tabname': 'ILOA', 'fieldname': 'OWNER'},
]
IFLO_CONDS = [
    _jl('ILOA', 'MANDT'), _jr('IFLOT', 'MANDT'),
    _jl('ILOA', 'ILOAN'), _jr('IFLOT', 'ILOAN'),
    _jl('IFLOT', 'MANDT'), _jr('IFLOTX', 'MANDT'),
    _jl('IFLOT', 'TPLNR'), _jr('IFLOTX', 'TPLNR'),
]
COLUMNS = {
    'iflot': {'mandt': 'character varying', 'tplnr': 'character varying', 'iloan': 'character varying'},
    'iloa': {'iloan': 'character varying', 'kostl': 'character varying'},
    'iflotx': {'mandt': 'character varying', 'tplnr': 'character varying', 'pltxt': 'character varying'},
}


def test_iflo_jointures_et_champs():
    r = build_view_sql('IFLO', IFLO_TABLES, IFLO_FIELDS, IFLO_CONDS, COLUMNS)
    assert r['blocking'] == []
    sql = r['sql']
    assert sql.startswith('DROP VIEW IF EXISTS sap_view."iflo";\nCREATE VIEW sap_view."iflo" AS')
    assert 'FROM raw_data."iflot" AS "iflot"' in sql
    assert 'JOIN raw_data."iloa" AS "iloa"\n      ON "iloa"."iloan" = "iflot"."iloan"' in sql
    assert '"iflot"."mandt" = "iflotx"."mandt"\n     AND "iflot"."tplnr" = "iflotx"."tplnr"' in sql
    assert 'NULL::text AS "owner"' in sql          # champ non extrait -> NULL
    assert '"-"' not in sql and '"*"' not in sql    # marqueurs SAP ignores
    assert 'WHERE' not in sql
    assert any('mandant' in w for w in r['warnings'])


def test_table_absente_bloque():
    cols = {k: v for k, v in COLUMNS.items() if k != 'iloa'}
    r = build_view_sql('IFLO', IFLO_TABLES, IFLO_FIELDS, IFLO_CONDS, cols)
    assert r['sql'] is None
    assert r['blocking'] == ['Tables absentes de raw_data : ILOA']


def test_filtres_or_groupes_not_et_constantes():
    f = lambda fld, op, c, ao, neg=None: {'tabname': 'TADIR', 'fieldname': fld, 'negation': neg,
                                          'operator': op, 'constants': c, 'and_or': ao}
    conds = [
        f('PGMID', 'EQ', "'R3TR'", 'AND'),
        f('OBJECT', 'EQ', "'FUGR'", 'OR'),
        f('OBJECT', 'EQ', "'FUGX'", 'AND'),
        f('DELFLAG', 'EQ', "'X'", 'AND', 'NOT'),
        f('LANGU', 'EQ', 'SY-LANGU', 'AND'),
        f('PGMID', 'EQ', 'T500P-MOLGA', None),
    ]
    cols = {'tadir': {'pgmid': 'text', 'object': 'text', 'delflag': 'text', 'langu': 'text', 'obj_name': 'text'}}
    r = build_view_sql('APPL_FUGR', ['TADIR'],
                       [{'viewfield': 'OBJ_NAME', 'tabname': 'TADIR', 'fieldname': 'OBJ_NAME'}], conds, cols)
    assert r['filters'] == [
        "COALESCE(TRIM(\"tadir\".\"pgmid\"::text), '') = 'R3TR'",
        "(COALESCE(TRIM(\"tadir\".\"object\"::text), '') = 'FUGR' OR COALESCE(TRIM(\"tadir\".\"object\"::text), '') = 'FUGX')",
        "NOT (COALESCE(TRIM(\"tadir\".\"delflag\"::text), '') = 'X')",
        "COALESCE(TRIM(\"tadir\".\"langu\"::text), '') = 'F'",
    ]
    assert any('non traduisible' in w for w in r['warnings'])
