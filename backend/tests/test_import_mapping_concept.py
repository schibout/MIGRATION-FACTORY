"""Rapprochement des colonnes par synonymes (services/import_mapping_service.py) :
seul le nom entier compte, sans base de donnees."""
from services.import_mapping_service import ImportMappingService


def score(source, cible):
    return ImportMappingService().calculate_match_score({'name': source, 'detectedType': 'text'},
                                                        {'name': cible, 'data_type': 'text'})


def test_mot_partage_ne_rapproche_pas():
    # Donnaient 90 % : 'id' dans "delaid'achat", 'no' dans 'noteinterne', name ~ nom, type
    assert score('STD_NAME_ID', "Délai d'achat") < 50
    assert score('ALLOW_AS_NOT_CONSUMED', 'Note interne') < 50
    assert score('STD_NAME_ID', 'Créé par Nom') < 50
    assert score('PRODUCT_TYPE_CLASSIF', 'Désignation du type') < 50


def test_synonyme_nom_entier_rapproche():
    assert score('Qte', 'quantite') >= 80
    assert score('DESCRIPTION', 'Description article') >= 80
