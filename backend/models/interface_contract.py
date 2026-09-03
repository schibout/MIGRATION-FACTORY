"""
Contrats d'interface SAP -> IFS (migrations 051 / 052).

La definition technique (table + colonnes) et l'etat de validation metier sont
deliberement dans DEUX tables distinctes : elles n'evoluent pas au meme rythme.
Une correction du mapping ne doit jamais effacer la relecture metier — elle la
rend seulement « obsolete » (cf. v_interface_contract.validation_obsolete, qui
compare interface_contract_column.updated_at a validation.validated_at).
"""

from datetime import datetime

from sqlalchemy import Index, UniqueConstraint

from . import db

STATUTS = ('A_VALIDER', 'VALIDE', 'A_CORRIGER', 'NON_APPLICABLE')
ROW_TYPES = ('COLUMN', 'CONFIG_SUMMARY', 'NOTE')
EVENT_TYPES = ('STATUT', 'COMMENTAIRE', 'DEFINITION', 'IMPORT_EXCEL')


class InterfaceContractTable(db.Model):
    """Une table cible IFS documentee = un onglet du classeur."""

    __tablename__ = 'interface_contract_table'
    __table_args__ = (
        UniqueConstraint('module', 'table_cible', name='uq_interface_contract_table'),
        {'schema': 'public'},
    )

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    module = db.Column(db.String(50), nullable=False)
    schema_cible = db.Column(db.String(50), nullable=False, default='clean_data')
    table_cible = db.Column(db.String(100), nullable=False)
    libelle = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text)
    source_procedure = db.Column(db.String(200))
    ordre = db.Column(db.Integer, nullable=False, default=0)
    owner_metier = db.Column(db.String(100))
    date_limite = db.Column(db.Date)
    signe_par = db.Column(db.String(50))
    signe_le = db.Column(db.DateTime)
    is_active = db.Column(db.Boolean, nullable=False, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    columns = db.relationship(
        'InterfaceContractColumn', backref='table', lazy='select',
        cascade='all, delete-orphan', order_by='InterfaceContractColumn.sort_order',
    )

    def to_dict(self):
        return {
            'id': self.id,
            'module': self.module,
            'schema_cible': self.schema_cible,
            'table_cible': self.table_cible,
            'libelle': self.libelle,
            'description': self.description,
            'source_procedure': self.source_procedure,
            'ordre': self.ordre,
            'owner_metier': self.owner_metier,
            'date_limite': self.date_limite.isoformat() if self.date_limite else None,
            'signe_par': self.signe_par,
            'signe_le': self.signe_le.isoformat() if self.signe_le else None,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
        }


class InterfaceContractColumn(db.Model):
    """Une ligne du contrat : la regle qui alimente une colonne cible.

    Cle naturelle (contract_table_id, section, target_column) : un onglet peut
    documenter deux fois la meme colonne quand le chargement se fait en
    plusieurs etapes (cf. migration 052 §4).
    """

    __tablename__ = 'interface_contract_column'
    __table_args__ = (
        Index('idx_ic_column_table', 'contract_table_id'),
        {'schema': 'public'},
    )

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    contract_table_id = db.Column(
        db.Integer,
        db.ForeignKey('public.interface_contract_table.id', ondelete='CASCADE'),
        nullable=False,
    )
    section = db.Column(db.String(200))
    target_column = db.Column(db.String(255), nullable=False)
    field_label = db.Column(db.String(200))
    systeme_source = db.Column(db.String(50))
    source_schema = db.Column(db.String(50))
    source_table = db.Column(db.String(100))
    source_column = db.Column(db.String(100))
    source_expression = db.Column(db.Text)
    transformation_rule = db.Column(db.Text)
    condition_application = db.Column(db.Text)
    exemple_valeur = db.Column(db.Text)
    row_type = db.Column(db.String(20), nullable=False, default='COLUMN')
    default_value_column = db.Column(db.String(100))
    default_value_variante = db.Column(db.String(30), nullable=False, default='STANDARD')
    sort_order = db.Column(db.Integer, nullable=False, default=0)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    validation = db.relationship(
        'InterfaceContractValidation', backref='column', uselist=False,
        cascade='all, delete-orphan',
    )
    events = db.relationship(
        'InterfaceContractEvent', backref='column', lazy='select',
        cascade='all, delete-orphan', order_by='InterfaceContractEvent.created_at',
    )

    def to_dict(self):
        return {
            'id': self.id,
            'contract_table_id': self.contract_table_id,
            'section': self.section,
            'target_column': self.target_column,
            'field_label': self.field_label,
            'systeme_source': self.systeme_source,
            'source_schema': self.source_schema,
            'source_table': self.source_table,
            'source_column': self.source_column,
            'source_expression': self.source_expression,
            'transformation_rule': self.transformation_rule,
            'condition_application': self.condition_application,
            'exemple_valeur': self.exemple_valeur,
            'row_type': self.row_type,
            'default_value_column': self.default_value_column,
            'default_value_variante': self.default_value_variante,
            'sort_order': self.sort_order,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
        }


class InterfaceContractValidation(db.Model):
    """DERNIER etat de validation metier d'une ligne de contrat (1-1)."""

    __tablename__ = 'interface_contract_validation'
    __table_args__ = ({'schema': 'public'},)

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    contract_column_id = db.Column(
        db.Integer,
        db.ForeignKey('public.interface_contract_column.id', ondelete='CASCADE'),
        nullable=False, unique=True,
    )
    statut = db.Column(db.String(20), nullable=False, default='A_VALIDER')
    remarque_metier = db.Column(db.Text)
    validated_by = db.Column(db.String(50))
    validated_at = db.Column(db.DateTime)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def to_dict(self):
        return {
            'id': self.id,
            'contract_column_id': self.contract_column_id,
            'statut': self.statut,
            'remarque_metier': self.remarque_metier,
            'validated_by': self.validated_by,
            'validated_at': self.validated_at.isoformat() if self.validated_at else None,
        }


class InterfaceContractEvent(db.Model):
    """Journal d'une ligne : audit des statuts ET fil de discussion tech/metier."""

    __tablename__ = 'interface_contract_event'
    __table_args__ = (
        Index('idx_ic_event_column', 'contract_column_id', 'created_at'),
        {'schema': 'public'},
    )

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    contract_column_id = db.Column(
        db.Integer,
        db.ForeignKey('public.interface_contract_column.id', ondelete='CASCADE'),
        nullable=False,
    )
    event_type = db.Column(db.String(20), nullable=False)
    ancien_statut = db.Column(db.String(20))
    nouveau_statut = db.Column(db.String(20))
    commentaire = db.Column(db.Text)
    auteur = db.Column(db.String(50), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            'id': self.id,
            'contract_column_id': self.contract_column_id,
            'event_type': self.event_type,
            'ancien_statut': self.ancien_statut,
            'nouveau_statut': self.nouveau_statut,
            'commentaire': self.commentaire,
            'auteur': self.auteur,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }
