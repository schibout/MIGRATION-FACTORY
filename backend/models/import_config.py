from datetime import datetime
from sqlalchemy.dialects.postgresql import JSONB
from . import db

class ImportFileTypesConfig(db.Model):
    """
    Modèle pour la configuration des types de fichiers d'import
    """
    __tablename__ = 'file_type_configs'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    type_name = db.Column(db.String(100), unique=True, nullable=False, index=True)
    display_name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text)
    target_table = db.Column(db.String(100))
    processor_class = db.Column(db.String(100))
    
    # Configuration colonnes
    required_columns = db.Column(JSONB, nullable=False)
    validation_rules = db.Column(JSONB, default={})
    column_mapping = db.Column(JSONB, default={})
    
    # Métadonnées
    is_active = db.Column(db.Boolean, default=True, index=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def __repr__(self):
        return f'<ImportFileTypesConfig {self.type_name}: {self.display_name}>'

    def to_dict(self):
        """Convertit l'objet en dictionnaire pour la sérialisation JSON"""
        return {
            'id': self.id,
            'type_code': self.type_name,  # Mapping pour compatibilité frontend
            'type_name': self.type_name,
            'display_name': self.display_name,
            'description': self.description,
            'category': 'customer',  # Valeur par défaut pour compatibilité
            'max_file_size_mb': 50,  # Valeur par défaut
            'allowed_extensions': ['csv', 'xlsx', 'xls'],  # Valeur par défaut
            'required_columns': self.required_columns,
            'optional_columns': [],  # Valeur par défaut
            'column_mappings': self.column_mapping,  # Mapping pour compatibilité frontend
            'validation_rules': self.validation_rules,
            'target_table': self.target_table,
            'processor_class': self.processor_class,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'template_url': None,  # Valeur par défaut
            'help_text': None,  # Valeur par défaut
            'icon': 'description'  # Valeur par défaut
        }

    @classmethod
    def get_active_by_category(cls, category=None):
        """Récupère toutes les configurations actives pour une catégorie donnée"""
        query = cls.query.filter(cls.is_active == True)
        # Pour l'instant, on ignore la catégorie car pas dans la table existante
        return query.order_by(cls.display_name).all()

    @classmethod
    def get_customer_types(cls):
        """Récupère les types liés aux clients"""
        return cls.query.filter(
            cls.is_active == True,
            cls.type_name.like('%customer%')
        ).order_by(cls.display_name).all()

    @classmethod
    def get_by_type_code(cls, type_code):
        """Récupère une configuration par son code de type"""
        return cls.query.filter(
            cls.type_name == type_code,
            cls.is_active == True
        ).first()

    @classmethod
    def get_validation_rules_for_type(cls, type_code):
        """Récupère les règles de validation pour un type donné"""
        config = cls.get_by_type_code(type_code)
        if config:
            return config.validation_rules
        return {}

    @classmethod
    def get_required_columns_for_type(cls, type_code):
        """Récupère les colonnes requises pour un type donné"""
        config = cls.get_by_type_code(type_code)
        if config:
            return config.required_columns
        return []

    def validate_file_structure(self, file_columns):
        """
        Valide la structure d'un fichier contre cette configuration
        
        Args:
            file_columns (list): Liste des colonnes présentes dans le fichier
            
        Returns:
            dict: {'valid': bool, 'errors': list, 'warnings': list}
        """
        errors = []
        warnings = []
        
        # Vérifier les colonnes requises
        missing_required = set(self.required_columns) - set(file_columns)
        if missing_required:
            errors.append(f"Colonnes requises manquantes: {', '.join(missing_required)}")
        
        return {
            'valid': len(errors) == 0,
            'errors': errors,
            'warnings': warnings
        }

    def get_column_mapping(self, source_column):
        """
        Récupère le mapping pour une colonne source
        
        Args:
            source_column (str): Nom de la colonne source
            
        Returns:
            str: Nom de la colonne cible ou la colonne source si pas de mapping
        """
        return self.column_mapping.get(source_column, source_column) 