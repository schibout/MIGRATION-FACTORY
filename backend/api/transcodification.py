from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from sqlalchemy.exc import SQLAlchemyError, IntegrityError
from werkzeug.exceptions import BadRequest
import csv
import io
from datetime import datetime

from models import db, Transcodification

transcodification_blueprint = Blueprint('transcodification', __name__)

@transcodification_blueprint.route('/transcodifications', methods=['GET'])
# @jwt_required()
def get_transcodifications():
    """Récupère la liste des transcodifications avec pagination et filtres"""
    try:
        # Récupération des paramètres de filtrage et pagination
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 25, type=int)
        category = request.args.get('category', '')
        source_system = request.args.get('source_system', '')
        target_system = request.args.get('target_system', '')
        status = request.args.get('status', 'all')  # 'active', 'inactive', 'all'
        search = request.args.get('search', '')
        
        # Création de la requête de base
        query = Transcodification.query
        
        # Application des filtres
        if category:
            query = query.filter(Transcodification.category == category)
        if source_system:
            query = query.filter(Transcodification.source_system == source_system)
        if target_system:
            query = query.filter(Transcodification.target_system == target_system)
        if status == 'active':
            query = query.filter(Transcodification.is_active == True)
        elif status == 'inactive':
            query = query.filter(Transcodification.is_active == False)
        
        # Recherche textuelle
        if search:
            search_term = f"%{search}%"
            query = query.filter(
                db.or_(
                    Transcodification.category.ilike(search_term),
                    Transcodification.source_value.ilike(search_term),
                    Transcodification.target_value.ilike(search_term),
                    Transcodification.description.ilike(search_term)
                )
            )
        
        # Tri par défaut : catégorie, puis valeur source
        query = query.order_by(Transcodification.category, Transcodification.source_value)
        
        # Pagination
        paginated_transcodifications = query.paginate(page=page, per_page=per_page, error_out=False)
        
        # Préparation de la réponse
        transcodifications = [t.to_dict() for t in paginated_transcodifications.items]
        
        response = {
            'transcodifications': transcodifications,
            'total': paginated_transcodifications.total,
            'page': page,
            'per_page': per_page,
            'pages': paginated_transcodifications.pages
        }
        
        return jsonify(response), 200
    
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des transcodifications: {str(e)}")
        return jsonify({"error": "Erreur lors de la récupération des transcodifications"}), 500

@transcodification_blueprint.route('/transcodifications/<int:transcodification_id>', methods=['GET'])
# @jwt_required()
def get_transcodification(transcodification_id):
    """Récupère une transcodification spécifique par son ID"""
    try:
        transcodification = Transcodification.query.get(transcodification_id)
        
        if not transcodification:
            return jsonify({"error": "Transcodification non trouvée"}), 404
            
        return jsonify(transcodification.to_dict()), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération de la transcodification {transcodification_id}: {str(e)}")
        return jsonify({"error": "Erreur lors de la récupération de la transcodification"}), 500

@transcodification_blueprint.route('/transcodifications', methods=['POST'])
# @jwt_required()
def create_transcodification():
    """Crée une nouvelle transcodification"""
    try:
        # Pour le développement, on utilise un utilisateur fixe
        # user_id = get_jwt_identity()
        user_id = "user_dev"
        
        data = request.get_json()
        if not data:
            return jsonify({"error": "Données manquantes"}), 400
            
        # Vérification des champs obligatoires
        required_fields = ['category', 'source_value', 'target_value']
        for field in required_fields:
            if field not in data:
                return jsonify({"error": f"Le champ {field} est obligatoire"}), 400
                
        # Ajout des métadonnées
        data['created_by'] = user_id
        data['updated_by'] = user_id
        
        # Création de la transcodification
        transcodification = Transcodification.from_dict(data)
        
        db.session.add(transcodification)
        db.session.commit()
        
        return jsonify(transcodification.to_dict()), 201
        
    except IntegrityError as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur d'intégrité lors de la création de la transcodification: {str(e)}")
        return jsonify({"error": "Une transcodification avec ces paramètres existe déjà"}), 409
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur lors de la création de la transcodification: {str(e)}")
        return jsonify({"error": "Erreur lors de la création de la transcodification"}), 500

@transcodification_blueprint.route('/transcodifications/<int:transcodification_id>', methods=['PUT'])
# @jwt_required()
def update_transcodification(transcodification_id):
    """Met à jour une transcodification existante"""
    try:
        # Pour le développement, on utilise un utilisateur fixe
        # user_id = get_jwt_identity()
        user_id = "user_dev"
        
        transcodification = Transcodification.query.get(transcodification_id)
        if not transcodification:
            return jsonify({"error": "Transcodification non trouvée"}), 404
            
        data = request.get_json()
        if not data:
            return jsonify({"error": "Données manquantes"}), 400
            
        # Ajout des métadonnées de mise à jour
        data['updated_by'] = user_id
        
        # Mise à jour de la transcodification
        updated_transcodification = Transcodification.from_dict(data, existing_transcodification=transcodification)
        
        db.session.commit()
        
        return jsonify(updated_transcodification.to_dict()), 200
        
    except IntegrityError as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur d'intégrité lors de la mise à jour de la transcodification: {str(e)}")
        return jsonify({"error": "Une transcodification avec ces paramètres existe déjà"}), 409
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur lors de la mise à jour de la transcodification {transcodification_id}: {str(e)}")
        return jsonify({"error": "Erreur lors de la mise à jour de la transcodification"}), 500

@transcodification_blueprint.route('/transcodifications/<int:transcodification_id>', methods=['DELETE'])
# @jwt_required()
def delete_transcodification(transcodification_id):
    """Supprime une transcodification"""
    try:
        transcodification = Transcodification.query.get(transcodification_id)
        
        if not transcodification:
            return jsonify({"error": "Transcodification non trouvée"}), 404
            
        db.session.delete(transcodification)
        db.session.commit()
        
        return jsonify({"message": "Transcodification supprimée avec succès"}), 200
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur lors de la suppression de la transcodification {transcodification_id}: {str(e)}")
        return jsonify({"error": "Erreur lors de la suppression de la transcodification"}), 500

@transcodification_blueprint.route('/transcodifications/bulk-action', methods=['POST'])
# @jwt_required()
def bulk_action():
    """Effectue une action sur plusieurs transcodifications en une seule fois"""
    try:
        data = request.get_json()
        if not data or 'action' not in data or 'transcodification_ids' not in data:
            return jsonify({"error": "Données manquantes"}), 400
            
        action = data['action']
        transcodification_ids = data['transcodification_ids']
        
        if not transcodification_ids or not isinstance(transcodification_ids, list):
            return jsonify({"error": "Liste d'IDs invalide"}), 400
            
        # Pour le développement, on utilise un utilisateur fixe
        # user_id = get_jwt_identity()
        user_id = "user_dev"
        
        if action == 'activate':
            # Activer les transcodifications sélectionnées
            count = Transcodification.query.filter(Transcodification.id.in_(transcodification_ids)).update(
                {'is_active': True, 'updated_by': user_id, 'updated_at': datetime.utcnow()},
                synchronize_session=False
            )
            db.session.commit()
            return jsonify({"message": f"{count} transcodifications activées"}), 200
            
        elif action == 'deactivate':
            # Désactiver les transcodifications sélectionnées
            count = Transcodification.query.filter(Transcodification.id.in_(transcodification_ids)).update(
                {'is_active': False, 'updated_by': user_id, 'updated_at': datetime.utcnow()},
                synchronize_session=False
            )
            db.session.commit()
            return jsonify({"message": f"{count} transcodifications désactivées"}), 200
            
        elif action == 'delete':
            # Supprimer les transcodifications sélectionnées
            count = Transcodification.query.filter(Transcodification.id.in_(transcodification_ids)).delete(
                synchronize_session=False
            )
            db.session.commit()
            return jsonify({"message": f"{count} transcodifications supprimées"}), 200
            
        elif action == 'duplicate':
            # Dupliquer les transcodifications sélectionnées
            duplicated = 0
            for tid in transcodification_ids:
                original = Transcodification.query.get(tid)
                if original:
                    duplicate = Transcodification(
                        category=original.category,
                        source_system=original.source_system,
                        target_system=original.target_system,
                        source_value=f"{original.source_value}_COPY",
                        target_value=f"{original.target_value}_COPY",
                        description=original.description,
                        created_by=user_id,
                        updated_by=user_id,
                        is_active=original.is_active
                    )
                    db.session.add(duplicate)
                    duplicated += 1
            
            db.session.commit()
            return jsonify({"message": f"{duplicated} transcodifications dupliquées"}), 200
            
        else:
            return jsonify({"error": "Action non supportée"}), 400
            
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur lors de l'action groupée: {str(e)}")
        return jsonify({"error": "Erreur lors de l'action groupée"}), 500

@transcodification_blueprint.route('/transcodifications/import', methods=['POST'])
# @jwt_required()
def import_transcodifications():
    """Importe des transcodifications depuis un fichier CSV ou Excel"""
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
            raw = file.stream.read()
            try:
                text = raw.decode("utf-8-sig")
            except UnicodeDecodeError:
                # Fichiers enregistres par Excel (Windows) : cp1252
                text = raw.decode("cp1252")
            stream = io.StringIO(text, newline='')
            # Détecter automatiquement le délimiteur (virgule ou point-virgule)
            sample = stream.read(1024)
            stream.seek(0)
            delimiter = ',' if sample.count(',') > sample.count(';') else ';'
            current_app.logger.info(f"📋 Délimiteur détecté: '{delimiter}'")
            reader = csv.DictReader(stream, delimiter=delimiter)
            
            created = 0
            updated = 0
            failed = 0
            errors = []
            
            current_app.logger.info(f"🔄 Début de l'import du fichier: {file.filename}")
            current_app.logger.info(f"📋 Colonnes détectées: {reader.fieldnames}")
            
            # Nettoyer les noms de colonnes (enlever les guillemets)
            if reader.fieldnames:
                reader.fieldnames = [field.strip('"').strip() for field in reader.fieldnames]
                current_app.logger.info(f"📋 Colonnes nettoyées: {reader.fieldnames}")
            
            # Lecture complete : une categorie vide reprend celle de la ligne precedente,
            # et une meme cle presente plusieurs fois dans le fichier est ecrasee (la derniere gagne)
            lignes = {}
            doublons = 0
            derniere_categorie = ''
            for row in reader:
                row = {k: (v or '').strip() for k, v in row.items() if k}
                row['category'] = row.get('category') or derniere_categorie
                derniere_categorie = row['category']
                row['source_system'] = row.get('source_system') or 'SAP'
                row['target_system'] = row.get('target_system') or 'IFS'
                row['is_active'] = row.get('is_active', 'true').lower() in ('true', 'yes', '1', '')
                if not (row['category'] and row.get('source_value') and row.get('target_value')):
                    failed += 1
                    errors.append(f"Ligne {reader.line_num}: Champs obligatoires manquants")
                    continue
                cle = (row['category'], row['source_system'], row['target_system'], row['source_value'])
                if lignes.pop(cle, None):
                    doublons += 1
                lignes[cle] = (reader.line_num, row)

            for line_num, row in lignes.values():
                try:
                    # Savepoint par ligne : une erreur n'annule pas les lignes deja traitees
                    with db.session.begin_nested():
                        existing = Transcodification.query.filter_by(
                            category=row['category'],
                            source_system=row['source_system'],
                            target_system=row['target_system'],
                            source_value=row['source_value']
                        ).first()
                        row['updated_by'] = user_id
                        if existing:
                            Transcodification.from_dict(row, existing_transcodification=existing)
                        else:
                            row['created_by'] = user_id
                            db.session.add(Transcodification.from_dict(row))
                        db.session.flush()
                    if existing:
                        updated += 1
                    else:
                        created += 1
                except Exception as e:
                    failed += 1
                    errors.append(f"Ligne {line_num}: {str(e)}")
                    current_app.logger.error(f"❌ Erreur ligne {line_num}: {str(e)}")

            # Commit final pour les lignes restantes
            db.session.commit()
            
            # Compter les lignes uniques en base
            total_in_db = Transcodification.query.count()
            current_app.logger.info(f"✅ Import terminé: {created} créées, {updated} mises à jour, {failed} échecs")
            current_app.logger.info(f"📊 Total en base: {total_in_db} transcodifications")
            
            return jsonify({
                "message": f"Import terminé: {created} créées, {updated} mises à jour, {doublons} doublons écrasés, {failed} échecs",
                "errors": errors
            }), 200
            
        else:
            return jsonify({"error": "Format de fichier non supporté"}), 400
            
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur lors de l'import: {str(e)}")
        return jsonify({"error": "Erreur lors de l'import"}), 500

@transcodification_blueprint.route('/transcodifications/export', methods=['GET'])
# @jwt_required()
def export_transcodifications():
    """Exporte les transcodifications filtrées au format CSV"""
    try:
        # Récupération des paramètres de filtrage
        category = request.args.get('category', '')
        source_system = request.args.get('source_system', '')
        target_system = request.args.get('target_system', '')
        status = request.args.get('status', 'all')  # 'active', 'inactive', 'all'
        use_column_names = request.args.get('useColumnNames', 'false').lower() == 'true'
        
        # Création de la requête de base
        query = Transcodification.query
        
        # Application des filtres
        if category:
            query = query.filter(Transcodification.category == category)
        if source_system:
            query = query.filter(Transcodification.source_system == source_system)
        if target_system:
            query = query.filter(Transcodification.target_system == target_system)
        if status == 'active':
            query = query.filter(Transcodification.is_active == True)
        elif status == 'inactive':
            query = query.filter(Transcodification.is_active == False)
        
        # Tri par catégorie puis valeur source
        query = query.order_by(Transcodification.category, Transcodification.source_value)
        
        # Récupération de toutes les transcodifications filtrées
        transcodifications = query.all()
          # Création du CSV
        output = io.StringIO()
        fieldnames = [
            'category', 'source_system', 'target_system', 'source_value', 'target_value',
            'description', 'is_active'
        ]
        
        writer = csv.DictWriter(output, fieldnames=fieldnames, delimiter=';')
        writer.writeheader()
        
        for transcodification in transcodifications:
            row = {
                'category': transcodification.category,
                'source_system': transcodification.source_system,
                'target_system': transcodification.target_system,
                'source_value': transcodification.source_value,
                'target_value': transcodification.target_value,
                'description': transcodification.description,
                'is_active': transcodification.is_active
            }
            writer.writerow(row)
          # Configuration de la réponse
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"transcodifications_{timestamp}.csv"
        
        return output.getvalue(), 200, {
            'Content-Type': 'text/csv',
            'Content-Disposition': f'attachment; filename="{filename}"'
        }
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de l'export: {str(e)}")
        return jsonify({"error": "Erreur lors de l'export"}), 500

@transcodification_blueprint.route('/transcodifications/categories', methods=['GET'])
# @jwt_required()
def get_categories():
    """Récupère la liste des catégories disponibles"""
    try:
        # Utiliser une requête distincte pour récupérer les catégories uniques
        categories = db.session.query(Transcodification.category).distinct().order_by(Transcodification.category).all()
        
        # Convertir le résultat en liste simple
        category_list = [category[0] for category in categories]
        
        # Si aucune catégorie n'existe encore, renvoyer des valeurs par défaut
        if not category_list:
            category_list = ['LANGUAGE', 'COUNTRY', 'CURRENCY', 'UOM']
        
        return jsonify(category_list), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des catégories: {str(e)}")
        return jsonify({"error": "Erreur lors de la récupération des catégories"}), 500 