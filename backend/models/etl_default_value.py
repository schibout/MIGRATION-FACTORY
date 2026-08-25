from . import db
from datetime import datetime
from sqlalchemy import UniqueConstraint, Index


class EtlDefaultValue(db.Model):
    """Valeur par défaut ETL paramétrable (écran Configuration > Valeurs par défaut)"""
    __tablename__ = 'etl_default_values'
    __table_args__ = (
        UniqueConstraint('table_cible', 'colonne', 'variante', name='uq_etl_default_values'),
        Index('idx_edv_module', 'module'),
        Index('idx_edv_table', 'table_cible'),
        {'schema': 'public'}
    )

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    module = db.Column(db.String(50), nullable=False)
    table_cible = db.Column(db.String(100), nullable=False)
    colonne = db.Column(db.String(100), nullable=False)
    variante = db.Column(db.String(30), nullable=False, default='STANDARD')
    type_valeur = db.Column(db.String(20), nullable=False)  # CONSTANTE | NULL
    valeur = db.Column(db.Text)
    description = db.Column(db.Text)
    is_active = db.Column(db.Boolean, nullable=False, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    created_by = db.Column(db.String(50))
    updated_by = db.Column(db.String(50))

    def to_dict(self):
        return {
            'id': self.id,
            'module': self.module,
            'table_cible': self.table_cible,
            'colonne': self.colonne,
            'variante': self.variante,
            'type_valeur': self.type_valeur,
            'valeur': self.valeur,
            'description': self.description,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'created_by': self.created_by,
            'updated_by': self.updated_by,
        }
