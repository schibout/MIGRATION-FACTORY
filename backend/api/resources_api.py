"""
API ressources : seule reste la recherche des personnes IFS (IfsPersonAutocomplete).
Les ecrans Ressources passent par api/resource_files.py.
"""
from flask import Blueprint, jsonify, request, current_app
import psycopg2.extras
from config.database import get_db_connection

resources_blueprint = Blueprint('resources', __name__)


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
