"""Axe des sites de l'ecran Matrice Site x Famille.

Regression du 2026-09-06 : l'axe etait deduit de
`SELECT DISTINCT contract FROM clean_data.inventory_part`, c'est-a-dire du
RESULTAT du chargement ETL. Seule la passe Castel ayant ete jouee, la base ne
contenait que des lignes `CS` : la colonne `SJ` disparaissait de l'ecran, et
avec elle les 36 regles deja saisies pour Saint-Jean, devenues invisibles et
non modifiables alors qu'elles restaient appliquees par
`public.get_default_value_ctx()`.

Un ecran de PARAMETRAGE doit s'utiliser AVANT le chargement : son axe ne peut
pas dependre de ce qui est deja charge.
"""
import pytest

import api.default_value_matrix as matrice
from api.default_value_matrix import SITES_REPLI, _fusionner_sites


def test_site_connu_reste_sur_l_axe_si_rien_n_est_charge():
    """Le bug exact : inventory_part ne contient que CS, SJ doit rester."""
    axe = _fusionner_sites(SITES_REPLI, ['CS'], [], [])
    assert axe == ['SJ', 'CS']


def test_site_parametre_dans_la_matrice_reste_visible():
    """Une regle saisie pour un site inconnu ne doit jamais devenir invisible."""
    axe = _fusionner_sites(SITES_REPLI, [], [], ['ZZ'])
    assert 'ZZ' in axe


def test_site_livre_dans_la_source_est_propose():
    """Un site present dans le fichier PHL est parametrable avant chargement."""
    axe = _fusionner_sites(SITES_REPLI, [], ['XX'], [])
    assert 'XX' in axe


def test_pas_de_doublon_et_ordre_metier_en_tete():
    axe = _fusionner_sites(SITES_REPLI, ['CS', 'SJ'], ['SJ', 'CS', 'XX'], ['CS'])
    assert axe == ['SJ', 'CS', 'XX']


@pytest.mark.parametrize('parasite', [None, '', '   '])
def test_valeurs_vides_ignorees(parasite):
    """NULL et chaines vides ne doivent pas creer une colonne fantome."""
    assert _fusionner_sites(SITES_REPLI, [parasite]) == ['SJ', 'CS']


# --------------------------------------------------------------------------- #
# Referentiel des sites (migration 070)
# --------------------------------------------------------------------------- #
@pytest.fixture()
def sans_base(monkeypatch):
    """Neutralise les quatre requetes : chaque test rebranche ce qu'il teste."""
    monkeypatch.setattr(matrice, '_sites_declares', lambda: [])
    monkeypatch.setattr(matrice, '_valeurs_distinctes', lambda sql: [])
    return monkeypatch


def test_le_referentiel_pilote_l_ordre_des_colonnes(sans_base):
    """L'ordre saisi dans Parametres de la matrice fait foi, pas SITES_REPLI."""
    sans_base.setattr(matrice, '_sites_declares', lambda: ['CS', 'SJ'])
    assert matrice._sites_de_l_ecran() == ['CS', 'SJ']


def test_site_declare_mais_pas_encore_charge_est_parametrable(sans_base):
    """Le but du referentiel : preparer un site avant tout chargement ETL."""
    sans_base.setattr(matrice, '_sites_declares', lambda: ['SJ', 'CS', 'XX'])
    assert 'XX' in matrice._sites_de_l_ecran()


def test_site_present_mais_non_declare_reste_visible(sans_base):
    """Meme regle que les familles : jamais de regle active invisible.

    Il ferme la liste : les sites declares gardent la tete de l'axe.
    """
    sans_base.setattr(matrice, '_sites_declares', lambda: ['SJ', 'CS'])
    sans_base.setattr(matrice, '_valeurs_distinctes', lambda sql: ['ZZ'])
    assert matrice._sites_de_l_ecran() == ['SJ', 'CS', 'ZZ']


def test_repli_si_le_referentiel_et_la_base_sont_vides(sans_base):
    """Migration 070 pas jouee : l'ecran reste utilisable."""
    assert matrice._sites_de_l_ecran() == SITES_REPLI
