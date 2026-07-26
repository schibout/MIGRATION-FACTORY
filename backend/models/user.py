from datetime import datetime
import uuid
from werkzeug.security import generate_password_hash, check_password_hash
from . import db

class User(db.Model):
    """Modèle d'utilisateur administrateur pour l'authentification"""
    
    __tablename__ = 'users'
    
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    username = db.Column(db.String(50), unique=True, nullable=False)
    email = db.Column(db.String(100), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    role = db.Column(db.String(20), nullable=False, default='operator')  # 'admin' ou 'operator'
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_login = db.Column(db.DateTime, nullable=True)
    reset_token = db.Column(db.String(100), nullable=True)
    reset_token_expiry = db.Column(db.DateTime, nullable=True)
    
    # Relations avec d'autres tables si nécessaire
    # export_configs = db.relationship('ExportConfig', backref='user', lazy=True)
    
    @property
    def password(self):
        """Empêche l'accès direct au mot de passe"""
        raise AttributeError('password is not a readable attribute')
    
    @password.setter
    def password(self, password):
        """Génère un hash pour le mot de passe"""
        self.password_hash = generate_password_hash(password, method='scrypt')
        
    def verify_password(self, password):
        """Vérifie le mot de passe"""
        return check_password_hash(self.password_hash, password)
        
    def update_last_login(self):
        """Met à jour la date de dernière connexion"""
        self.last_login = datetime.utcnow()
        db.session.commit()
    
    def is_admin(self):
        """Vérifie si l'utilisateur est admin"""
        return self.role == 'admin'
    
    def is_operator(self):
        """Vérifie si l'utilisateur est operator"""
        return self.role == 'operator'
    
    def has_permission(self, permission):
        """Vérifie les permissions selon le rôle"""
        admin_permissions = [
            'manage_users', 'view_all_data', 'configure_system',
            'view_sap_data', 'view_ifs_data', 'view_dashboards',
            'export_data', 'manage_mappings', 'manage_transcodification'
        ]
        
        operator_permissions = [
            'view_sap_data', 'view_ifs_data', 'view_dashboards',
            'export_data'
        ]
        
        if self.role == 'admin':
            return permission in admin_permissions
        elif self.role == 'operator':
            return permission in operator_permissions
        
        return False
    
    def to_dict(self):
        """Convertit l'utilisateur en dictionnaire pour l'API"""
        return {
            'id': self.id,
            'username': self.username,
            'email': self.email,
            'role': self.role,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'last_login': self.last_login.isoformat() if self.last_login else None
        }
    
    def __repr__(self):
        return f'<User {self.username} ({self.role})>' 