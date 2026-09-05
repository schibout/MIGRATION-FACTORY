"""Tables de référence de l'écran Matrice Site × Famille (migration 067).

Ces deux tables ne sont lues par AUCUNE procédure ETL : elles ne pilotent que
ce que l'écran propose. Une table vide fait retomber l'API sur son
comportement d'origine (familles déduites des données, toutes les tables
cibles), pour que l'écran reste utilisable si la migration n'est pas jouée.
"""
from . import db
from datetime import datetime


class EtlPartFamily(db.Model):
    """Famille d'articles proposée en colonne de la matrice.

    `code` est la valeur brute de la colonne "FAMILLE" du fichier PHL, celle
    que stocke etl_default_value_matrix.part_family. Il n'y a volontairement
    pas de clé étrangère entre les deux : une règle peut porter sur une famille
    non déclarée. Corollaire : renommer un code ne se propage pas aux règles,
    l'API refuse donc de le modifier tant que des règles l'utilisent.
    """
    __tablename__ = 'etl_part_family'
    __table_args__ = {'schema': 'public'}

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    code = db.Column(db.String(50), nullable=False)
    libelle = db.Column(db.String(120))
    description = db.Column(db.Text)
    ordre = db.Column(db.Integer, nullable=False, default=100)
    is_active = db.Column(db.Boolean, nullable=False, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    created_by = db.Column(db.String(50))
    updated_by = db.Column(db.String(50))

    def to_dict(self):
        return {
            'id': self.id,
            'code': self.code,
            'libelle': self.libelle,
            'description': self.description,
            'ordre': self.ordre,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'created_by': self.created_by,
            'updated_by': self.updated_by,
        }


class EtlMatrixTargetTable(db.Model):
    """Table cible proposée dans le sélecteur de la matrice.

    Désactiver une ligne retire la table du sélecteur mais ne supprime aucune
    règle déjà saisie sur elle : les règles restent appliquées par l'ETL.
    """
    __tablename__ = 'etl_matrix_target_table'
    __table_args__ = {'schema': 'public'}

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    table_cible = db.Column(db.String(100), nullable=False)
    libelle = db.Column(db.String(120))
    description = db.Column(db.Text)
    ordre = db.Column(db.Integer, nullable=False, default=100)
    is_active = db.Column(db.Boolean, nullable=False, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    created_by = db.Column(db.String(50))
    updated_by = db.Column(db.String(50))

    def to_dict(self):
        return {
            'id': self.id,
            'table_cible': self.table_cible,
            'libelle': self.libelle,
            'description': self.description,
            'ordre': self.ordre,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'created_by': self.created_by,
            'updated_by': self.updated_by,
        }
