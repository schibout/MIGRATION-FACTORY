"""Rapprochement des colonnes par synonymes (services/import_mapping_service.py) :
mots entiers seulement, sans base de donnees."""
from services.import_mapping_service import ImportMappingService


def score(source, cible):
    return ImportMappingService().calculate_match_score({'name': source, 'detectedType': 'text'},
                                                        {'name': cible, 'data_type': 'text'})


def test_synonyme_court_dans_un_mot_ne_rapproche_pas():
    # 'id' dans "delaid'achat", 'no' dans 'noteinterne' donnaient 90 %
    assert score('STD_NAME_ID', "Délai d'achat") < 50
    assert score('ALLOW_AS_NOT_CONSUMED', 'Note interne') < 50


def test_synonyme_mot_entier_rapproche():
    assert score('DESCRIPTION', 'Description article') >= 80
    assert score('part_no', 'numero') >= 80
