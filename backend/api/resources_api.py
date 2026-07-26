"""
API pour la gestion des ressources
"""
from flask import Blueprint, jsonify, request, current_app, send_file
import psycopg2.extras
import csv
import io
from config.database import get_db_connection

resources_blueprint = Blueprint('resources', __name__)


@resources_blueprint.route('/detail-files', methods=['GET'])
def get_resource_detail_files():
    """Récupère les fichiers de détails des ressources"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 50, type=int)
        search = request.args.get('search', '', type=str)
        
        per_page = min(per_page, 100)
        offset = (page - 1) * per_page
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            where_clause = ""
            params = []
            if search:
                where_clause = """
                    WHERE resource_id::TEXT ILIKE %s 
                       OR description ILIKE %s
                       OR resource_type ILIKE %s
                """
                search_param = f'%{search}%'
                params = [search_param, search_param, search_param]
            
            count_query = f"SELECT COUNT(*) as total FROM clean_data.resource_detail_file {where_clause}"
            cursor.execute(count_query, params)
            total = cursor.fetchone()['total']
            
            query = f"""
                SELECT 
                    resource_seq,
                    resource_id,
                    description,
                    resource_type,
                    calendar_id,
                    resource_category,
                    loaded_at
                FROM clean_data.resource_detail_file
                {where_clause}
                ORDER BY loaded_at DESC NULLS LAST
                LIMIT %s OFFSET %s
            """
            cursor.execute(query, params + [per_page, offset])
            data = cursor.fetchall()
            
            return jsonify({
                'success': True,
                'data': data,
                'total': total,
                'page': page,
                'per_page': per_page
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur récupération resource_detail_file: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la récupération des données',
            'message': str(e)
        }), 500


@resources_blueprint.route('/connections', methods=['GET'])
def get_resource_connections():
    """Récupère les connexions entre ressources"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 50, type=int)
        search = request.args.get('search', '', type=str)
        
        per_page = min(per_page, 100)
        offset = (page - 1) * per_page
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            where_clause = ""
            params = []
            if search:
                where_clause = """
                    WHERE resource_id::TEXT ILIKE %s 
                       OR employee_id::TEXT ILIKE %s
                       OR connection_type ILIKE %s
                       OR company ILIKE %s
                """
                search_param = f'%{search}%'
                params = [search_param, search_param, search_param, search_param]
            
            count_query = f"SELECT COUNT(*) as total FROM clean_data.resource_connection {where_clause}"
            cursor.execute(count_query, params)
            total = cursor.fetchone()['total']
            
            query = f"""
                SELECT 
                    resource_connection_seq,
                    resource_seq,
                    primary_parent_resource_seq,
                    connection_type,
                    company,
                    site,
                    employee_id,
                    resource_id,
                    resource_type,
                    loaded_at
                FROM clean_data.resource_connection
                {where_clause}
                ORDER BY loaded_at DESC NULLS LAST
                LIMIT %s OFFSET %s
            """
            cursor.execute(query, params + [per_page, offset])
            data = cursor.fetchall()
            
            return jsonify({
                'success': True,
                'data': data,
                'total': total,
                'page': page,
                'per_page': per_page
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur récupération resource_connection: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la récupération des données',
            'message': str(e)
        }), 500


@resources_blueprint.route('/availability', methods=['GET'])
def get_resource_availability():
    """Récupère la disponibilité des ressources"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 50, type=int)
        search = request.args.get('search', '', type=str)
        
        per_page = min(per_page, 100)
        offset = (page - 1) * per_page
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            where_clause = ""
            params = []
            if search:
                where_clause = """
                    WHERE resource_seq::TEXT ILIKE %s 
                       OR company ILIKE %s
                       OR site ILIKE %s
                """
                search_param = f'%{search}%'
                params = [search_param, search_param, search_param]
            
            count_query = f"SELECT COUNT(*) as total FROM clean_data.resource_availability {where_clause}"
            cursor.execute(count_query, params)
            total = cursor.fetchone()['total']
            
            query = f"""
                SELECT 
                    resource_availability_seq,
                    resource_parent_seq,
                    resource_seq,
                    company,
                    site,
                    start_date,
                    end_date,
                    available_percentage,
                    efficiency,
                    loaded_at
                FROM clean_data.resource_availability
                {where_clause}
                ORDER BY start_date DESC NULLS LAST
                LIMIT %s OFFSET %s
            """
            cursor.execute(query, params + [per_page, offset])
            data = cursor.fetchall()
            
            return jsonify({
                'success': True,
                'data': data,
                'total': total,
                'page': page,
                'per_page': per_page
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur récupération resource_availability: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la récupération des données',
            'message': str(e)
        }), 500


@resources_blueprint.route('/parents', methods=['GET'])
def get_resource_parents():
    """Récupère la hiérarchie des ressources parentes"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 50, type=int)
        search = request.args.get('search', '', type=str)
        
        per_page = min(per_page, 100)
        offset = (page - 1) * per_page
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            where_clause = ""
            params = []
            if search:
                where_clause = """
                    WHERE resource_seq::TEXT ILIKE %s 
                       OR resource_parent_seq::TEXT ILIKE %s
                """
                search_param = f'%{search}%'
                params = [search_param, search_param]
            
            count_query = f"SELECT COUNT(*) as total FROM clean_data.resource_parent {where_clause}"
            cursor.execute(count_query, params)
            total = cursor.fetchone()['total']
            
            query = f"""
                SELECT 
                    resource_parent_seq,
                    resource_seq,
                    scheduling_proficiency,
                    loaded_at
                FROM clean_data.resource_parent
                {where_clause}
                ORDER BY resource_parent_seq
                LIMIT %s OFFSET %s
            """
            cursor.execute(query, params + [per_page, offset])
            data = cursor.fetchall()
            
            return jsonify({
                'success': True,
                'data': data,
                'total': total,
                'page': page,
                'per_page': per_page
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur récupération resource_parent: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la récupération des données',
            'message': str(e)
        }), 500


@resources_blueprint.route('/maint-person', methods=['GET'])
def get_maint_person_resources():
    """Récupère les ressources de maintenance par personne"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 50, type=int)
        search = request.args.get('search', '', type=str)
        
        per_page = min(per_page, 100)
        offset = (page - 1) * per_page
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            where_clause = ""
            params = []
            if search:
                where_clause = """
                    WHERE maint_resource_seq::TEXT ILIKE %s 
                       OR company ILIKE %s
                       OR contract ILIKE %s
                       OR connection_type ILIKE %s
                """
                search_param = f'%{search}%'
                params = [search_param, search_param, search_param, search_param]
            
            count_query = f"SELECT COUNT(*) as total FROM clean_data.maint_person_resource {where_clause}"
            cursor.execute(count_query, params)
            total = cursor.fetchone()['total']
            
            query = f"""
                SELECT 
                    maint_resource_seq,
                    resource_connection_seq,
                    company,
                    contract,
                    connection_type,
                    org_code,
                    vendor_no,
                    mob_user,
                    mob_user_type,
                    primary_resource,
                    loaded_at
                FROM clean_data.maint_person_resource
                {where_clause}
                ORDER BY loaded_at DESC NULLS LAST
                LIMIT %s OFFSET %s
            """
            cursor.execute(query, params + [per_page, offset])
            data = cursor.fetchall()
            
            return jsonify({
                'success': True,
                'data': data,
                'total': total,
                'page': page,
                'per_page': per_page
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur récupération maint_person_resource: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la récupération des données',
            'message': str(e)
        }), 500


@resources_blueprint.route('/ifs-persons', methods=['GET'])
def get_ifs_persons():
    """Récupère les personnes IFS"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 50, type=int)
        search = request.args.get('search', '', type=str)
        
        per_page = min(per_page, 100)
        offset = (page - 1) * per_page
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            where_clause = ""
            params = []
            if search:
                where_clause = """
                    WHERE person_id::TEXT ILIKE %s 
                       OR first_name ILIKE %s
                       OR last_name ILIKE %s
                       OR internal_display_name ILIKE %s
                """
                search_param = f'%{search}%'
                params = [search_param] * 4
            
            count_query = f"SELECT COUNT(*) as total FROM clean_data.ifs_person {where_clause}"
            cursor.execute(count_query, params)
            total = cursor.fetchone()['total']
            
            query = f"""
                SELECT 
                    id,
                    person_id,
                    first_name,
                    last_name,
                    title,
                    internal_display_name,
                    date_of_birth,
                    gender,
                    marital_status,
                    currently_employed,
                    loaded_at
                FROM clean_data.ifs_person
                {where_clause}
                ORDER BY last_name NULLS LAST, first_name NULLS LAST
                LIMIT %s OFFSET %s
            """
            cursor.execute(query, params + [per_page, offset])
            data = cursor.fetchall()
            
            return jsonify({
                'success': True,
                'data': data,
                'total': total,
                'page': page,
                'per_page': per_page
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur récupération ifs_person: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la récupération des données',
            'message': str(e)
        }), 500


# ============= ENDPOINTS GÉNÉRIQUES POUR UPDATE/DELETE/EXPORT =============

@resources_blueprint.route('/<endpoint>/<record_id>', methods=['PUT'])
def update_resource_record(endpoint, record_id):
    """Met à jour un enregistrement dans une table de ressources"""
    try:
        data = request.get_json()
        
        # Mapper les endpoints vers les tables
        table_map = {
            'detail-files': 'resource_detail_file',
            'connections': 'resource_connection',
            'availability': 'resource_availability',
            'parents': 'resource_parent',
            'maint-person': 'maint_person_resource',
            'ifs-persons': 'ifs_person'
        }
        
        table_name = table_map.get(endpoint)
        if not table_name:
            return jsonify({'success': False, 'message': 'Endpoint invalide'}), 400
        
        # Construire la requête UPDATE
        set_clauses = []
        params = []
        for key, value in data.items():
            set_clauses.append(f"{key} = %s")
            params.append(value)
        
        params.append(record_id)
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Déterminer la colonne ID
            id_column = 'resource_seq' if 'resource' in table_name else 'id'
            
            query = f"""
                UPDATE clean_data.{table_name}
                SET {', '.join(set_clauses)}
                WHERE {id_column} = %s
            """
            
            cursor.execute(query, params)
            conn.commit()
            
            return jsonify({
                'success': True,
                'message': 'Enregistrement mis à jour avec succès'
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur mise à jour {endpoint}: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la mise à jour',
            'message': str(e)
        }), 500


@resources_blueprint.route('/<endpoint>/<record_id>', methods=['DELETE'])
def delete_resource_record(endpoint, record_id):
    """Supprime un enregistrement dans une table de ressources"""
    try:
        # Mapper les endpoints vers les tables
        table_map = {
            'detail-files': 'resource_detail_file',
            'connections': 'resource_connection',
            'availability': 'resource_availability',
            'parents': 'resource_parent',
            'maint-person': 'maint_person_resource',
            'ifs-persons': 'ifs_person'
        }
        
        table_name = table_map.get(endpoint)
        if not table_name:
            return jsonify({'success': False, 'message': 'Endpoint invalide'}), 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Déterminer la colonne ID
            id_column = 'resource_seq' if 'resource' in table_name else 'id'
            
            query = f"DELETE FROM clean_data.{table_name} WHERE {id_column} = %s"
            cursor.execute(query, [record_id])
            conn.commit()
            
            return jsonify({
                'success': True,
                'message': 'Enregistrement supprimé avec succès'
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur suppression {endpoint}: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la suppression',
            'message': str(e)
        }), 500


@resources_blueprint.route('/<endpoint>/export', methods=['GET'])
def export_resource_data(endpoint):
    """Exporte les données d'une table de ressources en CSV"""
    try:
        fields = request.args.get('fields', '').split(',')
        search = request.args.get('search', '', type=str)
        
        # Mapper les endpoints vers les tables
        table_map = {
            'detail-files': 'resource_detail_file',
            'connections': 'resource_connection',
            'availability': 'resource_availability',
            'parents': 'resource_parent',
            'maint-person': 'maint_person_resource',
            'ifs-persons': 'ifs_person'
        }
        
        table_name = table_map.get(endpoint)
        if not table_name:
            return jsonify({'success': False, 'message': 'Endpoint invalide'}), 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Construire la clause WHERE pour la recherche
            where_clause = ""
            params = []
            if search:
                where_clause = "WHERE CAST(ROW_TO_JSON(t.*) AS TEXT) ILIKE %s"
                params = [f'%{search}%']
            
            # Sélectionner les champs demandés ou tous
            field_list = ', '.join(fields) if fields and fields[0] else '*'
            
            query = f"""
                SELECT {field_list}
                FROM clean_data.{table_name} t
                {where_clause}
            """
            
            cursor.execute(query, params)
            rows = cursor.fetchall()
            
            # Créer le fichier CSV en mémoire
            output = io.StringIO()
            if rows:
                writer = csv.DictWriter(output, fieldnames=rows[0].keys())
                writer.writeheader()
                writer.writerows(rows)
            
            # Convertir en bytes
            output.seek(0)
            bytes_output = io.BytesIO(output.getvalue().encode('utf-8'))
            bytes_output.seek(0)
            
            return send_file(
                bytes_output,
                mimetype='text/csv',
                as_attachment=True,
                download_name=f'{table_name}_export.csv'
            )
            
    except Exception as e:
        current_app.logger.error(f"Erreur export {endpoint}: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de l\'export',
            'message': str(e)
        }), 500

