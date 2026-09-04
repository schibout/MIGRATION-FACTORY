from flask_sqlalchemy import SQLAlchemy

# Initialisation de SQLAlchemy
db = SQLAlchemy()

# Import des modèles pour les rendre disponibles
from .user import User
from .field_mapping import FieldMapping
from .transcodification import Transcodification
from .import_config import ImportFileTypesConfig
from .business_rule import BusinessRule
from .etl_default_value import EtlDefaultValue
from .etl_default_value_matrix import EtlDefaultValueMatrix, EtlPartTypeMatrix
from .interface_contract import (
    InterfaceContractTable,
    InterfaceContractColumn,
    InterfaceContractValidation,
    InterfaceContractEvent,
)
