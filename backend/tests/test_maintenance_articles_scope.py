"""
Tests du perimetre de l'ecran Articles maintenance (api/maintenance_articles.py).

L'ecran restreint par defaut aux types maintenance (ERSA/IBAU/NLAG) presents sur
le site St-Jean : ~29 000 articles sur les ~84 000 du catalogue SAP. Le drapeau
`all_sap` leve ce perimetre. C'est donc lui qui decide de la visibilite de
55 000 articles — d'ou ces garde-fous, qui ne demandent pas de base.
"""
import os
import importlib.util

import pytest

_PATH = os.path.join(os.path.dirname(__file__), '..', 'api', 'maintenance_articles.py')
_spec = importlib.util.spec_from_file_location('maintenance_articles_module', _PATH)
articles = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(articles)


# --------------------------------------------------------------------------- #
# Lecture du drapeau
# --------------------------------------------------------------------------- #
@pytest.mark.parametrize('value', ['1', 'true', 'TRUE', 'yes', ' true '])
def test_flag_reconnait_les_formes_vraies(value):
    assert articles._flag(value) is True


@pytest.mark.parametrize('value', ['', '0', 'false', 'no', None, 'oui'])
def test_flag_est_faux_par_defaut(value):
    """Toute valeur non reconnue laisse le perimetre maintenance en place :
    le comportement restrictif est le defaut sur."""
    assert articles._flag(value) is False


# --------------------------------------------------------------------------- #
# Perimetre maintenance
# --------------------------------------------------------------------------- #
def test_types_maintenance_attendus():
    assert set(articles.ALLOWED_MTART) == {'ERSA', 'IBAU', 'NLAG'}


def test_divisions_st_jean_attendues():
    assert set(articles.ST_JEAN_WERKS) == {'9200', '2200'}


def test_clause_perimetre_traite_ibau_a_part():
    """IBAU n'a pas de donnee de division : il est cadre par la structure IH02,
    les autres types par la division du site."""
    clause = articles._st_jean_scope_clause('m')
    assert "m.mtart = 'IBAU'" in clause
    assert 'clean_data.maintenance_object' in clause
    assert "m.mtart <> 'IBAU'" in clause
    assert 'raw_data.marc' in clause


def test_clause_perimetre_respecte_l_alias():
    """La clause se compose dans des requetes ou mara porte un autre alias."""
    clause = articles._st_jean_scope_clause('a')
    assert 'a.matnr' in clause
    assert 'm.matnr' not in clause


def test_clause_perimetre_sans_parametre_lie():
    """Aucun %s : la clause doit pouvoir s'inserer sans decaler les parametres
    des autres filtres (recherche, groupe d'articles...)."""
    assert '%s' not in articles._st_jean_scope_clause('m')


def test_clause_perimetre_cite_les_divisions_du_site():
    clause = articles._st_jean_scope_clause('m')
    for werks in articles.ST_JEAN_WERKS:
        assert f"'{werks}'" in clause
