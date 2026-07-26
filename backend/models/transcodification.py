from . import db
from datetime import datetime
from sqlalchemy import UniqueConstraint, Index

class Transcodification(db.Model):
    """Modèle pour la table de transcodification entre les systèmes source et cible"""
    __tablename__ = 'TranscodificationTable'
    __table_args__ = (
        UniqueConstraint('category', 'source_system', 'target_system', 'source_value', name='unique_transcodification'),
        # Ajouter des index pour améliorer les performances des requêtes fréquentes
        Index('idx_category', 'category'),
        Index('idx_source_system', 'source_system'),
        Index('idx_target_system', 'target_system'),
        Index('idx_is_active', 'is_active'),
        {'schema': 'public'}  # Spécifier le schéma explicitement
    )
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    category = db.Column(db.String(50), nullable=False)
    source_system = db.Column(db.String(20), nullable=False, default='SAP')
    target_system = db.Column(db.String(20), nullable=False, default='IFS')
    source_value = db.Column(db.String(100), nullable=False)
    target_value = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    created_by = db.Column(db.String(50))
    updated_by = db.Column(db.String(50))
    is_active = db.Column(db.Boolean, default=True)
    
    def to_dict(self):
        """Convertit l'objet en dictionnaire pour l'API"""
        return {
            'id': self.id,
            'category': self.category,
            'source_system': self.source_system,
            'target_system': self.target_system,
            'source_value': self.source_value,
            'target_value': self.target_value,
            'description': self.description,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'created_by': self.created_by,
            'updated_by': self.updated_by,
            'is_active': self.is_active
        }
    
    @staticmethod
    def from_dict(data, existing_transcodification=None):
        """Crée ou met à jour un objet Transcodification à partir d'un dictionnaire"""
        if existing_transcodification:
            # Mise à jour d'une transcodification existante
            transcodification = existing_transcodification
            # Ne mettre à jour que les champs modifiables
            if 'category' in data:
                transcodification.category = data['category']
            if 'source_system' in data:
                transcodification.source_system = data['source_system']
            if 'target_system' in data:
                transcodification.target_system = data['target_system']
            if 'source_value' in data:
                transcodification.source_value = data['source_value']
            if 'target_value' in data:
                transcodification.target_value = data['target_value']
            if 'description' in data:
                transcodification.description = data['description']
            if 'is_active' in data:
                transcodification.is_active = data['is_active']
            if 'updated_by' in data:
                transcodification.updated_by = data['updated_by']
            # La date de mise à jour sera automatiquement définie par SQLAlchemy
        else:
            # Création d'une nouvelle transcodification
            transcodification = Transcodification(
                category=data['category'],
                source_system=data.get('source_system', 'SAP'),
                target_system=data.get('target_system', 'IFS'),
                source_value=data['source_value'],
                target_value=data['target_value'],
                description=data.get('description'),
                created_by=data.get('created_by'),
                updated_by=data.get('updated_by'),
                is_active=data.get('is_active', True)
            )
        
        return transcodification 