from . import db
from datetime import datetime
from sqlalchemy import UniqueConstraint, Index

class FieldMapping(db.Model):
    """Modèle pour la table de mapping des champs entre tables source et cible"""
    __tablename__ = 'FieldMappingTable'
    __table_args__ = (
        UniqueConstraint('source_table_name', 'source_field_name', 'target_table', 'target_field_name', name='unique_field_mapping'),
        # Ajouter des index pour améliorer les performances des requêtes fréquentes
        Index('idx_source_table', 'source_table_name'),
        Index('idx_target_table', 'target_table'),
        Index('idx_is_active', 'is_active'),
        {'schema': 'public'}  # Spécifier le schéma explicitement
    )
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    source_table_name = db.Column(db.String(100), nullable=False)
    source_field_name = db.Column(db.String(100), nullable=False)
    target_table = db.Column(db.String(100), nullable=False)
    target_field_name = db.Column(db.String(100), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    created_by = db.Column(db.String(50))
    updated_by = db.Column(db.String(50))
    is_active = db.Column(db.Boolean, default=True)
    transformation_rule = db.Column(db.Text)
    data_type = db.Column(db.String(50))
    is_key = db.Column(db.Boolean, default=False)
    notes = db.Column(db.Text)
    
    def to_dict(self):
        """Convertit l'objet en dictionnaire pour l'API"""
        return {
            'id': self.id,
            'source_table_name': self.source_table_name,
            'source_field_name': self.source_field_name,
            'target_table': self.target_table,
            'target_field_name': self.target_field_name,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'created_by': self.created_by,
            'updated_by': self.updated_by,
            'is_active': self.is_active,
            'transformation_rule': self.transformation_rule,
            'data_type': self.data_type,
            'is_key': self.is_key,
            'notes': self.notes
        }
    
    @staticmethod
    def from_dict(data, existing_mapping=None):
        """Crée ou met à jour un objet FieldMapping à partir d'un dictionnaire"""
        if existing_mapping:
            # Mise à jour d'un mapping existant
            mapping = existing_mapping
            # Ne mettre à jour que les champs modifiables
            if 'source_table_name' in data:
                mapping.source_table_name = data['source_table_name']
            if 'source_field_name' in data:
                mapping.source_field_name = data['source_field_name']
            if 'target_table' in data:
                mapping.target_table = data['target_table']
            if 'target_field_name' in data:
                mapping.target_field_name = data['target_field_name']
            if 'is_active' in data:
                mapping.is_active = data['is_active']
            if 'transformation_rule' in data:
                mapping.transformation_rule = data['transformation_rule']
            if 'data_type' in data:
                mapping.data_type = data['data_type']
            if 'is_key' in data:
                mapping.is_key = data['is_key']
            if 'notes' in data:
                mapping.notes = data['notes']
            if 'updated_by' in data:
                mapping.updated_by = data['updated_by']
            # La date de mise à jour sera automatiquement définie par SQLAlchemy
        else:
            # Création d'un nouveau mapping
            mapping = FieldMapping(
                source_table_name=data['source_table_name'],
                source_field_name=data['source_field_name'],
                target_table=data['target_table'],
                target_field_name=data['target_field_name'],
                created_by=data.get('created_by'),
                updated_by=data.get('updated_by'),
                is_active=data.get('is_active', True),
                transformation_rule=data.get('transformation_rule'),
                data_type=data.get('data_type'),
                is_key=data.get('is_key', False),
                notes=data.get('notes')
            )
        
        return mapping 