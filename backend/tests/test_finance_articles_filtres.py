"""Filtre avance de Finance > Articles : il compose du SQL a partir de la requete HTTP,
d'ou ces garde-fous sur la liste blanche. Aucune base n'est necessaire."""
import importlib.util
import os

import pytest

_PATH = os.path.join(os.path.dirname(__file__), '..', 'api', 'finance.py')
_spec = importlib.util.spec_from_file_location('finance_module', _PATH)
finance = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(finance)
ART_VUES, _art_condition, _art_conditions = finance.ART_VUES, finance._art_condition, finance._art_conditions


def test_valeur_libre_toujours_en_parametre():
    injection = "x' OR 1=1 --"
    sql, params = _art_condition({'champ': 'type', 'op': 'est', 'valeur': injection}, 'c0')
    assert injection not in sql
    assert params == {'c0': injection}


@pytest.mark.parametrize('c', [
    {'champ': 'd.type_sap; DROP TABLE x', 'op': 'est', 'valeur': 'ERSA'},
    {'champ': 'destination', 'op': 'est', 'valeur': 'd.catalogue OR TRUE'},
    {'champ': 'stock', 'op': 'est', 'valeur': 'peut-etre'},
    {'champ': 'type', 'op': 'OR 1=1', 'valeur': 'ERSA'},
    {'champ': 'type', 'op': 'est', 'valeur': ['ERSA']},
    'pas un objet',
])
def test_condition_hors_liste_blanche_refusee(c):
    with pytest.raises(ValueError):
        _art_condition(c, 'c0')


def test_negation_et_combinaisons():
    assert _art_condition({'champ': 'destination', 'op': 'nest', 'valeur': 'inventory'}, 'c0')[0] \
        == 'NOT ((d.inventory) IS TRUE)'
    conds = [{'champ': 'stock', 'op': 'est', 'valeur': 'oui'}, {'champ': 'magasin', 'op': 'est', 'valeur': 'non'}]
    assert ' AND ' in _art_conditions(conds, 'ET')[0]
    assert ' OR ' in _art_conditions(conds, 'OU')[0]
    assert _art_conditions([]) == (None, {})
    with pytest.raises(ValueError):
        _art_conditions(conds, 'XOR')
    with pytest.raises(ValueError):
        _art_conditions(conds * 11)


def test_les_vues_sont_valides_et_leurs_parametres_distincts():
    params = {}
    for i, (_, _, conds) in enumerate(ART_VUES):
        sql, p = _art_conditions(conds, prefixe=f'v{i}_')
        assert sql
        assert not set(p) & set(params)
        params.update(p)
