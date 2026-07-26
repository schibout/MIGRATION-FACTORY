from functools import wraps
from flask import jsonify, current_app
from flask_jwt_extended import verify_jwt_in_request, get_jwt, get_jwt_identity
from models import User

def role_required(role):
    """
    Décorateur qui vérifie si l'utilisateur a le rôle requis
    Utilisage:
    @role_required('admin')
    ou
    @role_required(['admin', 'user'])
    """
    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            # Vérifier que le token JWT est présent et valide
            verify_jwt_in_request()
            
            # Obtenir les claims du token
            jwt_claims = get_jwt()
            user_role = jwt_claims.get("role", "")
            
            # Si le rôle passé est une liste, vérifier si le rôle de l'utilisateur est dans cette liste
            if isinstance(role, list):
                if user_role not in role:
                    current_app.logger.warning(f"Tentative d'accès non autorisé: role={user_role}, required={role}")
                    return jsonify({"error": "Accès refusé, rôle insuffisant"}), 403
            # Sinon, vérifier si le rôle de l'utilisateur correspond au rôle requis
            elif user_role != role:
                current_app.logger.warning(f"Tentative d'accès non autorisé: role={user_role}, required={role}")
                return jsonify({"error": "Accès refusé, rôle insuffisant"}), 403
                
            # Si tout est ok, exécuter la fonction
            return fn(*args, **kwargs)
        return wrapper
    return decorator

def admin_required(fn):
    """Décorateur qui vérifie si l'utilisateur est un administrateur"""
    @wraps(fn)
    def wrapper(*args, **kwargs):
        # Vérifier que le token JWT est présent et valide
        verify_jwt_in_request()
        
        # Obtenir les claims du token
        jwt_claims = get_jwt()
        user_role = jwt_claims.get("role", "")
        
        if user_role != "admin":
            current_app.logger.warning(f"Tentative d'accès administrateur non autorisé: role={user_role}")
            return jsonify({"error": "Accès administrateur refusé"}), 403
            
        # Si tout est ok, exécuter la fonction
        return fn(*args, **kwargs)
    return wrapper

def user_exists(fn):
    """Décorateur qui vérifie si l'utilisateur existe toujours en base de données"""
    @wraps(fn)
    def wrapper(*args, **kwargs):
        # Vérifier que le token JWT est présent et valide
        verify_jwt_in_request()
        
        # Obtenir l'identité de l'utilisateur
        user_id = get_jwt_identity()
        
        # Vérifier que l'utilisateur existe toujours en base
        user = User.query.get(user_id)
        if not user or not user.is_active:
            current_app.logger.warning(f"Tentative d'accès avec un compte inexistant ou désactivé: user_id={user_id}")
            return jsonify({"error": "Compte utilisateur inexistant ou désactivé"}), 401
            
        # Si tout est ok, exécuter la fonction
        return fn(*args, **kwargs)
    return wrapper 