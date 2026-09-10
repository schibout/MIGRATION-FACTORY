"""Catalogue Oracle/IFS : parsing, rapport de référence et intégration PostgreSQL.

IFS_CATALOG_TEST_DATABASE_URL active les tests SQL sur une base dédiée dont le
nom commence par ifs_catalog_test. Les tables du catalogue y sont vidées.
"""
import importlib.util
import io
import json
import os
from pathlib import Path
from unittest.mock import Mock

import pytest
from flask import Flask
from flask_jwt_extended import JWTManager, create_access_token
from openpyxl import Workbook
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import IntegrityError

from models import User, db
from services.ifs_dictionary_service import build_report, import_catalog, parse_catalog

ROOT = Path(__file__).resolve().parents[2]
TABLES = (ROOT / 'docs/ifs_Catalog/ifs_table_name.csv').read_bytes()
COLUMNS = (ROOT / 'docs/ifs_Catalog/COLUMN_NAME.csv').read_bytes()


def xlsx(csv_bytes, values=None):
    """Classeur .xlsx reprenant un CSV fourni ; values remplace les cellules du 1er onglet."""
    workbook = Workbook()
    sheet = workbook.active
    for line in values or [row.split(';') for row in csv_bytes.decode('utf-8-sig').splitlines() if row]:
        sheet.append(line)
    buffer = io.BytesIO()
    workbook.save(buffer)
    return buffer.getvalue()


TABLES_XLSX = xlsx(TABLES)
COLUMNS_XLSX = xlsx(COLUMNS)


def test_supplied_csv_and_metadata():
    tables, columns = parse_catalog(TABLES, COLUMNS)
    assert len(tables) == 2
    assert len(columns) == 9
    assert columns[0]['column_name'] == 'DUMMY'
    assert columns[0]['nullable'] is True
    assert columns[1]['nullable'] is False
    assert columns[2]['data_scale'] == 0
    assert 'Collation' in columns[0]['metadata']


def test_report_matches_supplied_template_exactly():
    template = (ROOT / 'docs/ifs_Catalog/report.md').read_text()
    import re
    names = re.findall(r'^    "([^"]+)"', template, re.MULTILINE)
    columns = [{'column_name': name, 'column_id': i + 1} for i, name in enumerate(names)]
    assert build_report({'owner': 'IFSAPP', 'table_name': 'PART_CATALOG'}, columns).strip() == template.strip()


def test_report_selection_uses_catalog_order_and_quotes_identifiers():
    columns = [{'column_name': 'B', 'column_id': 2}, {'column_name': 'A"x', 'column_id': 1}]
    sql = build_report({'owner': 'IFSAPP', 'table_name': 'Mixed Table'}, columns, ['B', 'A"x'], True)
    assert '    "A""x",\n    "B"' in sql
    assert 'FROM IFSAPP."Mixed Table"' in sql
    assert '        "A""x",' in sql


@pytest.mark.parametrize('selection', [[], ['ABSENT'], ['A', 'A'], 'A', [None], [1]])
def test_invalid_report_selection(selection):
    with pytest.raises(ValueError):
        build_report({'table_name': 'T'}, [{'column_name': 'A', 'column_id': 1}], selection)


def test_report_without_columns_is_rejected():
    with pytest.raises(ValueError):
        build_report({'table_name': 'T'}, [])


def test_bom_cp1252_and_multiline_default():
    tables = 'Owner;Table Name;Status\r\nIFSAPP;T;Validé\r\n'.encode('cp1252')
    columns = ('\ufeffOwner;Table Name;Column Name;Data Type;Nullable;Column Id;Data Default\r\n'
               'IFSAPP;T;C;VARCHAR2;Y;1;"texte;avec\nretour"\r\n').encode('utf-8')
    parsed_tables, parsed_columns = parse_catalog(tables, columns)
    assert parsed_tables[0]['status'] == 'Validé'
    assert parsed_columns[0]['data_default'] == 'texte;avec\nretour'


@pytest.mark.parametrize('tables,columns', [
    (b'Owner,Table Name\nIFSAPP,T', COLUMNS),
    (TABLES, COLUMNS.replace(b'SYS;DUAL;', b'IFSAPP;MISSING;', 1)),
    (TABLES, COLUMNS.replace(b';N;2;', b';N;1;', 1)),
    (TABLES, COLUMNS.replace(b';Y;1;', b';MAYBE;1;', 1)),
    (TABLES, COLUMNS.replace(b';Y;1;', b';Y;0;', 1)),
    (TABLES, COLUMNS.replace(b';Y;1;', b';Y;1.5;', 1)),
    (TABLES, COLUMNS + b'extra;row\n'),
    (b'', b''),
    (None, None),
])
def test_invalid_import_never_opens_a_transaction(tables, columns):
    engine = Mock()
    with pytest.raises(ValueError):
        import_catalog(engine, tables, columns)
    engine.begin.assert_not_called()


def test_repeated_rows_overwrite_instead_of_failing():
    # Le fichier Oracle répète parfois une table : la dernière ligne l'emporte.
    repeated = TABLES + TABLES.splitlines(keepends=True)[1].replace(b';VALID;', b';INVALID;', 1)
    tables, _ = parse_catalog(repeated, COLUMNS)
    assert [table['table_name'] for table in tables] == ['DUAL', 'PENDING_TRANS$']
    assert tables[0]['status'] == 'INVALID'
    # Idem pour une colonne répétée, y compris son Column Id.
    _, columns = parse_catalog(TABLES, COLUMNS + COLUMNS.splitlines(keepends=True)[1].replace(b';Y;1;', b';N;1;', 1))
    assert len(columns) == 9
    assert columns[0]['nullable'] is False


def test_excel_workbooks_parse_like_the_csv():
    assert parse_catalog(TABLES_XLSX, COLUMNS_XLSX) == parse_catalog(TABLES, COLUMNS)
    # Formats mixtes : un CSV d'un côté, un classeur de l'autre.
    assert parse_catalog(TABLES, COLUMNS_XLSX) == parse_catalog(TABLES, COLUMNS)


def test_excel_numbers_blank_rows_and_trailing_columns():
    headers = ['Owner', 'Table Name', 'Column Name', 'Data Type', 'Nullable', 'Column Id', 'Num Rows', '']
    book = xlsx(None, [headers, [], ['IFSAPP', 'T', 'C', 'VARCHAR2', 'Y', 1, 12000, None],
                       [None] * 8, ['IFSAPP', 'T', 'D', 'NUMBER', 'N', 2.0, None, None]])
    tables, columns = parse_catalog(None, book)
    assert (tables, len(columns)) == ([], 2)
    # Entiers Excel : 2 et non 2.0, et pas de colonne parasite dans les métadonnées.
    assert columns[1]['column_id'] == 2
    assert json.loads(columns[0]['metadata'])['Num Rows'] == '12000'


@pytest.mark.parametrize('content', [
    b'PK\x03\x04 archive tronquee',
    b'\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1 ancien classeur .xls',
    xlsx(None, [['Owner', 'Table Name'], ['IFSAPP', '']]),
    xlsx(None, [['Owner', 'Owner'], ['IFSAPP', 'IFSAPP']]),
    xlsx(None, [['Owner', 'Table Name'], ['IFSAPP', 'T', 'de trop']]),
    xlsx(None, [['Owner', 'Table Name']]),
])
def test_invalid_excel_is_rejected(content):
    with pytest.raises(ValueError):
        parse_catalog(content, None)


def test_each_file_is_optional_when_parsing():
    tables, columns = parse_catalog(TABLES, None)
    assert (len(tables), columns) == (2, [])
    tables, columns = parse_catalog(None, COLUMNS)
    assert (tables, len(columns)) == ([], 9)


@pytest.fixture()
def pg_engine():
    url = os.environ.get('IFS_CATALOG_TEST_DATABASE_URL')
    if not url:
        pytest.skip('Base PostgreSQL de test non configurée')
    assert (make_url(url).database or '').startswith('ifs_catalog_test'), 'Base de test dédiée requise'
    engine = create_engine(url)
    migration = (ROOT / 'migrations/073_create_ifs_dictionary.sql').read_text()
    with engine.connect() as connection:
        connection.exec_driver_sql(migration)
        connection.exec_driver_sql(migration)  # rejouable
        connection.commit()
        connection.execute(text('TRUNCATE public.ifs_column_catalog, public.ifs_table_catalog RESTART IDENTITY'))
        connection.commit()
    yield engine
    engine.dispose()


def test_import_upsert_preserves_other_entries(pg_engine):
    import_catalog(pg_engine, TABLES, COLUMNS)
    import_catalog(pg_engine, TABLES, COLUMNS)
    # Un fichier partiel n'efface ni l'autre table, ni ses colonnes.
    partial_tables = b'\n'.join(TABLES.splitlines()[:2])
    partial_columns = b'\n'.join(COLUMNS.splitlines()[:2]).replace(b';Y;1;', b';N;1;')
    import_catalog(pg_engine, partial_tables, partial_columns)
    with pg_engine.connect() as connection:
        assert connection.execute(text('SELECT count(*) FROM public.ifs_table_catalog')).scalar() == 2
        assert connection.execute(text('SELECT count(*) FROM public.ifs_column_catalog')).scalar() == 9
        assert connection.execute(text("SELECT nullable FROM public.ifs_column_catalog WHERE column_name='DUMMY'")).scalar() is False


def test_import_accepts_a_file_with_repeated_rows(pg_engine):
    repeated_tables = TABLES + TABLES.splitlines(keepends=True)[1].replace(b';VALID;', b';INVALID;', 1)
    repeated_columns = COLUMNS + COLUMNS.splitlines(keepends=True)[1].replace(b';Y;1;', b';N;1;', 1)
    assert import_catalog(pg_engine, repeated_tables, repeated_columns) == {
        'tables_imported': 2, 'columns_imported': 9}
    with pg_engine.connect() as connection:
        assert connection.execute(text("SELECT status FROM public.ifs_table_catalog WHERE table_name='DUAL'")).scalar() == 'INVALID'
        assert connection.execute(text("SELECT nullable FROM public.ifs_column_catalog WHERE column_name='DUMMY'")).scalar() is False


def test_tables_and_columns_can_be_imported_separately(pg_engine):
    assert import_catalog(pg_engine, TABLES) == {'tables_imported': 2, 'columns_imported': 0}
    with pg_engine.connect() as connection:
        assert connection.execute(text('SELECT count(*) FROM public.ifs_table_catalog')).scalar() == 2
        assert connection.execute(text('SELECT count(*) FROM public.ifs_column_catalog')).scalar() == 0
    # Les colonnes seules se rattachent aux tables déjà présentes au catalogue.
    assert import_catalog(pg_engine, columns_csv=COLUMNS) == {'tables_imported': 0, 'columns_imported': 9}
    with pg_engine.connect() as connection:
        assert connection.execute(text('SELECT count(*) FROM public.ifs_column_catalog')).scalar() == 9


def test_columns_alone_require_tables_already_in_the_catalog(pg_engine):
    with pytest.raises(ValueError):
        import_catalog(pg_engine, columns_csv=COLUMNS)
    with pg_engine.connect() as connection:
        assert connection.execute(text('SELECT count(*) FROM public.ifs_column_catalog')).scalar() == 0


def test_database_failure_rolls_back_both_files(pg_engine):
    with pg_engine.begin() as connection:
        connection.execute(text("ALTER TABLE public.ifs_column_catalog ADD CONSTRAINT test_reject CHECK (column_name <> 'DUMMY')"))
    try:
        with pytest.raises(IntegrityError):
            import_catalog(pg_engine, TABLES, COLUMNS)
        with pg_engine.connect() as connection:
            assert connection.execute(text('SELECT count(*) FROM public.ifs_table_catalog')).scalar() == 0
    finally:
        with pg_engine.begin() as connection:
            connection.execute(text('ALTER TABLE public.ifs_column_catalog DROP CONSTRAINT test_reject'))


@pytest.fixture()
def app(pg_engine):
    spec = importlib.util.spec_from_file_location('ifs_dictionary_api_test', ROOT / 'backend/api/ifs_dictionary.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    app = Flask(__name__)
    app.config.update(TESTING=True, JWT_SECRET_KEY='catalog-test-secret-for-local-tests-only',
                      SQLALCHEMY_DATABASE_URI=os.environ['IFS_CATALOG_TEST_DATABASE_URL'])
    db.init_app(app)
    JWTManager(app)
    app.register_blueprint(module.ifs_dictionary_blueprint, url_prefix='/api/v1/data')
    with app.app_context():
        User.__table__.create(db.engine, checkfirst=True)
        for role in ('admin', 'operator'):
            if not db.session.get(User, role):
                db.session.add(User(id=role, username=role, email=f'{role}@example.test', password_hash='unused', role=role))
        db.session.commit()
    return app


def _client(app, role='admin'):
    client = app.test_client()
    with app.app_context():
        token = create_access_token(identity=role)
    client.environ_base['HTTP_AUTHORIZATION'] = f'Bearer {token}'
    return client


def _files():
    return {'tables_file': (io.BytesIO(TABLES), 'tables.csv'),
            'columns_file': (io.BytesIO(COLUMNS), 'columns.csv')}


BASE = '/api/v1/data/ifs-dictionary'


def test_api_import_search_detail_and_report(app):
    client = _client(app)
    response = client.post(BASE + '/import', data=_files())
    assert response.status_code == 200
    assert response.json['columns_imported'] == 9
    result = client.get(BASE + '/tables?q=GLOBAL_TRAN_FMT').json
    assert result['total'] == 1
    assert result['owners'] == ['SYS']
    assert result['stats']['columns'] == 9
    table_id = result['items'][0]['table_id']
    detail = client.get(f'{BASE}/tables/{table_id}').json
    assert len(detail['columns']) == 8
    response = client.post(f'{BASE}/tables/{table_id}/report', json={'columns': ['STATE'], 'include_owner': True})
    assert response.status_code == 200
    assert 'FROM SYS.PENDING_TRANS$' in response.json['sql']
    assert response.json['filename'] == 'report.md'
    assert client.get(BASE + '/tables?q=GLOBAL%').json['total'] == 0
    assert client.get(BASE + '/tables?q=GLOBAL_').json['total'] == 1
    assert client.get(BASE + '/tables?owner=IFSAPP').json['total'] == 0
    assert client.get(BASE + '/tables?q=%27%3B%20DROP%20TABLE%20users%3B--').json['total'] == 0


def test_api_authentication_and_admin_import(app):
    anon = app.test_client()
    assert anon.get(BASE + '/tables').status_code == 401
    assert anon.get(BASE + '/tables/1').status_code == 401
    assert anon.post(BASE + '/tables/1/report', json={}).status_code == 401
    assert anon.post(BASE + '/import', data=_files()).status_code == 401
    operator = _client(app, 'operator')
    assert operator.post(BASE + '/import', data=_files()).status_code == 403
    assert operator.get(BASE + '/tables').status_code == 200


def test_api_import_accepts_a_single_file(app):
    client = _client(app)
    response = client.post(BASE + '/import', data={'tables_file': (io.BytesIO(TABLES), 'tables.csv')})
    assert response.status_code == 200
    assert (response.json['tables_imported'], response.json['columns_imported']) == (2, 0)
    response = client.post(BASE + '/import', data={'columns_file': (io.BytesIO(COLUMNS), 'columns.csv')})
    assert response.status_code == 200
    assert (response.json['tables_imported'], response.json['columns_imported']) == (0, 9)


def test_api_import_accepts_excel_workbooks(app):
    client = _client(app)
    response = client.post(BASE + '/import', data={
        'tables_file': (io.BytesIO(TABLES_XLSX), 'tables.xlsx'),
        'columns_file': (io.BytesIO(COLUMNS_XLSX), 'columns.xlsx')})
    assert response.status_code == 200
    assert (response.json['tables_imported'], response.json['columns_imported']) == (2, 9)
    assert client.get(BASE + '/tables?q=GLOBAL_TRAN_FMT').json['total'] == 1


def test_api_bad_requests(app):
    client = _client(app)
    assert client.post(BASE + '/import', data={}).status_code == 400
    assert client.get(BASE + '/tables?page=-1').status_code == 400
    assert client.get(BASE + '/tables?page_size=hello').status_code == 400
    assert client.get(BASE + '/tables/999').status_code == 404
    assert client.post(BASE + '/tables/999/report', json={}).status_code == 404
    for payload in ([], {'include_owner': 'yes'}, {'columns': None}):
        assert client.post(BASE + '/tables/1/report', json=payload).status_code == 400
    client.post(BASE + '/import', data=_files())
    table_id = client.get(BASE + '/tables').json['items'][0]['table_id']
    for payload in ({'columns': []}, {'columns': ['ABSENT']}):
        assert client.post(f'{BASE}/tables/{table_id}/report', json=payload).status_code == 400
