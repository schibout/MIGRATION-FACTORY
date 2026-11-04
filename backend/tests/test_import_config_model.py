"""Le modele doit suivre la table file_type_configs : la migration 005 a supprime required_columns
et validation_rules, et les lire en SQL faisait echouer tous les ecrans de types d'import (sans base)."""
from models.import_config import ImportFileTypesConfig


def test_colonnes_supprimees_par_la_migration_005_non_lues():
    colonnes = set(ImportFileTypesConfig.__table__.columns.keys())
    assert not colonnes & {'required_columns', 'validation_rules'}


def test_contrat_api_conserve_pour_le_frontend():
    config = ImportFileTypesConfig(type_name='customers', display_name='Clients')
    donnees = config.to_dict()
    assert list(donnees['required_columns']) == []
    assert donnees['validation_rules'] == {}
    assert config.validate_file_structure(['a'])['valid'] is True
