from flask import Blueprint, request, jsonify, make_response, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
import logging
from datetime import datetime
from services.export_service import ExportService
from api.auth_decorators import admin_required
from sqlalchemy import text
from services.data_service import get_data_service
from sqlalchemy.exc import SQLAlchemyError
from werkzeug.exceptions import BadRequest
import json
from utils.auth_decorators import require_permission
import time

logger = logging.getLogger(__name__)

export_bp = Blueprint('export', __name__)

@export_bp.route('/suppliers', methods=['POST'])
@jwt_required()
def export_suppliers():
    """
    Exporte les données des fournisseurs
    
    Body JSON:
    {
        "selectedTables": ["SUPPLIER_INFO_GENERAL", "SUPPLIER_INFO_ADDRESS", ...],
        "format": "csv" | "excel",
        "includeHeaders": true | false,
        "includeInactive": true | false,
        "csvSeparator": ";" | "," | "\t"
    }
    """
    try:
        # Récupérer l'utilisateur actuel
        current_user = get_jwt_identity()
        logger.info(f"🔐 Export demandé par l'utilisateur: {current_user}")
        
        # Récupérer la configuration depuis le body
        config = request.get_json()
        
        if not config:
            return jsonify({
                'error': 'Configuration d\'export requise'
            }), 400
        
        # Valider la configuration
        selected_tables = config.get('selectedTables', [])
        if not selected_tables:
            return jsonify({
                'error': 'Au moins une table doit être sélectionnée'
            }), 400
        
        # Configuration par défaut
        export_config = {
            'selectedTables': selected_tables,
            'format': config.get('format', 'csv'),
            'includeHeaders': config.get('includeHeaders', True),
            'includeInactive': config.get('includeInactive', False),
            'csvSeparator': config.get('csvSeparator', ';')  # Nouveau paramètre configurable
        }
        
        logger.info(f"📋 Configuration d'export: {export_config}")
        logger.error(f"🚨 DEBUG SEPARATOR - csvSeparator reçu: '{config.get('csvSeparator', 'NON_DEFINI')}'")
        
        # Créer le service d'export
        export_service = ExportService()
        
        # Générer le fichier d'export
        content, mime_type, metadata = export_service.generate_export_file(export_config)
        
        # Créer le nom de fichier ZIP basé sur la catégorie et l'horodatage
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        primary_category = metadata.get('primary_category', 'export')
        filename = f"{primary_category}_export_{timestamp}.zip"
        
        # Créer la réponse
        response = make_response(content)
        response.headers['Content-Type'] = mime_type
        response.headers['Content-Disposition'] = f'attachment; filename="{filename}"'
        
        # Convertir les métadonnées en JSON pour les headers
        import json
        response.headers['X-Export-Summary'] = json.dumps(metadata['summary'])
        response.headers['X-Export-Category'] = str(primary_category)
        response.headers['X-Export-Tables-Count'] = str(len(export_config['selectedTables']))
        response.headers['X-Export-Size-Bytes'] = str(metadata.get('zip_size_bytes', 0))
        response.headers['X-Export-Errors'] = json.dumps(metadata.get('errors', {}))
        
        # Headers CORS pour que le frontend puisse lire les headers personnalisés
        response.headers['Access-Control-Expose-Headers'] = 'X-Export-Summary,X-Export-Category,X-Export-Tables-Count,X-Export-Size-Bytes,X-Export-Errors'
        
        logger.info(f"✅ Export terminé: {filename}")
        logger.info(f"📊 Résumé: {metadata['summary']}")
        
        if metadata['errors']:
            logger.warning(f"⚠️ Erreurs: {metadata['errors']}")
        
        return response
        
    except Exception as e:
        logger.error(f"❌ Erreur lors de l'export: {str(e)}")
        return jsonify({
            'error': f'Erreur lors de l\'export: {str(e)}'
        }), 500

@export_bp.route('/suppliers/preview', methods=['POST'])
@jwt_required()
def preview_suppliers_export():
    """
    Prévisualise l'export des fournisseurs sans générer le fichier
    
    Retourne un résumé de ce qui sera exporté
    """
    try:
        current_user = get_jwt_identity()
        logger.info(f"🔍 Prévisualisation demandée par: {current_user}")
        
        config = request.get_json()
        
        if not config:
            return jsonify({
                'error': 'Configuration requise'
            }), 400
        
        selected_tables = config.get('selectedTables', [])
        if not selected_tables:
            return jsonify({
                'error': 'Au moins une table doit être sélectionnée'
            }), 400
        
        export_config = {
            'selectedTables': selected_tables,
            'includeInactive': config.get('includeInactive', False)
        }
        
        # Créer le service d'export
        export_service = ExportService()
        
        # Exporter les données pour obtenir le résumé
        export_result = export_service.export_supplier_data(export_config)
        
        # Préparer la réponse
        preview = {
            'summary': export_result['summary'],
            'errors': export_result['errors'],
            'tables_details': {}
        }
        
        # Ajouter les détails de chaque table
        for table_name in selected_tables:
            if table_name in export_result['results']:
                data = export_result['results'][table_name]
                preview['tables_details'][table_name] = {
                    'row_count': len(data),
                    'columns': list(data[0].keys()) if data else [],
                    'sample_data': data[:3] if len(data) > 0 else []  # 3 premières lignes
                }
            elif table_name in export_result['errors']:
                preview['tables_details'][table_name] = {
                    'error': export_result['errors'][table_name],
                    'row_count': 0,
                    'columns': [],
                    'sample_data': []
                }
        
        logger.info(f"✅ Prévisualisation terminée: {preview['summary']}")
        
        return jsonify(preview)
        
    except Exception as e:
        logger.error(f"❌ Erreur lors de la prévisualisation: {str(e)}")
        return jsonify({
            'error': f'Erreur lors de la prévisualisation: {str(e)}'
        }), 500

@export_bp.route('/suppliers/tables', methods=['GET'])
@jwt_required()
def get_available_tables():
    """
    Retourne la liste des tables disponibles pour l'export des fournisseurs
    """
    try:
        export_service = ExportService()
        
        # ✅ CORRECTION : Utiliser le nouveau système avec table_categories
        available_tables = list(export_service.table_categories.keys())
        
        # Ajouter des métadonnées sur chaque table
        tables_info = {}
        for table_name in available_tables:
            # Utiliser les nouvelles métadonnées
            table_info = export_service.get_table_info(table_name)
            tables_info[table_name] = {
                'name': table_name,
                'display_name': table_info.get('display_name', table_name),
                'category': table_info.get('category', 'unknown'),
                'schema': table_info.get('schema', 'public'),
                'column_count': table_info.get('column_count', 0),
                'description': f"Table des {table_name.lower().replace('_', ' ')}"
            }
        
        return jsonify({
            'tables': available_tables,
            'tables_info': tables_info,
            'total_tables': len(available_tables)
        })
        
    except Exception as e:
        logger.error(f"❌ Erreur lors de la récupération des tables: {str(e)}")
        return jsonify({
            'error': f'Erreur lors de la récupération des tables: {str(e)}'
        }), 500

@export_bp.route('/articles', methods=['POST'])
@jwt_required()
def export_articles():
    """
    Exporte les données des articles
    
    Body JSON:
    {
        "selectedTables": ["ARTICLE", "ARTICLE_INFO", "INVENTORY_PART", ...],
        "format": "csv" | "excel",
        "includeHeaders": true | false,
        "includeInactive": true | false
    }
    """
    try:
        # Récupérer l'utilisateur actuel
        current_user = get_jwt_identity()
        logger.info(f"🔐 Export articles demandé par l'utilisateur: {current_user}")
        
        # Récupérer la configuration depuis le body
        config = request.get_json()
        
        if not config:
            return jsonify({
                'error': 'Configuration d\'export requise'
            }), 400
        
        # Valider la configuration
        selected_tables = config.get('selectedTables', [])
        if not selected_tables:
            return jsonify({
                'error': 'Au moins une table doit être sélectionnée'
            }), 400
        
        # Configuration par défaut
        export_config = {
            'selectedTables': selected_tables,
            'format': config.get('format', 'csv'),
            'includeHeaders': config.get('includeHeaders', True),
            'includeInactive': config.get('includeInactive', False),
            'csvSeparator': config.get('csvSeparator', ';')  # Nouveau paramètre configurable
        }
        
        logger.info(f"📋 Configuration d'export articles: {export_config}")
        
        # Créer le service d'export
        export_service = ExportService()
        
        # Générer le fichier d'export
        content, mime_type, metadata = export_service.generate_export_file(export_config)
        
        # Créer le nom de fichier ZIP basé sur la catégorie et l'horodatage
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        primary_category = metadata.get('primary_category', 'articles')
        filename = f"{primary_category}_export_{timestamp}.zip"
        
        # Créer la réponse
        response = make_response(content)
        response.headers['Content-Type'] = mime_type
        response.headers['Content-Disposition'] = f'attachment; filename="{filename}"'
        
        # Convertir les métadonnées en JSON pour les headers
        import json
        response.headers['X-Export-Summary'] = json.dumps(metadata['summary'])
        response.headers['X-Export-Category'] = str(primary_category)
        response.headers['X-Export-Tables-Count'] = str(len(export_config['selectedTables']))
        response.headers['X-Export-Size-Bytes'] = str(metadata.get('zip_size_bytes', 0))
        response.headers['X-Export-Errors'] = json.dumps(metadata.get('errors', {}))
        
        # Headers CORS pour que le frontend puisse lire les headers personnalisés
        response.headers['Access-Control-Expose-Headers'] = 'X-Export-Summary,X-Export-Category,X-Export-Tables-Count,X-Export-Size-Bytes,X-Export-Errors'
        
        logger.info(f"✅ Export articles terminé: {filename}")
        logger.info(f"📊 Résumé: {metadata['summary']}")
        
        if metadata['errors']:
            logger.warning(f"⚠️ Erreurs: {metadata['errors']}")
        
        return response
        
    except Exception as e:
        logger.error(f"❌ Erreur lors de l'export articles: {str(e)}")
        return jsonify({
            'error': f'Erreur lors de l\'export articles: {str(e)}'
        }), 500

@export_bp.route('/clients', methods=['POST'])
@jwt_required()
def export_clients():
    """
    Exporte les données des clients
    
    Body JSON:
    {
        "selectedTables": ["CLIENT_TABLE1", "CLIENT_TABLE2", ...],
        "format": "csv" | "excel",
        "includeHeaders": true | false,
        "includeInactive": true | false
    }
    """
    try:
        # Récupérer l'utilisateur actuel
        current_user = get_jwt_identity()
        logger.info(f"🔐 Export clients demandé par l'utilisateur: {current_user}")
        
        # Récupérer la configuration depuis le body
        config = request.get_json()
        
        if not config:
            return jsonify({
                'error': 'Configuration d\'export requise'
            }), 400
        
        # Valider la présence des tables sélectionnées
        selected_tables = config.get('selectedTables', [])
        if not selected_tables:
            return jsonify({
                'error': 'Aucune table sélectionnée pour l\'export'
            }), 400
        
        # Configuration par défaut
        export_config = {
            'selectedTables': selected_tables,
            'format': config.get('format', 'csv'),
            'includeHeaders': config.get('includeHeaders', True),
            'includeInactive': config.get('includeInactive', False),
            'csvSeparator': config.get('csvSeparator', ';')  # Nouveau paramètre configurable
        }
        
        logger.info(f"📋 Configuration d'export clients: {export_config}")
        
        # Créer le service d'export
        export_service = ExportService()
        
        # Générer le fichier d'export
        content, mime_type, metadata = export_service.generate_export_file(export_config)
        
        # Créer le nom de fichier ZIP basé sur la catégorie et l'horodatage
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        primary_category = metadata.get('primary_category', 'clients')
        filename = f"{primary_category}_export_{timestamp}.zip"
        
        # Créer la réponse
        response = make_response(content)
        response.headers['Content-Type'] = mime_type
        response.headers['Content-Disposition'] = f'attachment; filename="{filename}"'
        
        # Convertir les métadonnées en JSON pour les headers
        import json
        response.headers['X-Export-Summary'] = json.dumps(metadata['summary'])
        response.headers['X-Export-Category'] = str(primary_category)
        response.headers['X-Export-Tables-Count'] = str(len(export_config['selectedTables']))
        response.headers['X-Export-Size-Bytes'] = str(metadata.get('zip_size_bytes', 0))
        response.headers['X-Export-Errors'] = json.dumps(metadata.get('errors', {}))
        
        # Headers CORS pour que le frontend puisse lire les headers personnalisés
        response.headers['Access-Control-Expose-Headers'] = 'X-Export-Summary,X-Export-Category,X-Export-Tables-Count,X-Export-Size-Bytes,X-Export-Errors'
        
        logger.info(f"✅ Export clients terminé: {filename}")
        logger.info(f"📊 Résumé: {metadata['summary']}")
        
        if metadata['errors']:
            logger.warning(f"⚠️ Erreurs: {metadata['errors']}")
        
        return response
        
    except Exception as e:
        logger.error(f"❌ Erreur lors de l'export clients: {str(e)}")
        return jsonify({
            'error': f'Erreur lors de l\'export clients: {str(e)}'
        }), 500

@export_bp.route('/maintenance', methods=['POST'])
@jwt_required()
def export_maintenance():
    """
    Exporte les données de maintenance
    
    Body JSON:
    {
        "selectedTables": ["MAINTENANCE_TABLE1", "MAINTENANCE_TABLE2", ...],
        "format": "csv" | "excel",
        "includeHeaders": true | false,
        "includeInactive": true | false
    }
    """
    try:
        # Récupérer l'utilisateur actuel
        current_user = get_jwt_identity()
        logger.info(f"🔐 Export maintenance demandé par l'utilisateur: {current_user}")
        
        # Récupérer la configuration depuis le body
        config = request.get_json()
        
        if not config:
            return jsonify({
                'error': 'Configuration d\'export requise'
            }), 400
        
        # Valider la présence des tables sélectionnées
        selected_tables = config.get('selectedTables', [])
        if not selected_tables:
            return jsonify({
                'error': 'Aucune table sélectionnée pour l\'export'
            }), 400
        
        # Configuration par défaut
        export_config = {
            'selectedTables': selected_tables,
            'format': config.get('format', 'csv'),
            'includeHeaders': config.get('includeHeaders', True),
            'includeInactive': config.get('includeInactive', False),
            'csvSeparator': config.get('csvSeparator', ';')  # Nouveau paramètre configurable
        }
        
        logger.info(f"📋 Configuration d'export maintenance: {export_config}")
        
        # Créer le service d'export
        export_service = ExportService()
        
        # Générer le fichier d'export
        content, mime_type, metadata = export_service.generate_export_file(export_config)
        
        # Créer le nom de fichier ZIP basé sur la catégorie et l'horodatage
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        primary_category = metadata.get('primary_category', 'maintenance')
        filename = f"{primary_category}_export_{timestamp}.zip"
        
        # Créer la réponse
        response = make_response(content)
        response.headers['Content-Type'] = mime_type
        response.headers['Content-Disposition'] = f'attachment; filename="{filename}"'
        
        # Convertir les métadonnées en JSON pour les headers
        import json
        response.headers['X-Export-Summary'] = json.dumps(metadata['summary'])
        response.headers['X-Export-Category'] = str(primary_category)
        response.headers['X-Export-Tables-Count'] = str(len(export_config['selectedTables']))
        response.headers['X-Export-Size-Bytes'] = str(metadata.get('zip_size_bytes', 0))
        response.headers['X-Export-Errors'] = json.dumps(metadata.get('errors', {}))
        
        # Headers CORS pour que le frontend puisse lire les headers personnalisés
        response.headers['Access-Control-Expose-Headers'] = 'X-Export-Summary,X-Export-Category,X-Export-Tables-Count,X-Export-Size-Bytes,X-Export-Errors'
        
        logger.info(f"✅ Export maintenance terminé: {filename}")
        logger.info(f"📊 Résumé: {metadata['summary']}")
        
        if metadata['errors']:
            logger.warning(f"⚠️ Erreurs: {metadata['errors']}")
        
        return response
        
    except Exception as e:
        logger.error(f"❌ Erreur lors de l'export maintenance: {str(e)}")
        return jsonify({
            'error': f'Erreur lors de l\'export maintenance: {str(e)}'
        }), 500

@export_bp.route('/projects', methods=['POST'])
@jwt_required()
def export_projects():
    """
    Exporte les données des projets
    
    Body JSON:
    {
        "selectedTables": ["PROJECT_BASE", "PROJECT_SITE_EXT", "PROJECT_MARGIN_MATRIX", ...],
        "format": "csv" | "excel",
        "includeHeaders": true | false,
        "includeInactive": true | false
    }
    """
    try:
        # Récupérer l'utilisateur actuel
        current_user = get_jwt_identity()
        logger.info(f"🔐 Export projets demandé par l'utilisateur: {current_user}")
        
        # Récupérer la configuration depuis le body
        config = request.get_json()
        
        if not config:
            return jsonify({
                'error': 'Configuration d\'export requise'
            }), 400
        
        # Valider la présence des tables sélectionnées
        selected_tables = config.get('selectedTables', [])
        if not selected_tables:
            return jsonify({
                'error': 'Aucune table sélectionnée pour l\'export'
            }), 400
        
        # Configuration par défaut
        export_config = {
            'selectedTables': selected_tables,
            'format': config.get('format', 'csv'),
            'includeHeaders': config.get('includeHeaders', True),
            'includeInactive': config.get('includeInactive', False),
            'csvSeparator': config.get('csvSeparator', ';')  # Nouveau paramètre configurable
        }
        
        logger.info(f"📋 Configuration d'export projets: {export_config}")
        
        # Créer le service d'export
        export_service = ExportService()
        
        # Générer le fichier d'export
        content, mime_type, metadata = export_service.generate_export_file(export_config)
        
        # Créer le nom de fichier ZIP basé sur la catégorie et l'horodatage
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"project_export_{timestamp}.zip"
        
        # Créer la réponse
        response = make_response(content)
        response.headers['Content-Type'] = mime_type
        response.headers['Content-Disposition'] = f'attachment; filename="{filename}"'
        
        # Convertir les métadonnées en JSON pour les headers
        import json
        response.headers['X-Export-Summary'] = json.dumps(metadata['summary'])
        response.headers['X-Export-Category'] = 'project'
        response.headers['X-Export-Tables-Count'] = str(len(export_config['selectedTables']))
        response.headers['X-Export-Size-Bytes'] = str(metadata.get('zip_size_bytes', 0))
        response.headers['X-Export-Errors'] = json.dumps(metadata.get('errors', {}))
        
        # Headers CORS pour que le frontend puisse lire les headers personnalisés
        response.headers['Access-Control-Expose-Headers'] = 'X-Export-Summary,X-Export-Category,X-Export-Tables-Count,X-Export-Size-Bytes,X-Export-Errors'
        
        logger.info(f"✅ Export projets terminé: {filename}")
        logger.info(f"📊 Résumé: {metadata['summary']}")
        
        if metadata['errors']:
            logger.warning(f"⚠️ Erreurs: {metadata['errors']}")
        
        return response
        
    except Exception as e:
        logger.error(f"❌ Erreur lors de l'export projets: {str(e)}")
        return jsonify({
            'error': f'Erreur lors de l\'export projets: {str(e)}'
        }), 500

@export_bp.route('/queries', methods=['GET'])
@jwt_required()
def get_export_queries():
    """Récupère la liste des requêtes d'export disponibles"""
    try:
        # Paramètres de filtrage
        category = request.args.get('category')
        is_active = request.args.get('is_active', 'true').lower() == 'true'
        
        data_service = get_data_service()
        
        with data_service.engine.connect() as connection:
            # Construction de la requête avec filtres - CORRECTION: sql_query supprimé
            query = """
                SELECT 
                    id, table_name, table_schema, display_name, column_list, description, category, 
                    is_active, created_at, updated_at, created_by, updated_by
                FROM etl_export_queries 
                WHERE is_active = :is_active
            """
            params = {'is_active': is_active}
            
            if category:
                query += " AND category = :category"
                params['category'] = category
                
            query += " ORDER BY category, display_name"
            
            result = connection.execute(text(query), params)
            
            queries = []
            for row in result:
                queries.append({
                    'id': row.id,
                    'table_name': row.table_name,
                    'table_schema': row.table_schema,
                    'display_name': row.display_name,
                    'column_list': row.column_list,
                    'sql_query': None,  # ✅ CORRECTION: Plus dans la DB, mais maintenu pour compatibilité frontend
                    'description': row.description,
                    'category': row.category,
                    'is_active': row.is_active,
                    'created_at': row.created_at.isoformat() if row.created_at else None,
                    'updated_at': row.updated_at.isoformat() if row.updated_at else None,
                    'created_by': row.created_by,
                    'updated_by': row.updated_by
                })
            
            # Grouper par catégorie pour faciliter l'utilisation frontend
            grouped_queries = {}
            for query in queries:
                cat = query['category']
                if cat not in grouped_queries:
                    grouped_queries[cat] = []
                grouped_queries[cat].append(query)
            
            return jsonify({
                'queries': queries,
                'grouped_queries': grouped_queries,
                'total': len(queries)
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des requêtes d'export: {str(e)}")
        return jsonify({"error": "Erreur lors de la récupération des requêtes d'export"}), 500

@export_bp.route('/queries/<table_name>', methods=['GET'])
@jwt_required()
def get_export_query(table_name):
    """Récupère une requête d'export spécifique avec son SQL"""
    try:
        # ✅ NOUVEAU: Gérer les doublons en retournant toutes les entrées
        category = request.args.get('category')
        
        data_service = get_data_service()
        
        with data_service.engine.connect() as connection:
            if category:
                # Si une catégorie est spécifiée, récupérer seulement cette entrée
                query = """
                    SELECT 
                        id, table_name, table_schema, display_name, column_list, description, 
                        category, is_active, created_at, updated_at, created_by, updated_by
                    FROM etl_export_queries 
                    WHERE table_name = :table_name AND category = :category
                """
                
                result = connection.execute(text(query), {'table_name': table_name, 'category': category})
                row = result.fetchone()
                
                if not row:
                    return jsonify({"error": f"Requête pour la table '{table_name}' dans la catégorie '{category}' non trouvée"}), 404
                
                query_data = {
                    'id': row.id,
                    'table_name': row.table_name,
                    'table_schema': row.table_schema,
                    'display_name': row.display_name,
                    'column_list': row.column_list,
                    'sql_query': None,  # ✅ CORRECTION: Plus dans la DB, mais maintenu pour compatibilité frontend
                    'description': row.description,
                    'category': row.category,
                    'is_active': row.is_active,
                    'created_at': row.created_at.isoformat() if row.created_at else None,
                    'updated_at': row.updated_at.isoformat() if row.updated_at else None,
                    'created_by': row.created_by,
                    'updated_by': row.updated_by
                }
                
                return jsonify(query_data), 200
            else:
                # Si pas de catégorie, retourner toutes les entrées pour ce table_name
                query = """
                    SELECT 
                        id, table_name, table_schema, display_name, column_list, description, 
                        category, is_active, created_at, updated_at, created_by, updated_by
                    FROM etl_export_queries 
                    WHERE table_name = :table_name
                    ORDER BY category
                """
                
                result = connection.execute(text(query), {'table_name': table_name})
                rows = result.fetchall()
                
                if not rows:
                    return jsonify({"error": f"Aucune requête trouvée pour la table '{table_name}'"}), 404
                
                queries = []
                for row in rows:
                    query_data = {
                        'id': row.id,
                        'table_name': row.table_name,
                        'table_schema': row.table_schema,
                        'display_name': row.display_name,
                        'column_list': row.column_list,
                        'sql_query': None,  # ✅ CORRECTION: Plus dans la DB, mais maintenu pour compatibilité frontend
                        'description': row.description,
                        'category': row.category,
                        'is_active': row.is_active,
                        'created_at': row.created_at.isoformat() if row.created_at else None,
                        'updated_at': row.updated_at.isoformat() if row.updated_at else None,
                        'created_by': row.created_by,
                        'updated_by': row.updated_by
                    }
                    queries.append(query_data)
                
                # Si une seule entrée, retourner l'objet directement (compatibilité)
                # Si plusieurs, retourner un tableau
                if len(queries) == 1:
                    return jsonify(queries[0]), 200
                else:
                    return jsonify({
                        'table_name': table_name,
                        'multiple_entries': True,
                        'queries': queries,
                        'count': len(queries)
                    }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération de la requête {table_name}: {str(e)}")
        return jsonify({"error": "Erreur lors de la récupération de la requête"}), 500

@export_bp.route('/queries', methods=['POST'])
@admin_required
def create_export_query():
    """Crée une nouvelle requête d'export (Admin seulement)"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "Données manquantes"}), 400
        
        # Validation des champs requis - CORRECTION: column_list au lieu de sql_query
        required_fields = ['table_name', 'table_schema', 'display_name', 'column_list']
        for field in required_fields:
            if not data.get(field):
                return jsonify({"error": f"Le champ '{field}' est requis"}), 400
        
        # Validation de la liste de colonnes
        column_list = data['column_list'].strip()
        if not column_list:
            return jsonify({"error": "La liste de colonnes ne peut pas être vide"}), 400
        
        data_service = get_data_service()
        # user_id = get_jwt_identity()  # Désactivé temporairement
        user_id = "admin"  # Placeholder
        
        with data_service.engine.connect() as connection:
            # Vérifier que le nom de table n'existe pas déjà dans le même schéma
            check_query = "SELECT id FROM etl_export_queries WHERE table_name = :table_name AND table_schema = :table_schema"
            existing = connection.execute(text(check_query), {
                'table_name': data['table_name'], 
                'table_schema': data['table_schema']
            })
            if existing.fetchone():
                return jsonify({"error": f"Une requête pour la table '{data['table_name']}' dans le schéma '{data['table_schema']}' existe déjà"}), 409
            
            # Insertion de la nouvelle requête - CORRECTION: column_list au lieu de sql_query
            insert_query = """
                INSERT INTO etl_export_queries 
                (table_name, table_schema, display_name, column_list, description, category, created_by, updated_by)
                VALUES (:table_name, :table_schema, :display_name, :column_list, :description, :category, :user_id, :user_id)
                RETURNING id, created_at
            """
            
            result = connection.execute(text(insert_query), {
                'table_name': data['table_name'],
                'table_schema': data['table_schema'],
                'display_name': data['display_name'],
                'column_list': column_list,
                'description': data.get('description', ''),
                'category': data.get('category', 'supplier'),
                'user_id': user_id
            })
            
            row = result.fetchone()
            connection.commit()
            
            return jsonify({
                'id': row.id,
                'table_name': data['table_name'],
                'message': 'Requête d\'export créée avec succès'
            }), 201
            
    except SQLAlchemyError as e:
        current_app.logger.error(f"Erreur SQL lors de la création de la requête: {str(e)}")
        return jsonify({"error": "Erreur lors de la création de la requête"}), 500
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la création de la requête: {str(e)}")
        return jsonify({"error": "Erreur lors de la création de la requête"}), 500

@export_bp.route('/queries/<table_name>', methods=['PUT'])
@admin_required
def update_export_query(table_name):
    """Met à jour une requête d'export existante (Admin seulement)"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "Données manquantes"}), 400
        
        # ✅ DEBUG: Log des données reçues
        current_app.logger.info(f"🔍 DEBUG - Données reçues pour {table_name}: {data}")
        
        # ✅ CORRECTION: Utiliser la catégorie pour distinguer les doublons
        category = data.get('category')
        if not category:
            current_app.logger.error(f"❌ DEBUG - Champ category manquant pour {table_name}")
            return jsonify({"error": "Le champ 'category' est requis pour identifier la requête"}), 400
        
        data_service = get_data_service()
        # user_id = get_jwt_identity()  # Désactivé temporairement
        user_id = "admin"  # Placeholder
        
        with data_service.engine.begin() as connection:  # ✅ CORRECTION: Utiliser begin() pour une transaction explicite
            # ✅ CORRECTION: Vérifier avec table_name ET category
            current_app.logger.info(f"🔍 DEBUG - Recherche de {table_name} avec category {category}")
            check_query = "SELECT id FROM etl_export_queries WHERE table_name = :table_name AND category = :category"
            existing = connection.execute(text(check_query), {'table_name': table_name, 'category': category})
            record = existing.fetchone()
            
            if not record:
                current_app.logger.error(f"❌ DEBUG - Aucun enregistrement trouvé pour {table_name} / {category}")
                return jsonify({"error": f"Requête pour la table '{table_name}' dans la catégorie '{category}' non trouvée"}), 404
            
            current_app.logger.info(f"✅ DEBUG - Enregistrement trouvé, ID: {record.id}")
            
            # Construction de la requête de mise à jour dynamique
            update_fields = []
            params = {'table_name': table_name, 'category': category, 'user_id': user_id}
            
            if 'display_name' in data:
                update_fields.append("display_name = :display_name")
                params['display_name'] = data['display_name']
            
            if 'column_list' in data:
                column_list = data['column_list'].strip()
                if not column_list:
                    return jsonify({"error": "La liste de colonnes ne peut pas être vide"}), 400
                update_fields.append("column_list = :column_list")
                params['column_list'] = column_list
            
            if 'description' in data:
                update_fields.append("description = :description")
                params['description'] = data['description']
            
            if 'table_schema' in data:
                update_fields.append("table_schema = :table_schema")
                params['table_schema'] = data['table_schema']
            
            if 'is_active' in data:
                update_fields.append("is_active = :is_active")
                params['is_active'] = data['is_active']
            
            if not update_fields:
                return jsonify({"error": "Aucun champ à mettre à jour"}), 400
            
            # Toujours mettre à jour updated_by et updated_at
            update_fields.append("updated_by = :user_id")
            
            # ✅ CORRECTION: Utiliser table_name ET category dans le WHERE
            update_query = f"""
                UPDATE etl_export_queries 
                SET {', '.join(update_fields)}
                WHERE table_name = :table_name AND category = :category
            """
            
            current_app.logger.info(f"🔍 DEBUG - Requête SQL: {update_query}")
            current_app.logger.info(f"🔍 DEBUG - Paramètres: {params}")
            
            result = connection.execute(text(update_query), params)
            current_app.logger.info(f"✅ DEBUG - Requête exécutée, lignes affectées: {result.rowcount}")
            
            # La transaction sera automatiquement commitée à la fin du with block
            current_app.logger.info("✅ DEBUG - Transaction va être commitée automatiquement")
            
            return jsonify({
                'table_name': table_name,
                'category': category,
                'message': 'Requête d\'export mise à jour avec succès'
            }), 200
            
    except SQLAlchemyError as e:
        current_app.logger.error(f"Erreur SQL lors de la mise à jour de la requête: {str(e)}")
        return jsonify({"error": "Erreur lors de la mise à jour de la requête"}), 500
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la mise à jour de la requête: {str(e)}")
        return jsonify({"error": "Erreur lors de la mise à jour de la requête"}), 500

@export_bp.route('/queries/<table_name>', methods=['DELETE'])
@admin_required
def delete_export_query(table_name):
    """Supprime une requête d'export (Admin seulement)"""
    try:
        # ✅ CORRECTION: Gérer les doublons avec la catégorie
        category = request.args.get('category')
        
        data_service = get_data_service()
        
        with data_service.engine.connect() as connection:
            if category:
                # Supprimer seulement la requête avec cette catégorie
                check_query = "SELECT id FROM etl_export_queries WHERE table_name = :table_name AND category = :category"
                existing = connection.execute(text(check_query), {'table_name': table_name, 'category': category})
                if not existing.fetchone():
                    return jsonify({"error": f"Requête pour la table '{table_name}' dans la catégorie '{category}' non trouvée"}), 404
                
                delete_query = "DELETE FROM etl_export_queries WHERE table_name = :table_name AND category = :category"
                connection.execute(text(delete_query), {'table_name': table_name, 'category': category})
                connection.commit()
                
                return jsonify({
                    'table_name': table_name,
                    'category': category,
                    'message': 'Requête d\'export supprimée avec succès'
                }), 200
            else:
                # Supprimer toutes les requêtes pour cette table (comportement original)
                check_query = "SELECT id FROM etl_export_queries WHERE table_name = :table_name"
                existing = connection.execute(text(check_query), {'table_name': table_name})
                if not existing.fetchone():
                    return jsonify({"error": f"Requête pour la table '{table_name}' non trouvée"}), 404
                
                delete_query = "DELETE FROM etl_export_queries WHERE table_name = :table_name"
                result = connection.execute(text(delete_query), {'table_name': table_name})
                connection.commit()
                
                return jsonify({
                    'table_name': table_name,
                    'deleted_count': result.rowcount,
                    'message': f'{result.rowcount} requête(s) d\'export supprimée(s) avec succès'
                }), 200
            
    except SQLAlchemyError as e:
        current_app.logger.error(f"Erreur SQL lors de la suppression de la requête: {str(e)}")
        return jsonify({"error": "Erreur lors de la suppression de la requête"}), 500
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la suppression de la requête: {str(e)}")
        return jsonify({"error": "Erreur lors de la suppression de la requête"}), 500

@export_bp.route('/queries/<table_name>/execute', methods=['POST'])
@jwt_required()
def execute_export_query(table_name):
    """Exécute une requête d'export spécifique et retourne les données - MISE À JOUR pour système dynamique"""
    try:
        # ✅ NOUVEAU : Utiliser ExportService pour exécution dynamique
        export_service = ExportService()
        
        # Exécuter la requête via le service (génération dynamique)
        data, error = export_service.execute_query(table_name)
        
        if error:
            current_app.logger.error(f"Erreur lors de l'exécution de la requête {table_name}: {error}")
            return jsonify({"error": error}), 500
        
        current_app.logger.info(f"Requête {table_name} exécutée avec succès: {len(data)} lignes retournées")
        
        return jsonify(data), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de l'exécution de la requête {table_name}: {str(e)}")
        return jsonify({"error": f"Erreur lors de l'exécution de la requête: {str(e)}"}), 500

@export_bp.route('/queries/test', methods=['POST'])
@admin_required
def test_sql_query():
    """Teste une requête SQL avant sa sauvegarde - MISE À JOUR pour système dynamique"""
    try:
        data = request.get_json()
        if not data or not data.get('column_list'):
            return jsonify({"error": "Les données 'column_list', 'table_name' et 'table_schema' sont requises"}), 400
        
        # Extraire les paramètres
        column_list = data['column_list'].strip()
        table_name = data.get('table_name', '').strip()
        table_schema = data.get('table_schema', '').strip()
        
        if not column_list or not table_name or not table_schema:
            return jsonify({"error": "Les champs 'column_list', 'table_name' et 'table_schema' sont requis"}), 400
        
        # Générer la requête SQL dynamiquement
        export_service = ExportService()
        
        try:
            sql_query = export_service.build_dynamic_query(table_name, table_schema, column_list)
        except ValueError as ve:
            return jsonify({"error": f"Erreur de configuration: {str(ve)}"}), 400
        
        # Validation de sécurité basique - vérifier que ce sont des mots-clés ISOLÉS, pas dans les noms de colonnes
        dangerous_keywords = ['DROP', 'DELETE', 'UPDATE', 'INSERT', 'CREATE', 'ALTER', 'TRUNCATE']
        sql_upper = sql_query.upper()
        
        # Vérifier seulement les mots-clés isolés (entourés d'espaces ou de début/fin de chaîne)
        import re
        for keyword in dangerous_keywords:
            # Pattern pour détecter le mot-clé comme mot isolé
            pattern = r'\b' + keyword + r'\b'
            if re.search(pattern, sql_upper):
                return jsonify({"error": f"Requête non autorisée - mot-clé dangereux détecté: {keyword}"}), 400
        
        data_service = get_data_service()
        
        with data_service.engine.connect() as connection:
            # Compter d'abord le nombre total de lignes
            count_query = f"SELECT COUNT(*) as total FROM ({sql_query}) AS subquery"
            count_result = connection.execute(text(count_query))
            total_rows = count_result.scalar()
            
            # Test avec LIMIT pour éviter les gros résultats
            limited_query = f"SELECT * FROM ({sql_query}) AS subquery LIMIT 10"
            
            start_time = time.time()
            result = connection.execute(text(limited_query))
            sample_data = [dict(row._mapping) for row in result]
            execution_time = time.time() - start_time
            
            # Gérer le cas des tables vides
            if total_rows == 0:
                # Pour les tables vides, obtenir les colonnes via une requête différente
                columns_query = text("""
                    SELECT column_name
                    FROM information_schema.columns
                    WHERE table_name = :table_name AND table_schema = :table_schema
                    ORDER BY ordinal_position
                """)
                columns_result = connection.execute(
                    columns_query,
                    {"table_name": table_name, "table_schema": table_schema},
                )
                columns = [row.column_name for row in columns_result]
                
                return jsonify({
                    "success": True,
                    "generated_sql": sql_query,
                    "execution_time": round(execution_time, 3),
                    "sample_data": [],
                    "total_rows": 0,
                    "columns": columns,
                    "message": f"✅ Requête valide mais la table '{table_name}' est vide (0 lignes)"
                })
            
            return jsonify({
                "success": True,
                "generated_sql": sql_query,
                "execution_time": round(execution_time, 3),
                "sample_data": sample_data,
                "total_rows": total_rows,
                "columns": list(sample_data[0].keys()) if sample_data else []
            })
            
    except SQLAlchemyError as e:
        error_msg = str(e.orig) if hasattr(e, 'orig') else str(e)
        current_app.logger.error(f"Erreur SQL lors du test: {error_msg}")
        return jsonify({"error": f"Erreur SQL: {error_msg}"}), 400
    except Exception as e:
        current_app.logger.error(f"Erreur lors du test de la requête: {str(e)}")
        return jsonify({"error": f"Erreur lors du test: {str(e)}"}), 500

@export_bp.route('/categories', methods=['GET'])
@jwt_required()
def get_export_categories():
    """Récupère la liste des catégories disponibles"""
    try:
        data_service = get_data_service()
        
        with data_service.engine.connect() as connection:
            query = """
                SELECT category, COUNT(*) as count
                FROM etl_export_queries 
                WHERE is_active = true
                GROUP BY category
                ORDER BY category
            """
            
            result = connection.execute(text(query))
            
            categories = []
            for row in result:
                categories.append({
                    'name': row.category,
                    'count': row.count
                })
            
            return jsonify({
                'categories': categories,
                'total': len(categories)
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des catégories: {str(e)}")
        return jsonify({"error": "Erreur lors de la récupération des catégories"}), 500 