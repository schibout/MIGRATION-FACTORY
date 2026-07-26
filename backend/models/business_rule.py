from . import db
from datetime import datetime
from sqlalchemy import Index


class BusinessRule(db.Model):
    """Modèle pour la table des règles de gestion (mappings métier Source SAP -> Cible IFS)"""
    __tablename__ = 'business_rules'
    __table_args__ = (
        Index('idx_business_rules_object', 'business_object'),
        Index('idx_business_rules_is_active', 'is_active'),
        {'schema': 'public'}
    )

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    business_object = db.Column(db.String(100), nullable=False)
    rule_name = db.Column(db.String(200), nullable=False)
    source_table = db.Column(db.String(150))
    source_field = db.Column(db.String(150))
    transformation = db.Column(db.Text)
    target_table = db.Column(db.String(150))
    target_field = db.Column(db.String(150))
    description = db.Column(db.Text)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    created_by = db.Column(db.String(50))
    updated_by = db.Column(db.String(50))

    def to_dict(self):
        """Convertit l'objet en dictionnaire pour l'API"""
        return {
            'id': self.id,
            'business_object': self.business_object,
            'rule_name': self.rule_name,
            'source_table': self.source_table,
            'source_field': self.source_field,
            'transformation': self.transformation,
            'target_table': self.target_table,
            'target_field': self.target_field,
            'description': self.description,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'created_by': self.created_by,
            'updated_by': self.updated_by,
        }

    @staticmethod
    def from_dict(data, existing_rule=None):
        """Crée ou met à jour un objet BusinessRule à partir d'un dictionnaire"""
        editable_fields = [
            'business_object', 'rule_name', 'source_table', 'source_field',
            'transformation', 'target_table', 'target_field', 'description',
            'is_active', 'updated_by'
        ]

        if existing_rule:
            rule = existing_rule
            for field in editable_fields:
                if field in data:
                    setattr(rule, field, data[field])
        else:
            rule = BusinessRule(
                business_object=data['business_object'],
                rule_name=data['rule_name'],
                source_table=data.get('source_table'),
                source_field=data.get('source_field'),
                transformation=data.get('transformation'),
                target_table=data.get('target_table'),
                target_field=data.get('target_field'),
                description=data.get('description'),
                is_active=data.get('is_active', True),
                created_by=data.get('created_by'),
                updated_by=data.get('updated_by'),
            )

        return rule
