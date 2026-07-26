"""
API Blueprint pour l'explorateur de données SAP
Basé sur sap_table_fields et sap_table_properties
Affiche les header_text au lieu des noms de colonnes
"""

from flask import Blueprint, request, jsonify, current_app, Response
import psycopg2.extras
import csv
import io

from config.database import get_db_connection

sap_data_explorer_blueprint = Blueprint('sap_data_explorer', __name__)


def _normalize_sap_field_rows(rows):
    """SAP DDIC export often pads field_name with spaces; strip for matching DB columns."""
    out = []
    for r in rows:
        d = dict(r)
        fn = d.get('field_name')
        if isinstance(fn, str):
            d['field_name'] = fn.strip()
        out.append(d)
    return out


@sap_data_explorer_blueprint.route('/tables', methods=['GET'])
def get_sap_tables():
    """Retourne la liste des tables SAP avec leurs propriétés"""
    try:
        search = request.args.get('search', '')

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            query = """
                SELECT 
                    p.table_name,
                    p.table_class,
                    p.description,
                    p.client_dependent,
                    (SELECT COUNT(*) FROM public.sap_table_fields f 
                     WHERE f.table_name = p.table_name) as field_count
                FROM public.sap_table_properties p
            """
            params = []

            if search:
                query += " WHERE p.table_name ILIKE %s OR p.description ILIKE %s"
                params.extend([f'%{search}%', f'%{search}%'])

            query += " ORDER BY p.table_name"

            cursor.execute(query, params)
            tables = cursor.fetchall()

            return jsonify({
                'success': True,
                'tables': tables
            }), 200

    except Exception as e:
        current_app.logger.error(f"Erreur récupération tables SAP: {e}")
        return jsonify({'error': str(e)}), 500


@sap_data_explorer_blueprint.route('/tables/<table_name>/fields', methods=['GET'])
def get_sap_table_fields(table_name: str):
    """Retourne les champs d'une table SAP avec header_text"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute("""
                SELECT 
                    f.field_name,
                    f.position,
                    f.key_flag,
                    f.mandatory,
                    f.data_type,
                    f.check_table,
                    f.length,
                    f.decimals,
                    f.abap_type,
                    f.field_text,
                    f.header_text,
                    f.long_description
                FROM public.sap_table_fields f
                WHERE f.table_name = %s
                  AND UPPER(TRIM(f.data_type)) NOT IN ('MANDT')
                  AND UPPER(TRIM(f.field_name)) NOT IN ('MANDT', 'CLIENT')
                ORDER BY f.position
            """, (table_name,))

            fields = _normalize_sap_field_rows(cursor.fetchall())

            # Récupérer les propriétés de la table
            cursor.execute("""
                SELECT * FROM public.sap_table_properties
                WHERE table_name = %s
            """, (table_name,))
            properties = cursor.fetchone()

            return jsonify({
                'success': True,
                'fields': fields,
                'properties': dict(properties) if properties else None,
                'tableName': table_name
            }), 200

    except Exception as e:
        current_app.logger.error(f"Erreur récupération champs SAP: {e}")
        return jsonify({'error': str(e)}), 500


@sap_data_explorer_blueprint.route('/tables/<table_name>/data', methods=['GET'])
def get_sap_table_data(table_name: str):
    """Retourne les données d'une table SAP extraite (raw_data) avec header_text comme en-tête"""
    try:
        page = int(request.args.get('page', 1))
        page_size = int(request.args.get('pageSize', 50))
        sort_column = request.args.get('sortColumn', None)
        sort_direction = request.args.get('sortDirection', 'asc')
        search = request.args.get('search', '')

        page_size = min(page_size, 500)
        offset = (page - 1) * page_size

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            # Récupérer les champs SAP avec header_text (exclure MANDT/CLIENT)
            cursor.execute("""
                SELECT field_name, header_text, field_text, data_type, key_flag, abap_type, length, decimals, long_description
                FROM public.sap_table_fields
                WHERE table_name = %s
                  AND UPPER(TRIM(data_type)) NOT IN ('MANDT')
                  AND UPPER(TRIM(field_name)) NOT IN ('MANDT', 'CLIENT')
                ORDER BY position
            """, (table_name,))
            sap_fields = _normalize_sap_field_rows(cursor.fetchall())

            if not sap_fields:
                return jsonify({'error': f'Table SAP {table_name} non trouvée dans les métadonnées'}), 404

            # Vérifier si la table existe dans raw_data ou clean_data
            schema = None
            for s in ['raw_data', 'clean_data', 'public']:
                cursor.execute("""
                    SELECT 1 FROM information_schema.tables 
                    WHERE table_schema = %s AND UPPER(table_name) = UPPER(%s)
                """, (s, table_name))
                if cursor.fetchone():
                    # Récupérer le nom exact de la table
                    cursor.execute("""
                        SELECT table_name FROM information_schema.tables 
                        WHERE table_schema = %s AND UPPER(table_name) = UPPER(%s)
                    """, (s, table_name))
                    actual_table = cursor.fetchone()['table_name']
                    schema = s
                    break

            if not schema:
                # Retourner seulement les métadonnées sans données
                return jsonify({
                    'success': True,
                    'data': [],
                    'fields': sap_fields,
                    'pagination': {
                        'page': 1,
                        'pageSize': page_size,
                        'totalRows': 0,
                        'totalPages': 0,
                        'hasNext': False,
                        'hasPrev': False
                    },
                    'tableName': table_name,
                    'schema': None,
                    'message': 'Données non encore extraites pour cette table'
                }), 200

            # Récupérer les colonnes réelles de la table
            cursor.execute("""
                SELECT column_name, data_type
                FROM information_schema.columns
                WHERE table_schema = %s AND table_name = %s
                ORDER BY ordinal_position
            """, (schema, actual_table))
            real_columns = cursor.fetchall()

            # Filtrer et trier par position SAP
            real_col_set = {c['column_name'].upper(): c for c in real_columns}
            # Ordre basé sur la position dans sap_table_fields
            filtered_columns = []
            for f in sap_fields:  # sap_fields est déjà trié par position
                fn = (f.get('field_name') or '').strip()
                if not fn or fn.startswith('.'):
                    continue
                upper_name = fn.upper()
                if upper_name in real_col_set:
                    filtered_columns.append(real_col_set[upper_name])

            # Si aucune correspondance, afficher toutes les colonnes sauf les colonnes système connues
            system_columns = {'id', 'created_at', 'updated_at', 'imported_at', '_import_id', '_source_file', '_row_number'}
            if not filtered_columns:
                filtered_columns = [c for c in real_columns if c['column_name'].lower() not in system_columns]

            real_col_names = [c['column_name'] for c in filtered_columns]
            text_columns = [c['column_name'] for c in filtered_columns
                           if c['data_type'] in ('character varying', 'text', 'character')]

            # Construire la requête avec seulement les colonnes filtrées
            select_cols = ', '.join(f'"{col}"' for col in real_col_names)
            base_query = f'SELECT {select_cols} FROM {schema}."{actual_table}"'
            count_query = f'SELECT COUNT(*) as total FROM {schema}."{actual_table}"'

            where_clauses = []
            params = []

            # Recherche globale
            if search and text_columns:
                search_conditions = []
                for col in text_columns[:10]:
                    search_conditions.append(f'"{col}"::text ILIKE %s')
                    params.append(f'%{search}%')
                where_clauses.append(f'({" OR ".join(search_conditions)})')

            if where_clauses:
                where_sql = ' WHERE ' + ' AND '.join(where_clauses)
                base_query += where_sql
                count_query += where_sql

            # Tri
            if sort_column and sort_column in real_col_names:
                direction = 'DESC' if sort_direction.lower() == 'desc' else 'ASC'
                base_query += f' ORDER BY "{sort_column}" {direction} NULLS LAST'

            base_query += f' LIMIT {page_size} OFFSET {offset}'

            cursor.execute(count_query, params)
            total_count = cursor.fetchone()['total']

            cursor.execute(base_query, params)
            rows = cursor.fetchall()

            # Convertir pour JSON
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

            total_pages = (total_count + page_size - 1) // page_size if total_count > 0 else 0

            return jsonify({
                'success': True,
                'data': data,
                'fields': sap_fields,
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
        current_app.logger.error(f"Erreur récupération données SAP: {e}", exc_info=True)
        return jsonify({'error': str(e)}), 500


@sap_data_explorer_blueprint.route('/tables/<table_name>/export', methods=['GET'])
def export_sap_table_data(table_name: str):
    """Exporte les données avec header_text comme en-têtes CSV"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            # Récupérer les champs SAP (exclure MANDT/CLIENT)
            cursor.execute("""
                SELECT field_name, header_text, field_text
                FROM public.sap_table_fields
                WHERE table_name = %s
                  AND UPPER(TRIM(data_type)) NOT IN ('MANDT')
                  AND UPPER(TRIM(field_name)) NOT IN ('MANDT', 'CLIENT')
                ORDER BY position
            """, (table_name,))
            sap_fields = _normalize_sap_field_rows(cursor.fetchall())

            # Trouver la table dans les schémas
            schema = None
            actual_table = table_name
            for s in ['raw_data', 'clean_data', 'public']:
                cursor.execute("""
                    SELECT table_name FROM information_schema.tables 
                    WHERE table_schema = %s AND UPPER(table_name) = UPPER(%s)
                """, (s, table_name))
                result = cursor.fetchone()
                if result:
                    actual_table = result['table_name']
                    schema = s
                    break

            if not schema:
                return jsonify({'error': 'Données non disponibles pour cette table'}), 404

            limit = min(int(request.args.get('limit', 10000)), 100000)

            # Mapping field_name -> header_text
            header_map = {}
            for f in sap_fields:
                fn = (f.get('field_name') or '').strip()
                if not fn or fn.startswith('.'):
                    continue
                header_map[fn.upper()] = f['header_text'] or f['field_text'] or fn

            # Récupérer les colonnes réelles et trier par position SAP
            cursor.execute("""
                SELECT column_name FROM information_schema.columns
                WHERE table_schema = %s AND table_name = %s
            """, (schema, actual_table))
            all_col_set = {r['column_name'].upper(): r['column_name'] for r in cursor.fetchall()}
            system_columns = {'id', 'created_at', 'updated_at', 'imported_at', '_import_id', '_source_file', '_row_number'}
            # Trier par position SAP (sap_fields est déjà ORDER BY position)
            real_columns = [
                all_col_set[(f.get('field_name') or '').strip().upper()]
                for f in sap_fields
                if (f.get('field_name') or '').strip()
                and not (f.get('field_name') or '').strip().startswith('.')
                and (f.get('field_name') or '').strip().upper() in all_col_set
            ]
            if not real_columns:
                real_columns = [v for k, v in all_col_set.items() if v.lower() not in system_columns]

            select_cols = ', '.join(f'"{col}"' for col in real_columns)
            cursor.execute(f'SELECT {select_cols} FROM {schema}."{actual_table}" LIMIT {limit}')
            rows = cursor.fetchall()

            if not rows:
                return jsonify({'error': 'Aucune donnée à exporter'}), 404

            output = io.StringIO()

            # En-têtes : header_text si disponible, sinon nom de colonne
            csv_headers = [header_map.get(col.upper(), col) for col in real_columns]

            writer = csv.writer(output, delimiter=';')
            writer.writerow(csv_headers)

            for row in rows:
                writer.writerow([str(v) if v is not None else '' for v in row.values()])

            output.seek(0)

            return Response(
                output.getvalue(),
                mimetype='text/csv',
                headers={
                    'Content-Disposition': f'attachment; filename=SAP_{table_name}.csv',
                    'Content-Type': 'text/csv; charset=utf-8'
                }
            )

    except Exception as e:
        current_app.logger.error(f"Erreur export SAP: {e}")
        return jsonify({'error': str(e)}), 500
