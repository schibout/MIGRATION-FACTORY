"""
API Blueprint pour la consultation générique de données
Permet de visualiser les données de n'importe quelle table
"""

from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required
import psycopg2.extras
from psycopg2 import sql

from config.database import get_db_connection

# Créer le blueprint
data_browser_blueprint = Blueprint('data_browser', __name__)


def _table_exists(cursor, schema: str, table_name: str) -> bool:
    """Vérifie qu'une table/vue existe réellement (anti-injection : on ne
    construit jamais de SQL avec un schema/table non validé)."""
    cursor.execute(
        """
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = %s AND table_name = %s
        """,
        (schema, table_name),
    )
    return cursor.fetchone() is not None


def _column_names(cursor, schema: str, table_name: str) -> set:
    """Retourne l'ensemble des colonnes réelles d'une table (pour valider
    les colonnes de tri / filtre avant de les injecter comme identifiants)."""
    cursor.execute(
        """
        SELECT column_name FROM information_schema.columns
        WHERE table_schema = %s AND table_name = %s
        """,
        (schema, table_name),
    )
    return {row['column_name'] for row in cursor.fetchall()}


@data_browser_blueprint.route('/schemas', methods=['GET'])
@jwt_required()
def get_schemas():
    """Retourne la liste des schémas disponibles"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute("""
                SELECT schema_name,
                       (SELECT COUNT(*) FROM information_schema.tables t 
                        WHERE t.table_schema = s.schema_name AND t.table_type = 'BASE TABLE') as table_count
                FROM information_schema.schemata s
                WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
                ORDER BY 
                    CASE WHEN schema_name = 'clean_data' THEN 0 
                         WHEN schema_name = 'raw_data' THEN 1
                         WHEN schema_name = 'public' THEN 2 
                         ELSE 3 END,
                    schema_name
            """)
            
            schemas = cursor.fetchall()
            
            return jsonify({
                'success': True,
                'schemas': schemas
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur récupération schémas: {e}")
        return jsonify({'error': str(e)}), 500


@data_browser_blueprint.route('/tables', methods=['GET'])
@jwt_required()
def get_tables():
    """Retourne la liste des tables d'un schéma"""
    try:
        schema = request.args.get('schema', 'clean_data')
        search = request.args.get('search', '')
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            query = """
                SELECT 
                    t.table_name,
                    t.table_schema,
                    pg_catalog.obj_description(pgc.oid, 'pg_class') as description,
                    (SELECT COUNT(*) FROM information_schema.columns c 
                     WHERE c.table_schema = t.table_schema AND c.table_name = t.table_name) as column_count,
                    pgc.reltuples::bigint as row_estimate
                FROM information_schema.tables t
                LEFT JOIN pg_catalog.pg_namespace pgn ON pgn.nspname = t.table_schema
                LEFT JOIN pg_catalog.pg_class pgc ON pgc.relname = t.table_name 
                                                  AND pgc.relnamespace = pgn.oid
                WHERE t.table_schema = %s
                AND t.table_type = 'BASE TABLE'
            """
            params = [schema]
            
            if search:
                query += " AND t.table_name ILIKE %s"
                params.append(f'%{search}%')
            
            query += " ORDER BY t.table_name"
            
            cursor.execute(query, params)
            tables = cursor.fetchall()
            
            return jsonify({
                'success': True,
                'tables': tables,
                'schema': schema
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur récupération tables: {e}")
        return jsonify({'error': str(e)}), 500


@data_browser_blueprint.route('/tables/<table_name>/columns', methods=['GET'])
@jwt_required()
def get_table_columns(table_name: str):
    """Retourne les colonnes d'une table"""
    try:
        schema = request.args.get('schema', 'clean_data')
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute("""
                SELECT 
                    c.column_name as name,
                    c.data_type,
                    c.is_nullable,
                    c.column_default,
                    c.character_maximum_length,
                    c.ordinal_position,
                    pg_catalog.col_description(pgc.oid, c.ordinal_position) as description
                FROM information_schema.columns c
                LEFT JOIN pg_catalog.pg_namespace pgn ON pgn.nspname = c.table_schema
                LEFT JOIN pg_catalog.pg_class pgc ON pgc.relname = c.table_name 
                                                  AND pgc.relnamespace = pgn.oid
                WHERE c.table_schema = %s AND c.table_name = %s
                ORDER BY c.ordinal_position
            """, (schema, table_name))
            
            columns = cursor.fetchall()
            
            # Récupérer les contraintes
            cursor.execute("""
                SELECT kcu.column_name, tc.constraint_type
                FROM information_schema.table_constraints tc
                JOIN information_schema.key_column_usage kcu 
                    ON tc.constraint_name = kcu.constraint_name
                    AND tc.table_schema = kcu.table_schema
                WHERE tc.table_schema = %s AND tc.table_name = %s
            """, (schema, table_name))
            
            constraints = {}
            for row in cursor.fetchall():
                col_name = row['column_name']
                if col_name not in constraints:
                    constraints[col_name] = []
                constraints[col_name].append(row['constraint_type'])
            
            for col in columns:
                col['constraints'] = constraints.get(col['name'], [])
                col['isPrimaryKey'] = 'PRIMARY KEY' in col['constraints']
            
            return jsonify({
                'success': True,
                'columns': columns,
                'tableName': table_name,
                'schema': schema
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur récupération colonnes: {e}")
        return jsonify({'error': str(e)}), 500


@data_browser_blueprint.route('/tables/<table_name>/data', methods=['GET'])
@jwt_required()
def get_table_data(table_name: str):
    """Retourne les données d'une table avec pagination et filtres"""
    try:
        schema = request.args.get('schema', 'clean_data')
        page = int(request.args.get('page', 1))
        page_size = int(request.args.get('pageSize', 50))
        sort_column = request.args.get('sortColumn', None)
        sort_direction = request.args.get('sortDirection', 'asc')
        search = request.args.get('search', '')
        filters_json = request.args.get('filters', '{}')
        
        # Limiter page_size pour éviter les abus
        page_size = min(page_size, 500)
        offset = (page - 1) * page_size
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Vérifier que la table existe (schema/table validés -> anti-injection)
            if not _table_exists(cursor, schema, table_name):
                return jsonify({'error': f'Table {schema}.{table_name} non trouvée'}), 404

            # Récupérer les colonnes pour la recherche globale
            cursor.execute("""
                SELECT column_name, data_type
                FROM information_schema.columns
                WHERE table_schema = %s AND table_name = %s
                ORDER BY ordinal_position
            """, (schema, table_name))
            columns_info = cursor.fetchall()
            valid_columns = {c['column_name'] for c in columns_info}
            text_columns = [c['column_name'] for c in columns_info
                          if c['data_type'] in ('character varying', 'text', 'character')]

            # Référence de table via des identifiants sûrs (jamais interpolés en texte)
            table_ref = sql.SQL('{}.{}').format(sql.Identifier(schema), sql.Identifier(table_name))

            where_clauses = []  # objets Composable
            params = []

            # Recherche globale sur colonnes texte
            if search and text_columns:
                search_conditions = []
                for col in text_columns[:10]:  # Limiter à 10 colonnes pour performance
                    search_conditions.append(sql.SQL('{}::text ILIKE %s').format(sql.Identifier(col)))
                    params.append(f'%{search}%')
                where_clauses.append(
                    sql.SQL('({})').format(sql.SQL(' OR ').join(search_conditions))
                )

            # Filtres par colonne — ne garder que les colonnes réellement existantes
            import json
            try:
                filters = json.loads(filters_json)
                for col_name, filter_value in filters.items():
                    if filter_value and col_name in valid_columns:
                        where_clauses.append(
                            sql.SQL('{}::text ILIKE %s').format(sql.Identifier(col_name))
                        )
                        params.append(f'%{filter_value}%')
            except json.JSONDecodeError:
                pass

            # Clause WHERE commune (liste de Composable, jointe par AND)
            where_parts = []
            if where_clauses:
                where_parts = [sql.SQL('WHERE'), sql.SQL(' AND ').join(where_clauses)]

            # COUNT
            count_query = sql.SQL(' ').join(
                [sql.SQL('SELECT COUNT(*) as total FROM {}').format(table_ref)] + where_parts
            )

            # SELECT + ORDER BY (colonne de tri validée) + pagination paramétrée
            base_parts = [sql.SQL('SELECT * FROM {}').format(table_ref)] + where_parts
            if sort_column and sort_column in valid_columns:
                direction = sql.SQL('DESC') if sort_direction.lower() == 'desc' else sql.SQL('ASC')
                base_parts.append(
                    sql.SQL('ORDER BY {} {} NULLS LAST').format(sql.Identifier(sort_column), direction)
                )
            base_parts.append(sql.SQL('LIMIT %s OFFSET %s'))
            base_query = sql.SQL(' ').join(base_parts)

            # Exécuter les requêtes
            cursor.execute(count_query, params)
            total_count = cursor.fetchone()['total']

            cursor.execute(base_query, params + [page_size, offset])
            rows = cursor.fetchall()
            
            # Convertir les données pour JSON
            data = []
            for row in rows:
                row_dict = {}
                for key, value in row.items():
                    if value is None:
                        row_dict[key] = None
                    elif isinstance(value, (int, float, bool)):
                        row_dict[key] = value
                    else:
                        row_dict[key] = str(value)
                data.append(row_dict)
            
            total_pages = (total_count + page_size - 1) // page_size
            
            return jsonify({
                'success': True,
                'data': data,
                'pagination': {
                    'page': page,
                    'pageSize': page_size,
                    'totalRows': total_count,
                    'totalPages': total_pages,
                    'hasNext': page < total_pages,
                    'hasPrev': page > 1
                },
                'tableName': table_name,
                'schema': schema
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur récupération données: {e}", exc_info=True)
        return jsonify({'error': str(e)}), 500


@data_browser_blueprint.route('/tables/<table_name>/export', methods=['GET'])
@jwt_required()
def export_table_data(table_name: str):
    """Exporte les données d'une table en CSV"""
    from flask import Response
    import csv
    import io
    
    try:
        schema = request.args.get('schema', 'clean_data')
        limit = int(request.args.get('limit', 10000))
        limit = min(limit, 100000)  # Max 100k lignes
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            # Vérifier que la table existe (anti-injection sur schema/table)
            if not _table_exists(cursor, schema, table_name):
                return jsonify({'error': f'Table {schema}.{table_name} non trouvée'}), 404

            # Récupérer les données (identifiants sûrs, limite paramétrée)
            export_query = sql.SQL('SELECT * FROM {}.{} LIMIT %s').format(
                sql.Identifier(schema), sql.Identifier(table_name)
            )
            cursor.execute(export_query, (limit,))
            rows = cursor.fetchall()
            
            if not rows:
                return jsonify({'error': 'Aucune donnée à exporter'}), 404
            
            # Créer le CSV
            output = io.StringIO()
            writer = csv.DictWriter(output, fieldnames=rows[0].keys(), delimiter=';')
            writer.writeheader()
            
            for row in rows:
                # Convertir les valeurs en strings
                row_str = {k: str(v) if v is not None else '' for k, v in row.items()}
                writer.writerow(row_str)
            
            output.seek(0)
            
            return Response(
                output.getvalue(),
                mimetype='text/csv',
                headers={
                    'Content-Disposition': f'attachment; filename={schema}_{table_name}.csv',
                    'Content-Type': 'text/csv; charset=utf-8'
                }
            )
            
    except Exception as e:
        current_app.logger.error(f"Erreur export: {e}")
        return jsonify({'error': str(e)}), 500
