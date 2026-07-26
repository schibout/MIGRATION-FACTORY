from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity, current_user
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy import text
from werkzeug.exceptions import BadRequest
from werkzeug.security import generate_password_hash
import psycopg2.extras

from services.data_service import get_data_service
from utils.validators import validate_pagination
from utils.auth_decorators import require_role, require_permission, admin_required
from models.user import User, db
from config.database import get_db_connection

data_blueprint = Blueprint('data', __name__)

@data_blueprint.route('/tables', methods=['GET'])
# @jwt_required()
def get_tables():
    """Récupère la liste des tables disponibles"""
    try:
        # Utiliser la fonction factory pour obtenir l'instance de DataService
        data_service = get_data_service()
        tables = data_service.get_tables()
        return jsonify(tables), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des tables: {str(e)}")
        return jsonify({"error": "Erreur lors de la récupération des tables"}), 500

@data_blueprint.route('/sap-tables', methods=['GET'])
# @jwt_required()
def get_sap_tables():
    """Récupère la liste des tables SAP disponibles"""
    try:
        data_service = get_data_service()
        
        # Pagination
        page = request.args.get('page', 1, type=int)
        limit = request.args.get('limit', 20, type=int)
        search = request.args.get('search', '')
        
        tables = data_service.get_sap_tables(page, limit, search)
        return jsonify(tables), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des tables SAP: {str(e)}")
        return jsonify({"error": "Erreur lors de la récupération des tables SAP"}), 500

@data_blueprint.route('/<table>/fields', methods=['GET'])
# @jwt_required()()
def get_table_fields(table):
    """Récupère la liste des champs d'une table"""
    try:
        data_service = get_data_service()
        fields = data_service.get_table_fields(table)
        return jsonify(fields), 200
        
    except BadRequest as e:
        return jsonify({"error": str(e)}), 400
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des champs de {table}: {str(e)}")
        return jsonify({"error": "Erreur lors de la récupération des champs"}), 500

@data_blueprint.route('/<table>/preview', methods=['GET'])
# @jwt_required()()
def get_preview_data(table):
    """Récupère un aperçu des données d'une table"""
    try:
        # Récupération des paramètres
        fields = request.args.get('fields', '').split(',') if request.args.get('fields') else None
        limit = int(request.args.get('limit', 5))
        
        # Limitation de la prévisualisation
        if limit > 100:
            limit = 100
        
        data_service = get_data_service()    
        preview = data_service.get_preview_data(table, fields, limit)
        return jsonify(preview), 200
        
    except BadRequest as e:
        return jsonify({"error": str(e)}), 400
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la prévisualisation de {table}: {str(e)}")
        return jsonify({"error": "Erreur lors de la prévisualisation des données"}), 500

@data_blueprint.route('/<table>/filter', methods=['POST'])
# @jwt_required()()
def filter_data(table):
    """Filtre les données d'une table selon des critères"""
    try:
        # Récupération des paramètres
        data = request.get_json()
        if not data:
            return jsonify({"error": "Données de requête manquantes"}), 400
            
        fields = data.get('fields')
        filters = data.get('filters', [])
        conjunction = data.get('conjunction', 'AND')
        page = int(data.get('page', 1))
        page_size = int(data.get('page_size', 20))
        
        # Validation de la pagination
        if not validate_pagination(page, page_size):
            return jsonify({"error": "Paramètres de pagination invalides"}), 400
            
        # Limitation de la taille de page
        if page_size > 100:
            page_size = 100
        
        data_service = get_data_service()    
        result = data_service.filter_data(table, filters, fields, conjunction, page, page_size)
        
        # Journalisation (désactivation de la référence à get_jwt_identity())
        current_app.logger.info(
            f"Filtrage de {table}: {len(result['data'])} résultats"
        )
        
        return jsonify(result), 200
        
    except BadRequest as e:
        return jsonify({"error": str(e)}), 400
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors du filtrage de {table}: {str(e)}")
        return jsonify({"error": "Erreur lors du filtrage des données"}), 500

@data_blueprint.route('/<table>/export', methods=['POST'])
# @jwt_required()()
def export_data(table):
    """Exporte les données d'une table au format spécifié"""
    try:
        # Récupération des paramètres
        data = request.get_json()
        if not data:
            return jsonify({"error": "Données de requête manquantes"}), 400
            
        fields = data.get('fields', [])
        if not fields:
            return jsonify({"error": "Liste de champs vide"}), 400
            
        filters = data.get('filters', [])
        format_type = data.get('format', 'csv').lower()
        options = data.get('options', {})
        
        # Journalisation de l'export (désactivation de la référence à get_jwt_identity())
        current_app.logger.info(
            f"Export {format_type} de {table} avec {len(fields)} champs"
        )
        
        data_service = get_data_service()
        # Export selon le format demandé
        if format_type == 'csv':
            return data_service.export_csv(table, fields, filters, options)
        elif format_type == 'excel':
            return data_service.export_excel(table, fields, filters, options)
        else:
            return jsonify({"error": f"Format d'export non supporté: {format_type}"}), 400
            
    except BadRequest as e:
        return jsonify({"error": str(e)}), 400
        
    except SQLAlchemyError as e:
        current_app.logger.error(f"Erreur SQL lors de l'export de {table}: {str(e)}")
        return jsonify({"error": "Erreur lors de l'accès aux données"}), 500
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de l'export de {table}: {str(e)}")
        return jsonify({"error": "Erreur lors de l'export des données"}), 500

@data_blueprint.route('/<table>/export-configs', methods=['GET', 'POST'])
# @jwt_required()()
def export_configs(table):
    """Gère les configurations d'export sauvegardées"""
    # Désactivation temporaire de l'authentification
    # user_id = get_jwt_identity()
    user_id = "demo_user"  # Utilisateur temporaire pour le développement
    
    if request.method == 'GET':
        # TODO: Implémenter la récupération des configurations d'export
        return jsonify([]), 200
        
    elif request.method == 'POST':
        # Sauvegarde d'une configuration d'export
        try:
            data = request.get_json()
            if not data or not data.get('name') or not data.get('configuration'):
                return jsonify({"error": "Données manquantes"}), 400
                
            # TODO: Implémenter la sauvegarde des configurations d'export
            
            return jsonify({
                "id": "config-123",  # Placeholder
                "message": "Configuration sauvegardée"
            }), 201
            
        except Exception as e:
            current_app.logger.error(f"Erreur lors de la sauvegarde de configuration: {str(e)}")
            return jsonify({"error": "Erreur lors de la sauvegarde"}), 500

# Routes pour les données SAP (Admin et Operator)
@data_blueprint.route('/sap', methods=['GET'])
@require_permission('view_sap_data')
def get_sap_data():
    """Récupère les données SAP (Admin et Operator)"""
    try:
        # Logique pour récupérer les données SAP
        # TODO: Implémenter la récupération des données SAP
        
        sample_data = [
            {
                'id': '1',
                'type': 'SAP_TABLE',
                'name': 'MARA',
                'description': 'Table des articles',
                'records_count': 1250,
                'last_update': '2024-01-15T10:30:00Z'
            },
            {
                'id': '2',
                'type': 'SAP_TABLE',
                'name': 'MARC',
                'description': 'Table des vues article/centre',
                'records_count': 3500,
                'last_update': '2024-01-15T10:30:00Z'
            }
        ]
        
        return jsonify({
            'data': sample_data,
            'total': len(sample_data),
            'message': 'Données SAP récupérées avec succès'
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des données SAP: {str(e)}")
        return jsonify({'error': 'Erreur lors de la récupération des données SAP'}), 500

@data_blueprint.route('/sap/<table_name>', methods=['GET'])
@require_permission('view_sap_data')
def get_sap_table_data(table_name):
    """Récupère les données d'une table SAP spécifique (Admin et Operator)"""
    try:
        # Logique pour récupérer les données d'une table SAP spécifique
        # TODO: Implémenter la récupération des données de table SAP
        
        return jsonify({
            'table': table_name,
            'data': [],
            'message': f'Données de la table SAP {table_name} récupérées avec succès'
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des données SAP {table_name}: {str(e)}")
        return jsonify({'error': f'Erreur lors de la récupération des données SAP {table_name}'}), 500

# Routes pour les données IFS (Admin et Operator)
@data_blueprint.route('/ifs', methods=['GET'])
@require_permission('view_ifs_data')
def get_ifs_data():
    """Récupère les données IFS (Admin et Operator)"""
    try:
        # Logique pour récupérer les données IFS
        # TODO: Implémenter la récupération des données IFS
        
        sample_data = [
            {
                'id': '1',
                'type': 'IFS_DATA',
                'name': 'Inventory Parts',
                'description': 'Données des pièces d\'inventaire',
                'records_count': 850,
                'last_update': '2024-01-15T11:00:00Z'
            },
            {
                'id': '2',
                'type': 'IFS_DATA',
                'name': 'Supplier Info',
                'description': 'Informations des fournisseurs',
                'records_count': 120,
                'last_update': '2024-01-15T11:00:00Z'
            }
        ]
        
        return jsonify({
            'data': sample_data,
            'total': len(sample_data),
            'message': 'Données IFS récupérées avec succès'
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des données IFS: {str(e)}")
        return jsonify({'error': 'Erreur lors de la récupération des données IFS'}), 500

@data_blueprint.route('/ifs/<data_type>', methods=['GET'])
@require_permission('view_ifs_data')
def get_ifs_specific_data(data_type):
    """Récupère un type spécifique de données IFS (Admin et Operator)"""
    try:
        # Logique pour récupérer un type spécifique de données IFS
        # TODO: Implémenter la récupération des données IFS spécifiques
        
        return jsonify({
            'data_type': data_type,
            'data': [],
            'message': f'Données IFS {data_type} récupérées avec succès'
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des données IFS {data_type}: {str(e)}")
        return jsonify({'error': f'Erreur lors de la récupération des données IFS {data_type}'}), 500

# Routes de configuration (Admin seulement)
@data_blueprint.route('/mappings', methods=['GET'])
@require_permission('manage_mappings')
def get_mappings():
    """Récupère les mappings de champs (Admin seulement)"""
    try:
        # TODO: Implémenter la récupération des mappings
        return jsonify({
            'mappings': [],
            'message': 'Mappings récupérés avec succès'
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des mappings: {str(e)}")
        return jsonify({'error': 'Erreur lors de la récupération des mappings'}), 500

@data_blueprint.route('/mappings', methods=['POST'])
@require_permission('manage_mappings')
def create_mapping():
    """Crée un nouveau mapping (Admin seulement)"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'Données manquantes'}), 400
        
        # TODO: Implémenter la création de mapping
        return jsonify({
            'mapping': data,
            'message': 'Mapping créé avec succès'
        }), 201
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la création du mapping: {str(e)}")
        return jsonify({'error': 'Erreur lors de la création du mapping'}), 500

@data_blueprint.route('/transcodifications', methods=['GET'])
@require_permission('manage_transcodification')
def get_transcodifications():
    """Récupère les transcodifications (Admin seulement)"""
    try:
        # TODO: Implémenter la récupération des transcodifications
        return jsonify({
            'transcodifications': [],
            'message': 'Transcodifications récupérées avec succès'
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des transcodifications: {str(e)}")
        return jsonify({'error': 'Erreur lors de la récupération des transcodifications'}), 500

@data_blueprint.route('/export', methods=['POST'])
@require_permission('export_data')
def export_general_data():
    """Exporte les données (Admin et Operator)"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'Données manquantes'}), 400
        
        export_type = data.get('type')  # 'sap' ou 'ifs'
        export_format = data.get('format', 'csv')  # 'csv', 'excel', 'json'
        
        if export_type not in ['sap', 'ifs']:
            return jsonify({'error': 'Type d\'export invalide'}), 400
        
        # TODO: Implémenter l'export des données
        return jsonify({
            'export_id': 'export_123',
            'status': 'processing',
            'message': f'Export {export_type} en cours de traitement'
        }), 202
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de l'export des données: {str(e)}")
        return jsonify({'error': 'Erreur lors de l\'export des données'}), 500

# Route pour les métriques du dashboard (Admin et Operator)
@data_blueprint.route('/metrics', methods=['GET'])
@require_permission('view_dashboards')
def get_metrics():
    """Récupère les métriques pour le dashboard (Admin et Operator)"""
    try:
        # TODO: Implémenter la récupération des métriques
        sample_metrics = {
            'sap_data': {
                'total_tables': 15,
                'total_records': 25000,
                'last_sync': '2024-01-15T10:30:00Z'
            },
            'ifs_data': {
                'total_datasets': 8,
                'total_records': 12000,
                'last_sync': '2024-01-15T11:00:00Z'
            },
            'system': {
                'status': 'healthy',
                'uptime': '99.9%',
                'last_backup': '2024-01-15T02:00:00Z'
            }
        }
        
        return jsonify({
            'metrics': sample_metrics,
            'message': 'Métriques récupérées avec succès'
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des métriques: {str(e)}")
        return jsonify({'error': 'Erreur lors de la récupération des métriques'}), 500

@data_blueprint.route('/users/<user_id>/password', methods=['PUT'])
@admin_required
def reset_user_password(user_id):
    """Réinitialise le mot de passe d'un utilisateur (Admin seulement)"""
    try:
        data = request.get_json()
        if not data or 'password' not in data:
            return jsonify({'error': 'Nouveau mot de passe requis'}), 400
        
        new_password = data['password']
        if len(new_password) < 6:
            return jsonify({'error': 'Le mot de passe doit contenir au moins 6 caractères'}), 400
        
        user = User.query.get(user_id)
        if not user:
            return jsonify({'error': 'Utilisateur non trouvé'}), 404
        
        # Hacher le nouveau mot de passe
        user.password_hash = generate_password_hash(new_password)
        db.session.commit()
        
        current_app.logger.info(f"Mot de passe réinitialisé pour l'utilisateur {user.username} par {current_user.username}")
        
        return jsonify({
            'message': 'Mot de passe réinitialisé avec succès'
        }), 200
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur lors de la réinitialisation du mot de passe: {str(e)}")
        return jsonify({'error': 'Erreur lors de la réinitialisation du mot de passe'}), 500

@data_blueprint.route('/query', methods=['POST'])
# @jwt_required()
def execute_custom_query():
    """Exécute une requête SQL personnalisée"""
    try:
        # Récupération des paramètres
        data = request.get_json()
        if not data:
            return jsonify({"error": "Données de requête manquantes"}), 400
            
        query = data.get('query')
        schema = data.get('schema', 'raw_data')
        
        if not query:
            return jsonify({"error": "Requête SQL manquante"}), 400
        
        # Validation basique de sécurité (empêcher les opérations dangereuses)
        query_upper = query.upper().strip()
        dangerous_operations = ['DROP', 'DELETE', 'UPDATE', 'INSERT', 'ALTER', 'CREATE', 'TRUNCATE']
        if any(op in query_upper for op in dangerous_operations):
            return jsonify({"error": "Seules les requêtes SELECT sont autorisées"}), 400
        
        data_service = get_data_service()
        
        with data_service.engine.connect() as connection:
            # Préfixer la requête avec le schéma si nécessaire
            if f"{schema}." not in query and "FROM " in query_upper:
                # Remplacer les noms de tables par schema.table_name
                import re
                query = re.sub(r'FROM\s+([A-Za-z_][A-Za-z0-9_]*)', f'FROM {schema}.\\1', query)
            
            # Exécuter la requête
            result = connection.execute(text(query))
            
            # Récupérer les noms des colonnes
            columns = result.keys()
            
            # Convertir les données en dictionnaires
            rows = [dict(zip(columns, row)) for row in result]
            
            current_app.logger.info(f"Requête exécutée avec succès: {len(rows)} lignes retournées")
            
            return jsonify(rows), 200
            
    except SQLAlchemyError as e:
        current_app.logger.error(f"Erreur SQL lors de l'exécution de la requête: {str(e)}")
        return jsonify({"error": f"Erreur SQL: {str(e)}"}), 500
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de l'exécution de la requête: {str(e)}")
        return jsonify({"error": "Erreur lors de l'exécution de la requête"}), 500


@data_blueprint.route('/sharepoint-projets', methods=['GET'])
# @jwt_required()
def get_sharepoint_projets():
    """Récupère la liste des projets SharePoint importés"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 50, type=int)
        search = request.args.get('search', '', type=str)
        
        # Limiter per_page
        per_page = min(per_page, 100)
        offset = (page - 1) * per_page
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Construire la clause WHERE si recherche
            where_clause = ""
            params = []
            if search:
                where_clause = """
                    WHERE title ILIKE %s 
                       OR code ILIKE %s 
                       OR project_number ILIKE %s
                       OR global_status ILIKE %s
                """
                search_param = f'%{search}%'
                params = [search_param, search_param, search_param, search_param]
            
            # Compter le total
            count_query = f"SELECT COUNT(*) as total FROM raw_data.sharepoint_projets {where_clause}"
            cursor.execute(count_query, params)
            total = cursor.fetchone()['total']
            
            # Récupérer les projets
            query = f"""
                SELECT 
                    id, sharepoint_id, title, code, project_number, description,
                    global_status, phase_text, percent_completed, health, planning, cost,
                    start_date, estimated_end_date, 
                    budget_initial, budget_total_sap, budget_actual, budget_at_completion,
                    sector, group_name, template, pm_id,
                    imported_at
                FROM raw_data.sharepoint_projets
                {where_clause}
                ORDER BY imported_at DESC, sharepoint_id DESC
                LIMIT %s OFFSET %s
            """
            cursor.execute(query, params + [per_page, offset])
            projets = cursor.fetchall()
            
            current_app.logger.info(f"✅ {len(projets)} projets récupérés (page {page}/{(total + per_page - 1) // per_page})")
            
            return jsonify({
                'success': True,
                'data': projets,
                'total': total,
                'page': page,
                'per_page': per_page,
                'total_pages': (total + per_page - 1) // per_page
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"❌ Erreur récupération projets SharePoint: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la récupération des projets',
            'message': str(e)
        }), 500

@data_blueprint.route('/sharepoint-projets/<int:project_id>', methods=['GET'])
# @jwt_required()
def get_sharepoint_projet_detail(project_id):
    """Récupère les détails complets d'un projet SharePoint"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Récupérer toutes les colonnes du projet
            query = """
                SELECT 
                    -- Informations de base
                    id, sharepoint_id, title, code, project_number, description,
                    
                    -- Statut et progression
                    global_status, phase_text, percent_completed, health, planning, cost,
                    passing_gate, project_ahead, retroplanning,
                    
                    -- Dates principales
                    start_date, estimated_end_date, last_status_report_date,
                    opening_date, modified, created, imported_at,
                    last_milestone_passed,
                    
                    -- Budgets
                    budget_initial, budget_total_sap, budget_actual, 
                    budget_at_completion, budget_demanded, budget_delivered,
                    budget_im_sap, budget_ex_sap,
                    
                    -- Organisation
                    sector, group_name, template,
                    
                    -- IDs de référence
                    pm_id, client_correspondent_id, project_team_id,
                    acheteur_capex_id, maintenance_correspondent_id, sponsor_id,
                    author_id, editor_id,
                    
                    -- Jalons (Gates)
                    end_p0, end_p1, end_p2, end_p3, end_p4, end_p5, end_p6,
                    
                    -- Dates spécifiques
                    conception_date, mise_en_service_date, achevement_industriel_date,
                    
                    -- États
                    conception_state, mise_en_service_state, achevement_industriel_state,
                    
                    -- Flags et autres
                    attachments, pris_en_charge, end_project_mark,
                    site_url, site_url_description, validation_id,
                    
                    -- Métadonnées
                    content_type_id, guid, static_id, ui_version_string, priority,
                    file_system_object_type,
                    
                    -- Données brutes complètes
                    raw_data
                    
                FROM raw_data.sharepoint_projets
                WHERE sharepoint_id = %s
            """
            
            cursor.execute(query, (project_id,))
            projet = cursor.fetchone()
            
            if not projet:
                return jsonify({
                    'success': False,
                    'error': 'Projet non trouvé',
                    'message': f'Aucun projet avec l\'ID {project_id}'
                }), 404
            
            current_app.logger.info(f"✅ Détails du projet {project_id} récupérés")
            
            return jsonify({
                'success': True,
                'data': projet
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"❌ Erreur récupération détails projet {project_id}: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la récupération du projet',
            'message': str(e)
        }), 500

@data_blueprint.route('/sharepoint-projets/<int:project_id>/etats-avancement', methods=['GET'])
def get_projet_etats_avancement(project_id):
    """Récupère les états d'avancement d'un projet via son site_id"""
    try:
        site_id = str(project_id)

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute("""
                SELECT sharepoint_id, title, status_date, percent_completed,
                       global_status, health, planning, cost, update_text,
                       current_phase_id, end_project_mark,
                       created, modified, author_id, editor_id, site_id
                FROM raw_data.sharepoint_etats_avancement
                WHERE site_id = %s
                ORDER BY status_date DESC
            """, [site_id])
            etats = cursor.fetchall()

            return jsonify({
                'success': True,
                'data': etats,
                'total': len(etats)
            }), 200

    except Exception as e:
        current_app.logger.error(f"Erreur récupération états avancement projet {project_id}: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@data_blueprint.route('/etats-avancement/<site_id>/<int:etat_id>/detail', methods=['GET'])
def get_etat_avancement_detail(site_id, etat_id):
    """
    Renvoie un état d'avancement avec ses listes filles assemblées :
    parent + phase label + jalons (avec labels) + CFV + coûts.

    FK enfants -> parent : raw_data->>'Status_x0020_Report' = parent.status_report_fk
    (status_report_fk est matérialisé par la migration 011 ; ce GUID
    SharePoint diffère du GUID interne de l'item — voir migration pour le pourquoi)
    FK jalon -> referentiel : raw_data->>'MilestoneId' = jalons_ref.sharepoint_id
    """
    try:
        with get_db_connection() as conn:
            cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            # 1. Parent état d'avancement
            cur.execute("""
                SELECT sharepoint_id, title, status_date, percent_completed,
                       global_status, health, planning, cost, update_text,
                       current_phase_id, end_project_mark,
                       raw_data->>'GUID' AS guid,
                       status_report_fk,
                       created, modified, site_id, raw_data
                FROM raw_data.sharepoint_etats_avancement
                WHERE site_id = %s AND sharepoint_id = %s
            """, [site_id, etat_id])
            etat = cur.fetchone()
            if not etat:
                return jsonify({'success': False, 'error': 'État d\'avancement introuvable'}), 404

            status_fk = etat['status_report_fk']

            # 2. Label de la phase courante (référentiel sharepoint_phases)
            phase_label = None
            if etat.get('current_phase_id'):
                cur.execute("""
                    SELECT title FROM raw_data.sharepoint_phases
                    WHERE site_id = %s AND sharepoint_id = %s
                """, [site_id, etat['current_phase_id']])
                row = cur.fetchone()
                if row:
                    phase_label = row['title']

            # 3. Jalons (avec label du référentiel)
            jalons = []
            if status_fk:
                cur.execute("""
                    SELECT
                        sj.sharepoint_id,
                        sj.title,
                        sj.raw_data->>'Gate'     AS gate,
                        sj.raw_data->>'Mark'     AS mark,
                        sj.raw_data->>'Ranking'  AS ranking,
                        sj.raw_data->>'Actual'   AS actual,
                        sj.raw_data->>'Baseline' AS baseline,
                        sj.raw_data->>'Forecast' AS forecast,
                        (sj.raw_data->>'MilestoneId')::int AS milestone_id,
                        jr.title AS jalon_label,
                        sj.raw_data
                    FROM raw_data.sharepoint_statut_jalons sj
                    LEFT JOIN raw_data.sharepoint_jalons_ref jr
                           ON jr.site_id = sj.site_id
                          AND jr.sharepoint_id = NULLIF(sj.raw_data->>'MilestoneId', '')::int
                    WHERE sj.site_id = %s
                      AND sj.raw_data->>'Status_x0020_Report' = %s
                    ORDER BY sj.raw_data->>'Gate'
                """, [site_id, status_fk])
                jalons = cur.fetchall()

            # 4. Commissions Feu Vert
            cfv = []
            if status_fk:
                cur.execute("""
                    SELECT sharepoint_id, title, raw_data
                    FROM raw_data.sharepoint_statut_cfv
                    WHERE site_id = %s
                      AND raw_data->>'Status_x0020_Report' = %s
                    ORDER BY sharepoint_id
                """, [site_id, status_fk])
                cfv = cur.fetchall()

            # 5. Coûts WBS
            couts = []
            if status_fk:
                cur.execute("""
                    SELECT sharepoint_id, title, raw_data
                    FROM raw_data.sharepoint_statut_couts
                    WHERE site_id = %s
                      AND raw_data->>'Status_x0020_Report' = %s
                    ORDER BY sharepoint_id
                """, [site_id, status_fk])
                couts = cur.fetchall()

            return jsonify({
                'success': True,
                'data': {
                    'etat':        etat,
                    'phase_label': phase_label,
                    'jalons':      jalons,
                    'cfv':         cfv,
                    'couts':       couts,
                }
            }), 200

    except Exception as e:
        current_app.logger.error(f"Erreur détail état d'avancement {site_id}/{etat_id}: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@data_blueprint.route('/etats-avancement/<site_id>/jalon/<int:milestone_id>/historique', methods=['GET'])
def get_jalon_historique(site_id, milestone_id):
    """Historique d'un jalon (porte) identifié par son milestone_id, à travers
    tous les états d'avancement du projet (une ligne par état).

    Jointure enfant->parent par (site_id, title) — robuste même si
    status_report_fk n'est pas matérialisé.
    """
    try:
        with get_db_connection() as conn:
            cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cur.execute("""
                SELECT
                    ea.sharepoint_id       AS etat_id,
                    ea.status_date,
                    sj.raw_data->>'Mark'     AS mark,
                    sj.raw_data->>'Ranking'  AS ranking,
                    sj.raw_data->>'Actual'   AS actual,
                    sj.raw_data->>'Baseline' AS baseline,
                    sj.raw_data->>'Forecast' AS forecast
                FROM raw_data.sharepoint_statut_jalons sj
                JOIN raw_data.sharepoint_etats_avancement ea
                  ON ea.site_id = sj.site_id AND ea.title = sj.title
                WHERE sj.site_id = %s
                  AND NULLIF(sj.raw_data->>'MilestoneId', '')::int = %s
                ORDER BY ea.status_date DESC
            """, [site_id, milestone_id])
            hist = cur.fetchall()
            return jsonify({'success': True, 'data': hist, 'total': len(hist)}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur historique jalon {milestone_id} site {site_id}: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@data_blueprint.route('/projets/<site_id>/porte/<gate>/historique', methods=['GET'])
def get_porte_historique(site_id, gate):
    """Historique d'une porte (Gate, ex. P3) au niveau projet, à travers tous les
    états d'avancement. Inclut le libellé référentiel (jalon_label) pour distinguer
    les milestones d'un même gate (P3 / P3 bis / P3 Ters).
    """
    try:
        with get_db_connection() as conn:
            cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cur.execute("""
                SELECT
                    ea.sharepoint_id AS etat_id,
                    ea.status_date,
                    NULLIF(sj.raw_data->>'MilestoneId', '')::int AS milestone_id,
                    jr.title AS jalon_label,
                    sj.raw_data->>'Mark'     AS mark,
                    sj.raw_data->>'Ranking'  AS ranking,
                    sj.raw_data->>'Actual'   AS actual,
                    sj.raw_data->>'Baseline' AS baseline,
                    sj.raw_data->>'Forecast' AS forecast
                FROM raw_data.sharepoint_statut_jalons sj
                JOIN raw_data.sharepoint_etats_avancement ea
                  ON ea.site_id = sj.site_id AND ea.title = sj.title
                LEFT JOIN raw_data.sharepoint_jalons_ref jr
                  ON jr.site_id = sj.site_id
                 AND jr.sharepoint_id = NULLIF(sj.raw_data->>'MilestoneId', '')::int
                WHERE sj.site_id = %s AND sj.raw_data->>'Gate' = %s
                ORDER BY ea.status_date DESC, jr.title
            """, [site_id, gate])
            hist = cur.fetchall()
            return jsonify({'success': True, 'data': hist, 'total': len(hist)}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur historique porte {gate} site {site_id}: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@data_blueprint.route('/projets/<site_id>/commissions-cfv', methods=['GET'])
def get_commissions_cfv(site_id):
    """Commissions Feu Vert du projet : dernier statut_cfv par phase
    (Conception / Mise en service / Achèvement industriel) — même source que la popup
    état d'avancement (raw_data.sharepoint_statut_cfv, le plus récent par 'modified').
    """
    try:
        with get_db_connection() as conn:
            cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cur.execute("""
                SELECT DISTINCT ON (c.title)
                    c.title                 AS phase,
                    c.raw_data->>'State'    AS state,
                    c.raw_data->>'Forecast' AS forecast,
                    c.raw_data->>'Baseline' AS baseline,
                    c.modified
                FROM raw_data.sharepoint_statut_cfv c
                WHERE c.site_id = %s
                  AND c.title IN ('Conception', 'Mise en service', 'Achèvement industriel')
                ORDER BY c.title, c.modified DESC NULLS LAST
            """, [site_id])
            rows = cur.fetchall()
            return jsonify({'success': True, 'data': rows}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur commissions CFV site {site_id}: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@data_blueprint.route('/ifs-model-project', methods=['GET'])
def get_ifs_model_project():
    """Structure du projet modèle IFS (clean_data.ifs_model_project), à plat.
    Le front reconstruit l'arbre sous-projets -> activités -> activity classes.
    """
    try:
        with get_db_connection() as conn:
            cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cur.execute("""
                SELECT id, project_id, project_name, node_type,
                       sub_project_id, sub_project_desc,
                       activity_no, activity_desc,
                       activity_class_id, activity_class_desc, value, validity, sort_order
                FROM clean_data.ifs_model_project
                ORDER BY sub_project_id, sort_order, activity_no
            """)
            rows = cur.fetchall()
            return jsonify({'success': True, 'data': rows, 'total': len(rows)}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur ifs_model_project: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@data_blueprint.route('/projets-a-reprendre', methods=['GET'])
def get_projets_a_reprendre():
    """Liste des projets à reprendre (export raw_data.sharepoint_project_to_save).

    Pagination + recherche + tri whitelisté + filtres statut/site.
    Renvoie toutes les colonnes (le détail dépliable du front en a besoin)
    + in_migration (le projet existe dans raw_data.sharepoint_projets)
    + un bloc stats pour les puces de résumé.

    NB : les identifiants contiennent '%' ("% Complété") — la requête passe par
    cursor.execute avec paramètres, donc les '%' des identifiants sont doublés.
    """
    try:
        page = request.args.get('page', 1, type=int)
        per_page = min(request.args.get('per_page', 50, type=int), 100)
        search = request.args.get('search', '', type=str)
        sort_by = request.args.get('sort_by', 'Numéro du projet', type=str)
        sort_order = request.args.get('sort_order', 'desc', type=str)
        statut = request.args.get('statut', '', type=str)
        site = request.args.get('site', '', type=str)

        allowed_sort = {
            'Numéro du projet', 'Nom du projet', 'Statut Global',
            'Site', 'Secteur', 'Chef de projet', '% Complété',
        }
        if sort_by not in allowed_sort:
            sort_by = 'Numéro du projet'
        sort_dir = 'ASC' if str(sort_order).lower() == 'asc' else 'DESC'
        # Identifiant quoté, '%' doublé pour cursor.execute avec paramètres
        sort_ident = '"' + sort_by.replace('%', '%%') + '"'

        where = 'WHERE 1=1'
        params = []
        if search:
            where += ''' AND ("Numéro du projet" ILIKE %s
                          OR "Nom du projet" ILIKE %s
                          OR "Chef de projet" ILIKE %s)'''
            like = f'%{search}%'
            params += [like, like, like]
        if statut:
            where += ' AND "Statut Global" = %s'
            params.append(statut)
        if site:
            where += ' AND "Site" = %s'
            params.append(site)

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute(
                f'SELECT COUNT(*) AS total FROM raw_data.sharepoint_project_to_save {where}',
                params)
            total = cursor.fetchone()['total']

            offset = (page - 1) * per_page
            cursor.execute(f'''
                SELECT t.*,
                       EXISTS (SELECT 1 FROM raw_data.sharepoint_projets sp
                               WHERE sp.project_number = t."Numéro du projet") AS in_migration,
                       -- sharepoint_id du projet importé -> lien vers /projets/detail/{id}
                       (SELECT sp.sharepoint_id FROM raw_data.sharepoint_projets sp
                        WHERE sp.project_number = t."Numéro du projet"
                        ORDER BY sp.sharepoint_id LIMIT 1) AS migration_sharepoint_id
                FROM raw_data.sharepoint_project_to_save t
                {where}
                ORDER BY {sort_ident} {sort_dir} NULLS LAST
                LIMIT %s OFFSET %s
            ''', params + [per_page, offset])
            rows = cursor.fetchall()

            # Stats globales (hors filtres) pour les puces de résumé
            cursor.execute('''
                SELECT
                    COUNT(*) AS total,
                    COUNT(*) FILTER (WHERE "Statut Global" = 'En cours') AS en_cours,
                    COUNT(*) FILTER (WHERE "Statut Global" = 'Clôturé')  AS clotures,
                    COUNT(*) FILTER (WHERE "Statut Global" = 'Pas démarré') AS pas_demarre,
                    COUNT(*) FILTER (WHERE EXISTS (
                        SELECT 1 FROM raw_data.sharepoint_projets sp
                        WHERE sp.project_number = t."Numéro du projet")) AS in_migration,
                    -- Critère ETL project_base (statut de la dernière synchronisation) :
                    -- présent dans sharepoint_projets ET non Clôturé/Annulé
                    COUNT(*) FILTER (WHERE EXISTS (
                        SELECT 1 FROM raw_data.sharepoint_projets sp
                        WHERE sp.project_number = t."Numéro du projet"
                          AND COALESCE(sp.global_status, '') NOT IN ('Clôturé', 'Annulé'))) AS a_reprendre_ifs
                FROM raw_data.sharepoint_project_to_save t
            ''')
            stats = cursor.fetchone()

            return jsonify({
                'success': True,
                'data': rows,
                'total': total,
                'page': page,
                'per_page': per_page,
                'stats': stats,
            }), 200

    except Exception as e:
        current_app.logger.error(f"Erreur projets à reprendre: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@data_blueprint.route('/projets-a-reprendre/refresh', methods=['POST'])
def refresh_projets_a_reprendre():
    """Recharge raw_data.sharepoint_project_to_save depuis la liste SharePoint
    (lists(guid'7a38eb49-...')/items) — voir SharePointService.import_projets_a_reprendre.
    """
    try:
        from services.sharepoint_service import SharePointService
        service = SharePointService()
        result = service.import_projets_a_reprendre()
        current_app.logger.info(f"✅ Projets à reprendre rechargés: {result}")
        return jsonify(result), 200
    except Exception as e:
        current_app.logger.error(f"❌ Erreur refresh projets à reprendre: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la mise à jour depuis SharePoint',
            'message': str(e)
        }), 500


@data_blueprint.route('/sharepoint-ressources', methods=['GET'])
# @jwt_required()
def get_sharepoint_ressources():
    """Récupère la liste des ressources SharePoint importées"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 50, type=int)
        search = request.args.get('search', '', type=str)
        
        # Limiter per_page
        per_page = min(per_page, 100)
        offset = (page - 1) * per_page
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Construire la clause WHERE si recherche
            where_clause = ""
            params = []
            if search:
                where_clause = """
                    WHERE CAST(sharepoint_item_id AS TEXT) ILIKE %s 
                       OR title ILIKE %s
                       OR CAST(resource_x0020_typeid AS TEXT) ILIKE %s 
                       OR windowsaccount_id ILIKE %s
                       OR securitygroup ILIKE %s
                """
                search_param = f'%{search}%'
                params = [search_param, search_param, search_param, search_param, search_param]
            
            # Compter le total
            count_query = f"SELECT COUNT(*) as total FROM raw_data.sharepoint_resources {where_clause}"
            cursor.execute(count_query, params)
            total = cursor.fetchone()['total']
            
            # Récupérer les ressources
            query = f"""
                SELECT 
                    id, sharepoint_item_id, 
                    resource_x0020_typeid as resource_type_id, 
                    generic, 
                    maxunit as max_unit,
                    windowsaccount_id as windows_account_id, 
                    securitygroup as security_group, 
                    modified, created, 
                    author_id, editor_id, 
                    contenttype_id as content_type_id, 
                    odata__uiversionstring as ui_version_string,
                    attachments, 
                    filesystemobjecttype as file_system_object_type, 
                    imported_at,
                    title,
                    etag,
                    guid
                FROM raw_data.sharepoint_resources
                {where_clause}
                ORDER BY imported_at DESC, sharepoint_item_id DESC
                LIMIT %s OFFSET %s
            """
            cursor.execute(query, params + [per_page, offset])
            ressources = cursor.fetchall()
            
            current_app.logger.info(f"✅ {len(ressources)} ressources récupérées (page {page}/{(total + per_page - 1) // per_page})")
            
            return jsonify({
                'success': True,
                'data': ressources,
                'total': total,
                'page': page,
                'per_page': per_page,
                'total_pages': (total + per_page - 1) // per_page
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"❌ Erreur récupération ressources SharePoint: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la récupération des ressources',
            'message': str(e)
        }), 500

@data_blueprint.route('/sharepoint-ressources/<int:resource_id>', methods=['GET'])
# @jwt_required()
def get_sharepoint_ressource_detail(resource_id):
    """Récupère les détails complets d'une ressource SharePoint"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Récupérer toutes les colonnes de la ressource
            query = """
                SELECT *
                FROM raw_data.sharepoint_resources
                WHERE sharepoint_item_id = %s
            """
            cursor.execute(query, (resource_id,))
            ressource = cursor.fetchone()
            
            if not ressource:
                return jsonify({
                    'success': False,
                    'error': 'Ressource non trouvée',
                    'message': f'Aucune ressource avec l\'ID {resource_id}'
                }), 404
            
            current_app.logger.info(f"✅ Détails ressource {resource_id} récupérés")
            
            return jsonify({
                'success': True,
                'data': ressource
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"❌ Erreur récupération détails ressource {resource_id}: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la récupération de la ressource',
            'message': str(e)
        }), 500

@data_blueprint.route('/sharepoint-users', methods=['GET'])
# @jwt_required()
def get_sharepoint_users():
    """Récupère la liste des utilisateurs SharePoint importés"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 50, type=int)
        search = request.args.get('search', '', type=str)
        sort_by = request.args.get('sort_by', 'title', type=str)
        sort_order = request.args.get('sort_order', 'asc', type=str)

        # Whitelist des colonnes triables (anti-injection)
        allowed_sort = {'sharepoint_user_id', 'title', 'login_name', 'email', 'person_id'}
        if sort_by not in allowed_sort:
            sort_by = 'title'
        sort_dir = 'DESC' if str(sort_order).lower() == 'desc' else 'ASC'

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            # Construire la requête de base
            base_query = """
                FROM raw_data.sharepoint_users
                WHERE 1=1
            """
            params = []
            
            # Filtre de recherche
            if search:
                base_query += """
                    AND (
                        LOWER(title) LIKE LOWER(%s)
                        OR LOWER(login_name) LIKE LOWER(%s)
                        OR LOWER(email) LIKE LOWER(%s)
                    )
                """
                search_pattern = f'%{search}%'
                params.extend([search_pattern, search_pattern, search_pattern])
            
            # Compter le total
            count_query = f"SELECT COUNT(*) as total {base_query}"
            cursor.execute(count_query, params)
            total = cursor.fetchone()['total']
            
            # Récupérer les données paginées
            offset = (page - 1) * per_page
            data_query = f"""
                SELECT
                    id,
                    sharepoint_user_id,
                    login_name,
                    title,
                    email,
                    person_id,
                    principal_type,
                    is_site_admin,
                    is_hidden_in_ui,
                    name_id,
                    name_id_issuer,
                    imported_at
                {base_query}
                ORDER BY {sort_by} {sort_dir} NULLS LAST
                LIMIT %s OFFSET %s
            """
            params.extend([per_page, offset])
            cursor.execute(data_query, params)
            users = cursor.fetchall()
            
            current_app.logger.info(f"✅ {len(users)} utilisateurs récupérés (page {page})")
            
            return jsonify({
                'success': True,
                'data': users,
                'total': total,
                'page': page,
                'per_page': per_page
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"❌ Erreur récupération utilisateurs: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la récupération des utilisateurs',
            'message': str(e)
        }), 500

@data_blueprint.route('/sharepoint-users/<int:user_id>', methods=['GET'])
# @jwt_required()
def get_sharepoint_user_detail(user_id):
    """Récupère les détails complets d'un utilisateur SharePoint"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            query = """
                SELECT *
                FROM raw_data.sharepoint_users
                WHERE sharepoint_user_id = %s
            """
            cursor.execute(query, (user_id,))
            user = cursor.fetchone()
            
            if not user:
                return jsonify({
                    'success': False,
                    'error': 'Utilisateur non trouvé',
                    'message': f'Aucun utilisateur avec l\'ID {user_id}'
                }), 404
            
            current_app.logger.info(f"✅ Détails utilisateur {user_id} récupérés")
            
            return jsonify({
                'success': True,
                'data': user
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"❌ Erreur récupération détails utilisateur {user_id}: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la récupération de l\'utilisateur',
            'message': str(e)
        }), 500


@data_blueprint.route('/sharepoint-users/<int:user_id>', methods=['PUT'])
# @jwt_required()
def update_sharepoint_user(user_id):
    """Met à jour l'association IFS Person (person_id) d'un utilisateur SharePoint.

    Body attendu : { "person_id": "PRENOM.NOM" }  ou  { "person_id": null } pour dissocier.
    Valide que le person_id existe dans clean_data.ifs_person avant l'écriture.
    """
    try:
        payload = request.get_json(silent=True) or {}
        if 'person_id' not in payload:
            return jsonify({
                'success': False,
                'message': 'Champ "person_id" requis (peut être null pour dissocier)'
            }), 400

        person_id = payload['person_id']
        if person_id is not None:
            person_id = str(person_id).strip()
            if person_id == '':
                person_id = None

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            # Validation : le person_id doit exister dans clean_data.ifs_person
            if person_id is not None:
                cursor.execute(
                    "SELECT 1 FROM clean_data.ifs_person WHERE UPPER(TRIM(person_id)) = UPPER(%s) LIMIT 1",
                    (person_id,)
                )
                if cursor.fetchone() is None:
                    return jsonify({
                        'success': False,
                        'message': f'Person ID "{person_id}" introuvable dans clean_data.ifs_person'
                    }), 400

            cursor.execute(
                """
                UPDATE raw_data.sharepoint_users
                SET person_id = %s
                WHERE sharepoint_user_id = %s
                RETURNING id, sharepoint_user_id, login_name, title, email, person_id
                """,
                (person_id, user_id)
            )
            updated = cursor.fetchone()

            if not updated:
                return jsonify({
                    'success': False,
                    'message': f'Aucun utilisateur avec l\'ID SharePoint {user_id}'
                }), 404

            conn.commit()
            current_app.logger.info(f"✅ IFS Person de l'utilisateur {user_id} → {person_id}")

            return jsonify({
                'success': True,
                'data': updated
            }), 200

    except Exception as e:
        current_app.logger.error(f"❌ Erreur mise à jour IFS Person utilisateur {user_id}: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la mise à jour de l\'utilisateur',
            'message': str(e)
        }), 500


@data_blueprint.route('/sharepoint-users/associate-ifs-persons', methods=['POST'])
# @jwt_required()
def associate_sharepoint_users_ifs_persons():
    """Lance le backfill des associations IFS Person par correspondance de nom.

    Exécute clean_data.associer_sharepoint_users_ifs_person() qui remplit
    person_id (uniquement les lignes NULL, correspondances uniques) et
    renvoie le nombre de nouvelles associations créées.
    """
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT clean_data.associer_sharepoint_users_ifs_person()")
            nb_associes = cursor.fetchone()[0]
            conn.commit()

            current_app.logger.info(f"✅ Association IFS Person : {nb_associes} nouvelles associations")

            return jsonify({
                'success': True,
                'associated_count': nb_associes,
                'message': f'{nb_associes} nouvelle(s) association(s) IFS Person'
            }), 200

    except Exception as e:
        current_app.logger.error(f"❌ Erreur association IFS Person: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de l\'association des IFS Person',
            'message': str(e)
        }), 500