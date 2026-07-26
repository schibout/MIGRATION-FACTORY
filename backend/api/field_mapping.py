from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from sqlalchemy.exc import SQLAlchemyError, IntegrityError
from werkzeug.exceptions import BadRequest
import csv
import io
from datetime import datetime

from models import db, FieldMapping
from services.data_service import get_data_service

field_mapping_blueprint = Blueprint('field_mapping', __name__)

@field_mapping_blueprint.route('/field-mappings', methods=['GET'])
# @jwt_required()
def get_field_mappings():
    """Récupère la liste des mappings de champs avec pagination et filtres"""
    try:
        # Récupération des paramètres de filtrage et pagination
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 25, type=int)
        source_table = request.args.get('source_table', '')
        target_table = request.args.get('target_table', '')
        status = request.args.get('status', 'all')  # 'active', 'inactive', 'all'
        search = request.args.get('search', '')
        
        current_app.logger.debug(f"Requête field-mappings avec paramètres: page={page}, per_page={per_page}, source={source_table}, target={target_table}, status={status}")
        
        # Création de la requête de base - utiliser le modèle qui pointe vers la bonne table
        try:
            query = FieldMapping.query
            current_app.logger.debug("Query de base créée avec succès")
        except Exception as query_error:
            current_app.logger.error(f"Erreur lors de la création de la requête de base: {str(query_error)}")
            return jsonify({"error": "Erreur lors de l'accès à la table de mapping"}), 500
        
        # Application des filtres
        try:
            if source_table:
                query = query.filter(FieldMapping.source_table_name == source_table)
            if target_table:
                query = query.filter(FieldMapping.target_table == target_table)
            if status == 'active':
                query = query.filter(FieldMapping.is_active == True)
            elif status == 'inactive':
                query = query.filter(FieldMapping.is_active == False)
            
            # Recherche textuelle
            if search:
                search_term = f"%{search}%"
                query = query.filter(
                    db.or_(
                        FieldMapping.source_table_name.ilike(search_term),
                        FieldMapping.source_field_name.ilike(search_term),
                        FieldMapping.target_table.ilike(search_term),
                        FieldMapping.target_field_name.ilike(search_term),
                        FieldMapping.notes.ilike(search_term)
                    )
                )
            current_app.logger.debug("Filtres appliqués avec succès")
        except Exception as filter_error:
            current_app.logger.error(f"Erreur lors de l'application des filtres: {str(filter_error)}")
            return jsonify({"error": "Erreur lors de l'application des filtres"}), 500
        
        # Tri par défaut : dernière modification en premier
        try:
            query = query.order_by(FieldMapping.updated_at.desc())
            current_app.logger.debug("Tri appliqué avec succès")
        except Exception as sort_error:
            current_app.logger.error(f"Erreur lors du tri: {str(sort_error)}")
            return jsonify({"error": "Erreur lors du tri des résultats"}), 500
        
        # Pagination
        try:
            # Récupération de tous les résultats et pagination manuelle pour éviter les problèmes
            all_mappings = query.all()
            total = len(all_mappings)
            
            # Calcul des indices pour la pagination manuelle
            start = (page - 1) * per_page
            end = min(start + per_page, total)
            
            # Découpage manuel des résultats
            paginated_items = all_mappings[start:end] if start < total else []
            
            mappings = [m.to_dict() for m in paginated_items]
            
            # Calcul manuel du nombre de pages
            pages = (total + per_page - 1) // per_page if per_page > 0 else 1
            
            current_app.logger.debug(f"Pagination appliquée avec succès: {len(mappings)} résultats sur {total} total")
            
            response = {
                'mappings': mappings,
                'total': total,
                'page': page,
                'per_page': per_page,
                'pages': pages
            }
            
            return jsonify(response), 200
            
        except Exception as pagination_error:
            current_app.logger.error(f"Erreur lors de la pagination: {str(pagination_error)}")
            return jsonify({"error": "Erreur lors de la pagination des résultats"}), 500
    
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des mappings: {str(e)}")
        # Afficher la trace complète pour le débogage
        import traceback
        current_app.logger.error(traceback.format_exc())
        return jsonify({"error": "Erreur lors de la récupération des mappings"}), 500

@field_mapping_blueprint.route('/field-mappings/<int:mapping_id>', methods=['GET'])
# @jwt_required()
def get_field_mapping(mapping_id):
    """Récupère un mapping spécifique par son ID"""
    try:
        mapping = FieldMapping.query.get(mapping_id)
        
        if not mapping:
            return jsonify({"error": "Mapping non trouvé"}), 404
            
        return jsonify(mapping.to_dict()), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération du mapping {mapping_id}: {str(e)}")
        return jsonify({"error": "Erreur lors de la récupération du mapping"}), 500

@field_mapping_blueprint.route('/field-mappings', methods=['POST'])
# @jwt_required()
def create_field_mapping():
    """Crée un nouveau mapping de champs"""
    try:
        # Pour le développement, on utilise un utilisateur fixe
        # user_id = get_jwt_identity()
        user_id = "user_dev"
        
        data = request.get_json()
        if not data:
            return jsonify({"error": "Données manquantes"}), 400
            
        # Vérification des champs obligatoires
        required_fields = ['source_table_name', 'source_field_name', 'target_table', 'target_field_name']
        for field in required_fields:
            if field not in data:
                return jsonify({"error": f"Le champ {field} est obligatoire"}), 400
                
        # Ajout des métadonnées
        data['created_by'] = user_id
        data['updated_by'] = user_id
        
        # Création du mapping
        mapping = FieldMapping.from_dict(data)
        
        db.session.add(mapping)
        db.session.commit()
        
        return jsonify(mapping.to_dict()), 201
        
    except IntegrityError as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur d'intégrité lors de la création du mapping: {str(e)}")
        return jsonify({"error": "Un mapping avec ces paramètres existe déjà"}), 409
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur lors de la création du mapping: {str(e)}")
        return jsonify({"error": "Erreur lors de la création du mapping"}), 500

@field_mapping_blueprint.route('/field-mappings/<int:mapping_id>', methods=['PUT'])
# @jwt_required()
def update_field_mapping(mapping_id):
    """Met à jour un mapping existant"""
    try:
        # Pour le développement, on utilise un utilisateur fixe
        # user_id = get_jwt_identity()
        user_id = "user_dev"
        
        mapping = FieldMapping.query.get(mapping_id)
        if not mapping:
            return jsonify({"error": "Mapping non trouvé"}), 404
            
        data = request.get_json()
        if not data:
            return jsonify({"error": "Données manquantes"}), 400
            
        # Ajout des métadonnées de mise à jour
        data['updated_by'] = user_id
        
        # Mise à jour du mapping
        updated_mapping = FieldMapping.from_dict(data, existing_mapping=mapping)
        
        db.session.commit()
        
        return jsonify(updated_mapping.to_dict()), 200
        
    except IntegrityError as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur d'intégrité lors de la mise à jour du mapping: {str(e)}")
        return jsonify({"error": "Un mapping avec ces paramètres existe déjà"}), 409
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur lors de la mise à jour du mapping {mapping_id}: {str(e)}")
        return jsonify({"error": "Erreur lors de la mise à jour du mapping"}), 500

@field_mapping_blueprint.route('/field-mappings/<int:mapping_id>', methods=['DELETE'])
# @jwt_required()
def delete_field_mapping(mapping_id):
    """Supprime un mapping"""
    try:
        mapping = FieldMapping.query.get(mapping_id)
        
        if not mapping:
            return jsonify({"error": "Mapping non trouvé"}), 404
            
        db.session.delete(mapping)
        db.session.commit()
        
        return jsonify({"message": "Mapping supprimé avec succès"}), 200
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur lors de la suppression du mapping {mapping_id}: {str(e)}")
        return jsonify({"error": "Erreur lors de la suppression du mapping"}), 500

@field_mapping_blueprint.route('/field-mappings/bulk-action', methods=['POST'])
# @jwt_required()
def bulk_action():
    """Effectue une action sur plusieurs mappings en une seule fois"""
    try:
        data = request.get_json()
        if not data or 'action' not in data or 'mapping_ids' not in data:
            return jsonify({"error": "Données manquantes"}), 400
            
        action = data['action']
        mapping_ids = data['mapping_ids']
        
        if not mapping_ids or not isinstance(mapping_ids, list):
            return jsonify({"error": "Liste d'IDs invalide"}), 400
            
        # Pour le développement, on utilise un utilisateur fixe
        # user_id = get_jwt_identity()
        user_id = "user_dev"
        
        if action == 'activate':
            # Activer les mappings sélectionnés
            count = FieldMapping.query.filter(FieldMapping.id.in_(mapping_ids)).update(
                {'is_active': True, 'updated_by': user_id, 'updated_at': datetime.utcnow()},
                synchronize_session=False
            )
            db.session.commit()
            return jsonify({"message": f"{count} mappings activés"}), 200
            
        elif action == 'deactivate':
            # Désactiver les mappings sélectionnés
            count = FieldMapping.query.filter(FieldMapping.id.in_(mapping_ids)).update(
                {'is_active': False, 'updated_by': user_id, 'updated_at': datetime.utcnow()},
                synchronize_session=False
            )
            db.session.commit()
            return jsonify({"message": f"{count} mappings désactivés"}), 200
            
        elif action == 'delete':
            # Supprimer les mappings sélectionnés
            count = FieldMapping.query.filter(FieldMapping.id.in_(mapping_ids)).delete(
                synchronize_session=False
            )
            db.session.commit()
            return jsonify({"message": f"{count} mappings supprimés"}), 200
            
        else:
            return jsonify({"error": "Action non supportée"}), 400
            
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur lors de l'action groupée: {str(e)}")
        return jsonify({"error": "Erreur lors de l'action groupée"}), 500

@field_mapping_blueprint.route('/field-mappings/import', methods=['POST'])
# @jwt_required()
def import_mappings():
    """Importe des mappings depuis un fichier CSV ou Excel"""
    try:
        if 'file' not in request.files:
            return jsonify({"error": "Aucun fichier fourni"}), 400
            
        file = request.files['file']
        if file.filename == '':
            return jsonify({"error": "Nom de fichier vide"}), 400
            
        # Pour le développement, on utilise un utilisateur fixe
        # user_id = get_jwt_identity()
        user_id = "user_dev"
        
        # Vérification de l'extension
        if file.filename.endswith('.csv'):
            # Traitement du CSV
            stream = io.StringIO(file.stream.read().decode("utf-8"), newline='')
            reader = csv.DictReader(stream)
            
            successful = 0
            failed = 0
            errors = []
            
            for row in reader:
                try:
                    # Conversion des valeurs booléennes
                    if 'is_active' in row:
                        row['is_active'] = row['is_active'].lower() in ('true', 'yes', '1')
                    if 'is_key' in row:
                        row['is_key'] = row['is_key'].lower() in ('true', 'yes', '1')
                        
                    # Validation des champs obligatoires
                    required_fields = ['source_table_name', 'source_field_name', 'target_table', 'target_field_name']
                    if not all(field in row and row[field] for field in required_fields):
                        failed += 1
                        errors.append(f"Ligne {reader.line_num}: Champs obligatoires manquants")
                        continue
                        
                    # Vérification si le mapping existe déjà
                    existing = FieldMapping.query.filter_by(
                        source_table_name=row['source_table_name'],
                        source_field_name=row['source_field_name'],
                        target_table=row['target_table'],
                        target_field_name=row['target_field_name']
                    ).first()
                    
                    if existing:
                        # Mise à jour
                        row['updated_by'] = user_id
                        FieldMapping.from_dict(row, existing_mapping=existing)
                    else:
                        # Création
                        row['created_by'] = user_id
                        row['updated_by'] = user_id
                        new_mapping = FieldMapping.from_dict(row)
                        db.session.add(new_mapping)
                        
                    successful += 1
                    
                except Exception as e:
                    failed += 1
                    errors.append(f"Ligne {reader.line_num}: {str(e)}")
                    
            db.session.commit()
            
            return jsonify({
                "message": f"Import terminé avec {successful} succès et {failed} échecs",
                "errors": errors
            }), 200
            
        else:
            return jsonify({"error": "Format de fichier non supporté"}), 400
            
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur lors de l'import: {str(e)}")
        return jsonify({"error": "Erreur lors de l'import"}), 500

@field_mapping_blueprint.route('/field-mappings/export', methods=['GET'])
# @jwt_required()
def export_mappings():
    """Exporte les mappings filtrés au format CSV"""
    try:
        # Récupération des paramètres de filtrage
        source_table = request.args.get('source_table', '')
        target_table = request.args.get('target_table', '')
        status = request.args.get('status', 'all')  # 'active', 'inactive', 'all'
        use_column_names = request.args.get('useColumnNames', 'false').lower() == 'true'
        
        # Création de la requête de base
        query = FieldMapping.query
        
        # Application des filtres
        if source_table:
            query = query.filter(FieldMapping.source_table_name == source_table)
        if target_table:
            query = query.filter(FieldMapping.target_table == target_table)
        if status == 'active':
            query = query.filter(FieldMapping.is_active == True)
        elif status == 'inactive':
            query = query.filter(FieldMapping.is_active == False)
        
        # Récupération de tous les mappings filtrés
        mappings = query.all()
          # Création du CSV
        output = io.StringIO()
        fieldnames = [
            'id', 'source_table_name', 'source_field_name', 'target_table', 'target_field_name',
            'is_active', 'transformation_rule', 'data_type', 'is_key', 'notes'
        ]
        
        writer = csv.DictWriter(output, fieldnames=fieldnames, delimiter=';')
        writer.writeheader()
        
        for mapping in mappings:
            row = {
                'id': mapping.id,
                'source_table_name': mapping.source_table_name,
                'source_field_name': mapping.source_field_name,
                'target_table': mapping.target_table,
                'target_field_name': mapping.target_field_name,
                'is_active': mapping.is_active,
                'transformation_rule': mapping.transformation_rule,
                'data_type': mapping.data_type,
                'is_key': mapping.is_key,
                'notes': mapping.notes
            }
            writer.writerow(row)
          # Configuration de la réponse
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"field_mappings_{timestamp}.csv"
        
        return output.getvalue(), 200, {
            'Content-Type': 'text/csv',
            'Content-Disposition': f'attachment; filename="{filename}"'
        }
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de l'export: {str(e)}")
        return jsonify({"error": "Erreur lors de l'export"}), 500

@field_mapping_blueprint.route('/field-mappings/tables-info', methods=['GET'])
# @jwt_required()
def get_tables_info():
    """Récupère les informations sur les tables source et cible disponibles"""
    try:
        data_service = get_data_service()
        
        # Récupération des tables source (SAP)
        source_tables = []
        try:
            sap_tables = data_service.get_sap_tables(page=1, limit=1000, search='')
            if 'tables' in sap_tables:
                source_tables = [{'name': t['name'], 'description': t.get('description', t['name'])} for t in sap_tables['tables']]
        except Exception as e:
            current_app.logger.warning(f"Erreur lors de la récupération des tables source: {str(e)}")
        
        # Récupération des tables cible (IFS)
        target_tables = []
        try:
            # On suppose que cette méthode existe ou sera créée pour récupérer les tables IFS
            ifs_tables = data_service.get_ifs_tables()
            target_tables = [{'name': t['name'], 'description': t.get('description', t['name'])} for t in ifs_tables]
        except Exception as e:
            current_app.logger.warning(f"Erreur lors de la récupération des tables cible: {str(e)}")
            # Fallback sur les valeurs statiques de l'API ifs_tables
            from api.ifs_tables import IFS_TABLES
            target_tables = [{'name': t['name'], 'description': t['label']} for t in IFS_TABLES]
        
        return jsonify({
            "source_tables": source_tables,
            "target_tables": target_tables
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des informations sur les tables: {str(e)}")
        return jsonify({"error": "Erreur lors de la récupération des informations sur les tables"}), 500