"""
Structure des vues SAP (dictionnaire DDIC extrait dans raw_data : dd25l/dd26s/dd27s/dd28s)
et creation de leur equivalent PostgreSQL dans le schema sap_view.

Lecture : tables de base, jointures, conditions de selection, champs et SQL genere.
Ecriture (admin) : CREATE / DROP VIEW dans sap_view uniquement, jamais dans raw_data.
"""
import psycopg2.extras
from flask import Blueprint, current_app, jsonify, request
from flask_jwt_extended import jwt_required

from config.database import get_db_connection
from services.sap_view_sql import SOURCE_SCHEMA, TARGET_SCHEMA, build_view_sql, qi
from utils.auth_decorators import admin_required

sap_view_structure_blueprint = Blueprint('sap_view_structure', __name__)

VIEW_CLASSES = {
    'D': 'Vue base de donnees', 'C': 'Vue de gestion (SM30)', 'H': "Vue d'aide",
    'P': 'Vue de projection', 'V': 'Vue de maintenance', 'S': 'Vue structure', 'E': 'Vue entite',
}


def _cursor(conn):
    return conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)


def _load(cur, name: str):
    """Tout ce que l'ecran affiche d'une vue ; None si la vue n'est pas dans dd25l."""
    name = name.strip().upper()
    cur.execute("""
        SELECT v.viewname, v.viewclass, v.roottab, v.as4user, v.as4date,
               (SELECT t.ddtext FROM raw_data.dd02t t
                 WHERE t.tabname = v.viewname AND t.as4local = 'A'
                 ORDER BY (t.ddlanguage = 'F') DESC, (t.ddlanguage = 'E') DESC LIMIT 1) AS description,
               EXISTS (SELECT 1 FROM information_schema.views w
                        WHERE w.table_schema = %s AND w.table_name = lower(v.viewname)) AS created
          FROM raw_data.dd25l v
         WHERE v.viewname = %s AND v.as4local = 'A'
         LIMIT 1
    """, (TARGET_SCHEMA, name))
    view = cur.fetchone()
    if not view:
        return None

    cur.execute("""
        SELECT s.tabname, s.tabpos, p.description,
               EXISTS (SELECT 1 FROM information_schema.tables t
                        WHERE t.table_schema = %s AND t.table_name = lower(s.tabname)) AS present
          FROM raw_data.dd26s s
          LEFT JOIN public.sap_table_properties p ON p.table_name = s.tabname
         WHERE s.viewname = %s AND s.as4local = 'A'
         ORDER BY s.tabpos
    """, (SOURCE_SCHEMA, name))
    tables = cur.fetchall()

    cur.execute("""
        SELECT f.objpos, f.viewfield, f.tabname, f.fieldname, f.keyflag = 'X' AS key_flag, f.rollname,
               COALESCE(NULLIF(stf.field_text, ''), NULLIF(stf.header_text, ''), d.ddtext) AS label
          FROM raw_data.dd27s f
          LEFT JOIN LATERAL (SELECT s.field_text, s.header_text FROM public.sap_table_fields s
                              WHERE s.table_name = f.tabname AND TRIM(s.field_name) = f.fieldname
                              LIMIT 1) stf ON TRUE
          LEFT JOIN raw_data.dd04t d
                 ON d.rollname = f.rollname AND d.ddlanguage = 'F' AND d.as4local = 'A'
         WHERE f.viewname = %s AND f.as4local = 'A'
         ORDER BY f.objpos
    """, (name,))
    fields = cur.fetchall()

    cur.execute("""
        SELECT position, tabname, fieldname, negation, operator, constants, and_or
          FROM raw_data.dd28s
         WHERE condname = %s AND as4local = 'A'
         ORDER BY position
    """, (name,))
    conds = cur.fetchall()

    cur.execute("""
        SELECT table_name, column_name, data_type
          FROM information_schema.columns
         WHERE table_schema = %s AND table_name = ANY(%s)
    """, (SOURCE_SCHEMA, [t['tabname'].lower() for t in tables]))
    columns = {}
    for c in cur.fetchall():
        columns.setdefault(c['table_name'], {})[c['column_name']] = c['data_type']

    gen = build_view_sql(name, [t['tabname'] for t in tables], fields, conds, columns)
    return {
        **view,
        'viewclass_label': VIEW_CLASSES.get(view['viewclass'] or '', 'Inconnue'),
        'tables': tables,
        'fields': [f for f in fields if (f['viewfield'] or '').strip() not in ('*', '-')],
        'join_conditions': [c for c in conds if c['negation'] in ('JL', 'JR')],
        'selection_conditions': [c for c in conds if c['negation'] not in ('JL', 'JR')],
        **gen,
    }


@sap_view_structure_blueprint.route('/views', methods=['GET'])
@jwt_required()
def list_views():
    """Liste paginee. search = nom de vue (contient) ou nom exact d'une table de base."""
    search = (request.args.get('search') or '').strip().upper()
    viewclass = (request.args.get('viewclass') or '').strip().upper()
    creatable = request.args.get('creatable') in ('1', 'true')
    page = max(int(request.args.get('page', 1)), 1)
    page_size = min(max(int(request.args.get('pageSize', 50)), 1), 200)

    with get_db_connection() as conn:
        cur = _cursor(conn)
        cur.execute("""
            WITH raw AS (
                SELECT upper(table_name) AS t FROM information_schema.tables WHERE table_schema = %(src)s
            ), v AS (
                SELECT v.viewname, v.viewclass, v.roottab,
                       count(s.tabname) AS nb_tables, count(raw.t) AS nb_present
                  FROM raw_data.dd25l v
                  LEFT JOIN raw_data.dd26s s ON s.viewname = v.viewname AND s.as4local = 'A'
                  LEFT JOIN raw ON raw.t = s.tabname
                 WHERE v.as4local = 'A'
                   AND (%(cls)s = '' OR v.viewclass = %(cls)s)
                   AND (%(search)s = '' OR v.viewname LIKE %(like)s
                        OR EXISTS (SELECT 1 FROM raw_data.dd26s s2
                                    WHERE s2.viewname = v.viewname AND s2.as4local = 'A'
                                      AND s2.tabname = %(search)s))
                 GROUP BY v.viewname, v.viewclass, v.roottab
            ), f AS (
                SELECT *, nb_tables > 0 AND nb_tables = nb_present AS creatable, count(*) OVER () AS total
                  FROM v
                 WHERE NOT %(creatable)s OR (nb_tables > 0 AND nb_tables = nb_present)
                 ORDER BY viewname
                 LIMIT %(limit)s OFFSET %(offset)s
            )
            SELECT f.*,
                   (SELECT t.ddtext FROM raw_data.dd02t t
                     WHERE t.tabname = f.viewname AND t.as4local = 'A'
                     ORDER BY (t.ddlanguage = 'F') DESC, (t.ddlanguage = 'E') DESC LIMIT 1) AS description,
                   EXISTS (SELECT 1 FROM information_schema.views w
                            WHERE w.table_schema = %(dst)s AND w.table_name = lower(f.viewname)) AS created
              FROM f ORDER BY f.viewname
        """, {'src': SOURCE_SCHEMA, 'dst': TARGET_SCHEMA, 'cls': viewclass, 'search': search,
              'like': f'%{search}%', 'creatable': creatable, 'limit': page_size,
              'offset': (page - 1) * page_size})
        rows = cur.fetchall()

    total = rows[0]['total'] if rows else 0
    for r in rows:
        r.pop('total', None)
    return jsonify({'views': rows, 'total': total, 'page': page, 'pageSize': page_size,
                    'classes': VIEW_CLASSES})


@sap_view_structure_blueprint.route('/views/<name>', methods=['GET'])
@jwt_required()
def get_view(name):
    with get_db_connection() as conn:
        detail = _load(_cursor(conn), name)
    if not detail:
        return jsonify({'error': f'Vue {name} absente du dictionnaire (dd25l)'}), 404
    return jsonify(detail)


@sap_view_structure_blueprint.route('/views/<name>/create', methods=['POST'])
@admin_required
def create_view(name):
    with get_db_connection() as conn:
        cur = _cursor(conn)
        detail = _load(cur, name)
        if not detail:
            return jsonify({'error': f'Vue {name} absente du dictionnaire (dd25l)'}), 404
        if detail['blocking']:
            return jsonify({'error': 'Vue non creable', 'blocking': detail['blocking']}), 409
        try:
            cur.execute(f'CREATE SCHEMA IF NOT EXISTS {TARGET_SCHEMA}')
            cur.execute(detail['sql'])
            conn.commit()
        except Exception as e:  # erreur PostgreSQL renvoyee telle quelle a l'ecran
            conn.rollback()
            current_app.logger.error(f'Creation vue SAP {name} : {e}')
            return jsonify({'error': str(e).strip(), 'sql': detail['sql']}), 400
    return jsonify({'created': True, 'view': f'{TARGET_SCHEMA}.{name.lower()}',
                    'warnings': detail['warnings']})


def _created_view(cur, name):
    """Nom exact de la vue dans sap_view, ou None : seul nom autorise dans du SQL dynamique."""
    cur.execute("""SELECT table_name FROM information_schema.views
                    WHERE table_schema = %s AND table_name = lower(%s)""", (TARGET_SCHEMA, name.strip()))
    row = cur.fetchone()
    return row['table_name'] if row else None


@sap_view_structure_blueprint.route('/views/<name>', methods=['DELETE'])
@admin_required
def drop_view(name):
    with get_db_connection() as conn:
        cur = _cursor(conn)
        view = _created_view(cur, name)
        if not view:
            return jsonify({'error': f'Vue {TARGET_SCHEMA}.{name.lower()} inexistante'}), 404
        cur.execute(f'DROP VIEW {TARGET_SCHEMA}.{qi(view)}')
        conn.commit()
    return jsonify({'dropped': True})


@sap_view_structure_blueprint.route('/views/<name>/data', methods=['GET'])
@jwt_required()
def view_data(name):
    """Apercu : premieres lignes de la vue creee (pas de COUNT, trop couteux sur les grosses jointures)."""
    limit = min(max(int(request.args.get('limit', 100)), 1), 1000)
    with get_db_connection() as conn:
        cur = _cursor(conn)
        view = _created_view(cur, name)
        if not view:
            return jsonify({'error': "Vue non creee : utilisez d'abord « Creer la vue »"}), 404
        try:
            cur.execute("SET statement_timeout = '30s'")
            cur.execute(f'SELECT * FROM {TARGET_SCHEMA}.{qi(view)} LIMIT %s', (limit,))
        except Exception as e:
            conn.rollback()
            return jsonify({'error': str(e).strip()}), 400
        columns = [d.name for d in cur.description]
        rows = cur.fetchall()
    return jsonify({'columns': columns, 'rows': rows, 'limit': limit})
