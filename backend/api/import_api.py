"""
API Blueprint pour les opérations d'import de fichiers
Endpoints pour upload, suivi et gestion des imports
"""

from flask import Blueprint, request, jsonify, current_app, send_file
from flask_jwt_extended import jwt_required, get_jwt_identity, get_jwt
from werkzeug.utils import secure_filename
from datetime import datetime
import io
import csv
import json
import os
import tempfile
from typing import Dict, Any, List
import requests
import psycopg2
import psycopg2.extras

from services.import_service import ImportService
from services.sharepoint_service import SharePointService
from utils.auth_decorators import admin_required, require_role
from utils.validators import validate_file_name, sanitize_file_name, format_file_size
from config.database import get_db_connection

# Créer le blueprint
import_blueprint = Blueprint('import', __name__)

# Instance du service d'import
import_service = ImportService()


@import_blueprint.route('/upload', methods=['POST'])
@jwt_required()
def upload_file():
    """
    Upload et lancement d'un import de fichier
    
    Expected form-data:
    - file: Fichier à importer (CSV, XLSX, XLS)
    - file_type: Type de fichier (customers, products, orders)
    """
    try:
        user_id = get_jwt_identity()
        
        # Vérifier qu'un fichier est présent
        if 'file' not in request.files:
            return jsonify({'error': 'Aucun fichier fourni'}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'error': 'Nom de fichier vide'}), 400
        
        # Récupérer le type de fichier
        file_type = request.form.get('file_type')
        if not file_type:
            return jsonify({'error': 'Type de fichier requis (customers, products, orders)'}), 400
        
        if file_type not in ['customers', 'products', 'orders']:
            return jsonify({'error': 'Type de fichier non supporté'}), 400
        
        # Validation du nom de fichier
        validation_result = validate_file_name(file.filename)
        if not validation_result['is_valid']:
            return jsonify({
                'error': 'Nom de fichier invalide',
                'details': validation_result['errors']
            }), 400
        
        # Nettoyer le nom de fichier
        filename = sanitize_file_name(secure_filename(file.filename))
        
        # Lire le contenu du fichier
        file_content = file.read()
        file_size = len(file_content)
        
        # Démarrer l'import
        try:
            job_uuid = import_service.start_import(
                user_id=user_id,
                file_name=filename,
                file_content=file_content,
                file_type=file_type
            )
            
            current_app.logger.info(f"Import démarré par utilisateur {user_id}: {job_uuid}")
            
            return jsonify({
                'message': 'Import démarré avec succès',
                'job_uuid': job_uuid,
                'file_name': filename,
                'file_size': format_file_size(file_size),
                'file_type': file_type,
                'status': 'pending'
            }), 201
            
        except ValueError as ve:
            return jsonify({'error': str(ve)}), 400
        except Exception as e:
            current_app.logger.error(f"Erreur démarrage import: {e}")
            return jsonify({'error': 'Erreur interne du serveur'}), 500
    
    except Exception as e:
        current_app.logger.error(f"Erreur upload fichier: {e}")
        return jsonify({'error': 'Erreur lors de l\'upload'}), 500


@import_blueprint.route('/jobs', methods=['GET'])
@jwt_required()
def get_import_jobs():
    """
    Liste des jobs d'import
    
    Query parameters:
    - limit: Nombre maximum de jobs à retourner (défaut: 50)
    - user_only: true pour ne voir que ses propres imports (défaut: false pour admin)
    """
    try:
        user_id = get_jwt_identity()
        claims = get_jwt()
        user_role = claims.get('role', 'operator')
        
        # Paramètres de requête
        limit = request.args.get('limit', 50, type=int)
        user_only = request.args.get('user_only', 'false').lower() == 'true'
        
        # Validation des paramètres
        if limit > 1000:
            limit = 1000
        
        # Déterminer si on filtre par utilisateur
        filter_user_id = None
        if user_role != 'admin' or user_only:
            filter_user_id = user_id
        
        # Récupérer l'historique
        jobs = import_service.get_import_history(
            user_id=filter_user_id,
            limit=limit
        )
        
        # Enrichir avec les informations utilisateur si admin
        if user_role == 'admin' and not user_only:
            jobs = _enrich_jobs_with_user_info(jobs)
        
        return jsonify({
            'jobs': jobs,
            'total': len(jobs),
            'limit': limit,
            'user_only': user_only
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur récupération jobs: {e}")
        return jsonify({'error': 'Erreur lors de la récupération des jobs'}), 500


@import_blueprint.route('/jobs/<job_uuid>', methods=['GET'])
@jwt_required()
def get_import_job(job_uuid: str):
    """
    Détail d'un job d'import spécifique
    """
    try:
        user_id = get_jwt_identity()
        claims = get_jwt()
        user_role = claims.get('role', 'operator')
        
        # Récupérer le statut du job
        job_info = import_service.get_import_status(job_uuid)
        
        if not job_info:
            return jsonify({'error': 'Job non trouvé'}), 404
        
        # Vérifier les permissions (operator ne peut voir que ses propres jobs)
        if user_role != 'admin' and job_info.get('user_id') != user_id:
            return jsonify({'error': 'Accès non autorisé'}), 403
        
        # Enrichir avec les détails si terminé
        if job_info['status'] in ['completed', 'completed_with_errors', 'failed']:
            job_info['details'] = _get_job_details(job_uuid)
        
        return jsonify(job_info), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur récupération job {job_uuid}: {e}")
        return jsonify({'error': 'Erreur lors de la récupération du job'}), 500


@import_blueprint.route('/jobs/<job_uuid>/details', methods=['GET'])
@jwt_required()
def get_import_job_details(job_uuid: str):
    """
    Détails ligne par ligne d'un import
    
    Query parameters:
    - page: Numéro de page (défaut: 1)
    - page_size: Taille de page (défaut: 100, max: 500)
    - status: Filtrer par statut (success, error)
    """
    try:
        user_id = get_jwt_identity()
        claims = get_jwt()
        user_role = claims.get('role', 'operator')
        
        # Vérifier que le job existe et les permissions
        job_info = import_service.get_import_status(job_uuid)
        if not job_info:
            return jsonify({'error': 'Job non trouvé'}), 404
        
        if user_role != 'admin' and job_info.get('user_id') != user_id:
            return jsonify({'error': 'Accès non autorisé'}), 403
        
        # Paramètres de pagination
        page = request.args.get('page', 1, type=int)
        page_size = request.args.get('page_size', 100, type=int)
        status_filter = request.args.get('status')
        
        # Validation
        if page < 1:
            page = 1
        if page_size > 500:
            page_size = 500
        
        # Récupérer les détails
        details = _get_job_details_paginated(job_uuid, page, page_size, status_filter)
        
        return jsonify(details), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur récupération détails job {job_uuid}: {e}")
        return jsonify({'error': 'Erreur lors de la récupération des détails'}), 500


@import_blueprint.route('/jobs/<job_uuid>/cancel', methods=['POST'])
@jwt_required()
def cancel_import_job(job_uuid: str):
    """
    Annule un job d'import en cours
    """
    try:
        user_id = get_jwt_identity()
        claims = get_jwt()
        user_role = claims.get('role', 'operator')
        
        # Vérifier que le job existe et les permissions
        job_info = import_service.get_import_status(job_uuid)
        if not job_info:
            return jsonify({'error': 'Job non trouvé'}), 404
        
        if user_role != 'admin' and job_info.get('user_id') != user_id:
            return jsonify({'error': 'Accès non autorisé'}), 403
        
        # Tenter l'annulation
        success = import_service.cancel_import(job_uuid)
        
        if success:
            current_app.logger.info(f"Job {job_uuid} annulé par utilisateur {user_id}")
            return jsonify({
                'message': 'Job annulé avec succès',
                'job_uuid': job_uuid
            }), 200
        else:
            return jsonify({
                'error': 'Impossible d\'annuler le job (déjà terminé ou introuvable)'
            }), 400
    
    except Exception as e:
        current_app.logger.error(f"Erreur annulation job {job_uuid}: {e}")
        return jsonify({'error': 'Erreur lors de l\'annulation'}), 500


@import_blueprint.route('/jobs/<job_uuid>/retry', methods=['POST'])
@jwt_required()
def retry_import_job(job_uuid: str):
    """
    Relance un job d'import échoué
    """
    try:
        user_id = get_jwt_identity()
        claims = get_jwt()
        user_role = claims.get('role', 'operator')
        
        # Vérifier que le job existe et les permissions
        job_info = import_service.get_import_status(job_uuid)
        if not job_info:
            return jsonify({'error': 'Job non trouvé'}), 404
        
        if user_role != 'admin' and job_info.get('user_id') != user_id:
            return jsonify({'error': 'Accès non autorisé'}), 403
        
        # Vérifier que le job peut être relancé
        if job_info['status'] not in ['failed', 'cancelled']:
            return jsonify({
                'error': f'Impossible de relancer un job avec le statut: {job_info["status"]}'
            }), 400
        
        # TODO: Implémenter la logique de retry
        # Pour l'instant, retourner une réponse temporaire
        return jsonify({
            'error': 'Fonctionnalité de retry en cours de développement'
        }), 501
    
    except Exception as e:
        current_app.logger.error(f"Erreur retry job {job_uuid}: {e}")
        return jsonify({'error': 'Erreur lors du retry'}), 500


@import_blueprint.route('/jobs/<job_uuid>/export-errors', methods=['GET'])
@jwt_required()
def export_job_errors(job_uuid: str):
    """
    Exporte les erreurs d'un job sous forme de CSV
    """
    try:
        user_id = get_jwt_identity()
        claims = get_jwt()
        user_role = claims.get('role', 'operator')
        
        # Vérifier que le job existe et les permissions
        job_info = import_service.get_import_status(job_uuid)
        if not job_info:
            return jsonify({'error': 'Job non trouvé'}), 404
        
        if user_role != 'admin' and job_info.get('user_id') != user_id:
            return jsonify({'error': 'Accès non autorisé'}), 403
        
        # Récupérer toutes les erreurs
        errors = _get_job_errors(job_uuid)
        
        if not errors:
            return jsonify({'error': 'Aucune erreur trouvée pour ce job'}), 404
        
        # Créer le fichier CSV en mémoire
        output = io.StringIO()
        writer = csv.writer(output)
        
        # En-têtes
        writer.writerow([
            'Ligne', 'Statut', 'Erreurs', 'Données Originales'
        ])
        
        # Données
        for error in errors:
            writer.writerow([
                error.get('row_number', ''),
                error.get('status', ''),
                error.get('error_message', ''),
                json.dumps(error.get('original_data', {}), ensure_ascii=False)
            ])
        
        # Préparer la réponse
        output.seek(0)
        file_content = output.getvalue()
        output.close()
        
        # Nom du fichier
        filename = f"erreurs_import_{job_uuid}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
        
        # Créer la réponse avec le fichier
        response = current_app.response_class(
            file_content,
            mimetype='text/csv',
            headers={
                'Content-Disposition': f'attachment; filename={filename}',
                'Content-Type': 'text/csv; charset=utf-8'
            }
        )
        
        current_app.logger.info(f"Export erreurs job {job_uuid} par utilisateur {user_id}")
        return response
        
    except Exception as e:
        current_app.logger.error(f"Erreur export erreurs job {job_uuid}: {e}")
        return jsonify({'error': 'Erreur lors de l\'export des erreurs'}), 500


@import_blueprint.route('/config/file-types', methods=['GET'])
@jwt_required()
def get_file_types_config():
    """
    Récupère la configuration des types de fichiers supportés
    """
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT file_type, display_name, description, 
                       required_columns, optional_columns, target_table
                FROM file_type_configs 
                WHERE is_active = true
                ORDER BY display_name
            """)
            
            configs = []
            for row in cursor.fetchall():
                configs.append({
                    'file_type': row[0],
                    'display_name': row[1],
                    'description': row[2],
                    'required_columns': row[3],
                    'optional_columns': row[4],
                    'target_table': row[5]
                })
            
            return jsonify({
                'file_types': configs,
                'count': len(configs)
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur récupération config types: {e}")
        return jsonify({'error': 'Erreur lors de la récupération de la configuration'}), 500


@import_blueprint.route('/stats', methods=['GET'])
@jwt_required()
def get_import_statistics():
    """
    Récupère les statistiques globales d'import
    
    Query parameters:
    - period: Période (today, week, month, all) - défaut: month
    """
    try:
        user_id = get_jwt_identity()
        claims = get_jwt()
        user_role = claims.get('role', 'operator')
        
        period = request.args.get('period', 'month')
        if period not in ['today', 'week', 'month', 'all']:
            period = 'month'
        
        # Calculer la période
        date_filter = _get_date_filter(period)
        
        # Récupérer les statistiques
        stats = _get_import_statistics(user_id, user_role, date_filter)
        
        return jsonify({
            'period': period,
            'statistics': stats
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur récupération statistiques: {e}")
        return jsonify({'error': 'Erreur lors de la récupération des statistiques'}), 500


@import_blueprint.route('/projets', methods=['POST'])
# @jwt_required()  # Désactivé pour développement local
def import_projets_sharepoint():
    """
    Importe les projets depuis SharePoint vers raw_data.sharepoint_projets
    Le backend sert de proxy pour éviter les problèmes CORS
    
    Body JSON:
    {
        "limit": 1000,
        "filters": {
            "Status": "Active"
        }
    }
    """
    try:
        # user_id = get_jwt_identity()  # Désactivé pour développement local
        user_id = "local_dev"
        current_app.logger.info(f"🔐 Import projets SharePoint demandé par: {user_id}")
        
        # Configuration depuis le body
        config = request.get_json() or {}
        
        # Paramètres pour SharePoint — pas de limite par défaut : tout est importé.
        # Une limite n'est appliquée que si explicitement fournie dans le body.
        sharepoint_params = {}
        if config.get('limit'):
            sharepoint_params['top'] = config['limit']
        
        # Ajouter des filtres si spécifiés
        if config.get('filters'):
            filters = []
            for key, value in config['filters'].items():
                filters.append(f"{key} eq '{value}'")
            if filters:
                sharepoint_params['filter'] = ' and '.join(filters)
        
        current_app.logger.info(f"📋 Paramètres SharePoint: {sharepoint_params}")
        
        # Service SharePoint - Instancié uniquement quand nécessaire (pas au démarrage)
        sharepoint_service = SharePointService()
        
        # Lancer l'import (fetch + save en DB)
        result = sharepoint_service.import_projets_from_sharepoint(**sharepoint_params)
        
        current_app.logger.info(f"✅ Import terminé: {result}")
        
        return jsonify({
            'success': result['success'],
            'message': 'Import des projets SharePoint terminé',
            'imported_count': result['imported_count'],
            'errors': result['errors']
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"❌ Erreur import projets SharePoint: {e}")
        return jsonify({
            'error': f'Erreur lors de l\'import: {str(e)}'
        }), 500

@import_blueprint.route('/projets/status', methods=['GET'])
# @jwt_required()  # Désactivé pour développement local
def get_projets_import_status():
    """Retourne le statut de l'import des projets SharePoint"""
    try:
        sharepoint_service = SharePointService()
        stats = sharepoint_service.get_table_status()
        
        return jsonify(stats), 200
            
    except Exception as e:
        current_app.logger.error(f"❌ Erreur statut projets: {e}")
        return jsonify({
            'error': f'Erreur lors de la récupération du statut: {str(e)}'
        }), 500

@import_blueprint.route('/projets/test-connection', methods=['GET'])
# @jwt_required()  # Désactivé pour développement local
def test_sharepoint_connection():
    """Teste la connexion à l'API SharePoint via le backend (proxy pour éviter CORS)"""
    try:
        # Service SharePoint - Instancié uniquement quand nécessaire
        sharepoint_service = SharePointService()
        result = sharepoint_service.test_connection()
        
        if result['success']:
            return jsonify(result), 200
        else:
            return jsonify(result), 500
            
    except Exception as e:
        current_app.logger.error(f"❌ Erreur test SharePoint: {e}")
        return jsonify({
            'success': False,
            'error': f'Erreur: {str(e)}'
        }), 500

@import_blueprint.route('/ressources', methods=['POST'])
# @jwt_required()  # Désactivé pour développement local
def import_ressources_sharepoint():
    """
    Importe les ressources depuis SharePoint vers raw_data.sharepoint_resources
    Le backend sert de proxy pour éviter les problèmes CORS
    
    Body JSON:
    {
        "limit": 1000,
        "filters": {
            "Generic": false
        }
    }
    """
    try:
        user_id = "local_dev"
        current_app.logger.info(f"🔐 Import ressources SharePoint demandé par: {user_id}")
        
        config = request.get_json() or {}
        
        sharepoint_params = {
            'top': config.get('limit', 1000)
        }
        
        if config.get('filters'):
            filters = []
            for key, value in config['filters'].items():
                filters.append(f"{key} eq '{value}'")
            if filters:
                sharepoint_params['filter'] = ' and '.join(filters)
        
        current_app.logger.info(f"📋 Paramètres SharePoint: {sharepoint_params}")
        
        sharepoint_service = SharePointService()
        result = sharepoint_service.import_resources_from_sharepoint(**sharepoint_params)
        
        current_app.logger.info(f"✅ Import terminé: {result}")
        
        return jsonify({
            'success': result['success'],
            'message': 'Import des ressources SharePoint terminé',
            'imported_count': result['imported_count'],
            'errors': result['errors']
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"❌ Erreur import ressources SharePoint: {e}")
        return jsonify({
            'error': f'Erreur lors de l\'import: {str(e)}'
        }), 500

@import_blueprint.route('/ressources/status', methods=['GET'])
# @jwt_required()  # Désactivé pour développement local
def get_ressources_import_status():
    """Retourne le statut de l'import des ressources SharePoint"""
    try:
        sharepoint_service = SharePointService()
        stats = sharepoint_service.get_resources_status()
        
        return jsonify(stats), 200
            
    except Exception as e:
        current_app.logger.error(f"❌ Erreur statut ressources: {e}")
        return jsonify({
            'error': f'Erreur lors de la récupération du statut: {str(e)}'
        }), 500

@import_blueprint.route('/ressources/test-connection', methods=['GET'])
# @jwt_required()  # Désactivé pour développement local
def test_sharepoint_ressources_connection():
    """Teste la connexion à l'API SharePoint pour les ressources"""
    try:
        sharepoint_service = SharePointService()
        url = f"{sharepoint_service.sharepoint_base_url}/_api/web/lists/getByTitle('Ressources')/items"
        
        response = sharepoint_service.session.get(url, params={'$top': 1}, timeout=10)
        response.raise_for_status()
        
        data = response.json()
        resources = data.get('d', {}).get('results', [])
        
        return jsonify({
            'success': True,
            'message': 'Connexion SharePoint OK',
            'url': url,
            'sample_count': len(resources),
            'status_code': response.status_code,
            'sample_data': resources[0] if resources else None
        }), 200
            
    except requests.exceptions.RequestException as e:
        return jsonify({
            'success': False,
            'error': f'Erreur de connexion: {str(e)}'
        }), 500
    except Exception as e:
        current_app.logger.error(f"❌ Erreur test SharePoint ressources: {e}")
        return jsonify({
            'success': False,
            'error': f'Erreur: {str(e)}'
        }), 500

@import_blueprint.route('/users', methods=['POST'])
# @jwt_required()  # Désactivé pour développement local
def import_users_sharepoint():
    """
    Importe les utilisateurs depuis SharePoint vers raw_data.sharepoint_users
    
    Body JSON:
    {
        "limit": 5000
    }
    """
    try:
        user_id = "local_dev"
        current_app.logger.info(f"🔐 Import utilisateurs SharePoint demandé par: {user_id}")
        
        config = request.get_json() or {}
        
        sharepoint_params = {
            'top': config.get('limit', 5000)
        }
        
        current_app.logger.info(f"📋 Paramètres SharePoint: {sharepoint_params}")
        
        sharepoint_service = SharePointService()
        result = sharepoint_service.import_users_from_sharepoint(**sharepoint_params)
        
        current_app.logger.info(f"✅ Import terminé: {result}")
        
        return jsonify({
            'success': result['success'],
            'message': 'Import des utilisateurs SharePoint terminé',
            'imported_count': result['imported_count'],
            'errors': result['errors']
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"❌ Erreur import utilisateurs SharePoint: {e}")
        return jsonify({
            'error': f'Erreur lors de l\'import: {str(e)}'
        }), 500

@import_blueprint.route('/users/status', methods=['GET'])
# @jwt_required()  # Désactivé pour développement local
def get_users_import_status():
    """Retourne le statut de l'import des utilisateurs SharePoint"""
    try:
        sharepoint_service = SharePointService()
        stats = sharepoint_service.get_users_status()
        
        return jsonify(stats), 200
            
    except Exception as e:
        current_app.logger.error(f"❌ Erreur statut utilisateurs: {e}")
        return jsonify({
            'error': f'Erreur lors de la récupération du statut: {str(e)}'
        }), 500

@import_blueprint.route('/users/test-connection', methods=['GET'])
# @jwt_required()  # Désactivé pour développement local
def test_sharepoint_users_connection():
    """Teste la connexion à l'API SharePoint pour les utilisateurs"""
    try:
        sharepoint_service = SharePointService()
        url = f"{sharepoint_service.sharepoint_base_url}/_api/web/siteusers"
        
        response = sharepoint_service.session.get(url, params={'$top': 1}, timeout=10)
        response.raise_for_status()
        
        data = response.json()
        users = data.get('d', {}).get('results', [])
        
        return jsonify({
            'success': True,
            'message': 'Connexion SharePoint OK',
            'url': url,
            'sample_count': len(users),
            'status_code': response.status_code,
            'sample_data': users[0] if users else None
        }), 200
            
    except requests.exceptions.RequestException as e:
        return jsonify({
            'success': False,
            'error': f'Erreur de connexion: {str(e)}'
        }), 500
    except Exception as e:
        current_app.logger.error(f"❌ Erreur test SharePoint utilisateurs: {e}")
        return jsonify({
            'success': False,
            'error': f'Erreur: {str(e)}'
        }), 500


# ============================================================
# ÉTATS D'AVANCEMENT (Status Reports)
# ============================================================

@import_blueprint.route('/etats-avancement/all', methods=['POST'])
# @jwt_required()  # Désactivé pour développement local
def import_all_etats_avancement_sharepoint():
    """
    Importe les états d'avancement de TOUS les projets SharePoint
    
    Body JSON:
    {
        "top_per_site": 100
    }
    """
    try:
        user_id = "local_dev"
        current_app.logger.info(f"🔐 Import de TOUS les états d'avancement demandé par: {user_id}")
        
        config = request.get_json() or {}
        
        sharepoint_params = {
            'top_per_site': config.get('top_per_site', 100)
        }
        
        current_app.logger.info(f"📋 Paramètres: {sharepoint_params}")
        
        sharepoint_service = SharePointService()
        result = sharepoint_service.import_all_etats_avancement(**sharepoint_params)
        
        current_app.logger.info(f"✅ Import global terminé: {result}")
        
        return jsonify({
            'success': result['success'],
            'message': result['message'],
            'total_imported': result['total_imported'],
            'sites_processed': result['sites_processed'],
            'sites_with_data': result['sites_with_data'],
            'errors': result['errors']
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"❌ Erreur import global états d'avancement: {e}")
        return jsonify({
            'error': f'Erreur lors de l\'import: {str(e)}'
        }), 500


@import_blueprint.route('/etats-avancement', methods=['POST'])
# @jwt_required()  # Désactivé pour développement local
def import_etats_avancement_sharepoint():
    """
    Importe les états d'avancement d'UN site SharePoint spécifique
    
    Body JSON:
    {
        "limit": 1000,
        "site_id": "863",
        "list_guid": "0143FA81-887F-49BC-9878-C1BF871D7F3B"
    }
    """
    try:
        user_id = "local_dev"
        current_app.logger.info(f"🔐 Import états d'avancement SharePoint demandé par: {user_id}")

        config = request.get_json() or {}

        site_id = str(config.get('site_id', '863'))
        list_guid = config.get('list_guid', '0143FA81-887F-49BC-9878-C1BF871D7F3B')
        include_related = bool(config.get('include_related', True))
        limit = int(config.get('limit', 5000))

        sharepoint_params = {
            'top': limit,
            'list_guid': list_guid
        }
        if config.get('filters'):
            filters = []
            for key, value in config['filters'].items():
                filters.append(f"{key} eq '{value}'")
            if filters:
                sharepoint_params['filter'] = ' and '.join(filters)

        current_app.logger.info(
            f"📋 Paramètres SharePoint: site_id={site_id}, "
            f"limit={limit}, include_related={include_related}"
        )

        sharepoint_service = SharePointService()

        # 1. États d'avancement (table principale)
        result = sharepoint_service.import_etats_avancement_from_sharepoint(
            site_id=site_id, **sharepoint_params
        )
        all_errors = list(result.get('errors') or [])

        # 2. Listes filles (phases, jalons_ref, statut_jalons, statut_cfv, statut_couts)
        related_counts = {}
        if include_related:
            for list_key in sharepoint_service.RELATED_LISTS.keys():
                try:
                    rel = sharepoint_service.import_related_list(
                        list_key, site_id,
                        top=limit,
                        skip_missing_list=True
                    )
                    related_counts[list_key] = rel.get('imported_count', 0)
                    if rel.get('errors'):
                        all_errors.extend(
                            f"{list_key}: {err}" for err in rel['errors'][:5]
                        )
                except Exception as e:
                    related_counts[list_key] = 0
                    all_errors.append(f"{list_key}: {e}")
                    current_app.logger.warning(f"⚠️ Liste {list_key} site {site_id}: {e}")

        current_app.logger.info(f"✅ Import terminé site {site_id}: {result.get('imported_count', 0)} états + {sum(related_counts.values())} liés")

        return jsonify({
            'success': result['success'],
            'message': 'Import des états d\'avancement SharePoint terminé',
            'imported_count': result['imported_count'],
            'errors': all_errors[:50],
            'site_id': site_id,
            'related_counts': related_counts
        }), 200

    except Exception as e:
        current_app.logger.error(f"❌ Erreur import états d'avancement SharePoint: {e}")
        return jsonify({
            'error': f'Erreur lors de l\'import: {str(e)}'
        }), 500

@import_blueprint.route('/etats-avancement/status', methods=['GET'])
# @jwt_required()  # Désactivé pour développement local
def get_etats_avancement_import_status():
    """Retourne le statut de l'import des états d'avancement SharePoint"""
    try:
        sharepoint_service = SharePointService()
        stats = sharepoint_service.get_etats_avancement_status()
        
        return jsonify(stats), 200
            
    except Exception as e:
        current_app.logger.error(f"❌ Erreur statut états d'avancement: {e}")
        return jsonify({
            'error': f'Erreur lors de la récupération du statut: {str(e)}'
        }), 500

@import_blueprint.route('/etats-avancement/test-connection', methods=['GET'])
# @jwt_required()  # Désactivé pour développement local
def test_sharepoint_etats_avancement_connection():
    """Teste la connexion à la liste des états d'avancement SharePoint"""
    try:
        # Paramètres optionnels via query string
        site_id = request.args.get('site_id', '863')
        list_guid = request.args.get('list_guid', '0143FA81-887F-49BC-9878-C1BF871D7F3B')
        
        sharepoint_service = SharePointService()
        result = sharepoint_service.test_etats_avancement_connection(site_id=site_id, list_guid=list_guid)
        
        if result['success']:
            return jsonify(result), 200
        else:
            return jsonify(result), 500
            
    except Exception as e:
        current_app.logger.error(f"❌ Erreur test SharePoint états d'avancement: {e}")
        return jsonify({
            'success': False,
            'error': f'Erreur: {str(e)}'
        }), 500


# ============================================================
# LISTES LIÉES À L'ÉTAT D'AVANCEMENT
# (Phases, Jalons, Statut des jalons / CFV / coûts)
# ============================================================

# Mapping entre slug d'URL et clé interne du service
_RELATED_LIST_URL_MAP = {
    'phases':         'phases',
    'jalons-ref':     'jalons_ref',
    'statut-jalons':  'statut_jalons',
    'statut-cfv':     'statut_cfv',
    'statut-couts':   'statut_couts',
}


@import_blueprint.route('/sharepoint-related/<list_slug>', methods=['POST'])
def import_sharepoint_related_one_site(list_slug):
    """
    Importe UNE liste fille (phases|jalons-ref|statut-jalons|statut-cfv|statut-couts)
    pour UN seul site SharePoint.
    Body: { "site_id": "863", "limit": 5000 }
    """
    list_key = _RELATED_LIST_URL_MAP.get(list_slug)
    if not list_key:
        return jsonify({
            'success': False,
            'error': f'Liste inconnue: {list_slug}',
            'available': list(_RELATED_LIST_URL_MAP.keys())
        }), 400

    try:
        data = request.get_json(silent=True) or {}
        site_id = str(data.get('site_id', '863'))
        params = {'top': int(data.get('limit', 5000))}

        sharepoint_service = SharePointService()
        result = sharepoint_service.import_related_list(list_key, site_id, **params)
        return jsonify(result), 200
    except Exception as e:
        current_app.logger.error(f"❌ Import {list_slug} (1 site): {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@import_blueprint.route('/sharepoint-related/<list_slug>/all', methods=['POST'])
def import_sharepoint_related_all_sites(list_slug):
    """
    Importe UNE liste fille sur TOUS les sites projet.
    Body: { "top_per_site": 5000 }
    """
    list_key = _RELATED_LIST_URL_MAP.get(list_slug)
    if not list_key:
        return jsonify({
            'success': False,
            'error': f'Liste inconnue: {list_slug}',
            'available': list(_RELATED_LIST_URL_MAP.keys())
        }), 400

    try:
        data = request.get_json(silent=True) or {}
        params = {'top_per_site': int(data.get('top_per_site', 5000))}

        sharepoint_service = SharePointService()
        result = sharepoint_service.import_related_list_all_sites(list_key, **params)
        return jsonify(result), 200
    except Exception as e:
        current_app.logger.error(f"❌ Import {list_slug} (tous sites): {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@import_blueprint.route('/etats-avancement/all-related', methods=['POST'])
def import_all_etats_avancement_related():
    """
    Bouton tout-en-un : importe les 5 listes filles (phases, jalons_ref,
    statut_jalons, statut_cfv, statut_couts) sur TOUS les sites projet.
    Body: { "top_per_site": 5000 }
    """
    try:
        data = request.get_json(silent=True) or {}
        params = {'top_per_site': int(data.get('top_per_site', 5000))}

        sharepoint_service = SharePointService()
        result = sharepoint_service.import_all_etat_avancement_related(**params)
        return jsonify(result), 200
    except Exception as e:
        current_app.logger.error(f"❌ Import global listes liées: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# Fonctions utilitaires privées

def _enrich_jobs_with_user_info(jobs: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Enrichit la liste des jobs avec les infos utilisateur"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            user_ids = [job['user_id'] for job in jobs if job.get('user_id')]
            
            if not user_ids:
                return jobs
            
            # Récupérer les infos utilisateurs
            placeholders = ','.join(['%s'] * len(user_ids))
            cursor.execute(f"""
                SELECT id, username, first_name, last_name 
                FROM users 
                WHERE id IN ({placeholders})
            """, user_ids)
            
            users_info = {row[0]: {
                'username': row[1],
                'first_name': row[2],
                'last_name': row[3]
            } for row in cursor.fetchall()}
            
            # Enrichir les jobs
            for job in jobs:
                user_id = job.get('user_id')
                if user_id in users_info:
                    job['user_info'] = users_info[user_id]
            
            return jobs
            
    except Exception as e:
        current_app.logger.warning(f"Erreur enrichissement jobs avec users: {e}")
        return jobs


def _get_job_details(job_uuid: str) -> Dict[str, Any]:
    """Récupère les détails d'un job"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT COUNT(*) as total,
                       COUNT(CASE WHEN status = 'success' THEN 1 END) as success,
                       COUNT(CASE WHEN status = 'error' THEN 1 END) as errors
                FROM import_details id
                JOIN import_jobs ij ON id.import_job_id = ij.id
                WHERE ij.job_uuid = %s
            """, (job_uuid,))
            
            result = cursor.fetchone()
            return {
                'total_lines': result[0] if result else 0,
                'success_lines': result[1] if result else 0,
                'error_lines': result[2] if result else 0
            }
            
    except Exception as e:
        current_app.logger.error(f"Erreur détails job {job_uuid}: {e}")
        return {}


def _get_job_details_paginated(job_uuid: str, page: int, page_size: int, 
                              status_filter: str = None) -> Dict[str, Any]:
    """Récupère les détails paginés d'un job"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Construire la requête
            base_query = """
                FROM import_details id
                JOIN import_jobs ij ON id.import_job_id = ij.id
                WHERE ij.job_uuid = %s
            """
            params = [job_uuid]
            
            if status_filter:
                base_query += " AND id.status = %s"
                params.append(status_filter)
            
            # Compter le total
            cursor.execute(f"SELECT COUNT(*) {base_query}", params)
            total = cursor.fetchone()[0]
            
            # Récupérer les données paginées
            offset = (page - 1) * page_size
            cursor.execute(f"""
                SELECT id.row_number, id.status, id.original_data, 
                       id.transformed_data, id.error_message, id.processed_at
                {base_query}
                ORDER BY id.row_number
                LIMIT %s OFFSET %s
            """, params + [page_size, offset])
            
            details = []
            for row in cursor.fetchall():
                details.append({
                    'row_number': row[0],
                    'status': row[1],
                    'original_data': json.loads(row[2]) if row[2] else {},
                    'transformed_data': json.loads(row[3]) if row[3] else {},
                    'error_message': row[4],
                    'processed_at': row[5].isoformat() if row[5] else None
                })
            
            return {
                'details': details,
                'pagination': {
                    'page': page,
                    'page_size': page_size,
                    'total': total,
                    'total_pages': (total + page_size - 1) // page_size
                }
            }
            
    except Exception as e:
        current_app.logger.error(f"Erreur détails paginés job {job_uuid}: {e}")
        return {'details': [], 'pagination': {}}


def _get_job_errors(job_uuid: str) -> List[Dict[str, Any]]:
    """Récupère toutes les erreurs d'un job"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT id.row_number, id.status, id.original_data, id.error_message
                FROM import_details id
                JOIN import_jobs ij ON id.import_job_id = ij.id
                WHERE ij.job_uuid = %s AND id.status = 'error'
                ORDER BY id.row_number
            """, (job_uuid,))
            
            errors = []
            for row in cursor.fetchall():
                errors.append({
                    'row_number': row[0],
                    'status': row[1],
                    'original_data': json.loads(row[2]) if row[2] else {},
                    'error_message': row[3]
                })
            
            return errors
            
    except Exception as e:
        current_app.logger.error(f"Erreur récupération erreurs job {job_uuid}: {e}")
        return []


def _get_date_filter(period: str) -> str:
    """Génère un filtre de date SQL selon la période"""
    if period == 'today':
        return "DATE(created_at) = CURRENT_DATE"
    elif period == 'week':
        return "created_at >= CURRENT_DATE - INTERVAL '7 days'"
    elif period == 'month':
        return "created_at >= CURRENT_DATE - INTERVAL '30 days'"
    else:  # all
        return "1=1"


def _get_import_statistics(user_id: int, user_role: str, date_filter: str) -> Dict[str, Any]:
    """Récupère les statistiques d'import"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Filtre utilisateur si nécessaire
            user_filter = ""
            params = []
            if user_role != 'admin':
                user_filter = "AND user_id = %s"
                params.append(user_id)
            
            # Statistiques globales
            cursor.execute(f"""
                SELECT 
                    COUNT(*) as total_jobs,
                    COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_jobs,
                    COUNT(CASE WHEN status = 'completed_with_errors' THEN 1 END) as completed_with_errors,
                    COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_jobs,
                    COUNT(CASE WHEN status IN ('pending', 'processing') THEN 1 END) as active_jobs,
                    SUM(COALESCE(total_rows, 0)) as total_rows_processed,
                    SUM(COALESCE(success_rows, 0)) as total_success_rows,
                    SUM(COALESCE(error_rows, 0)) as total_error_rows
                FROM import_jobs 
                WHERE {date_filter} {user_filter}
            """, params)
            
            stats = cursor.fetchone()
            
            # Statistiques par type de fichier
            cursor.execute(f"""
                SELECT file_type, COUNT(*) as count
                FROM import_jobs 
                WHERE {date_filter} {user_filter}
                GROUP BY file_type
                ORDER BY count DESC
            """, params)
            
            file_types_stats = dict(cursor.fetchall())
            
            return {
                'total_jobs': stats[0] or 0,
                'completed_jobs': stats[1] or 0,
                'completed_with_errors': stats[2] or 0,
                'failed_jobs': stats[3] or 0,
                'active_jobs': stats[4] or 0,
                'total_rows_processed': stats[5] or 0,
                'total_success_rows': stats[6] or 0,
                'total_error_rows': stats[7] or 0,
                'success_rate': round((stats[6] or 0) / max(stats[5] or 1, 1) * 100, 2),
                'file_types': file_types_stats
            }
            
    except Exception as e:
        current_app.logger.error(f"Erreur statistiques import: {e}")
        return {}


# ===============================================
# Fonctions helper pour les endpoints d'import
# ===============================================

def _enrich_jobs_with_user_info(jobs: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Enrichit la liste des jobs avec les informations utilisateur
    """
    try:
        if not jobs:
            return jobs
        
        # Récupérer tous les user_ids uniques
        user_ids = list(set(job.get('user_id') for job in jobs if job.get('user_id')))
        
        if not user_ids:
            return jobs
        
        # Récupérer les informations utilisateur
        from models.user import User
        users = User.query.filter(User.id.in_(user_ids)).all()
        user_map = {user.id: user.to_dict() for user in users}
        
        # Enrichir les jobs
        for job in jobs:
            user_id = job.get('user_id')
            if user_id and user_id in user_map:
                job['user_info'] = {
                    'username': user_map[user_id].get('username'),
                    'email': user_map[user_id].get('email')
                }
        
        return jobs
        
    except Exception as e:
        current_app.logger.error(f"Erreur enrichissement jobs: {e}")
        return jobs


def _get_job_details(job_uuid: str) -> Dict[str, Any]:
    """
    Récupère les détails complets d'un job
    """
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Récupérer les détails de traitement
            cursor.execute("""
                SELECT 
                    row_number, status, original_data, transformed_data,
                    error_message, validation_errors, processed_at
                FROM import_details 
                WHERE import_job_id = (
                    SELECT id FROM import_jobs WHERE job_uuid = %s
                )
                ORDER BY row_number
                LIMIT 1000
            """, (job_uuid,))
            
            details = []
            for row in cursor.fetchall():
                details.append({
                    'row_number': row[0],
                    'status': row[1],
                    'original_data': json.loads(row[2]) if row[2] else {},
                    'transformed_data': json.loads(row[3]) if row[3] else {},
                    'error_message': row[4],
                    'validation_errors': json.loads(row[5]) if row[5] else [],
                    'processed_at': row[6].isoformat() if row[6] else None
                })
            
            # Récupérer les logs
            cursor.execute("""
                SELECT log_level, message, details, created_at
                FROM import_logs 
                WHERE import_job_id = (
                    SELECT id FROM import_jobs WHERE job_uuid = %s
                )
                ORDER BY created_at DESC
                LIMIT 100
            """, (job_uuid,))
            
            logs = []
            for row in cursor.fetchall():
                logs.append({
                    'level': row[0],
                    'message': row[1],
                    'details': json.loads(row[2]) if row[2] else {},
                    'created_at': row[3].isoformat() if row[3] else None
                })
            
            return {
                'details': details,
                'logs': logs,
                'details_count': len(details),
                'logs_count': len(logs)
            }
            
    except Exception as e:
        current_app.logger.error(f"Erreur récupération détails job {job_uuid}: {e}")
        return {'details': [], 'logs': [], 'details_count': 0, 'logs_count': 0}


def _get_job_details_paginated(job_uuid: str, page: int, page_size: int, status_filter: str = None) -> Dict[str, Any]:
    """
    Récupère les détails d'un job avec pagination
    """
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Construire la requête avec filtre optionnel
            where_clause = "WHERE import_job_id = (SELECT id FROM import_jobs WHERE job_uuid = %s)"
            params = [job_uuid]
            
            if status_filter:
                where_clause += " AND status = %s"
                params.append(status_filter)
            
            # Compter le total
            cursor.execute(f"""
                SELECT COUNT(*) FROM import_details {where_clause}
            """, params)
            total = cursor.fetchone()[0]
            
            # Récupérer les données paginées
            offset = (page - 1) * page_size
            cursor.execute(f"""
                SELECT 
                    row_number, status, original_data, transformed_data,
                    error_message, validation_errors, processed_at
                FROM import_details 
                {where_clause}
                ORDER BY row_number
                LIMIT %s OFFSET %s
            """, params + [page_size, offset])
            
            details = []
            for row in cursor.fetchall():
                details.append({
                    'row_number': row[0],
                    'status': row[1],
                    'original_data': json.loads(row[2]) if row[2] else {},
                    'transformed_data': json.loads(row[3]) if row[3] else {},
                    'error_message': row[4],
                    'validation_errors': json.loads(row[5]) if row[5] else [],
                    'processed_at': row[6].isoformat() if row[6] else None
                })
            
            return {
                'details': details,
                'total': total,
                'page': page,
                'page_size': page_size,
                'total_pages': (total + page_size - 1) // page_size
            }
            
    except Exception as e:
        current_app.logger.error(f"Erreur récupération détails paginés job {job_uuid}: {e}")
        return {'details': [], 'total': 0, 'page': page, 'page_size': page_size, 'total_pages': 0}


def _get_date_filter(period: str) -> str:
    """
    Retourne un filtre SQL selon la période demandée
    """
    if period == 'today':
        return "created_at >= CURRENT_DATE"
    elif period == 'week':
        return "created_at >= CURRENT_DATE - INTERVAL '7 days'"
    elif period == 'month':
        return "created_at >= CURRENT_DATE - INTERVAL '30 days'"
    else:  # all
        return "1=1" 