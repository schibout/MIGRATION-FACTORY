"""Validation d'une regle "code fichier PE Tools -> organisation IFS".

La regle est saisie dans l'ecran Maintenance / Organisations PE Tools et lue
par `public.pe_tools_org_code()` a chaque import de fichier. Deux contraintes
viennent de la base (migration 077) et doivent etre refusees AVANT l'INSERT,
avec un message lisible plutot qu'une erreur SQL :
  * `code_fichier` est la cle primaire -> obligatoire ;
  * `org_code` porte un CHECK de 8 caracteres, parce que la cible
    `clean_data.pm_action.org_code` est un varchar(8) : une organisation plus
    longue ferait echouer l'ETL PM Actions, pas seulement l'ecran.

La validation est une fonction pure : testable sans base ni Flask.
"""
import pytest

from api.pe_tools_organisation import ORG_CODE_MAX, valider_regle


def test_code_et_organisation_sont_normalises():
    """Le code est le segment "7.<CODE>.csv" du nom de fichier, compare en
    majuscules par public.pe_tools_code_fichier() : on stocke en majuscules."""
    regle, erreur = valider_regle({'code_fichier': ' mcar ', 'org_code': ' sj-mcar '})
    assert erreur is None
    assert regle['code_fichier'] == 'MCAR'
    assert regle['org_code'] == 'SJ-MCAR'


def test_description_vide_devient_nulle():
    regle, erreur = valider_regle({'code_fichier': 'MCAR', 'org_code': 'SJ-MCAR', 'description': '   '})
    assert erreur is None
    assert regle['description'] is None


def test_is_active_par_defaut_vrai():
    regle, _ = valider_regle({'code_fichier': 'MCAR', 'org_code': 'SJ-MCAR'})
    assert regle['is_active'] is True
    regle, _ = valider_regle({'code_fichier': 'MCAR', 'org_code': 'SJ-MCAR', 'is_active': False})
    assert regle['is_active'] is False


@pytest.mark.parametrize('code', ['', '   ', None])
def test_code_fichier_obligatoire(code):
    _, erreur = valider_regle({'code_fichier': code, 'org_code': 'SJ-MCAR'})
    assert erreur and 'code' in erreur.lower()


@pytest.mark.parametrize('org', ['', '   ', None])
def test_organisation_obligatoire(org):
    """Pas de repli generique : une organisation vide doit etre refusee, sinon
    l'import poserait une organisation NULL sans que personne le voie."""
    _, erreur = valider_regle({'code_fichier': 'MCAR', 'org_code': org})
    assert erreur and 'organisation' in erreur.lower()


def test_organisation_limitee_a_huit_caracteres():
    """CHECK de la migration 077 : pm_action.org_code est un varchar(8)."""
    _, erreur = valider_regle({'code_fichier': 'MCAR', 'org_code': 'SJ-MCARLONG'})
    assert erreur and str(ORG_CODE_MAX) in erreur
    _, erreur = valider_regle({'code_fichier': 'MCAR', 'org_code': 'A' * ORG_CODE_MAX})
    assert erreur is None


def test_code_fichier_sans_caractere_interdit():
    """Le code vient d'un nom de fichier : espaces et points le rendraient
    introuvable par public.pe_tools_code_fichier()."""
    _, erreur = valider_regle({'code_fichier': 'MC AR', 'org_code': 'SJ-MCAR'})
    assert erreur and 'code' in erreur.lower()
    _, erreur = valider_regle({'code_fichier': 'MCAR.1', 'org_code': 'SJ-MCAR'})
    assert erreur
