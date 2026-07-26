from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import (
    create_access_token, create_refresh_token,
    jwt_required, get_jwt_identity, get_jwt
)
from datetime import datetime, timedelta
import uuid
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

from models import db, User
from utils.auth_decorators import admin_required, require_role

auth_blueprint = Blueprint('auth', __name__)

@auth_blueprint.route('/login', methods=['POST'])
def login():
    """Authentification de l'utilisateur et génération du JWT"""
    try:
        # Récupération et validation des données
        data = request.get_json()
        if not data:
            return jsonify({'error': 'Données manquantes'}), 400
            
        username = data.get('username')
        password = data.get('password')
        
        if not username or not password:
            return jsonify({'error': 'Nom d\'utilisateur et mot de passe requis'}), 400
        
        # Vérification de l'utilisateur dans la base de données
        user = User.query.filter_by(username=username).first()
        
        if not user or not user.verify_password(password):
            return jsonify({'error': 'Nom d\'utilisateur ou mot de passe incorrect'}), 401
        
        if not user.is_active:
            return jsonify({'error': 'Compte désactivé'}), 403
        
        # Mise à jour de la dernière connexion
        user.last_login = datetime.now()
        db.session.commit()
        
        # Génération des tokens avec claims personnalisés incluant le rôle
        additional_claims = {"role": user.role}
        access_token = create_access_token(identity=user.id, additional_claims=additional_claims)
        refresh_token = create_refresh_token(identity=user.id)
        
        current_app.logger.info(f"Utilisateur {user.username} ({user.role}) connecté avec succès")
        
        return jsonify({
            'user': user.to_dict(),
            'access_token': access_token,
            'refresh_token': refresh_token
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la connexion: {str(e)}")
        return jsonify({'error': 'Erreur lors de la connexion'}), 500

@auth_blueprint.route('/refresh', methods=['POST'])
@jwt_required(refresh=True)
def refresh():
    """Rafraîchissement du token d'accès"""
    try:
        current_user_id = get_jwt_identity()
        user = User.query.get(current_user_id)
        
        if not user or not user.is_active:
            return jsonify({'error': 'Utilisateur non trouvé ou désactivé'}), 401
            
        # Inclure le rôle dans le nouveau token
        additional_claims = {"role": user.role}
        access_token = create_access_token(identity=current_user_id, additional_claims=additional_claims)
        
        return jsonify({'access_token': access_token}), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors du rafraîchissement du token: {str(e)}")
        return jsonify({'error': 'Erreur lors du rafraîchissement du token'}), 500

@auth_blueprint.route('/me', methods=['GET'])
@jwt_required()
def get_user_info():
    """Récupère les informations de l'utilisateur connecté"""
    try:
        current_user_id = get_jwt_identity()
        user = User.query.get(current_user_id)
        
        if not user:
            return jsonify({'error': 'Utilisateur non trouvé'}), 404
            
        return jsonify(user.to_dict()), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des informations utilisateur: {str(e)}")
        return jsonify({'error': 'Erreur interne du serveur'}), 500

@auth_blueprint.route('/logout', methods=['POST'])
@jwt_required()
def logout():
    """Déconnexion de l'utilisateur"""
    try:
        # Dans une implémentation plus complète, on pourrait ajouter le token à une liste noire
        current_user_id = get_jwt_identity()
        user = User.query.get(current_user_id)
        
        if user:
            current_app.logger.info(f"Utilisateur {user.username} ({user.role}) déconnecté")
        
        return jsonify({'message': 'Déconnexion réussie'}), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la déconnexion: {str(e)}")
        return jsonify({'error': 'Erreur lors de la déconnexion'}), 500

@auth_blueprint.route('/users', methods=['GET'])
@admin_required
def get_users():
    """Récupère la liste des utilisateurs (Admin seulement)"""
    try:
        users = User.query.all()
        return jsonify([user.to_dict() for user in users]), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des utilisateurs: {str(e)}")
        return jsonify({'error': 'Erreur interne du serveur'}), 500

@auth_blueprint.route('/users', methods=['POST'])
@admin_required
def create_user():
    """Crée un nouvel utilisateur (Admin seulement)"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'Données manquantes'}), 400
        
        required_fields = ['username', 'email', 'password', 'role']
        for field in required_fields:
            if not data.get(field):
                return jsonify({'error': f'Champ requis: {field}'}), 400
        
        if data['role'] not in ['admin', 'operator']:
            return jsonify({'error': 'Rôle invalide. Utilisez "admin" ou "operator"'}), 400
        
        # Vérifier si l'utilisateur existe déjà
        if User.query.filter_by(username=data['username']).first():
            return jsonify({'error': 'Nom d\'utilisateur déjà utilisé'}), 409
            
        if User.query.filter_by(email=data['email']).first():
            return jsonify({'error': 'Email déjà utilisé'}), 409
        
        # Créer l'utilisateur
        user = User(
            username=data['username'],
            email=data['email'],
            role=data['role']
        )
        user.password = data['password']
        
        db.session.add(user)
        db.session.commit()
        
        current_app.logger.info(f"Nouvel utilisateur créé: {user.username} ({user.role})")
        
        return jsonify(user.to_dict()), 201
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur lors de la création de l'utilisateur: {str(e)}")
        return jsonify({'error': 'Erreur lors de la création de l\'utilisateur'}), 500

@auth_blueprint.route('/users/<user_id>', methods=['PUT'])
@admin_required
def update_user(user_id):
    """Met à jour un utilisateur (Admin seulement)"""
    try:
        user = User.query.get(user_id)
        if not user:
            return jsonify({'error': 'Utilisateur non trouvé'}), 404
        
        data = request.get_json()
        if not data:
            return jsonify({'error': 'Données manquantes'}), 400
        
        # Mise à jour des champs autorisés
        if 'username' in data:
            if User.query.filter(User.username == data['username'], User.id != user_id).first():
                return jsonify({'error': 'Nom d\'utilisateur déjà utilisé'}), 409
            user.username = data['username']
            
        if 'email' in data:
            if User.query.filter(User.email == data['email'], User.id != user_id).first():
                return jsonify({'error': 'Email déjà utilisé'}), 409
            user.email = data['email']
            
        if 'role' in data:
            if data['role'] not in ['admin', 'operator']:
                return jsonify({'error': 'Rôle invalide. Utilisez "admin" ou "operator"'}), 400
            user.role = data['role']
            
        if 'is_active' in data:
            user.is_active = bool(data['is_active'])
            
        if 'password' in data:
            user.password = data['password']
        
        db.session.commit()
        
        current_app.logger.info(f"Utilisateur mis à jour: {user.username} ({user.role})")
        
        return jsonify(user.to_dict()), 200
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur lors de la mise à jour de l'utilisateur: {str(e)}")
        return jsonify({'error': 'Erreur lors de la mise à jour de l\'utilisateur'}), 500

@auth_blueprint.route('/forgot-password', methods=['POST'])
def forgot_password():
    """Envoie un email de réinitialisation de mot de passe"""
    try:
        data = request.get_json()
        email = data.get('email', '').strip() if data else ''

        if not email:
            return jsonify({'error': 'Email requis'}), 400

        user = User.query.filter_by(email=email).first()
        if not user or not user.is_active:
            return jsonify({'message': 'Si un compte existe avec cet email, un lien de réinitialisation a été envoyé.'}), 200

        token = str(uuid.uuid4())
        expiry_seconds = current_app.config.get('PASSWORD_RESET_EXPIRY', 3600)
        user.reset_token = token
        user.reset_token_expiry = datetime.utcnow() + timedelta(seconds=expiry_seconds)
        db.session.commit()

        frontend_url = current_app.config.get('FRONTEND_URL', 'http://localhost:3000')
        reset_link = f"{frontend_url}/reset-password?token={token}"

        smtp_server = current_app.config.get('SMTP_SERVER', '')
        if not smtp_server:
            current_app.logger.error("SMTP non configuré – impossible d'envoyer l'email de réinitialisation")
            return jsonify({'error': 'Le serveur SMTP n\'est pas configuré. Contactez l\'administrateur.'}), 503

        smtp_port = current_app.config.get('SMTP_PORT', 587)
        smtp_use_tls = current_app.config.get('SMTP_USE_TLS', True)
        smtp_username = current_app.config.get('SMTP_USERNAME', '')
        smtp_password = current_app.config.get('SMTP_PASSWORD', '')
        from_email = current_app.config.get('SMTP_FROM_EMAIL', smtp_username)
        from_name = current_app.config.get('SMTP_FROM_NAME', 'Migration Factory')

        msg = MIMEMultipart('alternative')
        msg['Subject'] = 'Réinitialisation de votre mot de passe'
        msg['From'] = f"{from_name} <{from_email}>"
        msg['To'] = email

        html_body = f"""
        <html><body>
        <h2>Réinitialisation de mot de passe</h2>
        <p>Bonjour <strong>{user.username}</strong>,</p>
        <p>Vous avez demandé la réinitialisation de votre mot de passe.</p>
        <p><a href="{reset_link}" style="background:#1976d2;color:#fff;padding:10px 20px;text-decoration:none;border-radius:4px;">Réinitialiser mon mot de passe</a></p>
        <p>Ce lien expire dans {expiry_seconds // 60} minutes.</p>
        <p>Si vous n'avez pas fait cette demande, ignorez cet email.</p>
        </body></html>
        """
        msg.attach(MIMEText(html_body, 'html'))

        try:
            server = smtplib.SMTP(smtp_server, smtp_port, timeout=10)
            if smtp_use_tls:
                server.starttls()
            if smtp_username and smtp_password:
                server.login(smtp_username, smtp_password)
            server.sendmail(from_email, [email], msg.as_string())
            server.quit()
            current_app.logger.info(f"Email de réinitialisation envoyé à {email}")
        except Exception as smtp_err:
            current_app.logger.error(f"Erreur SMTP: {str(smtp_err)}")
            return jsonify({'error': f'Erreur lors de l\'envoi de l\'email: {str(smtp_err)}'}), 500

        return jsonify({'message': 'Si un compte existe avec cet email, un lien de réinitialisation a été envoyé.'}), 200

    except Exception as e:
        current_app.logger.error(f"Erreur forgot-password: {str(e)}")
        return jsonify({'error': 'Erreur interne'}), 500


@auth_blueprint.route('/reset-password', methods=['POST'])
def reset_password():
    """Réinitialise le mot de passe avec un token valide"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'Données manquantes'}), 400

        token = data.get('token', '').strip()
        new_password = data.get('password', '').strip()

        if not token or not new_password:
            return jsonify({'error': 'Token et nouveau mot de passe requis'}), 400

        if len(new_password) < 6:
            return jsonify({'error': 'Le mot de passe doit contenir au moins 6 caractères'}), 400

        user = User.query.filter_by(reset_token=token).first()
        if not user:
            return jsonify({'error': 'Token invalide ou expiré'}), 400

        if user.reset_token_expiry and user.reset_token_expiry < datetime.utcnow():
            user.reset_token = None
            user.reset_token_expiry = None
            db.session.commit()
            return jsonify({'error': 'Token expiré. Veuillez refaire une demande.'}), 400

        user.password = new_password
        user.reset_token = None
        user.reset_token_expiry = None
        db.session.commit()

        current_app.logger.info(f"Mot de passe réinitialisé pour {user.username}")
        return jsonify({'message': 'Mot de passe réinitialisé avec succès'}), 200

    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur reset-password: {str(e)}")
        return jsonify({'error': 'Erreur interne'}), 500


@auth_blueprint.route('/smtp-config', methods=['GET'])
@admin_required
def get_smtp_config():
    """Retourne la configuration SMTP actuelle (sans le mot de passe)"""
    return jsonify({
        'smtp_server': current_app.config.get('SMTP_SERVER', ''),
        'smtp_port': current_app.config.get('SMTP_PORT', 587),
        'smtp_use_tls': current_app.config.get('SMTP_USE_TLS', True),
        'smtp_username': current_app.config.get('SMTP_USERNAME', ''),
        'smtp_from_email': current_app.config.get('SMTP_FROM_EMAIL', ''),
        'smtp_from_name': current_app.config.get('SMTP_FROM_NAME', 'Migration Factory'),
        'password_reset_expiry': current_app.config.get('PASSWORD_RESET_EXPIRY', 3600),
        'frontend_url': current_app.config.get('FRONTEND_URL', 'http://localhost:3000'),
    }), 200


@auth_blueprint.route('/smtp-config', methods=['PUT'])
@admin_required
def update_smtp_config():
    """Met à jour la configuration SMTP en runtime"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'Données manquantes'}), 400

        allowed_keys = {
            'smtp_server': 'SMTP_SERVER',
            'smtp_port': 'SMTP_PORT',
            'smtp_use_tls': 'SMTP_USE_TLS',
            'smtp_username': 'SMTP_USERNAME',
            'smtp_password': 'SMTP_PASSWORD',
            'smtp_from_email': 'SMTP_FROM_EMAIL',
            'smtp_from_name': 'SMTP_FROM_NAME',
            'password_reset_expiry': 'PASSWORD_RESET_EXPIRY',
            'frontend_url': 'FRONTEND_URL',
        }

        for key, config_key in allowed_keys.items():
            if key in data:
                current_app.config[config_key] = data[key]

        current_app.logger.info("Configuration SMTP mise à jour")
        return jsonify({'message': 'Configuration SMTP mise à jour'}), 200

    except Exception as e:
        current_app.logger.error(f"Erreur update SMTP config: {str(e)}")
        return jsonify({'error': 'Erreur interne'}), 500


@auth_blueprint.route('/smtp-config/test', methods=['POST'])
@admin_required
def test_smtp_config():
    """Envoie un email de test pour vérifier la configuration SMTP"""
    try:
        data = request.get_json()
        test_email = data.get('email', '') if data else ''

        if not test_email:
            return jsonify({'error': 'Email de test requis'}), 400

        smtp_server = current_app.config.get('SMTP_SERVER', '')
        if not smtp_server:
            return jsonify({'error': 'Serveur SMTP non configuré'}), 400

        smtp_port = current_app.config.get('SMTP_PORT', 587)
        smtp_use_tls = current_app.config.get('SMTP_USE_TLS', True)
        smtp_username = current_app.config.get('SMTP_USERNAME', '')
        smtp_password = current_app.config.get('SMTP_PASSWORD', '')
        from_email = current_app.config.get('SMTP_FROM_EMAIL', smtp_username)
        from_name = current_app.config.get('SMTP_FROM_NAME', 'Migration Factory')

        msg = MIMEText('Ceci est un email de test depuis Migration Factory. La configuration SMTP fonctionne correctement.')
        msg['Subject'] = '[Test] Configuration SMTP Migration Factory'
        msg['From'] = f"{from_name} <{from_email}>"
        msg['To'] = test_email

        server = smtplib.SMTP(smtp_server, smtp_port, timeout=10)
        if smtp_use_tls:
            server.starttls()
        if smtp_username and smtp_password:
            server.login(smtp_username, smtp_password)
        server.sendmail(from_email, [test_email], msg.as_string())
        server.quit()

        return jsonify({'message': f'Email de test envoyé à {test_email}'}), 200

    except Exception as e:
        current_app.logger.error(f"Erreur test SMTP: {str(e)}")
        return jsonify({'error': f'Erreur SMTP: {str(e)}'}), 500


@auth_blueprint.route('/permissions', methods=['GET'])
@jwt_required()
def get_user_permissions():
    """Récupère les permissions de l'utilisateur connecté"""
    try:
        current_user_id = get_jwt_identity()
        user = User.query.get(current_user_id)
        
        if not user:
            return jsonify({'error': 'Utilisateur non trouvé'}), 404
        
        permissions = {
            'role': user.role,
            'permissions': {
                'manage_users': user.has_permission('manage_users'),
                'view_all_data': user.has_permission('view_all_data'),
                'configure_system': user.has_permission('configure_system'),
                'view_sap_data': user.has_permission('view_sap_data'),
                'view_ifs_data': user.has_permission('view_ifs_data'),
                'view_dashboards': user.has_permission('view_dashboards'),
                'export_data': user.has_permission('export_data'),
                'manage_mappings': user.has_permission('manage_mappings'),
                'manage_transcodification': user.has_permission('manage_transcodification')
            }
        }
        
        return jsonify(permissions), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des permissions: {str(e)}")
        return jsonify({'error': 'Erreur interne du serveur'}), 500