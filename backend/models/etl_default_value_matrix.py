from . import db
from datetime import datetime
from sqlalchemy import Index


class EtlDefaultValueMatrix(db.Model):
    """Valeur par défaut ETL dépendant du site (contract) et de la famille d'article.

    Se place au-dessus de EtlDefaultValue : public.get_default_value_ctx() lit
    d'abord cette table (ligne la plus spécifique), puis retombe sur la
    constante de public.etl_default_values (migration 066).

    L'unicité de la clé naturelle est portée par un index d'expression
    (uq_etl_default_value_matrix, sur COALESCE(contract,'*') /
    COALESCE(part_family,'*')) : une contrainte UNIQUE ordinaire laisserait
    passer plusieurs lignes joker, PostgreSQL considérant deux NULL comme
    distincts. Elle n'est donc pas déclarée ici, seulement en base.
    """
    __tablename__ = 'etl_default_value_matrix'
    __table_args__ = (
        Index('idx_edvm_lookup', 'table_cible', 'colonne', 'variante'),
        {'schema': 'public'}
    )

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    module = db.Column(db.String(50), nullable=False, default='articlePhl')
    table_cible = db.Column(db.String(100), nullable=False)
    colonne = db.Column(db.String(100), nullable=False)
    contract = db.Column(db.String(10))       # NULL = joker (tous les sites)
    part_family = db.Column(db.String(50))    # NULL = joker (toutes les familles)
    variante = db.Column(db.String(30), nullable=False, default='STANDARD')
    type_valeur = db.Column(db.String(20), nullable=False)  # CONSTANTE | NULL
    valeur = db.Column(db.Text)
    description = db.Column(db.Text)
    is_active = db.Column(db.Boolean, nullable=False, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    created_by = db.Column(db.String(50))
    updated_by = db.Column(db.String(50))

    # Spécificité de la ligne : 2 = site + famille, 1 = l'un des deux, 0 = joker.
    # Sert à afficher la règle appliquée côté écran, dans le même ordre que la
    # clause ORDER BY des fonctions de résolution.
    @property
    def specificite(self):
        return (1 if self.contract else 0) + (1 if self.part_family else 0)

    def to_dict(self):
        return {
            'id': self.id,
            'module': self.module,
            'table_cible': self.table_cible,
            'colonne': self.colonne,
            'contract': self.contract,
            'part_family': self.part_family,
            'variante': self.variante,
            'type_valeur': self.type_valeur,
            'valeur': self.valeur,
            'description': self.description,
            'is_active': self.is_active,
            'specificite': self.specificite,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'created_by': self.created_by,
            'updated_by': self.updated_by,
        }


class EtlPartTypeMatrix(db.Model):
    """Routage de création des tables article par site x famille.

    Un article peut relever de plusieurs cas à la fois (fabriqué ET vendu) :
    un flag par table cible, pas un « type d'article » à valeur unique.
    Absence de ligne = création autorisée (les loaders appliquent
    COALESCE(get_part_type_matrix(...), TRUE)).
    """
    __tablename__ = 'etl_part_type_matrix'
    __table_args__ = (
        Index('idx_eptm_lookup', 'target_table'),
        {'schema': 'public'}
    )

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    target_table = db.Column(db.String(100), nullable=False)
    contract = db.Column(db.String(10))
    part_family = db.Column(db.String(50))
    should_create = db.Column(db.Boolean, nullable=False)
    description = db.Column(db.Text)
    is_active = db.Column(db.Boolean, nullable=False, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    created_by = db.Column(db.String(50))
    updated_by = db.Column(db.String(50))

    @property
    def specificite(self):
        return (1 if self.contract else 0) + (1 if self.part_family else 0)

    def to_dict(self):
        return {
            'id': self.id,
            'target_table': self.target_table,
            'contract': self.contract,
            'part_family': self.part_family,
            'should_create': self.should_create,
            'description': self.description,
            'is_active': self.is_active,
            'specificite': self.specificite,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'created_by': self.created_by,
            'updated_by': self.updated_by,
        }
