from functools import wraps
from flask import jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import User

def require_role(*allowed_roles):
    """Décorateur pour vérifier les rôles d'utilisateur"""
    def decorator(f):
        @wraps(f)
        @jwt_required()
        def decorated_function(*args, **kwargs):
            try:
                current_user_id = get_jwt_identity()
                user = User.query.get(current_user_id)
                
                if not user:
                    return jsonify({'error': 'Utilisateur non trouvé'}), 404
                
                if not user.is_active:
                    return jsonify({'error': 'Compte désactivé'}), 403
                
                if user.role not in allowed_roles:
                    return jsonify({
                        'error': 'Accès refusé',
                        'message': f'Rôle requis: {", ".join(allowed_roles)}. Votre rôle: {user.role}'
                    }), 403
                
                return f(*args, **kwargs)
                
            except Exception as e:
                current_app.logger.error(f"Erreur de vérification des rôles: {str(e)}")
                return jsonify({'error': 'Erreur de vérification des permissions'}), 500
                
        return decorated_function
    return decorator

def require_permission(permission):
    """Décorateur pour vérifier une permission spécifique"""
    def decorator(f):
        @wraps(f)
        @jwt_required()
        def decorated_function(*args, **kwargs):
            try:
                current_user_id = get_jwt_identity()
                user = User.query.get(current_user_id)
                
                if not user:
                    return jsonify({'error': 'Utilisateur non trouvé'}), 404
                
                if not user.is_active:
                    return jsonify({'error': 'Compte désactivé'}), 403
                
                if not user.has_permission(permission):
                    return jsonify({
                        'error': 'Permission refusée',
                        'message': f'Permission requise: {permission}'
                    }), 403
                
                return f(*args, **kwargs)
                
            except Exception as e:
                current_app.logger.error(f"Erreur de vérification des permissions: {str(e)}")
                return jsonify({'error': 'Erreur de vérification des permissions'}), 500
                
        return decorated_function
    return decorator

def admin_required(f):
    """Décorateur pour les routes admin uniquement"""
    @wraps(f)
    @jwt_required()
    def decorated_function(*args, **kwargs):
        try:
            current_user_id = get_jwt_identity()
            user = User.query.get(current_user_id)
            
            if not user:
                return jsonify({'error': 'Utilisateur non trouvé'}), 404
            
            if not user.is_active:
                return jsonify({'error': 'Compte désactivé'}), 403
            
            if not user.is_admin():
                return jsonify({
                    'error': 'Accès refusé',
                    'message': 'Accès administrateur requis'
                }), 403
            
            return f(*args, **kwargs)
            
        except Exception as e:
            current_app.logger.error(f"Erreur de vérification admin: {str(e)}")
            return jsonify({'error': 'Erreur de vérification des permissions'}), 500
            
    return decorated_function 