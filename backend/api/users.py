from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from werkzeug.security import generate_password_hash
from datetime import datetime

from models import db, User
from utils.auth_decorators import admin_required

users_blueprint = Blueprint('users', __name__)

@users_blueprint.route('', methods=['GET'])
@jwt_required()
def get_users():
    """Récupère la liste des utilisateurs"""
    try:
        # Récupération des utilisateurs
        users = User.query.all()
        return jsonify([user.to_dict() for user in users]), 200
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des utilisateurs: {str(e)}")
        return jsonify({'error': 'Erreur interne du serveur'}), 500

@users_blueprint.route('/<user_id>', methods=['GET'])
@jwt_required()
def get_user(user_id):
    """Récupère les informations d'un utilisateur spécifique"""
    try:
        user = User.query.get(user_id)
        
        if not user:
            return jsonify({'error': 'Utilisateur non trouvé'}), 404
            
        return jsonify(user.to_dict()), 200
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération de l'utilisateur: {str(e)}")
        return jsonify({'error': 'Erreur interne du serveur'}), 500

@users_blueprint.route('', methods=['POST'])
@admin_required
def create_user():
    """Crée un nouvel utilisateur"""
    try:
        # Récupération et validation des données
        data = request.get_json()
        if not data:
            return jsonify({'error': 'Données manquantes'}), 400
            
        username = data.get('username')
        email = data.get('email')
        password = data.get('password')
        
        if not username or not email or not password:
            return jsonify({'error': 'Nom d\'utilisateur, email et mot de passe requis'}), 400
        
        # Vérification si l'utilisateur existe déjà
        if User.query.filter_by(username=username).first():
            return jsonify({'error': 'Nom d\'utilisateur déjà utilisé'}), 409
        
        if User.query.filter_by(email=email).first():
            return jsonify({'error': 'Email déjà utilisé'}), 409
        
        # Création du nouvel utilisateur
        new_user = User(
            username=username,
            email=email,
            is_active=True,
            created_at=datetime.utcnow()
        )
        new_user.password = password  # Utilise le setter qui fait le hash
        
        # Ajout à la base de données
        db.session.add(new_user)
        db.session.commit()
        
        current_app.logger.info(f"Nouvel utilisateur créé: {username}")
        
        return jsonify(new_user.to_dict()), 201
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur lors de la création de l'utilisateur: {str(e)}")
        return jsonify({'error': 'Erreur lors de la création de l\'utilisateur'}), 500

@users_blueprint.route('/<user_id>', methods=['PUT'])
@admin_required
def update_user(user_id):
    """Met à jour les informations d'un utilisateur"""
    try:
        current_app.logger.info(f"🔧 Début update_user pour ID: {user_id}")
        user = User.query.get(user_id)
        
        if not user:
            return jsonify({'error': 'Utilisateur non trouvé'}), 404
        
        current_app.logger.info(f"👤 Utilisateur trouvé: {user.username}, role actuel: {user.role}")
        
        # Récupération et validation des données
        data = request.get_json()
        if not data:
            return jsonify({'error': 'Données manquantes'}), 400
        
        current_app.logger.info(f"📦 Données reçues: {data}")
        
        # Mise à jour des champs
        if 'username' in data:
            current_app.logger.info(f"🔄 Mise à jour username: {data['username']}")
            # Vérification si le nom d'utilisateur est déjà utilisé
            existing_user = User.query.filter_by(username=data['username']).first()
            if existing_user and existing_user.id != user_id:
                return jsonify({'error': 'Nom d\'utilisateur déjà utilisé'}), 409
            user.username = data['username']
            
        if 'email' in data:
            current_app.logger.info(f"📧 Mise à jour email: {data['email']}")
            # Vérification si l'email est déjà utilisé
            existing_user = User.query.filter_by(email=data['email']).first()
            if existing_user and existing_user.id != user_id:
                return jsonify({'error': 'Email déjà utilisé'}), 409
            user.email = data['email']
            
        if 'role' in data:
            current_app.logger.info(f"🎭 Mise à jour role: '{user.role}' -> '{data['role']}'")
            # Validation du rôle
            if data['role'] not in ['admin', 'operator']:
                return jsonify({'error': 'Rôle invalide. Utilisez "admin" ou "operator"'}), 400
            user.role = data['role']
            current_app.logger.info(f"✅ Role assigné dans l'objet: {user.role}")
            
        if 'is_active' in data:
            current_app.logger.info(f"🔲 Mise à jour is_active: {data['is_active']}")
            user.is_active = data['is_active']
        
        # Vérification avant commit
        current_app.logger.info(f"💾 Avant commit - user.role = {user.role}")
        
        # Sauvegarde des modifications
        db.session.commit()
        
        current_app.logger.info(f"✅ COMMIT réussi")
        
        # Vérification après commit
        updated_user = User.query.get(user_id)
        current_app.logger.info(f"📖 Après commit - user.role lu depuis DB = {updated_user.role}")
        
        current_app.logger.info(f"Utilisateur {user.username} mis à jour")
        
        return jsonify(user.to_dict()), 200
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"❌ ERREUR - ROLLBACK effectué: {str(e)}")
        current_app.logger.error(f"Erreur lors de la mise à jour de l'utilisateur: {str(e)}")
        return jsonify({'error': 'Erreur lors de la mise à jour de l\'utilisateur'}), 500

@users_blueprint.route('/<user_id>', methods=['DELETE'])
@admin_required
def delete_user(user_id):
    """Supprime un utilisateur"""
    try:
        user = User.query.get(user_id)
        
        if not user:
            return jsonify({'error': 'Utilisateur non trouvé'}), 404
        
        # Supprimer l'utilisateur
        db.session.delete(user)
        db.session.commit()
        
        current_app.logger.info(f"Utilisateur {user.username} supprimé")
        
        return jsonify({'message': 'Utilisateur supprimé avec succès'}), 200
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur lors de la suppression de l'utilisateur: {str(e)}")
        return jsonify({'error': 'Erreur lors de la suppression de l\'utilisateur'}), 500

@users_blueprint.route('/<user_id>/reset-password', methods=['POST'])
@admin_required
def reset_password(user_id):
    """Réinitialise le mot de passe d'un utilisateur"""
    try:
        user = User.query.get(user_id)
        
        if not user:
            return jsonify({'error': 'Utilisateur non trouvé'}), 404
        
        # Récupération et validation des données
        data = request.get_json()
        if not data or 'newPassword' not in data:
            return jsonify({'error': 'Nouveau mot de passe requis'}), 400
        
        # Mise à jour du mot de passe
        user.password = data['newPassword']
        db.session.commit()
        
        current_app.logger.info(f"Mot de passe réinitialisé pour l'utilisateur {user.username}")
        
        return jsonify({'message': 'Mot de passe réinitialisé avec succès'}), 200
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur lors de la réinitialisation du mot de passe: {str(e)}")
        return jsonify({'error': 'Erreur lors de la réinitialisation du mot de passe'}), 500

@users_blueprint.route('/<user_id>/status', methods=['PATCH'])
@admin_required
def toggle_status(user_id):
    """Active ou désactive un compte utilisateur"""
    try:
        user = User.query.get(user_id)
        
        if not user:
            return jsonify({'error': 'Utilisateur non trouvé'}), 404
        
        # Récupération et validation des données
        data = request.get_json()
        if not data or 'is_active' not in data:
            return jsonify({'error': 'Statut requis'}), 400
        
        # Mise à jour du statut
        user.is_active = data['is_active']
        db.session.commit()
        
        status = "activé" if user.is_active else "désactivé"
        current_app.logger.info(f"Compte de l'utilisateur {user.username} {status}")
        
        return jsonify(user.to_dict()), 200
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur lors de la modification du statut: {str(e)}")
        return jsonify({'error': 'Erreur lors de la modification du statut'}), 500 