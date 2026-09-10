"""Consultation du dictionnaire Oracle/IFS, import CSV et rapports SQL."""
from functools import wraps

from flask import Blueprint, current_app, jsonify, request
from flask_jwt_extended import jwt_required
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from models import db
from services.ifs_dictionary_service import MAX_FILE_BYTES, build_report, import_catalog
from utils.auth_decorators import admin_required

ifs_dictionary_blueprint = Blueprint('ifs_dictionary', __name__)


def catalog_errors(fn):
    @wraps(fn)
    def wrapped(*args, **kwargs):
        try:
            return fn(*args, **kwargs)
        except ValueError as exc:
            return jsonify(error=str(exc)), 400
        except SQLAlchemyError:
            current_app.logger.exception('Erreur du catalogue technique IFS')
            return jsonify(error='Catalogue IFS indisponible. Vérifiez la connexion et la migration 073.'), 503
    return wrapped


def _table(connection, table_id):
    result = connection.execute(text(
        'SELECT * FROM public.ifs_table_catalog WHERE table_id = :id'), {'id': table_id}).mappings().first()
    return dict(result) if result else None


def _columns(connection, table_id):
    return [dict(row) for row in connection.execute(text('''
        SELECT * FROM public.ifs_column_catalog WHERE table_id = :id ORDER BY column_id, column_name
    '''), {'id': table_id}).mappings()]


@ifs_dictionary_blueprint.route('/ifs-dictionary/tables', methods=['GET'])
@jwt_required()
@catalog_errors
def list_tables():
    try:
        page = int(request.args.get('page', 0))
        size = int(request.args.get('page_size', 25))
    except ValueError:
        raise ValueError('Pagination invalide.')
    if page < 0 or page > 1000000 or size not in (25, 50, 100):
        raise ValueError('Pagination invalide (25, 50 ou 100 lignes par page).')
    search = request.args.get('q', '').strip()
    # Recherche littérale : _ est fréquent dans les noms Oracle.
    escaped = search.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_')
    params = {'owner': request.args.get('owner', '').strip(), 'q': f'%{escaped}%',
              'limit': size, 'offset': page * size}
    where = '''
        WHERE (:owner = '' OR t.owner = :owner)
          AND (t.table_name ILIKE :q OR t.owner ILIKE :q OR EXISTS (
            SELECT 1 FROM public.ifs_column_catalog c
            WHERE c.table_id = t.table_id AND c.column_name ILIKE :q))
    '''
    with db.engine.connect() as connection:
        total = connection.execute(text('SELECT count(*) FROM public.ifs_table_catalog t ' + where), params).scalar_one()
        items = [dict(row) for row in connection.execute(text('''
            SELECT t.table_id, t.owner, t.table_name, t.tablespace_name, t.status,
                   t.num_rows, t.imported_at,
                   (SELECT count(*) FROM public.ifs_column_catalog c WHERE c.table_id = t.table_id) AS column_count
            FROM public.ifs_table_catalog t
        ''' + where + ' ORDER BY t.owner, t.table_name LIMIT :limit OFFSET :offset'), params).mappings()]
        owners = list(connection.execute(text(
            'SELECT DISTINCT owner FROM public.ifs_table_catalog ORDER BY owner')).scalars())
        stats = dict(connection.execute(text('''
            SELECT (SELECT count(*) FROM public.ifs_table_catalog) AS tables,
                   (SELECT count(*) FROM public.ifs_column_catalog) AS columns,
                   (SELECT max(imported_at) FROM public.ifs_table_catalog) AS imported_at
        ''')).mappings().one())
    return jsonify(items=items, total=total, owners=owners, stats=stats)


@ifs_dictionary_blueprint.route('/ifs-dictionary/tables/<int:table_id>', methods=['GET'])
@jwt_required()
@catalog_errors
def table_detail(table_id):
    with db.engine.connect() as connection:
        table = _table(connection, table_id)
        if table is None:
            return jsonify(error='Table introuvable dans le catalogue.'), 404
        return jsonify(table=table, columns=_columns(connection, table_id))


@ifs_dictionary_blueprint.route('/ifs-dictionary/import', methods=['POST'])
@admin_required
@catalog_errors
def upload_catalog():
    tables = request.files.get('tables_file')
    columns = request.files.get('columns_file')
    if not tables and not columns:
        raise ValueError('Fournissez au moins un fichier : les tables, les colonnes ou les deux.')
    result = import_catalog(db.engine,
                            tables.read(MAX_FILE_BYTES + 1) if tables else None,
                            columns.read(MAX_FILE_BYTES + 1) if columns else None)
    return jsonify(**result, message='Import terminé. Les entrées absentes des fichiers ont été conservées.')


@ifs_dictionary_blueprint.route('/ifs-dictionary/tables/<int:table_id>/report', methods=['POST'])
@jwt_required()
@catalog_errors
def generate_report(table_id):
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        raise ValueError('Un objet JSON est requis.')
    include_owner = payload.get('include_owner', False)
    if not isinstance(include_owner, bool):
        raise ValueError('include_owner doit être un booléen.')
    if 'columns' in payload and payload['columns'] is None:
        raise ValueError('La sélection de colonnes doit être une liste.')
    with db.engine.connect() as connection:
        table = _table(connection, table_id)
        if table is None:
            return jsonify(error='Table introuvable dans le catalogue.'), 404
        sql = build_report(table, _columns(connection, table_id), payload.get('columns'), include_owner)
    return jsonify(sql=sql, filename='report.md')
