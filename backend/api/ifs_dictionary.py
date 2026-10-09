"""Consultation du dictionnaire Oracle/IFS, import CSV et rapports SQL."""
from functools import wraps

from flask import Blueprint, current_app, jsonify, request
from flask_jwt_extended import jwt_required
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from models import db
from services.ifs_dictionary_service import (MAX_FILE_BYTES, build_report, import_catalog, import_view_columns,
                                           import_view_comments, import_views, view_columns, view_tables)
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


# ---------------------------------------------------------------------------
# Vues IFS (public.ifs_view_catalog + dictionnaire IFS, migrations 116 à 118) : écran sur le modèle de
# Maintenance > Équipements (facettes, étiquettes, export Excel) + rapport SQL.
# ---------------------------------------------------------------------------
VIDE = '__vide__'
NATURES = {
    'TAB': 'Vue de table (_TAB)', 'VRT': 'Entité virtuelle (_VRT)', 'LOV': 'Liste de valeurs (_LOV)',
    'DM': 'Data mart (_DM)', 'OL': 'Accès BI en ligne (_OL)', 'MV': 'Source BI matérialisée (_MV*)',
    'REP': 'Rapport (_REP / _RPV)', 'PUB': 'Publique (_PUB)', 'UIV': "Vue d'interface (_UIV)",
    'QRY': 'Requête (_QRY)', 'CF': 'Champs personnalisés (_CFV / _CLV)', 'TMP': 'Temporaire (_TMP)',
    'EXT': 'Extension (_EXT)', 'METIER': 'Vue métier', 'SYSTEME': 'Système Oracle',
}
TAILLES = {'XS': '< 1 000 car.', 'S': '1 000 – 5 000 car.', 'M': '5 000 – 20 000 car.', 'L': '≥ 20 000 car.'}
LECTURE = {'true': 'Lecture seule', 'false': 'Modifiable'}
# clé -> (expression SQL, titre)
VIEW_FACETTES = {
    'nature': ('nature', 'Nature'),
    'owner': ('owner', 'Propriétaire'),
    'lecture': ('read_only::text', 'Accès'),
    'taille': ('taille', 'Taille du SQL'),
    'module': ('module', 'Module IFS'),
}
VIEW_LIBELLES = {'nature': NATURES, 'taille': TAILLES, 'lecture': LECTURE}
# Étiquettes (équivalent des anomalies des équipements) : clé -> (libellé, condition)
ETIQUETTES = {
    'union': ('Contient un UNION', 'has_union'),
    'api': ('Appelle des API PL/SQL', 'calls_api'),
    'cf': ('Champs personnalisés', 'custom_fields'),
    'modifiable': ('Modifiable (sans WITH READ ONLY)', 'read_only IS FALSE'),
    'volumineux': ('SQL ≥ 20 000 caractères', "taille = 'L'"),
    # Fichier sans colonne Text : seul Text Vc (4000 car.) est disponible
    'tronque': ('SQL tronqué dans le fichier',
                "CASE WHEN metadata->>'Text Length' ~ '^[0-9]+$' "
                "THEN (metadata->>'Text Length')::bigint > 4000 AND length(view_text) <= 4000 END"),
    'rls': ('Sécurité par ligne (RLS)', "fnd_attributes ? 'ROW_LEVEL_SECURITY'"),
    'non_documentee': ('Absente du dictionnaire IFS', 'fnd_attributes IS NULL'),
}
VIEW_TRIS = {'view_name': 'view_name', 'owner': 'owner', 'nature': 'nature', 'text_length': 'length(view_text)',
             'module': 'module', 'prompt': 'prompt', 'nb_colonnes_fnd': 'nb_colonnes_fnd'}


def _view_filters(sauf=None):
    where, params = [], {}
    search = request.args.get('q', '').strip()
    if search:
        escaped = search.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_')
        params['q'] = f'%{escaped}%'
        sql = ' OR view_text ILIKE :q' if request.args.get('in_sql') == '1' else ''
        where.append(f'(view_name ILIKE :q OR owner ILIKE :q OR prompt ILIKE :q OR lu_name ILIKE :q{sql})')
    for cle, (expr, _) in VIEW_FACETTES.items():
        brut = request.args.get(cle, '')
        if cle == sauf or not brut:
            continue
        valeurs = [v for v in brut.split(',') if v]
        autres = [v for v in valeurs if v != VIDE]
        conds = [f'{expr} IS NULL'] if VIDE in valeurs else []
        if autres:
            conds.append(f'{expr} = ANY(:f_{cle})')
            params[f'f_{cle}'] = autres
        where.append('(' + ' OR '.join(conds) + ')')
    etiquette = request.args.get('etiquette')
    if etiquette in ETIQUETTES:
        where.append(f'({ETIQUETTES[etiquette][1]})')
    return ('WHERE ' + ' AND '.join(where)) if where else '', params


def _view_tags():
    return ', '.join(f'({sql}) IS TRUE AS tag_{k}' for k, (_, sql) in ETIQUETTES.items())


def _view_row(row):
    d = dict(row)
    d['etiquettes'] = [k for k in ETIQUETTES if d.pop(f'tag_{k}', False)]
    return d


@ifs_dictionary_blueprint.route('/ifs-dictionary/views', methods=['GET'])
@jwt_required()
@catalog_errors
def list_views():
    try:
        page = int(request.args.get('page', 0))
        size = int(request.args.get('page_size', 50))
    except ValueError:
        raise ValueError('Pagination invalide.')
    if page < 0 or page > 1000000 or size not in (25, 50, 100, 200):
        raise ValueError('Pagination invalide (25, 50, 100 ou 200 lignes par page).')
    clause, params = _view_filters()
    tri = VIEW_TRIS.get(request.args.get('sort'), 'view_name')
    sens = 'DESC' if request.args.get('dir') == 'desc' else 'ASC'
    with db.engine.connect() as connection:
        rows = connection.execute(text(f'''
            SELECT view_id, owner, view_name, nature, taille, read_only, length(view_text) AS text_length,
                   imported_at, lu_name, prompt, module, nb_colonnes_fnd, {_view_tags()}, count(*) OVER () AS total_lignes
            FROM public.v_ifs_view_catalog {clause}
            ORDER BY {tri} {sens} NULLS LAST, owner, view_name LIMIT :limit OFFSET :offset'''),
            {**params, 'limit': size, 'offset': page * size}).mappings().all()
    total = rows[0]['total_lignes'] if rows else 0
    items = []
    for r in rows:
        d = _view_row(r)
        d.pop('total_lignes')
        items.append(d)
    return jsonify(items=items, total=total)


@ifs_dictionary_blueprint.route('/ifs-dictionary/views/facettes', methods=['GET'])
@jwt_required()
@catalog_errors
def view_facettes():
    """Compteurs par valeur, chaque facette ignorant son propre filtre."""
    resultat = {}
    with db.engine.connect() as connection:
        for cle, (expr, titre) in VIEW_FACETTES.items():
            clause, params = _view_filters(sauf=cle)
            libelles = VIEW_LIBELLES.get(cle, {})
            valeurs = [{'code': r.code if r.code is not None else VIDE,
                        'libelle': libelles.get(r.code), 'nb': r.nb}
                       for r in connection.execute(text(
                           f'SELECT {expr} AS code, count(*) AS nb FROM public.v_ifs_view_catalog {clause} '
                           'GROUP BY 1 ORDER BY 2 DESC'), params)]
            resultat[cle] = {'titre': titre, 'valeurs': valeurs}
        clause, params = _view_filters()
        compteurs = connection.execute(text(
            'SELECT count(*) AS total, '
            + ', '.join(f'count(*) FILTER (WHERE {sql}) AS {k}' for k, (_, sql) in ETIQUETTES.items())
            + f' FROM public.v_ifs_view_catalog {clause}'), params).mappings().one()
        catalogue = connection.execute(text(
            'SELECT count(*) AS views, max(imported_at) AS imported_at, '
            '(SELECT count(*) FROM public.ifs_view_comment) AS comments, '
            '(SELECT count(*) FROM public.ifs_view_column) AS columns '
            'FROM public.ifs_view_catalog')).mappings().one()
    return jsonify(facettes=resultat, total=compteurs['total'], catalogue=dict(catalogue),
                   etiquettes=[{'cle': k, 'libelle': lib, 'nb': compteurs[k]} for k, (lib, _) in ETIQUETTES.items()])


@ifs_dictionary_blueprint.route('/ifs-dictionary/views/export.xlsx', methods=['GET'])
@jwt_required()
@catalog_errors
def export_views():
    from openpyxl import Workbook

    from api.finance import _envoyer, _feuille_tableau

    clause, params = _view_filters()
    with db.engine.connect() as connection:
        rows = connection.execute(text(
            f'SELECT owner, view_name, prompt, module, lu_name, base_table, nb_colonnes_fnd, nature, read_only, '
            f'length(view_text) AS text_length, {_view_tags()} '
            f'FROM public.v_ifs_view_catalog {clause} ORDER BY owner, view_name'), params).mappings().all()
    entetes = [('owner', 'Propriétaire'), ('view_name', 'Vue'), ('prompt', 'Prompt'), ('module', 'Module'),
               ('lu_name', 'Entité (LU)'), ('base_table', 'Table de base'), ('nb_colonnes_fnd', 'Colonnes'),
               ('nature', 'Nature'),
               ('read_only', 'Accès'), ('text_length', 'Taille du SQL'), ('etiquettes', 'Étiquettes')]
    lignes = []
    for r in rows:
        d = _view_row(r)
        lignes.append([d['owner'], d['view_name'], d['prompt'], d['module'], d['lu_name'], d['base_table'],
                       d['nb_colonnes_fnd'], NATURES.get(d['nature'], d['nature']),
                       LECTURE.get(str(d['read_only']).lower(), ''), d['text_length'],
                       ', '.join(ETIQUETTES[k][0] for k in d['etiquettes'])])
    wb = Workbook()
    _feuille_tableau(wb.active, 'Vues IFS', entetes, lignes, set())
    return _envoyer(wb, 'vues_ifs')


def _fnd_columns(connection, view_name):
    return [dict(r) for r in connection.execute(text(
        'SELECT view_column_name, column_name FROM public.ifs_view_column '
        'WHERE view_name = :v ORDER BY position'), {'v': view_name}).mappings()]


def _view(connection, view_id):
    row = connection.execute(text(f'SELECT *, {_view_tags()} FROM public.v_ifs_view_catalog WHERE view_id = :id'),
                             {'id': view_id}).mappings().first()
    return _view_row(row) if row else None


@ifs_dictionary_blueprint.route('/ifs-dictionary/views/<int:view_id>', methods=['GET'])
@jwt_required()
@catalog_errors
def view_detail(view_id):
    with db.engine.connect() as connection:
        view = _view(connection, view_id)
        if view is None:
            return jsonify(error='Vue introuvable dans le catalogue.'), 404
        fnd = _fnd_columns(connection, view['view_name'])
        tables = view_tables(view['view_text'])
        # Objets lus présents dans le catalogue des tables
        connues = {r.table_name: r.table_id for r in connection.execute(text(
            'SELECT table_name, table_id FROM public.ifs_table_catalog WHERE table_name = ANY(:t)'),
            {'t': [t.split('.')[-1] for t in tables]})}
    # Colonnes : dictionnaire IFS (FND_TAB_VIEW_COLUMNS) s'il connaît la vue, sinon SQL de la vue
    return jsonify(view=view, columns=[c['view_column_name'] for c in fnd] or view_columns(view['view_text']),
                   columns_source='fnd' if fnd else 'sql',
                   column_origins={c['view_column_name']: c['column_name'] for c in fnd},
                   tables=[{'name': t, 'table_id': connues.get(t.split('.')[-1])} for t in tables],
                   natures=NATURES, etiquettes={k: lib for k, (lib, _) in ETIQUETTES.items()})


@ifs_dictionary_blueprint.route('/ifs-dictionary/views/<int:view_id>/report', methods=['POST'])
@jwt_required()
@catalog_errors
def view_report(view_id):
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        raise ValueError('Un objet JSON est requis.')
    include_owner = payload.get('include_owner', False)
    if not isinstance(include_owner, bool):
        raise ValueError('include_owner doit être un booléen.')
    with db.engine.connect() as connection:
        view = _view(connection, view_id)
        if view is None:
            return jsonify(error='Vue introuvable dans le catalogue.'), 404
        names = [c['view_column_name'] for c in _fnd_columns(connection, view['view_name'])]
    columns = [{'column_name': c, 'column_id': i + 1}
               for i, c in enumerate(names or view_columns(view['view_text']))]
    if not columns:
        raise ValueError('Colonnes de la vue non identifiées dans son SQL : rapport impossible.')
    sql = build_report({'owner': view['owner'], 'table_name': view['view_name']},
                       columns, payload.get('columns'), include_owner)
    return jsonify(sql=sql, filename='report.md')


@ifs_dictionary_blueprint.route('/ifs-dictionary/views/import', methods=['POST'])
@admin_required
@catalog_errors
def upload_views():
    """Trois fichiers facultatifs et indépendants : ALL_VIEWS, FND_TAB_COMMENTS, FND_TAB_VIEW_COLUMNS."""
    fichiers = {cle: request.files.get(cle) for cle in ('file', 'comments_file', 'columns_file')}
    if not any(fichiers.values()):
        raise ValueError('Fournissez au moins un fichier : vues, commentaires IFS ou colonnes IFS.')
    lire = lambda f: f.read(MAX_FILE_BYTES + 1)  # noqa: E731
    result = {}
    if fichiers['file']:
        result.update(import_views(db.engine, lire(fichiers['file'])))
    if fichiers['comments_file']:
        result.update(import_view_comments(db.engine, lire(fichiers['comments_file'])))
    if fichiers['columns_file']:
        result.update(import_view_columns(db.engine, lire(fichiers['columns_file'])))
    return jsonify(**result, message='Import terminé. Les entrées absentes des fichiers ont été conservées.')
