from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from sqlalchemy.exc import IntegrityError
from sqlalchemy import or_
from models import db
from models.import_config import ImportFileTypesConfig
from utils.auth_decorators import admin_required

# Création du blueprint
import_config_bp = Blueprint('import_config', __name__)

@import_config_bp.route('/import-types', methods=['GET'])
@jwt_required()
def get_import_types():
    """
    Récupère la liste des types d'import configurés
    Query params:
    - category: filtrer par catégorie (customer, product, order)
    - active_only: afficher seulement les types actifs (default: true)
    """
    try:
        category = request.args.get('category')
        active_only = request.args.get('active_only', 'true').lower() == 'true'
        
        query = ImportFileTypesConfig.query
        
        if active_only:
            query = query.filter(ImportFileTypesConfig.is_active == True)
        
        # Filtrage par catégorie basé sur type_name puisque la colonne category n'existe pas
        if category == 'customer':
            # Filtrer les types liés aux clients
            query = query.filter(
                or_(
                    ImportFileTypesConfig.type_name.like('%customer%'),
                    ImportFileTypesConfig.type_name.like('%client%'),
                    ImportFileTypesConfig.type_name == 'customers'
                )
            )
        elif category == 'product':
            # Filtrer les types liés aux produits/articles
            query = query.filter(
                or_(
                    ImportFileTypesConfig.type_name.like('%product%'),
                    ImportFileTypesConfig.type_name.like('%part%'),
                    ImportFileTypesConfig.type_name.like('%article%'),
                    ImportFileTypesConfig.type_name.like('%material%')
                )
            )
        
        configs = query.order_by(ImportFileTypesConfig.display_name).all()
        
        return jsonify({
            'success': True,
            'data': [config.to_dict() for config in configs],
            'count': len(configs)
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Erreur lors de la récupération des types: {str(e)}'
        }), 500

@import_config_bp.route('/import-types/<int:config_id>', methods=['GET'])
@jwt_required()
def get_import_type(config_id):
    """Récupère un type d'import spécifique par son ID"""
    try:
        config = ImportFileTypesConfig.query.get_or_404(config_id)
        return jsonify({
            'success': True,
            'data': config.to_dict()
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Erreur lors de la récupération du type: {str(e)}'
        }), 500

@import_config_bp.route('/import-types/<string:type_code>', methods=['GET'])
@jwt_required()
def get_import_type_by_code(type_code):
    """Récupère un type d'import par son code"""
    try:
        config = ImportFileTypesConfig.get_by_type_code(type_code)
        if not config:
            return jsonify({
                'success': False,
                'error': f'Type d\'import "{type_code}" non trouvé'
            }), 404
            
        return jsonify({
            'success': True,
            'data': config.to_dict()
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Erreur lors de la récupération du type: {str(e)}'
        }), 500

@import_config_bp.route('/import-types', methods=['POST'])
@jwt_required()
@admin_required
def create_import_type():
    """Crée un nouveau type d'import"""
    try:
        data = request.get_json()
        current_user_id = get_jwt_identity()
        
        # Validation des champs requis
        required_fields = ['type_code', 'display_name', 'required_columns']
        for field in required_fields:
            if field not in data:
                return jsonify({
                    'success': False,
                    'error': f'Champ requis manquant: {field}'
                }), 400
        
        # Création de la nouvelle configuration
        config = ImportFileTypesConfig(
            type_code=data['type_code'],
            display_name=data['display_name'],
            description=data.get('description', ''),
            category=data.get('category', 'customer'),
            max_file_size_mb=data.get('max_file_size_mb', 50),
            allowed_extensions=data.get('allowed_extensions', ['csv', 'xlsx', 'xls']),
            required_columns=data['required_columns'],
            optional_columns=data.get('optional_columns', []),
            column_mappings=data.get('column_mappings', {}),
            validation_rules=data.get('validation_rules', {}),
            target_table=data.get('target_table', ''),
            processor_class=data.get('processor_class', ''),
            is_active=data.get('is_active', True),
            template_url=data.get('template_url', ''),
            help_text=data.get('help_text', ''),
            icon=data.get('icon', 'description'),
            created_by=current_user_id
        )
        
        db.session.add(config)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'data': config.to_dict(),
            'message': 'Type d\'import créé avec succès'
        }), 201
        
    except IntegrityError:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': 'Un type avec ce code existe déjà'
        }), 400
        
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': f'Erreur lors de la création: {str(e)}'
        }), 500

@import_config_bp.route('/import-types/<int:config_id>', methods=['PUT'])
@jwt_required()
@admin_required
def update_import_type(config_id):
    """Met à jour un type d'import existant"""
    try:
        config = ImportFileTypesConfig.query.get_or_404(config_id)
        data = request.get_json()
        
        # Mise à jour des champs modifiables
        updatable_fields = [
            'display_name', 'description', 'category', 'max_file_size_mb',
            'allowed_extensions', 'required_columns', 'optional_columns',
            'column_mappings', 'validation_rules', 'target_table',
            'processor_class', 'is_active', 'template_url', 'help_text', 'icon'
        ]
        
        for field in updatable_fields:
            if field in data:
                setattr(config, field, data[field])
        
        # Note: type_code n'est pas modifiable pour éviter les problèmes de cohérence
        
        db.session.commit()
        
        return jsonify({
            'success': True,
            'data': config.to_dict(),
            'message': 'Type d\'import mis à jour avec succès'
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': f'Erreur lors de la mise à jour: {str(e)}'
        }), 500

@import_config_bp.route('/import-types/<int:config_id>', methods=['DELETE'])
@jwt_required()
@admin_required
def delete_import_type(config_id):
    """Supprime un type d'import"""
    try:
        config = ImportFileTypesConfig.query.get_or_404(config_id)
        
        # Vérifier qu'il n'y a pas d'imports en cours avec ce type
        # TODO: Ajouter cette vérification quand la logique d'import sera en place
        
        db.session.delete(config)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Type d\'import supprimé avec succès'
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': f'Erreur lors de la suppression: {str(e)}'
        }), 500

@import_config_bp.route('/import-types/<int:config_id>/toggle', methods=['POST'])
@jwt_required()
@admin_required
def toggle_import_type(config_id):
    """Active/désactive un type d'import"""
    try:
        config = ImportFileTypesConfig.query.get_or_404(config_id)
        config.is_active = not config.is_active
        
        db.session.commit()
        
        status = "activé" if config.is_active else "désactivé"
        return jsonify({
            'success': True,
            'data': config.to_dict(),
            'message': f'Type d\'import {status} avec succès'
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': f'Erreur lors du changement de statut: {str(e)}'
        }), 500

@import_config_bp.route('/import-types/<string:type_code>/validate', methods=['POST'])
@jwt_required()
def validate_file_structure(type_code):
    """
    Valide la structure d'un fichier contre un type d'import
    Body: {'columns': ['col1', 'col2', ...]}
    """
    try:
        config = ImportFileTypesConfig.get_by_type_code(type_code)
        if not config:
            return jsonify({
                'success': False,
                'error': f'Type d\'import "{type_code}" non trouvé'
            }), 404
        
        data = request.get_json()
        if 'columns' not in data:
            return jsonify({
                'success': False,
                'error': 'Liste des colonnes requise'
            }), 400
        
        validation_result = config.validate_file_structure(data['columns'])
        
        return jsonify({
            'success': True,
            'data': validation_result
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Erreur lors de la validation: {str(e)}'
        }), 500

@import_config_bp.route('/import-types/categories', methods=['GET'])
@jwt_required()
def get_categories():
    """Récupère la liste des catégories disponibles"""
    try:
        categories = db.session.query(ImportFileTypesConfig.category)\
            .filter(ImportFileTypesConfig.is_active == True)\
            .distinct().all()
        
        category_list = [cat[0] for cat in categories]
        
        return jsonify({
            'success': True,
            'data': category_list
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Erreur lors de la récupération des catégories: {str(e)}'
        }), 500 